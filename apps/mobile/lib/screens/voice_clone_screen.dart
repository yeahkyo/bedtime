import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/client.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';

/// Dedicated flow: name + record + clone a parent voice.
class VoiceCloneScreen extends StatefulWidget {
  const VoiceCloneScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<VoiceCloneScreen> createState() => _VoiceCloneScreenState();
}

class _VoiceCloneScreenState extends State<VoiceCloneScreen> {
  final recorder = AudioRecorder();
  final nameCtrl = TextEditingController(text: '家长声音');
  bool consent = false;
  bool recording = false;
  bool uploading = false;
  String? path;

  static const scriptZh =
      '今晚我用温柔的声音给孩子讲故事。风很轻，月亮很亮，我们慢慢闭上眼睛。';
  static const scriptEn =
      'Tonight I will tell a gentle bedtime story. The wind is soft, the moon is bright, and we slowly close our eyes.';

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
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写音色名称')),
      );
      return;
    }
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
        name: name,
        language: 'zh',
      );
      try {
        await File(path!).delete();
      } catch (_) {}
      path = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('克隆成功，可在生成故事时选用')),
      );
      Navigator.of(context).pop(true);
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
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final canUpload =
        path != null && !recording && !uploading && consent && nameCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('克隆新音色'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const BrandHeader(
            eyebrow: '呼呼 · Clone',
            title: '录制家长声音',
            subtitle: '安静环境朗读约 10–15 秒，克隆后可用于睡前故事朗读',
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: '音色名称',
            child: TextField(
              controller: nameCtrl,
              maxLength: 64,
              decoration: const InputDecoration(
                hintText: '例如：妈妈的声音、爸爸哄睡',
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '使用说明',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '原始录音上传后会尽快删除。克隆成功后可在创作故事时选用该音色。',
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
                        label: Text(
                          recording ? '停止录音' : (path != null ? '重录一段' : '开始录音'),
                        ),
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
                    '已录好样本，确认名称与同意后即可上传克隆',
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
        ],
      ),
    );
  }
}
