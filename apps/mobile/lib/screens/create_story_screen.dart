import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../config.dart';
import '../local/create_draft.dart';
import '../local/local_store.dart';
import '../local/network_errors.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import '../utils/child_age.dart';
import 'children_manage_screen.dart';
import 'creating_story_screen.dart';
import 'voice_picker_sheet.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key, required this.api, this.localStore});

  final ApiClient api;
  final LocalStore? localStore;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final themeCtrl = TextEditingController();
  final recapCtrl = TextEditingController();

  String language = 'zh';
  String? birthDate;
  String gender = 'unspecified';
  String nickname = '';
  List<String> interests = [];
  List<Map<String, dynamic>> children = [];

  /// Listeners selected for tonight (multi-select when 2+ children).
  final Set<int> selectedChildIds = {};

  String wonder = 'soft';
  String dialogue = 'some';
  int duration = 5;
  /// Not exposed in UI; preserved so saving voice id does not reset TTS prefs.
  String _speedTier = 'medium';
  String _tonePreset = 'gentle';
  bool softSeries = false;
  int? continueSeriesId;
  int episodeCount = 4;
  bool busy = false;
  bool preparing = true;
  bool moreOptionsOpen = false;
  /// AppBar title fades in after the page hero title scrolls away.
  double _appBarTitleOpacity = 0;
  String? quotaText;
  int storyUsed = 0;
  int storyLimit = 0;
  int? childId;
  int? voiceId;
  List<Map<String, dynamic>> voices = [];
  /// Roster for the primary listener (child + person + toy).
  List<Map<String, dynamic>> rosterCharacters = [];
  final Set<int> selectedCharacterIds = {};

  static const genders = [
    ('unspecified', '不指定'),
    ('boy', '男孩'),
    ('girl', '女孩'),
  ];

  /// everyday | soft | fantasy — 生活向 ↔ 想象力
  static const wonders = [
    ('everyday', '日常生活'),
    ('soft', '一点想象'),
    ('fantasy', '奇妙世界'),
  ];
  /// low | some | more
  static const dialogues = [
    ('low', '很少对话'),
    ('some', '一点对话'),
    ('more', '对话多些'),
  ];
  static const languages = [
    ('zh', '中文'),
    ('en', 'English'),
  ];
  /// Discrete duration ticks (minutes).
  static const durationTicks = [3, 5, 8, 10, 12];

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Map<String, dynamic>? get _selectedVoice {
    if (voiceId == null) return null;
    for (final v in voices) {
      if (_asId(v['id']) == voiceId) return v;
    }
    return null;
  }

  Future<void> _openVoicePicker() async {
    final picked = await showVoicePickerSheet(
      context: context,
      voices: voices,
      selectedId: voiceId,
    );
    if (picked == null || !mounted) return;
    setState(() => voiceId = picked);
  }

  int? _asId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  String _genderLabel(String? id) {
    for (final (gid, label) in genders) {
      if (gid == id) return label;
    }
    if (id == 'other') return '其他';
    return '不指定';
  }

  Map<String, dynamic>? _characterById(int id) {
    for (final c in rosterCharacters) {
      if (_asId(c['id']) == id) return c;
    }
    return null;
  }

  /// API only accepts characters belonging to the primary listener.
  List<int> _characterIdsForApi() {
    final primary = childId;
    if (primary == null) return const [];
    final out = <int>[];
    for (final id in selectedCharacterIds) {
      final c = _characterById(id);
      if (c == null) continue;
      if (_asId(c['related_child_id']) == primary) out.add(id);
    }
    return out;
  }

  /// Names of selected cast that cannot go on the primary child_id.
  List<String> _extraCastKeywords() {
    final primary = childId;
    if (primary == null) return const [];
    final names = <String>[];
    for (final id in selectedCharacterIds) {
      final c = _characterById(id);
      if (c == null) continue;
      if (_asId(c['related_child_id']) == primary) continue;
      final name = (c['name'] as String?)?.trim() ?? '';
      if (name.isNotEmpty) names.add(name);
    }
    if (names.isEmpty) return const [];
    return ['今晚一起出场：${names.join('、')}'];
  }

  Map<String, dynamic>? _childById(int id) {
    for (final c in children) {
      if (_asId(c['id']) == id) return c;
    }
    return null;
  }

  /// Primary listener: first selected in roster order (drives API child_id / voice / roster).
  int? get _primaryChildId {
    for (final c in children) {
      final id = _asId(c['id']);
      if (id != null && selectedChildIds.contains(id)) return id;
    }
    return selectedChildIds.isEmpty ? null : selectedChildIds.first;
  }

  void _applyChild(Map<String, dynamic> c) {
    childId = _asId(c['id']);
    nickname = (c['nickname'] as String?)?.trim().isNotEmpty == true
        ? (c['nickname'] as String).trim()
        : '';
    birthDate = c['birth_date'] as String?;
    gender = c['gender'] as String? ?? gender;
    interests = (c['interests'] as List<dynamic>? ?? []).cast<String>();
    unawaited(_loadRosterForChild());
  }

  void _clearChildSelection() {
    childId = null;
    nickname = '';
    interests = [];
    gender = 'unspecified';
    birthDate = null;
    voiceId = null;
    voices = [];
    rosterCharacters = [];
    selectedCharacterIds.clear();
    selectedChildIds.clear();
  }

  Future<void> _syncPrimaryFromSelection() async {
    final primary = _primaryChildId;
    if (primary == null) {
      _clearChildSelection();
      if (mounted) setState(() {});
      return;
    }
    if (primary == childId) return;
    final c = _childById(primary);
    if (c == null) return;
    _applyChild(c);
    if (mounted) setState(() {});
    await _reloadVoicePrefs();
  }

  Future<void> _toggleChildSelection(int id) async {
    setState(() {
      if (selectedChildIds.contains(id)) {
        if (selectedChildIds.length <= 1) return; // keep at least one
        selectedChildIds.remove(id);
      } else {
        selectedChildIds.add(id);
      }
      _syncChildCastWithListeners();
    });
    await _syncPrimaryFromSelection();
    unawaited(_saveDraft());
  }

  /// Keep kind=child cast chips in sync with selected little listeners only.
  void _syncChildCastWithListeners() {
    final keepNonChild = <int>{};
    for (final id in selectedCharacterIds) {
      final c = _characterById(id);
      if (c != null && c['kind'] != 'child') keepNonChild.add(id);
    }
    final listenerCast = rosterCharacters
        .where(
          (c) =>
              c['kind'] == 'child' &&
              selectedChildIds.contains(_asId(c['related_child_id'])),
        )
        .map((c) => _asId(c['id']))
        .whereType<int>();
    selectedCharacterIds
      ..clear()
      ..addAll(keepNonChild)
      ..addAll(listenerCast);
  }

  Future<void> _loadRosterForChild() async {
    // Load full roster so「今晚一起出场」lists every little listener twin,
    // not only the primary child's characters.
    try {
      List<Map<String, dynamic>> listed;
      final store = widget.localStore;
      if (store != null) {
        listed = await store.characters.refresh();
      } else {
        listed = (await widget.api.listCharacters()).cast<Map<String, dynamic>>();
      }
      if (!mounted) return;
      final validIds = listed.map((c) => _asId(c['id'])).whereType<int>().toSet();
      setState(() {
        rosterCharacters = listed;
        selectedCharacterIds.removeWhere((id) => !validIds.contains(id));
        _syncChildCastWithListeners();
      });
    } catch (_) {
      // Roster is optional for create.
    }
  }

  Future<void> _restoreDraft() async {
    final store = widget.localStore;
    if (store == null) return;
    final draft = await CreateDraft.load(store.userId);
    if (draft == null || !mounted) return;
    setState(() {
      final draftChild = _asId(draft['child_id']);
      if (draftChild != null) {
        childId = draftChild;
        selectedChildIds
          ..clear()
          ..add(draftChild);
      }
      final ids = draft['child_ids'];
      if (ids is List) {
        selectedChildIds
          ..clear()
          ..addAll(ids.map(_asId).whereType<int>());
      }
      final t = draft['theme'] as String?;
      if (t != null) themeCtrl.text = t;
      final d = draft['duration'] as int?;
      if (d != null) duration = d;
      final w = draft['wonder'] as String?;
      if (w != null) wonder = w;
      final dlg = draft['dialogue'] as String?;
      if (dlg != null) dialogue = dlg;
      // English stories are not ready on the backend yet — keep UI entry, force zh.
      language = 'zh';
      softSeries = kFeatureSoftSeries
          ? (draft['soft_series'] as bool? ?? softSeries)
          : false;
    });
  }

  Future<void> _saveDraft() async {
    final store = widget.localStore;
    if (store == null) return;
    await CreateDraft.save(store.userId, {
      'child_id': childId,
      'child_ids': selectedChildIds.toList(),
      'theme': themeCtrl.text,
      'duration': duration,
      'wonder': wonder,
      'dialogue': dialogue,
      'language': language,
      'soft_series': softSeries,
    });
  }

  void _applyQuotaMap(Map<String, dynamic> q) {
    storyUsed = (q['story_used'] as num?)?.toInt() ?? 0;
    storyLimit = (q['story_limit'] as num?)?.toInt() ?? 0;
    final story = '本月故事 $storyUsed/$storyLimit';
    quotaText = kFeatureVoiceClone
        ? '$story · 克隆 ${q['clone_used']}/${q['clone_limit']}'
        : story;
  }

  String get _voiceSummaryName {
    final v = _selectedVoice;
    final name = (v?['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return voices.isEmpty ? '未选音色' : '请选音色';
  }

  String get _languageLabel => language == 'en' ? 'English' : '中文';

  String get _moreOptionsSummary => '$_languageLabel · ${_dialogueLabel()}';

  String _dialogueLabel() {
    for (final (id, label) in dialogues) {
      if (id == dialogue) return label;
    }
    return '一点对话';
  }

  String _durationMoodLabel(int minutes) {
    switch (minutes) {
      case 3:
        return '3 分钟 · 短篇微睡';
      case 5:
        return '5 分钟 · 适合入睡';
      case 8:
        return '8 分钟 · 沉浸暖梦';
      case 10:
        return '10 分钟 · 悠长童话';
      case 12:
        return '12 分钟 · 深度安歇';
      default:
        return '$minutes 分钟';
    }
  }

  Future<void> _prepare() async {
    setState(() => preparing = true);
    final store = widget.localStore;
    try {
      await _restoreDraft();

      List<Map<String, dynamic>> listed;
      if (store != null) {
        listed = await store.children.refresh();
      } else {
        listed = (await widget.api.listChildren()).cast<Map<String, dynamic>>();
      }
      children = listed;
      if (children.isEmpty) {
        _clearChildSelection();
      } else {
        final validIds = children.map((c) => _asId(c['id'])).whereType<int>().toSet();
        selectedChildIds.removeWhere((id) => !validIds.contains(id));
        if (selectedChildIds.isEmpty) {
          final fallback = childId != null && validIds.contains(childId)
              ? childId!
              : validIds.first;
          selectedChildIds.add(fallback);
        }
        final primary = _primaryChildId!;
        final keep = _childById(primary) ?? children.first;
        _applyChild(keep);
      }

      if (store != null) {
        final snap = await store.account.refresh();
        final q = snap?['quota'] as Map<String, dynamic>?;
        if (q != null) _applyQuotaMap(q);
      } else {
        final q = await widget.api.quota();
        _applyQuotaMap(q);
      }

      // No child yet: stop after quota; UI prompts to create a profile.
      if (childId == null) {
        return;
      }

      Map<String, dynamic>? system;
      try {
        system = await widget.api.ensureSystemVoice();
      } catch (_) {
        // All system voices may be disabled; still load clones / other enabled voices.
        system = null;
      }

      if (store != null) {
        voices = await store.voices.refresh();
      } else {
        final voiceList = await widget.api.listVoices();
        voices = voiceList.cast<Map<String, dynamic>>();
      }
      if (!kFeatureVoiceClone) {
        voices = voices.where((v) => v['kind'] != 'clone').toList();
      }
      if (voices.isEmpty && system != null) {
        voices = [system];
      }

      Map<String, dynamic>? prefs;
      if (store != null) {
        prefs = await store.voices.refreshVoicePrefs(childId!);
      } else {
        try {
          prefs = await widget.api.getVoicePrefs(childId!);
        } catch (_) {
          prefs = null;
        }
      }
      final prefVoiceId = _asId(prefs?['default_voice_id']);
      final prefSpeed = prefs?['speed_tier'] as String?;
      final prefTone = prefs?['tone_preset'] as String?;
      if (prefSpeed is String && prefSpeed.isNotEmpty) _speedTier = prefSpeed;
      if (prefTone is String && prefTone.isNotEmpty) _tonePreset = prefTone;

      int? chosen;
      if (prefVoiceId != null && voices.any((v) => _asId(v['id']) == prefVoiceId)) {
        chosen = prefVoiceId;
      } else {
        Map<String, dynamic>? clone;
        if (kFeatureVoiceClone) {
          for (final v in voices) {
            if (v['kind'] == 'clone') {
              clone = v;
              break;
            }
          }
        }
        chosen = _asId(clone?['id']) ?? _asId(system?['id']);
      }
      voiceId = chosen;
      await _saveDraft();
    } catch (e) {
      // Keep cached child selection if we already applied one.
      if (!mounted) return;
      if (children.isEmpty) childId = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyNetworkError(e))),
      );
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Future<void> _openChildEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChildrenManageScreen(api: widget.api)),
    );
    if (!mounted) return;
    await _prepare();
  }

  List<String> _companionListenerKeywords() {
    final primary = childId;
    if (primary == null || selectedChildIds.length <= 1) return const [];
    final names = <String>[];
    for (final c in children) {
      final id = _asId(c['id']);
      if (id == null || id == primary || !selectedChildIds.contains(id)) continue;
      final n = (c['nickname'] as String?)?.trim() ?? '';
      if (n.isNotEmpty) names.add(n);
    }
    if (names.isEmpty) return const [];
    return ['今晚也讲给：${names.join('、')}'];
  }

  Future<void> _generate() async {
    if (children.isEmpty || childId == null || selectedChildIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加孩子档案')),
      );
      await _openChildEditor();
      return;
    }
    if (nickname.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完善孩子昵称（点档案卡片编辑）')),
      );
      return;
    }
    if (voiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择音色（或先到「音色」页创建系统音色）')),
      );
      return;
    }

    final theme = themeCtrl.text.trim();
    final keywords = [
      ..._companionListenerKeywords(),
      ..._extraCastKeywords(),
    ];

    setState(() => busy = true);
    try {
      await widget.api.updateVoicePrefs(
        childId: childId!,
        speedTier: _speedTier,
        tonePreset: _tonePreset,
        likenessBoost: false,
        defaultVoiceId: voiceId,
      );
      final created = await widget.api.createStory(
        childId: childId!,
        theme: theme,
        language: language,
        durationMinutes: duration,
        voiceId: voiceId,
        softSeriesMode: kFeatureSoftSeries &&
            (softSeries || continueSeriesId != null),
        seriesId: kFeatureSoftSeries ? continueSeriesId : null,
        episodeCount: episodeCount,
        keywords: keywords,
        characterIds: _characterIdsForApi(),
        childCastRole: 'auto',
        recap: kFeatureSoftSeries &&
                softSeries &&
                recapCtrl.text.trim().isNotEmpty
            ? recapCtrl.text.trim()
            : null,
        wonder: wonder,
        dialogue: dialogue,
      );
      await widget.localStore?.stories.upsertOne(created);
      if (widget.localStore != null) {
        unawaited(CreateDraft.clear(widget.localStore!.userId));
      }
      if (!mounted) return;

      final id = created['id'];
      final storyId = id is int ? id : int.tryParse('$id');
      if (storyId == null) {
        throw ApiException('故事创建失败');
      }

      final status = created['status'] as String? ?? '';
      if (status == 'failed') {
        throw ApiException(
          created['error_message'] as String? ?? '故事生成失败',
          storyId: storyId,
        );
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CreatingStoryScreen(
            api: widget.api,
            localStore: widget.localStore,
            storyId: storyId,
            initialStory: created,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyNetworkError(e))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_saveDraft());
    themeCtrl.dispose();
    recapCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (preparing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (children.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandHeader(
                title: '先添加小听众',
                subtitle: quotaText ?? '有了孩子档案，才能定制今晚的故事',
              ),
              const SizedBox(height: 24),
              SectionCard(
                title: '还没有角色',
                child: Text(
                  '请先创建孩子档案（昵称、年龄等）。创建后即可回来生成故事。',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const Spacer(),
              AmberCta(
                label: '去添加孩子档案',
                onPressed: _openChildEditor,
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: AnimatedOpacity(
          opacity: _appBarTitleOpacity,
          duration: const Duration(milliseconds: 120),
          child: const Text('定制今晚的故事'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onCreateScroll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _buildCreateHeader(context),
                  const SizedBox(height: 18),
                  _buildListenersCard(context),
                  const SizedBox(height: 14),
                  _buildStoryOptionsCard(context),
                  const SizedBox(height: 14),
                  _buildMoreOptions(context),
                  const SizedBox(height: 14),
                  _buildDreamRulesCard(context),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.92),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xB3070A12),
                  blurRadius: 32,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AmberCta(
                  label: busy ? '生成中…' : '生成今晚的故事',
                  busy: busy,
                  onPressed: busy ? null : _generate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _onCreateScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    // Fade AppBar title in once the hero headline has mostly scrolled off.
    final next = (notification.metrics.pixels / 56).clamp(0.0, 1.0);
    if ((next - _appBarTitleOpacity).abs() >= 0.05 ||
        (next == 0 && _appBarTitleOpacity != 0) ||
        (next == 1 && _appBarTitleOpacity != 1)) {
      setState(() => _appBarTitleOpacity = next);
    }
    return false;
  }

  Widget _buildCreateHeader(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final progress = storyLimit <= 0
        ? 0.0
        : (storyUsed / storyLimit).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandMark(),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text('定制今晚的故事', style: tt.headlineMedium),
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: tt.labelMedium?.copyWith(color: AppColors.onSurfaceMuted),
                children: [
                  const TextSpan(text: '本月故事 '),
                  TextSpan(
                    text: '$storyUsed',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: '/$storyLimit',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: AppColors.surfaceHigh,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildListenersCard(BuildContext context) {
    final multi = children.length > 1;
    return SectionCard(
      title: '今晚，讲给谁听？',
      subtitle: multi ? '可多选；故事会以小听众的偏好来编织' : '故事会以小听众偏好来编织',
      trailing: IconButton(
        tooltip: '管理小听众档案',
        onPressed: _openChildEditor,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfacePaperLayered,
          side: const BorderSide(color: AppColors.outlineSubtle),
        ),
        icon: const Icon(Icons.manage_accounts_outlined, size: 18, color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (multi)
            for (final c in children) ...[
              _listenerSelectTile(context, c),
              const SizedBox(height: 10),
            ]
          else
            _listenerProfileTile(context, children.first),
        ],
      ),
    );
  }

  Widget _listenerSelectTile(BuildContext context, Map<String, dynamic> c) {
    final id = _asId(c['id']);
    if (id == null) return const SizedBox.shrink();
    final selected = selectedChildIds.contains(id);
    final isPrimary = id == childId;
    final name = (c['nickname'] as String?)?.trim().isNotEmpty == true
        ? (c['nickname'] as String).trim()
        : '未命名';
    final g = c['gender'] as String? ?? 'unspecified';
    final bd = c['birth_date'] as String?;
    final tags = (c['interests'] as List<dynamic>? ?? []).cast<String>();
    final tagLine = tags.isEmpty ? '暂无特殊标签 · 偏爱睡前童话' : tags.take(4).join(' · ');

    return Material(
      color: selected ? AppColors.surfacePaperLayered : AppColors.inputWell,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => unawaited(_toggleChildSelection(id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _avatarBubble(name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name, style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (isPrimary && selected) ...[
                          const SizedBox(width: 8),
                          Text(
                            '主听众',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.primarySoft,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    _ageGenderPill(g, bd),
                    const SizedBox(height: 6),
                    Text(
                      tagLine,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.onSurfaceDim,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listenerProfileTile(BuildContext context, Map<String, dynamic> c) {
    final name = (c['nickname'] as String?)?.trim().isNotEmpty == true
        ? (c['nickname'] as String).trim()
        : (nickname.isEmpty ? '未命名' : nickname);
    final g = c['gender'] as String? ?? gender;
    final bd = c['birth_date'] as String? ?? birthDate;
    final tags = (c['interests'] as List<dynamic>? ?? interests);
    final tagLine = tags.isEmpty
        ? '暂无特殊标签 · 偏爱睡前童话'
        : tags.take(4).map((e) => '$e').join(' · ');

    return Material(
      color: AppColors.surfacePaperLayered,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openChildEditor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _avatarBubble(name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    _ageGenderPill(g, bd),
                    const SizedBox(height: 6),
                    Text(tagLine, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.onSurfaceMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarBubble(String name) {
    final ch = name.isEmpty ? '?' : String.fromCharCode(name.runes.first);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A3A4F), Color(0xFF3A2A22)],
        ),
        border: Border.all(color: AppColors.outlineSubtle),
      ),
      alignment: Alignment.center,
      child: Text(
        ch,
        style: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.primarySoft,
        ),
      ),
    );
  }

  Widget _ageGenderPill(String g, String? bd) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${_genderLabel(g)} · ${formatAgeYearsLabel(bd)}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.secondary,
        ),
      ),
    );
  }

  Widget _sectionLabel(
    BuildContext context,
    IconData icon,
    String label, {
    String? hint,
    Widget? action,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Expanded(
          child: hint == null
              ? const SizedBox.shrink()
              : Text(
                  hint,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                        fontWeight: FontWeight.w400,
                      ),
                ),
        ),
        if (action != null) ...[
          const SizedBox(width: 8),
          action,
        ],
      ],
    );
  }

  Widget _buildStoryOptionsCard(BuildContext context) {
    return SectionCard(
      title: '想听什么故事？',
      subtitle: '故事将依据这些要素来创作',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(
            context,
            Icons.auto_stories_outlined,
            '故事灵感',
            hint: '留空即由系统织梦',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: themeCtrl,
            decoration: const InputDecoration(
              hintText: '今晚想讲什么（可选，例如：在云朵上看星星的小猫咪…）',
            ),
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => unawaited(_saveDraft()),
          ),
          const SizedBox(height: 22),
          _sectionLabel(
            context,
            Icons.groups_outlined,
            '今晚一起出场',
            action: TextButton(
              onPressed: _openChildEditor,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('添加角色'),
            ),
          ),
          const SizedBox(height: 10),
          if (rosterCharacters.isEmpty)
            Text(
              '可在角色管理中添加小听众、家人或玩具。',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in rosterCharacters)
                  Builder(
                    builder: (context) {
                      final cid = _asId(c['id']);
                      if (cid == null) return const SizedBox.shrink();
                      final kind = c['kind'] as String? ?? '';
                      final name = (c['name'] as String?)?.trim() ?? '';
                      final rel = (c['relation'] as String?)?.trim();
                      final label = kind == 'person' &&
                              rel != null &&
                              rel.isNotEmpty
                          ? '$name（$rel）'
                          : name;
                      final selected = selectedCharacterIds.contains(cid);
                      return SoftChip(
                        label: label.isEmpty ? '角色' : label,
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            if (selected) {
                              selectedCharacterIds.remove(cid);
                            } else if (selectedCharacterIds.length < 8) {
                              selectedCharacterIds.add(cid);
                            }
                          });
                        },
                      );
                    },
                  ),
              ],
            ),
          const SizedBox(height: 22),
          _sectionLabel(context, Icons.auto_awesome_outlined, '故事类型'),
          const SizedBox(height: 10),
          _wonderSegmented(),
          const SizedBox(height: 22),
          _durationTickPicker(),
          const SizedBox(height: 22),
          _sectionLabel(
            context,
            Icons.graphic_eq,
            '朗读音色',
            hint: '已选：$_voiceSummaryName',
          ),
          const SizedBox(height: 10),
          Material(
            color: AppColors.inputWell,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: InkWell(
              onTap: voices.isEmpty ? null : _openVoicePicker,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final v = _selectedVoice;
                          final tt = Theme.of(context).textTheme;
                          final name = _voiceSummaryName;
                          final desc =
                              (v?['description'] as String?)?.trim() ?? '';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: tt.titleMedium),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    Text(
                      '更换',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.primarySoft,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wonderSegmented() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Row(
        children: [
          for (final (id, label) in wonders)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: wonder == id
                      ? AppColors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  elevation: wonder == id ? 2 : 0,
                  shadowColor: AppColors.lanternGlow,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    onTap: () {
                      setState(() => wonder = id);
                      unawaited(_saveDraft());
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              wonder == id ? FontWeight.w700 : FontWeight.w500,
                          color: wonder == id
                              ? AppColors.onPrimaryContainer
                              : AppColors.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoreOptions(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.outlineSubtle),
        boxShadow: const [
          BoxShadow(
            color: AppColors.paperShadow,
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              onTap: () => setState(() => moreOptionsOpen = !moreOptionsOpen),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '更多选项（语言与对话）',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Text(
                      _moreOptionsSummary,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      moreOptionsOpen ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.onSurfaceMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (moreOptionsOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel(context, Icons.translate, '讲述语言'),
                    const SizedBox(height: 10),
                    _wonderLikeSegment(
                      options: languages,
                      selected: language,
                      disabledIds: const {'en'},
                      onDisabledTap: (id) {
                        if (id == 'en') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('英文故事暂未开放，敬请期待'),
                            ),
                          );
                        }
                      },
                      onSelect: (v) {
                        language = v;
                        unawaited(_saveDraft());
                      },
                    ),
                    const SizedBox(height: 22),
                    _sectionLabel(context, Icons.forum_outlined, '对话多少'),
                    const SizedBox(height: 10),
                    _wonderLikeSegment(
                      options: dialogues,
                      selected: dialogue,
                      onSelect: (v) {
                        dialogue = v;
                        unawaited(_saveDraft());
                      },
                    ),
                    if (kFeatureSoftSeries) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('软系列（可续写）'),
                        value: softSeries,
                        onChanged: (v) => setState(() {
                          softSeries = v;
                          if (!v) continueSeriesId = null;
                          unawaited(_saveDraft());
                        }),
                      ),
                      if (softSeries) ...[
                        TextField(
                          controller: recapCtrl,
                          decoration: const InputDecoration(
                            labelText: '上一集轻钩子（可选）',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SoftSelectField<int>(
                          label: '系列集数',
                          value: episodeCount,
                          options: [
                            for (final n in [2, 3, 4, 5, 6, 7, 8]) (n, '$n'),
                          ],
                          onChanged: (v) => setState(() => episodeCount = v),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _wonderLikeSegment({
    required List<(String, String)> options,
    required String selected,
    required void Function(String) onSelect,
    Set<String> disabledIds = const {},
    void Function(String id)? onDisabledTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.inputWell,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Row(
        children: [
          for (final (id, label) in options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Builder(
                  builder: (context) {
                    final disabled = disabledIds.contains(id);
                    final active = !disabled && selected == id;
                    return Material(
                      color: active
                          ? AppColors.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        onTap: () {
                          if (disabled) {
                            onDisabledTap?.call(id);
                            return;
                          }
                          setState(() => onSelect(id));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: disabled
                                  ? AppColors.onSurfaceDim.withValues(alpha: 0.55)
                                  : active
                                      ? AppColors.onPrimaryContainer
                                      : AppColors.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDreamRulesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.outlineSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A3A4F), Color(0xFF3A2A22)],
              ),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '织梦守则',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '故事将自动调节平静舒缓的语言节奏，末尾缓缓淡入晚安白噪音。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadVoicePrefs() async {
    if (childId == null) return;
    try {
      final prefs = await widget.api.getVoicePrefs(childId!);
      final prefVoiceId = _asId(prefs['default_voice_id']);
      final prefSpeed = prefs['speed_tier'] as String?;
      final prefTone = prefs['tone_preset'] as String?;
      if (!mounted) return;
      setState(() {
        if (prefSpeed is String && prefSpeed.isNotEmpty) _speedTier = prefSpeed;
        if (prefTone is String && prefTone.isNotEmpty) _tonePreset = prefTone;
        if (prefVoiceId != null &&
            voices.any((v) => _asId(v['id']) == prefVoiceId)) {
          voiceId = prefVoiceId;
        }
      });
    } catch (_) {}
  }

  Widget _durationTickPicker() {
    final ticks = durationTicks;
    var idx = ticks.indexOf(duration);
    if (idx < 0) idx = ticks.indexOf(5).clamp(0, ticks.length - 1);
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bedtime_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('时长 (分钟)', style: tt.labelLarge),
            const Spacer(),
            Text(
              _durationMoodLabel(duration),
              style: tt.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.surfaceHighest,
            thumbColor: AppColors.primaryContainer,
            overlayColor: AppColors.primary.withValues(alpha: 0.18),
            activeTickMarkColor: AppColors.onPrimary,
            inactiveTickMarkColor: AppColors.onSurfaceDim,
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: idx.toDouble(),
            min: 0,
            max: (ticks.length - 1).toDouble(),
            divisions: ticks.length - 1,
            onChanged: (v) {
              setState(() => duration = ticks[v.round()]);
              unawaited(_saveDraft());
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final m in ticks)
                Text(
                  '$m',
                  style: tt.labelSmall?.copyWith(
                    color: m == duration
                        ? AppColors.primary
                        : AppColors.onSurfaceDim,
                    fontWeight:
                        m == duration ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
