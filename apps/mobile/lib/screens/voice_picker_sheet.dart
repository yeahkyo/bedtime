import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Modal picker: system / clone sections, preview, description.
Future<int?> showVoicePickerSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> voices,
  int? selectedId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (ctx) => _VoicePickerSheet(
      voices: voices,
      selectedId: selectedId,
    ),
  );
}

class _VoicePickerSheet extends StatefulWidget {
  const _VoicePickerSheet({
    required this.voices,
    this.selectedId,
  });

  final List<Map<String, dynamic>> voices;
  final int? selectedId;

  @override
  State<_VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends State<_VoicePickerSheet> {
  late int? _selectedId;
  final _preview = AudioPlayer();
  int? _loadingId;
  int? _playingId;
  /// Bumps on each preview request so an older load cannot resume after interrupt.
  int _previewGen = 0;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
    _preview.playerStateStream.listen((state) {
      if (!mounted) return;
      // just_audio's play() Future may not complete until end — drive UI from stream.
      if (state.playing && _loadingId != null) {
        setState(() {
          _playingId = _loadingId;
          _loadingId = null;
        });
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playingId = null;
          _loadingId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _previewGen++;
    _preview.stop();
    _preview.dispose();
    super.dispose();
  }

  int? _asId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  List<Map<String, dynamic>> _ofKind(String kind) {
    return widget.voices
        .where((v) => (v['kind'] as String?) == kind)
        .toList();
  }

  Future<void> _togglePreview(Map<String, dynamic> voice) async {
    final id = _asId(voice['id']);
    if (id == null) return;
    final url = resolveMediaUrl(voice['preview_audio_url'] as String?);
    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).voicesPreviewUnavailableShort)),
      );
      return;
    }
    // Same item while playing (or ready to play) → stop.
    if (_playingId == id) {
      _previewGen++;
      await _preview.stop();
      if (mounted) {
        setState(() {
          _playingId = null;
          _loadingId = null;
        });
      }
      return;
    }
    // Same item while loading → cancel.
    if (_loadingId == id) {
      _previewGen++;
      await _preview.stop();
      if (mounted) {
        setState(() {
          _loadingId = null;
          _playingId = null;
        });
      }
      return;
    }
    final gen = ++_previewGen;
    if (mounted) {
      setState(() {
        _loadingId = id;
        _playingId = null;
      });
    }
    try {
      await _preview.stop();
      if (gen != _previewGen) return;
      await _preview.setUrl(url);
      if (gen != _previewGen || !mounted) return;
      // Flip to playing as soon as source is ready; do not await play() (it can
      // complete only when the clip ends on some platforms).
      setState(() {
        _loadingId = null;
        _playingId = id;
      });
      await _preview.play();
    } catch (_) {
      if (gen != _previewGen || !mounted) return;
      setState(() {
        _loadingId = null;
        _playingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).voicesPreviewFailed)),
      );
    }
  }

  Widget _section(String title, List<Map<String, dynamic>> rows) {
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: tt.titleSmall?.copyWith(color: AppColors.primarySoft)),
            const SizedBox(height: 8),
            Text(l10n.voicePickerEmpty, style: tt.bodySmall?.copyWith(color: AppColors.onSurfaceDim)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tt.titleSmall?.copyWith(color: AppColors.primarySoft)),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _voiceTile(rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _voiceTile(Map<String, dynamic> voice) {
    final tt = Theme.of(context).textTheme;
    final id = _asId(voice['id']);
    final selected = id != null && id == _selectedId;
    final l10n = AppLocalizations.of(context);
    final name = (voice['name'] as String?)?.trim().isNotEmpty == true
        ? voice['name'] as String
        : l10n.voicePickerUnnamed;
    final desc = (voice['description'] as String?)?.trim() ?? '';
    final hasPreview = (voice['preview_audio_url'] as String?)?.isNotEmpty == true;
    final loading = id != null && _loadingId == id;
    final playing = id != null && _playingId == id && !loading;

    return InkWell(
      onTap: id == null ? null : () => setState(() => _selectedId = id),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.onSurfaceDim,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: tt.titleMedium),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: tt.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: !hasPreview
                  ? l10n.voicesPreviewUnavailable
                  : (loading
                      ? l10n.commonLoading
                      : (playing
                          ? l10n.voicesPreviewStopShort
                          : l10n.voicesPreviewPlay)),
              onPressed: hasPreview ? () => _togglePreview(voice) : null,
              icon: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      playing
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                      color: hasPreview
                          ? AppColors.primary
                          : AppColors.primarySoft.withValues(alpha: 0.35),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final system = _ofKind('system');
    final clones = kFeatureVoiceClone ? _ofKind('clone') : const <Map<String, dynamic>>[];
    final maxH = MediaQuery.of(context).size.height * 0.78;

    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.voicePickerTitle, style: tt.titleLarge),
                  ),
                  IconButton(
                    tooltip: l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l10n.voicePickerHint,
                style: tt.bodySmall?.copyWith(color: AppColors.onSurfaceDim),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                children: [
                  _section(l10n.voicesKindSystem, system),
                  if (kFeatureVoiceClone) _section(l10n.voicesKindClone, clones),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: _selectedId == null
                    ? null
                    : () => Navigator.of(context).pop(_selectedId),
                child: Text(l10n.voicePickerUse),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
