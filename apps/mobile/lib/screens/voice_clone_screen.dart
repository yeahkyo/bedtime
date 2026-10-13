import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/client.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';

class VoiceCloneScreen extends StatefulWidget {
  const VoiceCloneScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<VoiceCloneScreen> createState() => _VoiceCloneScreenState();
}

class _VoiceCloneScreenState extends State<VoiceCloneScreen> {
  final recorder = AudioRecorder();
  bool consent = false;
  bool recording = false;
  bool uploading = false;
  String? path;
  List<dynamic> voices = [];

  static const scriptZh =
      '今晚我用温柔的声音给孩子讲故事。风很轻，月亮很亮，我们慢慢闭上眼睛。';
  static const scriptEn =
      'Tonight I will tell a gentle bedtime story. The wind is soft, the moon is bright, and we slowly close our eyes.';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      voices = await widget.api.listVoices();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _toggleRecord() async {
    if (recording) {
      final p = await recorder.stop();
      if (!mounted) return;
      setState(() {
        recording = false;
        path = p;
      });
      return;
    }
    if (!await recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要麦克风权限')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = '${dir.path}/clone_sample.m4a';
    // ~10–15s clean speech works best for Seed-ICL; AAC/m4a is fine on iOS.
    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: file,
    );
    if (!mounted) return;
    setState(() {
      recording = true;
      path = file;
    });
  }

  Future<void> _upload() async {
    if (!consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先勾选同意条款')),
      );
      return;
    }
    if (path == null) return;
    setState(() => uploading = true);
    try {
      final bytes = await File(path!).readAsBytes();
      await widget.api.cloneVoice(
        bytes: bytes,
        filename: 'clone_sample.m4a',
        name: '家长声音',
        language: 'zh',
      );
      // Delete local sample after upload
      try {
        await File(path!).delete();
      } catch (_) {}
      path = null;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('克隆成功，可在生成故事时选用')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  void dispose() {
    if (recording) {
      recorder.stop().catchError((_) => null);
    }
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final canUpload = path != null && !recording && !uploading && consent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const BrandHeader(
          eyebrow: 'Lullvale · Voice',
          title: '枕边音色',
          subtitle: '克隆家长本人的声音，用于给孩子朗读睡前故事',
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: '使用说明',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '原始录音上传后会尽快删除。建议安静环境朗读 10–15 秒；克隆成功后回到「创作室」可选该音色。',
                style: tt.bodyMedium,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => consent = !consent),
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: consent,
                      onChanged: (v) => setState(() => consent = v ?? false),
                      activeColor: AppColors.primary,
                      checkColor: AppColors.onPrimary,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '我同意将我的声音用于本 App 的睡前故事朗读',
                          style: tt.bodyLarge?.copyWith(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '请朗读这段话',
          subtitle: '中英文各读一遍亦可，语速自然即可',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.inputWell,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: const Color(0xFF323D4E)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scriptZh, style: tt.bodyLarge?.copyWith(height: 1.55)),
                    const SizedBox(height: 10),
                    Text(
                      scriptEn,
                      style: tt.bodyMedium?.copyWith(
                        height: 1.5,
                        color: AppColors.onSurfaceDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: uploading ? null : _toggleRecord,
                      icon: Icon(
                        recording ? Icons.stop_circle_outlined : Icons.mic,
                        color: recording ? AppColors.tertiary : AppColors.primary,
                      ),
                      label: Text(recording ? '停止录音' : (path != null ? '重录一段' : '开始录音')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onSurface,
                        side: BorderSide(
                          color: recording ? AppColors.tertiary : AppColors.outlineWarm,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (recording) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.tertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '正在录音… 读完后点停止',
                      style: tt.bodySmall?.copyWith(color: AppColors.tertiary),
                    ),
                  ],
                ),
              ] else if (path != null) ...[
                const SizedBox(height: 10),
                Text(
                  '已录好样本，确认同意后即可上传克隆',
                  style: tt.bodySmall?.copyWith(color: AppColors.secondary),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: AmberCta(
                  label: uploading ? '上传中…' : '上传并克隆',
                  busy: uploading,
                  icon: Icons.upload_rounded,
                  onPressed: canUpload ? _upload : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '已有音色',
          subtitle: voices.isEmpty ? '还没有克隆音色' : '共 ${voices.length} 个',
          child: voices.isEmpty
              ? Text(
                  '克隆成功后会出现在这里，并在创作室可选。',
                  style: tt.bodyMedium,
                )
              : Column(
                  children: [
                    for (var i = 0; i < voices.length; i++) ...[
                      if (i > 0) const Divider(height: 20),
                      Builder(
                        builder: (context) {
                          final m = voices[i] as Map<String, dynamic>;
                          return Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                ),
                                child: const Icon(
                                  Icons.record_voice_over,
                                  color: AppColors.secondary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['name'] as String? ?? 'Voice',
                                      style: tt.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${m['kind']} · ${m['language']}',
                                      style: tt.bodySmall,
                                    ),
                                  ],
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
    );
  }
}
