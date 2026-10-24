import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../config.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import 'voice_clone_screen.dart';

/// List / rename voices; entry to clone flow; play stored preview samples.
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
  final _preview = AudioPlayer();
  int? _loadingVoiceId;
  int? _playingVoiceId;
  /// Bumps on each preview request so an older load cannot resume after interrupt.
  int _previewGen = 0;

  @override
  void initState() {
    super.initState();
    _preview.playerStateStream.listen((state) {
      if (!mounted) return;
      // just_audio's play() Future may not complete until end — drive UI from stream.
      if (state.playing && _loadingVoiceId != null) {
        setState(() {
          _playingVoiceId = _loadingVoiceId;
          _loadingVoiceId = null;
        });
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playingVoiceId = null;
          _loadingVoiceId = null;
        });
      }
    });
    _refresh();
  }

  @override
  void dispose() {
    _previewGen++;
    _preview.stop();
    _preview.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      try {
        await widget.api.ensureSystemVoice();
      } catch (_) {
        // Disabled system catalog must not block listing clones.
      }
      var listed = await widget.api.listVoices();
      if (!kFeatureVoiceClone) {
        listed = listed.where((v) {
          final m = v as Map<String, dynamic>;
          return m['kind'] != 'clone';
        }).toList();
      }
      voices = listed;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openClone() async {
    if (!kFeatureVoiceClone) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VoiceCloneScreen(api: widget.api)),
    );
    if (created == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _togglePreview(Map<String, dynamic> voice) async {
    final id = voice['id'] as int?;
    if (id == null) return;
    final url = resolveMediaUrl(voice['preview_audio_url'] as String?);
    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).voicesPreviewUnavailableSnack)),
      );
      return;
    }
    if (_playingVoiceId == id) {
      _previewGen++;
      await _preview.stop();
      if (mounted) {
        setState(() {
          _playingVoiceId = null;
          _loadingVoiceId = null;
        });
      }
      return;
    }
    if (_loadingVoiceId == id) {
      _previewGen++;
      await _preview.stop();
      if (mounted) {
        setState(() {
          _loadingVoiceId = null;
          _playingVoiceId = null;
        });
      }
      return;
    }
    final gen = ++_previewGen;
    if (mounted) {
      setState(() {
        _loadingVoiceId = id;
        _playingVoiceId = null;
      });
    }
    try {
      await _preview.stop();
      if (gen != _previewGen) return;
      await _preview.setUrl(url);
      if (gen != _previewGen || !mounted) return;
      // Flip to playing as soon as source is ready; do not await play() before
      // updating UI (play()'s Future can complete only when the clip ends).
      setState(() {
        _loadingVoiceId = null;
        _playingVoiceId = id;
      });
      await _preview.play();
    } catch (_) {
      if (gen != _previewGen || !mounted) return;
      setState(() {
        _loadingVoiceId = null;
        _playingVoiceId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).voicesPreviewFailed)),
      );
    }
  }

  String _kindLabel(AppLocalizations l10n, String? kind) {
    switch (kind) {
      case 'clone':
        return l10n.voicesKindClone;
      case 'system':
        return l10n.voicesKindSystem;
      default:
        return kind ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.voicesManageTitle),
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
                  BrandHeader(
                    eyebrow: l10n.voicesManageEyebrow,
                    title: l10n.voicesManageHeaderTitle,
                    subtitle: kFeatureVoiceClone
                        ? l10n.voicesManageSubtitleClone
                        : l10n.voicesManageSubtitleSystem,
                  ),
                  const SizedBox(height: 18),
                  if (kFeatureVoiceClone) ...[
                    AmberCta(
                      label: l10n.voicesManageCloneCta,
                      icon: Icons.mic_none,
                      onPressed: _openClone,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (error != null) ...[
                    Text(error!, style: tt.bodySmall?.copyWith(color: Colors.redAccent)),
                    const SizedBox(height: 12),
                  ],
                  SectionCard(
                    title: l10n.voicesManageSectionTitle,
                    subtitle: voices.isEmpty
                        ? l10n.voicesManageNone
                        : l10n.voicesManageCount(voices.length),
                    child: voices.isEmpty
                        ? Text(
                            kFeatureVoiceClone
                                ? l10n.voicesManageEmptyCloneHint
                                : l10n.voicesManageEmptySystemHint,
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
                                    final id = m['id'] as int?;
                                    final hasPreview =
                                        (m['preview_audio_url'] as String?)
                                            ?.isNotEmpty ==
                                        true;
                                    final previewLoading =
                                        id != null && _loadingVoiceId == id;
                                    final playing = id != null &&
                                        _playingVoiceId == id &&
                                        !previewLoading;
                                    final desc =
                                        (m['description'] as String?)?.trim();
                                    final subtitle = (desc != null &&
                                            desc.isNotEmpty)
                                        ? desc
                                        : '${_kindLabel(l10n, kind)} · ${m['language'] ?? 'zh'}'
                                            '${hasPreview ? '' : l10n.voicesNoPreviewSuffix}';
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
                                                subtitle,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: tt.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: !hasPreview
                                              ? l10n.voicesPreviewUnavailable
                                              : (previewLoading
                                                  ? l10n.commonLoading
                                                  : (playing
                                                      ? l10n.voicesPreviewStop
                                                      : l10n.voicesPreviewPlay)),
                                          onPressed: hasPreview
                                              ? () => _togglePreview(m)
                                              : null,
                                          icon: previewLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.primary,
                                                  ),
                                                )
                                              : Icon(
                                                  playing
                                                      ? Icons
                                                          .stop_circle_outlined
                                                      : Icons
                                                          .play_circle_outline,
                                                  color: hasPreview
                                                      ? AppColors.primary
                                                      : AppColors.primarySoft
                                                          .withValues(
                                                              alpha: 0.35),
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
