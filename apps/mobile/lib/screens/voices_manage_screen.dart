import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import 'voice_clone_screen.dart';

/// List / rename voices; entry to clone flow.
class VoicesManageScreen extends StatefulWidget {
  const VoicesManageScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<VoicesManageScreen> createState() => _VoicesManageScreenState();
}

class _VoicesManageScreenState extends State<VoicesManageScreen> {
  List<dynamic> voices = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.ensureSystemVoice();
      voices = await widget.api.listVoices();
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openClone() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VoiceCloneScreen(api: widget.api)),
    );
    if (created == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _rename(Map<String, dynamic> voice) async {
    final id = voice['id'] as int?;
    if (id == null) return;
    final ctrl = TextEditingController(text: voice['name'] as String? ?? '');
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceLow,
          title: const Text('修改名称'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 64,
            decoration: const InputDecoration(
              labelText: '音色名称',
              hintText: '例如：妈妈的声音',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (next == null || !mounted) return;
    if (next.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称不能为空')),
      );
      return;
    }
    if (next == (voice['name'] as String?)) return;
    try {
      await widget.api.updateVoice(voiceId: id, name: next);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已更新名称')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _kindLabel(String? kind) {
    switch (kind) {
      case 'clone':
        return '克隆音色';
      case 'system':
        return '系统音色';
      default:
        return kind ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('音色管理'),
        backgroundColor: AppColors.background,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  const BrandHeader(
                    eyebrow: '呼呼 · Voice',
                    title: '我的音色',
                    subtitle: '管理朗读音色，或克隆家长声音给孩子讲故事',
                  ),
                  const SizedBox(height: 18),
                  AmberCta(
                    label: '克隆新音色',
                    icon: Icons.mic_none,
                    onPressed: _openClone,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: tt.bodySmall?.copyWith(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 18),
                  SectionCard(
                    title: '已有音色',
                    subtitle: voices.isEmpty ? '暂无音色' : '共 ${voices.length} 个 · 点铅笔可改名',
                    child: voices.isEmpty
                        ? Text(
                            '可先点上方按钮克隆家长声音。',
                            style: tt.bodyMedium,
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < voices.length; i++) ...[
                                if (i > 0) const Divider(height: 20),
                                Builder(
                                  builder: (context) {
                                    final m = voices[i] as Map<String, dynamic>;
                                    final kind = m['kind'] as String?;
                                    return Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: AppColors.secondaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(AppRadii.md),
                                          ),
                                          child: Icon(
                                            kind == 'clone'
                                                ? Icons.record_voice_over
                                                : Icons.graphic_eq,
                                            color: AppColors.secondary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m['name'] as String? ?? 'Voice',
                                                style: tt.titleMedium,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${_kindLabel(kind)} · ${m['language'] ?? 'zh'}',
                                                style: tt.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: '修改名称',
                                          onPressed: () => _rename(m),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: AppColors.primarySoft,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
