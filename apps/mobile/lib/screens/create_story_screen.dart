import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../config.dart';
import '../data/chip_cache.dart';
import '../data/create_fallbacks.dart';
import '../local/create_draft.dart';
import '../local/local_store.dart';
import '../local/network_errors.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import '../utils/child_age.dart';
import 'children_manage_screen.dart';
import 'player_screen.dart';
import 'voice_picker_sheet.dart';

class _ChipOpt {
  const _ChipOpt({
    required this.key,
    required this.label,
    this.focusId,
    this.serverId,
  });

  final String key;
  final String label;
  final String? focusId;
  /// Non-null when backed by a real catalog row (elements).
  final String? serverId;
}

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key, required this.api, this.localStore});

  final ApiClient api;
  final LocalStore? localStore;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final themeCtrl = TextEditingController();
  final keywordsCtrl = TextEditingController();
  final recapCtrl = TextEditingController();

  String language = 'zh';
  /// Internal bucket for suggestion APIs only — never shown in UI.
  String ageBand = '3-5';
  String? birthDate;
  String gender = 'unspecified';
  String nickname = '';
  List<String> interests = [];
  List<Map<String, dynamic>> children = [];

  List<_ChipOpt> inspirationChips = [];
  List<_ChipOpt> thingChips = [];
  /// null = 自动
  String? selectedInspirationKey;
  String? selectedThingKey;

  String childCastRole = 'auto';
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
  bool chipsLoading = false;
  String? quotaText;
  String? progressText;
  int? childId;
  int? voiceId;
  List<Map<String, dynamic>> voices = [];
  /// Roster for the selected listener (child + person + toy).
  List<Map<String, dynamic>> rosterCharacters = [];
  final Set<int> selectedCharacterIds = {};

  static const genders = [
    ('girl', '女孩'),
    ('boy', '男孩'),
    ('other', '其他'),
    ('unspecified', '不指定'),
  ];

  static const castRoles = [
    ('auto', '自动'),
    ('protagonist', '孩子主角'),
    ('supporting', '孩子配角'),
    ('absent', '不出现孩子'),
  ];

  /// everyday | soft | fantasy — 生活向 ↔ 想象力
  static const wonders = [
    ('everyday', '生活向'),
    ('soft', '轻想象'),
    ('fantasy', '更幻想'),
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
    return '不指定';
  }

  String get _interestsSummary {
    if (interests.isEmpty) return '暂无兴趣标签';
    return interests.take(4).join(' · ');
  }

  void _applyChild(Map<String, dynamic> c) {
    childId = _asId(c['id']);
    nickname = (c['nickname'] as String?)?.trim().isNotEmpty == true
        ? (c['nickname'] as String).trim()
        : '';
    birthDate = c['birth_date'] as String?;
    ageBand = c['age_band'] as String? ?? ageBand;
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
    ageBand = '3-5';
    voiceId = null;
    voices = [];
    inspirationChips = [];
    thingChips = [];
    selectedInspirationKey = null;
    selectedThingKey = null;
    rosterCharacters = [];
    selectedCharacterIds.clear();
  }

  Future<void> _loadRosterForChild() async {
    final id = childId;
    if (id == null) {
      if (mounted) {
        setState(() {
          rosterCharacters = [];
          selectedCharacterIds.clear();
        });
      }
      return;
    }
    try {
      List<Map<String, dynamic>> listed;
      final store = widget.localStore;
      if (store != null) {
        listed = await store.characters.refresh(relatedChildId: id);
      } else {
        listed = (await widget.api.listCharacters(relatedChildId: id))
            .cast<Map<String, dynamic>>();
      }
      if (!mounted) return;
      setState(() {
        rosterCharacters = listed;
        // Default-select the listener twin (kind=child).
        selectedCharacterIds
          ..clear()
          ..addAll(
            listed
                .where((c) => c['kind'] == 'child')
                .map((c) => _asId(c['id']))
                .whereType<int>(),
          );
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
      if (draftChild != null) childId = draftChild;
      final t = draft['theme'] as String?;
      if (t != null) themeCtrl.text = t;
      final d = draft['duration'] as int?;
      if (d != null) duration = d;
      final w = draft['wonder'] as String?;
      if (w != null) wonder = w;
      final dlg = draft['dialogue'] as String?;
      if (dlg != null) dialogue = dlg;
      final cast = draft['child_cast_role'] as String?;
      if (cast != null) childCastRole = cast;
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
      'theme': themeCtrl.text,
      'duration': duration,
      'wonder': wonder,
      'dialogue': dialogue,
      'child_cast_role': childCastRole,
      'soft_series': softSeries,
    });
  }

  void _applyQuotaMap(Map<String, dynamic> q) {
    final story = '本月故事 ${q['story_used']}/${q['story_limit']}';
    quotaText = kFeatureVoiceClone
        ? '$story · 克隆 ${q['clone_used']}/${q['clone_limit']}'
        : story;
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
        final keep = childId != null
            ? children.cast<Map<String, dynamic>?>().firstWhere(
                  (c) => _asId(c?['id']) == childId,
                  orElse: () => null,
                )
            : null;
        _applyChild(keep ?? children.first);
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

      await _loadSuggestionChips();

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

  Future<void> _loadSuggestionChips() async {
    if (childId == null) return;
    setState(() => chipsLoading = true);
    try {
      List<Map<String, dynamic>>? kRows;
      List<Map<String, dynamic>>? eRows;
      try {
        final results = await Future.wait([
          widget.api.listKernels(ageBand: ageBand, limit: 12, childId: childId),
          widget.api.listElementSuggestions(ageBand: ageBand, limit: 12, childId: childId),
        ]);
        kRows = results[0];
        eRows = results[1];
      } catch (_) {
        // network / timeout → cache below
      }

      if (kRows != null && kRows.isNotEmpty) {
        await ChipCache.save('kernels', ageBand, kRows);
      } else {
        kRows = await ChipCache.load('kernels', ageBand);
      }
      if (eRows != null && eRows.isNotEmpty) {
        await ChipCache.save('elements', ageBand, eRows);
      } else {
        eRows = await ChipCache.load('elements', ageBand);
      }

      final insp = <_ChipOpt>[];
      if (kRows != null && kRows.isNotEmpty) {
        for (final r in kRows) {
          final focus = (r['focus_id'] as String?) ?? '';
          final name = (r['name'] as String?) ?? '';
          final id = (r['id'] as String?) ?? focus;
          if (focus.isEmpty || name.isEmpty) continue;
          insp.add(_ChipOpt(key: id, label: name, focusId: focus, serverId: id));
        }
      }
      if (insp.isEmpty) {
        for (final c in inspirationFallbackFor(ageBand)) {
          insp.add(_ChipOpt(key: c.focusId, label: c.name, focusId: c.focusId));
        }
      }

      final things = <_ChipOpt>[];
      if (eRows != null && eRows.isNotEmpty) {
        for (final r in eRows) {
          final id = (r['id'] as String?) ?? '';
          final name = (r['name'] as String?) ?? '';
          if (id.isEmpty || name.isEmpty) continue;
          things.add(_ChipOpt(key: id, label: name, serverId: id));
        }
      }
      if (things.isEmpty) {
        for (final name in thingFallbackSample(limit: 12, salt: ageBand)) {
          things.add(_ChipOpt(key: 'local_$name', label: name));
        }
      }

      if (!mounted) return;
      setState(() {
        inspirationChips = insp;
        thingChips = things;
        if (selectedInspirationKey != null &&
            !insp.any((c) => c.key == selectedInspirationKey)) {
          selectedInspirationKey = null;
        }
        if (selectedThingKey != null && !things.any((c) => c.key == selectedThingKey)) {
          selectedThingKey = null;
        }
      });
    } finally {
      if (mounted) setState(() => chipsLoading = false);
    }
  }

  Future<void> _openChildEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChildrenManageScreen(api: widget.api)),
    );
    if (!mounted) return;
    await _prepare();
  }

  Future<void> _generate() async {
    if (children.isEmpty || childId == null) {
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

    final insp = selectedInspirationKey == null
        ? null
        : inspirationChips.cast<_ChipOpt?>().firstWhere(
              (c) => c?.key == selectedInspirationKey,
              orElse: () => null,
            );
    final thing = selectedThingKey == null
        ? null
        : thingChips.cast<_ChipOpt?>().firstWhere(
              (c) => c?.key == selectedThingKey,
              orElse: () => null,
            );

    // Free text wins; else chip label; else empty → server fills from tonight's kernel.
    final freeTheme = themeCtrl.text.trim();
    final theme = freeTheme.isNotEmpty ? freeTheme : (insp?.label ?? '');
    // Prefer catalog kernel id so server selects that row (not another with same focus).
    final developmentFocus = insp?.serverId ?? insp?.focusId;

    final keywords = _parseList(keywordsCtrl.text);
    String? storyElementId;
    if (thing != null) {
      if (thing.serverId != null) {
        storyElementId = thing.serverId;
      } else if (!keywords.contains(thing.label)) {
        keywords.insert(0, thing.label);
      }
    }

    setState(() {
      busy = true;
      progressText = '已提交，排队中…';
    });
    try {
      await widget.api.updateVoicePrefs(
        childId: childId!,
        speedTier: _speedTier,
        tonePreset: _tonePreset,
        likenessBoost: false,
        defaultVoiceId: voiceId,
      );
      final story = await widget.api.createStoryAndWait(
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
        characterIds: selectedCharacterIds.toList(),
        developmentFocus: developmentFocus,
        storyElementId: storyElementId,
        childCastRole: childCastRole,
        recap: kFeatureSoftSeries &&
                softSeries &&
                recapCtrl.text.trim().isNotEmpty
            ? recapCtrl.text.trim()
            : null,
        wonder: wonder,
        dialogue: dialogue,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => progressText = _progressLabel(p));
        },
      );
      if (!mounted) return;
      if (kFeatureSoftSeries) {
        final sid = story['series_id'] as int?;
        final ep = story['episode_no'] as int?;
        if (sid != null) {
          setState(() {
            softSeries = true;
            continueSeriesId = sid;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('系列第 ${ep ?? '?'} 集已生成，可再点生成续写下一集')),
            );
          }
        }
      }
      await widget.localStore?.stories.upsertOne(story);
      if (widget.localStore != null) {
        unawaited(CreateDraft.clear(widget.localStore!.userId));
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen.fromStory(
            story,
            localStore: widget.localStore,
          ),
        ),
      );
      try {
        final q = await widget.api.quota();
        if (!mounted) return;
        setState(() => _applyQuotaMap(q));
        final me = await widget.api.me();
        await widget.localStore?.account.saveSnapshot(me: me, quota: q);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      final storyId = e is ApiException ? e.storyId : null;
      final msg = friendlyNetworkError(e);
      if (storyId != null) {
        final isGenFail = msg.contains('生成失败');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            action: SnackBarAction(
              label: isGenFail ? '重试' : '继续等待',
              onPressed: () => unawaited(
                isGenFail ? _retryFailed(storyId) : _resumeWait(storyId),
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progressText = null;
        });
      }
    }
  }

  Future<void> _resumeWait(int storyId) async {
    if (busy) return;
    setState(() {
      busy = true;
      progressText = '继续等待生成…';
    });
    try {
      final story = await widget.api.waitForStory(
        storyId,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => progressText = _progressLabel(p));
        },
      );
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen.fromStory(
            story,
            localStore: widget.localStore,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyNetworkError(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progressText = null;
        });
      }
    }
  }

  Future<void> _retryFailed(int storyId) async {
    if (busy) return;
    setState(() {
      busy = true;
      progressText = '正在重新生成…';
    });
    try {
      final story = await widget.api.retryStoryAndWait(
        storyId,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => progressText = _progressLabel(p));
        },
      );
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen.fromStory(
            story,
            localStore: widget.localStore,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final resumeId = e is ApiException ? e.storyId : storyId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyNetworkError(e)),
          action: SnackBarAction(
            label: '继续等待',
            onPressed: () => unawaited(_resumeWait(resumeId ?? storyId)),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progressText = null;
        });
      }
    }
  }

  String _progressLabel(String progress) {
    switch (progress) {
      case 'queued':
        return '排队中…';
      case 'series_outline':
        return '正在构思系列大纲…';
      case 'episode_plan':
        return '正在构思今晚情节…';
      case 'draft':
        return '正在写故事正文…';
      case 'tts':
        return '正在生成朗读音频…';
      case 'ready':
        return '完成';
      case 'failed':
        return '生成失败';
      default:
        return '生成中（$progress）…';
    }
  }

  List<String> _parseList(String raw) {
    return raw
        .split(RegExp(r'[,，、\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    unawaited(_saveDraft());
    themeCtrl.dispose();
    keywordsCtrl.dispose();
    recapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (preparing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('创作故事'),
          backgroundColor: AppColors.background,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (children.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('创作故事'),
          backgroundColor: AppColors.background,
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandHeader(
                eyebrow: 'Lullvale · Studio',
                title: '先添加小主角',
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
        title: const Text('创作故事'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                BrandHeader(
                  eyebrow: 'Lullvale · Studio',
                  title: '定制今晚的枕边夜话',
                  subtitle: quotaText ?? '温柔、可听、慢慢入睡',
                ),
                const SizedBox(height: 20),
                _buildProfileCard(context),
                const SizedBox(height: 14),
                SectionCard(
                  title: '今晚的故事',
                  subtitle: '点选灵感与轻轻带上的事物；也可自己写一句',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('孩子在故事中的角色', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      _softChipRow(
                        castRoles,
                        childCastRole,
                        (v) => setState(() => childCastRole = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('故事灵感', style: Theme.of(context).textTheme.labelLarge),
                          if (chipsLoading) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      _suggestChipWrap(
                        chips: inspirationChips,
                        selectedKey: selectedInspirationKey,
                        onSelect: (k) => setState(() => selectedInspirationKey = k),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: themeCtrl,
                        decoration: const InputDecoration(
                          labelText: '今晚想讲什么（可选）',
                          hintText: '不写也行，点灵感或交给我们安排',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('今晚一起出场', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      if (rosterCharacters.isEmpty)
                        Text(
                          '可在「角色管理」添加家人或玩具；也可下方临时补充。',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceDim,
                              ),
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
                                  final selected =
                                      selectedCharacterIds.contains(cid);
                                  return SoftChip(
                                    label: label.isEmpty ? '角色' : label,
                                    selected: selected,
                                    onSelected: (_) {
                                      setState(() {
                                        if (selected) {
                                          selectedCharacterIds.remove(cid);
                                        } else if (selectedCharacterIds.length <
                                            8) {
                                          selectedCharacterIds.add(cid);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Text('轻轻带上', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      _suggestChipWrap(
                        chips: thingChips,
                        selectedKey: selectedThingKey,
                        onSelect: (k) => setState(() => selectedThingKey = k),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: keywordsCtrl,
                        decoration: const InputDecoration(
                          labelText: '未建档的临时补充（可选）',
                          hintText: '偶发事物，如：公园的鸽子',
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: '叙事风格',
                  subtitle: '其余听感交给系统默认',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _labeledChips('生活 / 想象', wonders, wonder, (v) => wonder = v),
                      _labeledChips('对话多少', dialogues, dialogue, (v) => dialogue = v),
                      _labeledChips(
                        '语言',
                        languages,
                        language,
                        (v) => language = v,
                      ),
                      _durationTickPicker(),
                      if (kFeatureSoftSeries) ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('软系列（可续写）'),
                          value: softSeries,
                          onChanged: (v) => setState(() {
                            softSeries = v;
                            if (!v) continueSeriesId = null;
                          }),
                        ),
                        if (softSeries) ...[
                          TextField(
                            controller: recapCtrl,
                            decoration: const InputDecoration(
                              labelText: '上一集轻钩子（可选）',
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: episodeCount,
                            decoration: const InputDecoration(labelText: '系列集数'),
                            items: [2, 3, 4, 5, 6, 7, 8]
                                .map((n) =>
                                    DropdownMenuItem(value: n, child: Text('$n')))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => episodeCount = v ?? 4),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: '声音电台',
                  subtitle: '默认记住你上次的音色',
                  child: Material(
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
                                  final name = (v?['name'] as String?)
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                      ? v!['name'] as String
                                      : (voices.isEmpty ? '暂无可用音色' : '请选择音色');
                                  final desc =
                                      (v?['description'] as String?)?.trim() ??
                                          '';
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '音色',
                                        style: tt.labelSmall?.copyWith(
                                          color: AppColors.onSurfaceDim,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(name, style: tt.titleMedium),
                                      if (desc.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          desc,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: tt.bodySmall?.copyWith(
                                            color: AppColors.onSurfaceMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.primarySoft,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (progressText != null) ...[
                  Text(progressText!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                ],
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

  Widget _buildProfileCard(BuildContext context) {
    return SectionCard(
      title: '小主角档案',
      subtitle: '点按编辑角色信息',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (children.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in children)
                  SoftChip(
                    label: (c['nickname'] as String?) ?? '孩子',
                    selected: _asId(c['id']) == childId,
                    onSelected: (_) async {
                      _applyChild(c);
                      setState(() {});
                      await _loadSuggestionChips();
                      await _reloadVoicePrefs();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Material(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openChildEditor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nickname.isEmpty ? '未命名' : nickname,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_genderLabel(gender)} · ${formatAgeYearsLabel(birthDate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _interestsSummary,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.onSurfaceMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
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
        if (prefVoiceId != null && voices.any((v) => _asId(v['id']) == prefVoiceId)) {
          voiceId = prefVoiceId;
        }
      });
    } catch (_) {}
  }

  Widget _suggestChipWrap({
    required List<_ChipOpt> chips,
    required String? selectedKey,
    required void Function(String? key) onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SoftChip(
          label: '自动',
          selected: selectedKey == null,
          onSelected: (_) => onSelect(null),
        ),
        for (final c in chips)
          SoftChip(
            label: c.label,
            selected: selectedKey == c.key,
            onSelected: (_) => onSelect(selectedKey == c.key ? null : c.key),
          ),
      ],
    );
  }

  Widget _softChipRow(
    List<(String, String)> options,
    String selected,
    void Function(String) onSelect,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, label) in options)
          SoftChip(
            label: label,
            selected: selected == id,
            onSelected: (_) => onSelect(id),
          ),
      ],
    );
  }

  Widget _labeledChips(
    String label,
    List<(String, String)> options,
    String selected,
    void Function(String) assign,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _softChipRow(options, selected, (v) => setState(() => assign(v))),
        ],
      ),
    );
  }

  Widget _durationTickPicker() {
    final ticks = durationTicks;
    var idx = ticks.indexOf(duration);
    if (idx < 0) idx = ticks.indexOf(5).clamp(0, ticks.length - 1);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('时长（分钟）', style: tt.labelLarge),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surfaceHighest,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.16),
              activeTickMarkColor: AppColors.onPrimary,
              inactiveTickMarkColor: AppColors.onSurfaceDim,
              valueIndicatorColor: AppColors.primary,
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
      ),
    );
  }
}
