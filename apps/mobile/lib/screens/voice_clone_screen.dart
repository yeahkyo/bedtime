import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
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
  final nameCtrl = TextEditingController();
  bool consent = false;
  bool recording = false;
  bool uploading = false;
  String? path;
  bool _seededName = false;

  static const scriptEn =
      'Tonight I will tell a gentle bedtime story. The wind is soft, the moon is bright, and we slowly close our eyes.';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seededName) {
      _seededName = true;
      nameCtrl.text = AppLocalizations.of(context).voiceCloneDefaultName;
    }
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
        SnackBar(content: Text(AppLocalizations.of(context).voiceCloneNeedMic)),
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
    final l10n = AppLocalizations.of(context);
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voiceCloneNeedName)),
      );
      return;
    }
    if (!consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voiceCloneNeedConsent)),
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
        SnackBar(content: Text(l10n.voiceCloneSuccess)),
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
    final l10n = AppLocalizations.of(context);
    final canUpload =
        path != null && !recording && !uploading && consent && nameCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.voiceCloneTitle),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          BrandHeader(
            eyebrow: l10n.voiceCloneEyebrow,
            title: l10n.voiceCloneHeaderTitle,
            subtitle: l10n.voiceCloneHeaderSubtitle,
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: l10n.voiceCloneNameSection,
            child: TextField(
              controller: nameCtrl,
              maxLength: 64,
              decoration: InputDecoration(
                hintText: l10n.voiceCloneNameHint,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: l10n.voiceCloneUsageTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.voiceCloneUsageBody,
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
                            l10n.voiceCloneConsent,
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
            title: l10n.voiceCloneScriptTitle,
            subtitle: l10n.voiceCloneScriptSubtitle,
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
                      Text(l10n.voiceCloneScriptZh, style: tt.bodyLarge?.copyWith(height: 1.55)),
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
                          recording
                              ? l10n.voiceCloneStopRecord
                              : (path != null
                                  ? l10n.voiceCloneRerecord
                                  : l10n.voiceCloneStartRecord),
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
                        l10n.voiceCloneRecordingHint,
                        style: tt.bodySmall?.copyWith(color: AppColors.tertiary),
                      ),
                    ],
                  ),
                ] else if (path != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.voiceCloneReadyHint,
                    style: tt.bodySmall?.copyWith(color: AppColors.secondary),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: AmberCta(
                    label: uploading ? l10n.voiceCloneUploading : l10n.voiceCloneUpload,
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
