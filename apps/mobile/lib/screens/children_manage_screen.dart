import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';

/// Manage child profiles (角色).
class ChildrenManageScreen extends StatefulWidget {
  const ChildrenManageScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ChildrenManageScreen> createState() => _ChildrenManageScreenState();
}

class _ChildrenManageScreenState extends State<ChildrenManageScreen> {
  List<Map<String, dynamic>> children = [];
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
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final listed = await widget.api.listChildren();
      children = listed.cast<Map<String, dynamic>>();
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

  DateTime _parseBirth(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DateTime(DateTime.now().year - 4, DateTime.now().month, DateTime.now().day);
    }
    return DateTime.tryParse(raw) ??
        DateTime(DateTime.now().year - 4, DateTime.now().month, DateTime.now().day);
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
                      existing == null ? '添加角色' : '编辑角色',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nickCtrl,
                      decoration: const InputDecoration(labelText: '昵称'),
                    ),
                    const SizedBox(height: 12),
                    Text('性别', style: Theme.of(ctx).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (id, label) in genders)
                          ChoiceChip(
                            label: Text(label),
                            selected: gender == id,
                            onSelected: (_) => setModal(() => gender = id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('出生日期'),
                      subtitle: Text(_fmtDate(birth)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: birth,
                          firstDate: DateTime(DateTime.now().year - 12),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setModal(() => birth = picked);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: introCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '介绍（可选）',
                        hintText: '性格、近期小事、喜欢的称呼…写给故事参考',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: interestsCtrl,
                      decoration: const InputDecoration(labelText: '兴趣（逗号分隔，可选）'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        final nick = nickCtrl.text.trim();
                        if (nick.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请填写昵称')),
                          );
                          return;
                        }
                        final interests = interestsCtrl.text
                            .split(RegExp(r'[,，、\n]+'))
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        try {
                          if (existing == null) {
                            await widget.api.createChild(
                              nickname: nick,
                              birthDate: _fmtDate(birth),
                              gender: gender,
                              intro: introCtrl.text.trim(),
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
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                      child: const Text('保存'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('角色管理'),
        backgroundColor: AppColors.background,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editChild(),
        icon: const Icon(Icons.add),
        label: const Text('添加'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                children: [
                  if (children.isEmpty)
                    SectionCard(
                      title: '还没有角色',
                      child: Text(
                        '添加孩子档案后，创作故事时可选用。',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  else
                    for (final c in children) ...[
                      Material(
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
                                        '${c['birth_date'] ?? '-'} · '
                                        '档 ${c['age_band'] ?? '-'}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      if ((c['intro'] as String?)?.trim().isNotEmpty == true)
                                        Text(
                                          c['intro'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.onSurfaceDim,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit_outlined, color: AppColors.onSurfaceDim),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                ],
              ),
            ),
    );
  }
}
