import 'package:flutter/material.dart';

import '../api/client.dart';
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
    ('girl', '女孩'),
    ('boy', '男孩'),
    ('other', '其他'),
    ('unspecified', '不指定'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _genderLabel(String? id) {
    for (final (gid, label) in genders) {
      if (gid == id) return label;
    }
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
    final interestsCtrl = TextEditingController(
      text: ((existing?['interests'] as List<dynamic>?) ?? []).cast<String>().join(', '),
    );
    var gender = existing?['gender'] as String? ?? 'unspecified';
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
                      existing == null ? '添加听故事的人' : '编辑听故事的人',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nickCtrl,
                      decoration: const InputDecoration(labelText: '昵称'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: gender,
                      decoration: const InputDecoration(labelText: '性别'),
                      items: [
                        for (final (id, label) in genders)
                          DropdownMenuItem(value: id, child: Text(label)),
                      ],
                      onChanged: (v) => setModal(() => gender = v ?? 'unspecified'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('生日'),
                      subtitle: Text(_fmtDate(birth)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: birth,
                          firstDate: DateTime(DateTime.now().year - 14),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setModal(() => birth = picked);
                      },
                    ),
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
                      controller: interestsCtrl,
                      decoration: const InputDecoration(
                        labelText: '兴趣（逗号分隔）',
                        hintText: '恐龙, 画画',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        final nick = nickCtrl.text.trim();
                        if (nick.isEmpty) return;
                        final interests = interestsCtrl.text
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
                              interests: interests,
                            );
                          } else {
                            await widget.api.updateChild(
                              childId: existing['id'] as int,
                              nickname: nick,
                              birthDate: _fmtDate(birth),
                              gender: gender,
                              intro: introCtrl.text.trim(),
                              interests: interests,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('$e')),
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
    interestsCtrl.dispose();
    if (saved == true) await _load();
  }

  Future<void> _editRoster({
    required String kind,
    Map<String, dynamic>? existing,
  }) async {
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加听故事的人')),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final relationCtrl =
        TextEditingController(text: existing?['relation'] as String? ?? '');
    final noteCtrl = TextEditingController(text: existing?['note'] as String? ?? '');
    var relatedId = existing?['related_child_id'] as int? ?? children.first['id'] as int;

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
                    DropdownButtonFormField<int>(
                      value: relatedId,
                      decoration: InputDecoration(
                        labelText: kind == 'toy' ? '属于谁' : '关联小孩',
                      ),
                      items: [
                        for (final c in children)
                          DropdownMenuItem(
                            value: c['id'] as int,
                            child: Text(
                              (c['nickname'] as String?)?.trim().isNotEmpty == true
                                  ? c['nickname'] as String
                                  : '未命名',
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setModal(() => relatedId = v);
                      },
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
                              SnackBar(content: Text('$e')),
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
        title: const Text('删除听故事的人？'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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

  @override
  Widget build(BuildContext context) {
    final fabLabel = switch (_tabs.index) {
      1 => '添加家人',
      2 => '添加玩具',
      _ => '添加听众',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('角色管理'),
        backgroundColor: AppColors.background,
        bottom: TabBar(
          controller: _tabs,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: '听故事的人'),
            Tab(text: '家人朋友'),
            Tab(text: '玩具'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFab,
        icon: const Icon(Icons.add),
        label: Text(fabLabel),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _listenersTab(),
                _rosterTab(kind: 'person'),
                _rosterTab(kind: 'toy'),
              ],
            ),
    );
  }

  Widget _listenersTab() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
        children: [
          if (children.isEmpty)
            SectionCard(
              title: '还没有听故事的人',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '添加孩子档案后，才能创建故事并挂上家人、玩具。',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => _editChild(),
                    child: const Text('添加第一个'),
                  ),
                ],
              ),
            )
          else
            for (final c in children) ...[
              _listenerTile(c),
            ],
        ],
      ),
    );
  }

  Widget _listenerTile(Map<String, dynamic> c) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => _editChild(existing: c),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.secondaryContainer,
                child: Text(
                  ((c['nickname'] as String?)?.isNotEmpty == true)
                      ? (c['nickname'] as String).characters.first
                      : '?',
                  style: const TextStyle(color: AppColors.secondary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['nickname'] as String? ?? '未命名',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${_genderLabel(c['gender'] as String?)} · '
                      '${formatAgeYearsLabel(c['birth_date'] as String?)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: () => _confirmDeleteChild(c),
                icon: const Icon(Icons.delete_outline, color: AppColors.onSurfaceDim),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rosterTab({required String kind}) {
    final rows = _ofKind(kind);
    final emptyTitle = kind == 'toy' ? '还没有玩具伙伴' : '还没有家人 / 朋友';
    final emptyHint = kind == 'toy'
        ? '把娃娃、玩偶建档后，创作故事时可勾选出场。'
        : '把外公、同学等建档后，创作故事时可勾选出场。';

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
        children: [
          if (rows.isEmpty)
            SectionCard(
              title: emptyTitle,
              child: Text(emptyHint, style: Theme.of(context).textTheme.bodyLarge),
            )
          else
            for (final c in rows) ...[
              Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  onTap: () => _editRoster(kind: kind, existing: c),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['name'] as String? ?? '未命名',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                [
                                  if (kind == 'person' &&
                                      (c['relation'] as String?)
                                              ?.trim()
                                              .isNotEmpty ==
                                          true)
                                    c['relation'] as String,
                                  '属于 ${_childName(c['related_child_id'] as int?)}',
                                ].join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if ((c['note'] as String?)?.trim().isNotEmpty == true)
                                Text(
                                  c['note'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.onSurfaceDim,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: () => _confirmDeleteCharacter(c),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.onSurfaceDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}
