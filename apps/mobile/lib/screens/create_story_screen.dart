import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import 'player_screen.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final themeCtrl = TextEditingController(text: '月光下的小兔子');
  final nicknameCtrl = TextEditingController(text: '豆豆');
  final keywordsCtrl = TextEditingController(text: '星星娃娃, 小毯子');
  final interestsCtrl = TextEditingController();
  final valuesCtrl = TextEditingController();
  final recapCtrl = TextEditingController();

  String language = 'zh';
  String ageBand = '3-5';
  String? developmentFocus;
  String childCastRole = 'auto';
  String plotDrive = 'light';
  String imagery = 'balanced';
  String wonder = 'soft';
  String windDown = 'gentle';
  String dialogue = 'some';
  String leadIn = 'soft';
  int duration = 5;
  String speedTier = 'slow';
  String tone = 'gentle';
  bool softSeries = false;
  int? continueSeriesId;
  int episodeCount = 4;
  bool busy = false;
  bool preparing = true;
  String? quotaText;
  String? progressText;
  int? childId;
  int? voiceId;
  List<Map<String, dynamic>> voices = [];

  static const ageBands = [
    ('2-3', '2–3岁'),
    ('3-5', '3–5岁'),
    ('6-8', '6–8岁'),
  ];

  static const castRoles = [
    ('auto', '自动'),
    ('protagonist', '孩子主角'),
    ('supporting', '孩子配角'),
    ('absent', '不出现孩子'),
  ];

  static const plotDrives = [
    ('mood', '氛围向'),
    ('light', '轻情节'),
    ('arc', '更有故事'),
  ];
  static const imageries = [
    ('sparse', '干净口述'),
    ('balanced', '适中'),
    ('rich', '更细腻'),
  ];
  static const wonders = [
    ('everyday', '日常'),
    ('soft', '轻奇幻'),
    ('fantasy', '更幻想'),
  ];
  static const windDowns = [
    ('deep', '很快安静'),
    ('gentle', '先轻轻再睡'),
    ('playful', '活泼一点再收'),
  ];
  static const dialogues = [
    ('low', '很少对话'),
    ('some', '一点对话'),
    ('more', '对话多些'),
  ];
  static const leadIns = [
    ('none', '直接开讲'),
    ('soft', '轻轻总领'),
    ('curious', '好奇开场'),
  ];

  static const focusOptions = <String, List<(String, String)>>{
    '2-3': [
      ('secure_presence', '安心在场'),
      ('body_rhythm', '身体节奏'),
      ('name_feeling', '轻轻命名感受'),
    ],
    '3-5': [
      ('tiny_brave', '小小勇敢'),
      ('emotion_held', '情绪被接住'),
      ('gentle_agency', '小小自主'),
      ('share_space', '留一点空间'),
      ('wind_down', '慢慢安静'),
    ],
    '6-8': [
      ('try_persist', '坚持一下'),
      ('friend_repair', '和好'),
      ('fair_turn', '轮流公平'),
      ('mentalize_light', '理解小心思'),
    ],
  };

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() => preparing = true);
    try {
      final children = await widget.api.listChildren();
      if (children.isEmpty) {
        final child = await widget.api.createChild(
          nickname: nicknameCtrl.text.trim().isEmpty ? '豆豆' : nicknameCtrl.text.trim(),
          ageBand: ageBand,
        );
        childId = child['id'] as int;
        ageBand = child['age_band'] as String? ?? ageBand;
      } else {
        final c = children.first as Map<String, dynamic>;
        childId = c['id'] as int;
        nicknameCtrl.text = c['nickname'] as String? ?? nicknameCtrl.text;
        ageBand = c['age_band'] as String? ?? ageBand;
        final interests = (c['interests'] as List<dynamic>? ?? []).cast<String>();
        interestsCtrl.text = interests.join(', ');
      }
      final system = await widget.api.ensureSystemVoice();
      final listed = await widget.api.listVoices();
      voices = listed.cast<Map<String, dynamic>>();
      if (voices.isEmpty) {
        voices = [system];
      }
      Map<String, dynamic>? preferred;
      for (final v in voices) {
        if (v['kind'] == 'clone') {
          preferred = v;
          break;
        }
      }
      voiceId = (preferred?['id'] as int?) ?? (system['id'] as int);
      final q = await widget.api.quota();
      quotaText =
          '本月故事 ${q['story_used']}/${q['story_limit']} · 克隆 ${q['clone_used']}/${q['clone_limit']}';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Future<void> _generate() async {
    if (childId == null) return;
    final nick = nicknameCtrl.text.trim();
    if (nick.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写孩子昵称（即使故事里可不出现）')),
      );
      return;
    }
    setState(() {
      busy = true;
      progressText = '已提交，排队中…';
    });
    try {
      await widget.api.updateChild(
        childId: childId!,
        nickname: nick,
        ageBand: ageBand,
        interests: _parseList(interestsCtrl.text),
      );
      await widget.api.updateVoicePrefs(
        childId: childId!,
        speedTier: speedTier,
        tonePreset: tone,
        likenessBoost: false,
        defaultVoiceId: voiceId,
      );
      final story = await widget.api.createStoryAndWait(
        childId: childId!,
        theme: themeCtrl.text.trim().isEmpty ? '温柔的夜晚' : themeCtrl.text.trim(),
        language: language,
        durationMinutes: duration,
        voiceId: voiceId,
        softSeriesMode: softSeries || continueSeriesId != null,
        seriesId: continueSeriesId,
        episodeCount: episodeCount,
        keywords: _parseList(keywordsCtrl.text),
        values: _parseList(valuesCtrl.text),
        developmentFocus: developmentFocus,
        childCastRole: childCastRole,
        recap: softSeries && recapCtrl.text.trim().isNotEmpty ? recapCtrl.text.trim() : null,
        plotDrive: plotDrive,
        imagery: imagery,
        wonder: wonder,
        windDown: windDown,
        dialogue: dialogue,
        leadIn: leadIn,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => progressText = _progressLabel(p));
        },
      );
      if (!mounted) return;
      final sid = story['series_id'] as int?;
      final ep = story['episode_no'] as int?;
      if (sid != null) {
        setState(() {
          softSeries = true;
          continueSeriesId = sid;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('系列第 ${ep ?? '?'} 集已生成，可再点生成续写下一集')),
        );
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            title: story['title'] as String? ?? 'Story',
            body: story['body'] as String? ?? '',
            audioUrl: story['audio_url'] as String?,
            softHook: story['soft_hook'] as String?,
          ),
        ),
      );
      final q = await widget.api.quota();
      if (!mounted) return;
      setState(() {
        quotaText =
            '本月故事 ${q['story_used']}/${q['story_limit']} · 克隆 ${q['clone_used']}/${q['clone_limit']}';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
    themeCtrl.dispose();
    nicknameCtrl.dispose();
    keywordsCtrl.dispose();
    interestsCtrl.dispose();
    valuesCtrl.dispose();
    recapCtrl.dispose();
    super.dispose();
  }

  List<(String, String)> get _fociForAge => focusOptions[ageBand] ?? focusOptions['3-5']!;

  @override
  Widget build(BuildContext context) {
    if (preparing) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
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
              SectionCard(
                title: '小主角档案',
                subtitle: '昵称会传给模型；是否出场由「孩子角色」决定',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nicknameCtrl,
                      decoration: const InputDecoration(labelText: '孩子昵称'),
                    ),
                    const SizedBox(height: 14),
                    Text('年龄档', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _softChipRow(
                      ageBands,
                      ageBand,
                      (id) => setState(() {
                        ageBand = id;
                        final ids = focusOptions[id]!.map((e) => e.$1).toSet();
                        if (developmentFocus != null && !ids.contains(developmentFocus)) {
                          developmentFocus = null;
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: interestsCtrl,
                      decoration: const InputDecoration(
                        labelText: '长期兴趣（可选）',
                        hintText: '恐龙, 火车',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('孩子在故事中的角色', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _softChipRow(castRoles, childCastRole, (v) => setState(() => childCastRole = v)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '今晚的故事',
                subtitle: '主题、伙伴与轻发展焦点',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: themeCtrl,
                      decoration: const InputDecoration(labelText: '主题'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keywordsCtrl,
                      decoration: const InputDecoration(
                        labelText: '关键词（人 / 玩具 / 事物）',
                        hintText: '星星娃娃, 外公, 粉色秋千',
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    Text('发展焦点（可选）', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SoftChip(
                          label: '自动',
                          selected: developmentFocus == null,
                          onSelected: (_) => setState(() => developmentFocus = null),
                        ),
                        for (final (id, label) in _fociForAge)
                          SoftChip(
                            label: label,
                            selected: developmentFocus == id,
                            onSelected: (_) => setState(() => developmentFocus = id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valuesCtrl,
                      decoration: const InputDecoration(
                        labelText: '价值观提示（可选，勿说教）',
                        hintText: '温柔, 分享',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '叙事风格',
                subtitle: '像旋钮一样轻轻拧一拧',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _labeledChips('情节性', plotDrives, plotDrive, (v) => plotDrive = v),
                    _labeledChips('描写密度', imageries, imagery, (v) => imagery = v),
                    _labeledChips('奇幻度', wonders, wonder, (v) => wonder = v),
                    _labeledChips('安眠节奏', windDowns, windDown, (v) => windDown = v),
                    _labeledChips('对话多少', dialogues, dialogue, (v) => dialogue = v),
                    _labeledChips('开场总领', leadIns, leadIn, (v) => leadIn = v),
                    const SizedBox(height: 8),
                    Text('语言', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _softChipRow(
                      const [('zh', '中文'), ('en', 'English')],
                      language,
                      (v) => setState(() => language = v),
                    ),
                    const SizedBox(height: 14),
                    Text('时长', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 3, label: Text('3分')),
                        ButtonSegment(value: 5, label: Text('5分')),
                        ButtonSegment(value: 8, label: Text('8分')),
                      ],
                      selected: {duration},
                      onSelectionChanged: (s) => setState(() => duration = s.first),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('软系列连载', style: TextStyle(color: AppColors.onSurface)),
                      subtitle: Text(
                        continueSeriesId != null
                            ? '续写系列 #$continueSeriesId'
                            : '开启后先大纲，再写第 1 集',
                        style: const TextStyle(color: AppColors.onSurfaceDim),
                      ),
                      value: softSeries || continueSeriesId != null,
                      onChanged: (v) => setState(() {
                        softSeries = v;
                        if (!v) continueSeriesId = null;
                      }),
                    ),
                    if (softSeries || continueSeriesId != null) ...[
                      if (continueSeriesId == null) ...[
                        Text('系列集数', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 3, label: Text('3集')),
                            ButtonSegment(value: 4, label: Text('4集')),
                            ButtonSegment(value: 5, label: Text('5集')),
                          ],
                          selected: {episodeCount},
                          onSelectionChanged: (s) => setState(() => episodeCount = s.first),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: recapCtrl,
                        decoration: const InputDecoration(
                          labelText: '前情提要（可选）',
                          hintText: '上次小兔子找到了星星毯子…',
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                      if (continueSeriesId != null)
                        TextButton(
                          onPressed: () => setState(() {
                            continueSeriesId = null;
                            softSeries = true;
                          }),
                          child: const Text('改为开新系列'),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '声音电台',
                subtitle: '语速、语气与音色',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('语速', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'slow', label: Text('慢')),
                        ButtonSegment(value: 'medium', label: Text('适中')),
                        ButtonSegment(value: 'fast', label: Text('稍快')),
                      ],
                      selected: {speedTier},
                      onSelectionChanged: (s) => setState(() => speedTier = s.first),
                    ),
                    const SizedBox(height: 12),
                    Text('语气', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'gentle', label: Text('温柔')),
                        ButtonSegment(value: 'clear', label: Text('平稳')),
                        ButtonSegment(value: 'lively', label: Text('生动')),
                      ],
                      selected: {tone},
                      onSelectionChanged: (s) => setState(() => tone = s.first),
                    ),
                    const SizedBox(height: 12),
                    Text('音色', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    if (voices.isEmpty)
                      const Text('加载音色中…', style: TextStyle(color: AppColors.onSurfaceDim))
                    else
                      DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: voiceId,
                        items: voices.map((v) {
                          final id = v['id'] as int;
                          final name = v['name'] as String? ?? 'Voice';
                          final kind = v['kind'] as String? ?? '';
                          final label = kind == 'clone' ? '$name（克隆）' : '$name（系统）';
                          return DropdownMenuItem(value: id, child: Text(label));
                        }).toList(),
                        onChanged: (id) => setState(() => voiceId = id),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '可在「音色」页录制家长声音',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 88),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLow,
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AmberCta(
                label: busy ? (progressText ?? '编织中…') : '编织今晚的枕边故事',
                busy: busy,
                onPressed: busy ? null : _generate,
              ),
              if (busy && progressText != null) ...[
                const SizedBox(height: 8),
                Text(
                  progressText!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _labeledChips(
    String label,
    List<(String, String)> options,
    String selected,
    void Function(String) onSelect,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _softChipRow(options, selected, (v) => setState(() => onSelect(v))),
        ],
      ),
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
}
