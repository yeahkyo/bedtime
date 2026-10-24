import 'package:flutter/material.dart';

import '../api/client.dart';
import '../local/network_errors.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import '../utils/child_age.dart';

/// Manage listeners (children) + reusable story characters (person / toy).
class ChildrenManageScreen extends StatefulWidget {
  const ChildrenManageScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ChildrenManageScreen> createState() => _ChildrenManageScreenState();
}

class _ChildrenManageScreenState extends State<ChildrenManageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> children = [];
  List<Map<String, dynamic>> characters = [];
  bool loading = true;

  static const genders = [
    ('unspecified', '不指定'),
    ('boy', '男孩'),
    ('girl', '女孩'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final listed = await widget.api.listChildren();
      children = listed.cast<Map<String, dynamic>>();
      final chars = await widget.api.listCharacters();
      characters = chars.cast<Map<String, dynamic>>();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyNetworkError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _genderLabel(String? id) {
    for (final (gid, label) in genders) {
      if (gid == id) return label;
    }
    // Legacy API values (e.g. other) — UI options no longer include them.
    if (id == 'other') return '其他';
    return '不指定';
  }

  String _childName(int? id) {
    if (id == null) return '未关联';
    for (final c in children) {
      if (c['id'] == id) {
        return (c['nickname'] as String?)?.trim().isNotEmpty == true
            ? c['nickname'] as String
            : '未命名';
      }
    }
    return '小孩 #$id';
  }

  DateTime _parseBirth(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DateTime(DateTime.now().year - 4, DateTime.now().month, DateTime.now().day);
    }
    return DateTime.tryParse(raw) ??
        DateTime(DateTime.now().year - 4, DateTime.now().month, DateTime.now().day);
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _ofKind(String kind) =>
      characters.where((c) => c['kind'] == kind).toList();

  Future<void> _editChild({Map<String, dynamic>? existing}) async {
    final nickCtrl = TextEditingController(text: existing?['nickname'] as String? ?? '');
    final introCtrl = TextEditingController(text: existing?['intro'] as String? ?? '');
    final preferCtrl = TextEditingController(
      text: ((existing?['prefer'] as List<dynamic>?) ?? [])
          .cast<String>()
          .join(', '),
    );
    var gender = existing?['gender'] as String? ?? 'unspecified';
    if (!genders.any((g) => g.$1 == gender)) {
      gender = 'unspecified';
    }
    var birth = _parseBirth(existing?['birth_date'] as String?);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLow,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '小听众档案',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nickCtrl,
                      decoration: const InputDecoration(labelText: '昵称'),
                    ),
                    const SizedBox(height: 12),
                    SoftSelectField<String>(
                      label: '性别',
                      value: gender,
                      options: genders,
                      onChanged: (v) => setModal(() => gender = v),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      onTap: () async {
                        await waitForKeyboardDismissed(ctx);
                        if (!ctx.mounted) return;
                        final picked = await showDatePicker(
                          context: ctx,
                          locale: const Locale('zh', 'CN'),
                          helpText: '选择生日',
                          cancelText: '取消',
                          confirmText: '确定',
                          fieldLabelText: '生日',
                          fieldHintText: '年/月/日',
                          initialDate: birth,
                          firstDate: DateTime(DateTime.now().year - 14),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setModal(() => birth = picked);
                        if (ctx.mounted) {
                          FocusScope.of(ctx).unfocus();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (ctx.mounted) FocusScope.of(ctx).unfocus();
                          });
                        }
                      },
                      child: InputDecorator(
                        isEmpty: false,
                        decoration: const InputDecoration(
                          labelText: '生日',
                          suffixIcon: Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                        child: Text(
                          _fmtDate(birth),
                          style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                height: 1.25,
                                color: AppColors.onSurface,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: introCtrl,
                      decoration: const InputDecoration(
                        labelText: '简介（可选）',
                        hintText: '性格、近期心情…',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: preferCtrl,
                      decoration: const InputDecoration(
                        labelText: '故事偏好（逗号分隔）',
                        hintText: '恐龙冒险, 温柔童话, 一点点幽默',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        final nick = nickCtrl.text.trim();
                        if (nick.isEmpty) return;
                        final prefer = preferCtrl.text
                            .split(RegExp(r'[,，]'))
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        try {
                          if (existing == null) {
                            await widget.api.createChild(
                              nickname: nick,
                              birthDate: _fmtDate(birth),
                              gender: gender,
                              intro: introCtrl.text.trim().isEmpty
                                  ? null
                                  : introCtrl.text.trim(),
                              prefer: prefer,
                            );
                          } else {
                            await widget.api.updateChild(
                              childId: existing['id'] as int,
                              nickname: nick,
                              birthDate: _fmtDate(birth),
                              gender: gender,
                              intro: introCtrl.text.trim(),
                              prefer: prefer,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(friendlyNetworkError(e))),
                            );
                          }
                        }
                      },
                      child: Text(existing == null ? '创建' : '保存'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    nickCtrl.dispose();
    introCtrl.dispose();
    preferCtrl.dispose();
    if (saved == true) await _load();
  }

  Future<void> _editRoster({
    required String kind,
    Map<String, dynamic>? existing,
  }) async {
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加小听众')),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final relationCtrl =
        TextEditingController(text: existing?['relation'] as String? ?? '');
    final noteCtrl = TextEditingController(text: existing?['note'] as String? ?? '');
    var relatedId = existing?['related_child_id'] as int? ?? children.first['id'] as int;
    if (!children.any((c) => c['id'] == relatedId)) {
      relatedId = children.first['id'] as int;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLow,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? (kind == 'toy' ? '添加玩具' : '添加家人 / 朋友')
                          : (kind == 'toy' ? '编辑玩具' : '编辑家人 / 朋友'),
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: kind == 'toy' ? '名字' : '称呼',
                        hintText: kind == 'toy' ? '星星娃娃' : '外公',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SoftSelectField<int>(
                      label: kind == 'toy' ? '属于谁' : '关联小听众',
                      value: relatedId,
                      options: [
                        for (final c in children)
                          (
                            c['id'] as int,
                            (c['nickname'] as String?)?.trim().isNotEmpty == true
                                ? c['nickname'] as String
                                : '未命名',
                          ),
                      ],
                      onChanged: (v) => setModal(() => relatedId = v),
                    ),
                    if (kind == 'person') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: relationCtrl,
                        decoration: const InputDecoration(
                          labelText: '关系',
                          hintText: '外公 / 同学 / 老师…',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        labelText: kind == 'toy' ? '外观 / 脾气（可选）' : '特征（可选）',
                        hintText: kind == 'toy' ? '蓝色耳朵、会唱歌' : '爱讲故事',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        try {
                          if (existing == null) {
                            await widget.api.createCharacter(
                              kind: kind,
                              name: name,
                              relatedChildId: relatedId,
                              relation: kind == 'person'
                                  ? relationCtrl.text.trim()
                                  : null,
                              note: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                            );
                          } else {
                            await widget.api.updateCharacter(
                              characterId: existing['id'] as int,
                              name: name,
                              relatedChildId: relatedId,
                              relation: kind == 'person'
                                  ? relationCtrl.text.trim()
                                  : '',
                              note: noteCtrl.text.trim(),
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(friendlyNetworkError(e))),
                            );
                          }
                        }
                      },
                      child: Text(existing == null ? '创建' : '保存'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    nameCtrl.dispose();
    relationCtrl.dispose();
    noteCtrl.dispose();
    if (saved == true) await _load();
  }

  Future<void> _confirmDeleteChild(Map<String, dynamic> c) async {
    final childId = c['id'] as int?;
    if (childId == null) return;
    final name = (c['nickname'] as String?)?.trim().isNotEmpty == true
        ? (c['nickname'] as String).trim()
        : '未命名';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLow,
        title: const Text('删除小听众？'),
        content: Text('将一并删除「$name」名下的家人与玩具角色。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.api.deleteChild(childId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除「$name」')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyNetworkError(e))),
      );
    }
  }

  Future<void> _confirmDeleteCharacter(Map<String, dynamic> c) async {
    final id = c['id'] as int?;
    if (id == null) return;
    final name = (c['name'] as String?)?.trim() ?? '角色';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLow,
        title: const Text('删除角色？'),
        content: Text('删除「$name」后，创作时将无法再勾选。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.api.deleteCharacter(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyNetworkError(e))),
      );
    }
  }

  void _onFab() {
    switch (_tabs.index) {
      case 1:
        _editRoster(kind: 'person');
      case 2:
        _editRoster(kind: 'toy');
      default:
        _editChild();
    }
  }

  String get _fabLabel => switch (_tabs.index) {
        1 => '添加家人朋友',
        2 => '添加玩具伙伴',
        _ => '添加小听众',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('角色管理'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _segmentedTabs(),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.nightlight_round, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '梦境主角簿 · 定制专属睡前入眠物语',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.onSurfaceMuted,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _listenersTab(),
                      _rosterTab(kind: 'person'),
                      _rosterTab(kind: 'toy'),
                    ],
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
                  child: AmberCta(
                    label: _fabLabel,
                    icon: Icons.add,
                    onPressed: _onFab,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _segmentedTabs() {
    const items = [
      (Icons.face_retouching_natural, '小听众档案'),
      (Icons.groups_outlined, '家人朋友'),
      (Icons.cruelty_free_outlined, '玩具伙伴'),
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outlineSubtle),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Material(
                color: _tabs.index == i
                    ? AppColors.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    _tabs.animateTo(i);
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_tabs.index == i && i == 0) ...[
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: const BoxDecoration(
                              color: AppColors.onPrimaryContainer,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            items[i].$1,
                            size: 14,
                            color: _tabs.index == i
                                ? AppColors.onPrimaryContainer
                                : AppColors.onSurfaceMuted,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            items[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _tabs.index == i
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _tabs.index == i
                                  ? AppColors.onPrimaryContainer
                                  : AppColors.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _listenersTab() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        children: [
          if (children.isEmpty)
            SectionCard(
              title: '还没有小听众',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '添加小听众档案后，才能创建故事并挂上家人、玩具。',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  AmberCta(
                    label: '添加第一个小听众',
                    icon: Icons.add,
                    onPressed: () => _editChild(),
                  ),
                ],
              ),
            )
          else
            for (final c in children) ...[
              _listenerCard(c),
              const SizedBox(height: 12),
            ],
          if (children.isNotEmpty) ...[
            const SizedBox(height: 4),
            _magicHintCard(),
          ],
        ],
      ),
    );
  }

  Widget _listenerCard(Map<String, dynamic> c) {
    final name = (c['nickname'] as String?)?.trim().isNotEmpty == true
        ? (c['nickname'] as String).trim()
        : '未命名';
    final gender = c['gender'] as String?;
    final birth = c['birth_date'] as String?;
    final prefer = ((c['prefer'] as List<dynamic>?) ?? []).cast<String>();
    final intro = (c['intro'] as String?)?.trim() ?? '';
    final initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first);

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E3A34), Color(0xFF2A4A3F)],
                      ),
                      border: Border.all(color: AppColors.outlineSubtle),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primarySoft,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star, size: 11, color: AppColors.onPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _pillTag('小听众', mauve: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_genderLabel(gender)} · ${formatAgeDetailedLabel(birth)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: () => _confirmDeleteChild(c),
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.onSurfaceDim),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: () => _editChild(existing: c),
                icon: const Icon(Icons.tune, size: 20, color: AppColors.onSurfaceMuted),
              ),
            ],
          ),
          if (prefer.isNotEmpty || intro.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (prefer.isNotEmpty)
                  _infoChip(
                    Icons.auto_awesome_outlined,
                    '偏好：${prefer.take(3).join('、')}',
                  ),
                if (intro.isNotEmpty)
                  _infoChip(Icons.auto_stories_outlined, intro),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Material(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () => _editChild(existing: c),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.music_note, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '编辑档案与睡前偏好',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurface,
                            ),
                      ),
                    ),
                    Text(
                      '入眠预设',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rosterTab({required String kind}) {
    final rows = _ofKind(kind);
    final emptyTitle = kind == 'toy' ? '还没有玩具伙伴' : '还没有家人 / 朋友';
    final emptyHint = kind == 'toy'
        ? '把娃娃、玩偶建档后，创作故事时可勾选出场。'
        : '把外公、同学等建档后，创作故事时可勾选出场。';
    final tag = kind == 'toy' ? '安抚布偶' : '家人朋友';

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        children: [
          if (rows.isEmpty)
            SectionCard(
              title: emptyTitle,
              child: Text(emptyHint, style: Theme.of(context).textTheme.bodyLarge),
            )
          else
            for (final c in rows) ...[
              _rosterCard(c, kind: kind, tag: tag),
              const SizedBox(height: 12),
            ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 4),
            _magicHintCard(),
          ],
        ],
      ),
    );
  }

  Widget _rosterCard(
    Map<String, dynamic> c, {
    required String kind,
    required String tag,
  }) {
    final name = (c['name'] as String?)?.trim().isNotEmpty == true
        ? (c['name'] as String).trim()
        : '未命名';
    final note = (c['note'] as String?)?.trim() ?? '';
    final relation = (c['relation'] as String?)?.trim() ?? '';
    final related = _childName(c['related_child_id'] as int?);
    final initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first);
    final subtitle = kind == 'person'
        ? [
            if (relation.isNotEmpty) relation,
            '属于 $related',
          ].join(' · ')
        : '床头伙伴 · 属于 $related';

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: kind == 'toy'
                        ? const [Color(0xFF3A2A22), Color(0xFF5A4030)]
                        : const [Color(0xFF2A3A4F), Color(0xFF3A4A5F)],
                  ),
                  border: Border.all(color: AppColors.outlineSubtle),
                ),
                alignment: Alignment.center,
                child: kind == 'toy'
                    ? const Icon(Icons.toys_outlined, color: AppColors.primarySoft)
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primarySoft,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _pillTag(tag, mauve: kind != 'toy'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: () => _confirmDeleteCharacter(c),
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.onSurfaceDim),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: () => _editRoster(kind: kind, existing: c),
                icon: const Icon(Icons.tune, size: 20, color: AppColors.onSurfaceMuted),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoChip(Icons.psychology_outlined, '性格：$note'),
          ],
        ],
      ),
    );
  }

  Widget _pillTag(String label, {bool mauve = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: mauve
            ? AppColors.secondaryContainer.withValues(alpha: 0.7)
            : AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: mauve ? AppColors.secondary : AppColors.primarySoft,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfacePaperLayered,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x40C38D9E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.secondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _magicHintCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
                colors: [Color(0xFF2A3A4F), Color(0xFF3A2A22)],
              ),
            ),
            child: const Icon(Icons.menu_book_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '角色定制魔力',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '织梦引擎根据主角年龄与偏好，在每晚的声景中植入专属温润台词与助眠呼吸节律。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
