import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../config.dart';
import '../l10n/app_localizations.dart';
import '../local/local_store.dart';
import '../local/network_errors.dart';
import '../theme/app_theme.dart';

class _BedTrack {
  const _BedTrack({required this.id, required this.label, required this.asset});

  final String id;
  final String label;
  final String asset;
}

List<String> _splitSentences(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return const [];
  final parts = <String>[];
  final buf = StringBuffer();
  for (final rune in trimmed.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(ch);
    if ('。！？…；\n'.contains(ch)) {
      final s = buf.toString().trim();
      if (s.isNotEmpty) parts.add(s);
      buf.clear();
    }
  }
  final tail = buf.toString().trim();
  if (tail.isNotEmpty) parts.add(tail);
  return parts.isEmpty ? [trimmed] : parts;
}

int _sentenceIndexForPosition({
  required List<String> sentences,
  required Duration position,
  required Duration total,
}) {
  if (sentences.isEmpty) return 0;
  if (total.inMilliseconds <= 0) return 0;
  final totalChars = sentences.fold<int>(0, (a, s) => a + math.max(1, s.length));
  if (totalChars <= 0) return 0;
  final ratio = (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 0.999999);
  var target = ratio * totalChars;
  var acc = 0;
  for (var i = 0; i < sentences.length; i++) {
    acc += math.max(1, sentences[i].length);
    if (target < acc) return i;
  }
  return sentences.length - 1;
}

Duration _positionForSentence({
  required List<String> sentences,
  required int index,
  required Duration total,
}) {
  if (sentences.isEmpty || total.inMilliseconds <= 0) return Duration.zero;
  final i = index.clamp(0, sentences.length - 1);
  final totalChars = sentences.fold<int>(0, (a, s) => a + math.max(1, s.length));
  var before = 0;
  for (var k = 0; k < i; k++) {
    before += math.max(1, sentences[k].length);
  }
  final ms = (before / totalChars * total.inMilliseconds).round();
  return Duration(milliseconds: ms.clamp(0, total.inMilliseconds));
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.title,
    required this.body,
    this.storyId,
    this.audioUrl,
    this.softHook,
    this.theme,
    this.voiceName,
    this.core,
    this.localStore,
  });

  final String title;
  final String body;
  final int? storyId;
  final String? audioUrl;
  final String? softHook;
  final String? theme;
  final String? voiceName;
  final String? core;
  final LocalStore? localStore;

  /// Convenience for story JSON from API / list.
  factory PlayerScreen.fromStory(
    Map<String, dynamic> story, {
    LocalStore? localStore,
  }) {
    final id = story['id'];
    final storyId = id is int ? id : int.tryParse('$id');
    return PlayerScreen(
      title: story['title'] as String? ?? 'Story',
      body: story['body'] as String? ?? '',
      storyId: storyId,
      audioUrl: story['audio_url'] as String?,
      softHook: story['soft_hook'] as String?,
      theme: story['theme'] as String?,
      voiceName: story['voice_name'] as String?,
      core: story['core'] as String? ??
          story['development_focus_label'] as String?,
      localStore: localStore,
    );
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _bedTrack = _BedTrack(
    id: 'music_box',
    label: 'Music box', // localized via playerBedMusicBox when shown
    asset:
        'assets/audio/denis-pavlov-music-calm-baby-lullaby-sweet-dreams-music-box-397059.mp3',
  );

  String _bedTrackLabel(AppLocalizations l10n) => l10n.playerBedMusicBox;

  static const _bedVolumeDefault = 0.14;
  /// 0 = stop bed music as soon as narration ends.
  static const _outroMinutesOptions = <int>[0, 1, 5, 10, 15, 30];
  static const _outroMinutesDefault = 5;
  static const _outroFade = Duration(seconds: 20);
  static const _outroPrefsKey = 'bed_outro_minutes';
  static const _outroTick = Duration(milliseconds: 200);

  final narration = AudioPlayer();
  final bed = AudioPlayer(handleInterruptions: false);
  StreamSubscription<PlayerState>? _narrationStateSub;
  StreamSubscription<double>? _cacheProgressSub;
  Timer? _outroTimer;
  final _passageScroll = ScrollController();
  final Map<int, GlobalKey> _sentenceKeys = {};
  /// Story id currently being filled via LockCaching (cleared in dispose).
  int? _playbackCachingStoryId;

  late final List<String> _sentences = _splitSentences(widget.body);

  double playSpeed = 1.0;
  double bedVolume = _bedVolumeDefault;
  bool bedEnabled = true;
  bool showText = true;
  bool textExpanded = false;
  String? error;

  int outroMinutes = _outroMinutesDefault;
  bool _outroActive = false;
  DateTime? _outroEndsAt;

  bool _scrubbing = false;
  double _scrubMs = 0;
  int _lastScrolledSentence = -1;

  GlobalKey _keyFor(int i) => _sentenceKeys.putIfAbsent(i, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _narrationStateSub = narration.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_onNarrationCompleted());
      }
    });
    unawaited(_load());
  }

  String? _resolveUrl(String? url) {
    if (url == null) return null;
    if (url.startsWith('http')) return url;
    return '$apiBaseUrl$url';
  }

  Future<void> _persistProgress() async {
    final store = widget.localStore;
    final id = widget.storyId;
    if (store == null || id == null) return;
    try {
      final pos = narration.position;
      final total = narration.duration;
      if (total != null &&
          total.inMilliseconds > 0 &&
          pos.inMilliseconds >= total.inMilliseconds - 1500) {
        await store.playback.clear(id);
        return;
      }
      await store.playback.savePositionMs(id, pos.inMilliseconds);
    } catch (_) {}
  }

  Future<void> _loadNarrationSource({
    required LocalStore? store,
    required int? storyId,
    required String? localPath,
    required String? url,
  }) async {
    final noAudioMsg = AppLocalizations.of(context).storyNoAudioShort;
    if (localPath != null) {
      try {
        await narration.setFilePath(localPath);
        if (store != null && storyId != null) {
          await store.media.touchPlayed(storyId);
        }
        return;
      } catch (_) {
        // Corrupt / wrong-extension cache (e.g. legacy `.audio` on iOS).
        if (store != null && storyId != null) {
          await store.media.invalidate(storyId);
        }
      }
    }

    if (store != null && storyId != null && url != null) {
      store.media.beginPlaybackCaching(storyId);
      _playbackCachingStoryId = storyId;
      final cacheFile = await store.media.cacheFileFor(storyId);
      final headers = store.media.downloadHeaders(url);
      final source = LockCachingAudioSource(
        Uri.parse(url),
        cacheFile: cacheFile,
        headers: headers.isEmpty ? null : headers,
      );
      await _cacheProgressSub?.cancel();
      _cacheProgressSub = source.downloadProgressStream.listen((p) {
        if (p >= 1.0) {
          unawaited(store.media.markReadyIfComplete(storyId));
        }
      });
      try {
        await narration.setAudioSource(source);
        return;
      } catch (_) {
        store.media.endPlaybackCaching(storyId);
        _playbackCachingStoryId = null;
        await store.media.invalidate(storyId);
        await _cacheProgressSub?.cancel();
        _cacheProgressSub = null;
        // Fall through to plain streaming.
      }
    }

    if (url == null) {
      throw ApiException(noAudioMsg);
    }
    await narration.setUrl(url);
  }

  Future<void> _load() async {
    final store = widget.localStore;
    final storyId = widget.storyId;
    String? localPath;
    if (store != null && storyId != null) {
      localPath = await store.media.localPathIfReady(storyId);
    }

    final url = _resolveUrl(widget.audioUrl);
    if (localPath == null && url == null) {
      if (!mounted) return;
      setState(() => error = AppLocalizations.of(context).storyNoAudioShort);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_outroPrefsKey);
      if (saved != null && _outroMinutesOptions.contains(saved)) {
        outroMinutes = saved;
      }

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      await _cacheProgressSub?.cancel();
      _cacheProgressSub = null;

      await Future.wait([
        _loadNarrationSource(
          store: store,
          storyId: storyId,
          localPath: localPath,
          url: url,
        ),
        bed.setAsset(_bedTrack.asset),
      ]);
      if (!mounted) return;
      await bed.setLoopMode(LoopMode.one);
      await bed.setVolume(bedEnabled ? bedVolume : 0);
      await narration.setSpeed(playSpeed);

      if (store != null && storyId != null) {
        final resumeMs = await store.playback.getPositionMs(storyId);
        if (resumeMs != null && resumeMs > 1500) {
          await narration.seek(Duration(milliseconds: resumeMs));
        }
      }

      if (mounted) setState(() {});
      await Future.wait([
        narration.play(),
        if (bedEnabled) bed.play(),
      ]);
    } catch (e) {
      final cachingId = _playbackCachingStoryId;
      if (cachingId != null) {
        widget.localStore?.media.endPlaybackCaching(cachingId);
        _playbackCachingStoryId = null;
      }
      if (!mounted) return;
      setState(() => error = friendlyNetworkError(e));
    }
  }

  Future<void> _onNarrationCompleted() async {
    final store = widget.localStore;
    final id = widget.storyId;
    if (store != null && id != null) {
      unawaited(store.playback.clear(id));
      unawaited(store.media.markReadyIfComplete(id));
    }
    if (!bedEnabled) {
      await bed.pause();
      return;
    }
    if (outroMinutes <= 0) {
      await _cancelBedOutro(restoreVolume: false);
      try {
        await bed.setVolume(0);
        await bed.pause();
        await bed.setVolume(bedVolume);
      } catch (_) {
        /* ignore */
      }
      return;
    }
    await _startBedOutro(Duration(minutes: outroMinutes));
  }

  Future<void> _startBedOutro(Duration total) async {
    await _cancelBedOutro(restoreVolume: false);
    if (!bedEnabled) return;

    final fade = total <= _outroFade ? total : _outroFade;
    final hold = total - fade;
    final startVolume = bedVolume;
    final endsAt = DateTime.now().add(total);

    if (mounted) {
      setState(() {
        _outroActive = true;
        _outroEndsAt = endsAt;
      });
    }

    try {
      await bed.setVolume(startVolume);
      if (!bed.playing) await bed.play();
    } catch (_) {
      /* ignore */
    }

    final started = DateTime.now();
    _outroTimer = Timer.periodic(_outroTick, (timer) async {
      final elapsed = DateTime.now().difference(started);
      if (elapsed >= total) {
        timer.cancel();
        _outroTimer = null;
        try {
          await bed.setVolume(0);
          await bed.pause();
          await bed.setVolume(startVolume);
        } catch (_) {
          /* ignore */
        }
        if (mounted) {
          setState(() {
            _outroActive = false;
            _outroEndsAt = null;
          });
        }
        return;
      }

      if (elapsed < hold) {
        if (mounted) setState(() {});
        return;
      }

      final fadeElapsed = elapsed - hold;
      final t = fade.inMilliseconds <= 0
          ? 1.0
          : (fadeElapsed.inMilliseconds / fade.inMilliseconds).clamp(0.0, 1.0);
      final vol = startVolume * (1.0 - t);
      try {
        await bed.setVolume(vol);
      } catch (_) {
        /* ignore */
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _cancelBedOutro({bool restoreVolume = true}) async {
    _outroTimer?.cancel();
    _outroTimer = null;
    final wasActive = _outroActive;
    if (mounted && wasActive) {
      setState(() {
        _outroActive = false;
        _outroEndsAt = null;
      });
    } else {
      _outroActive = false;
      _outroEndsAt = null;
    }
    if (restoreVolume && bedEnabled) {
      try {
        await bed.setVolume(bedVolume);
      } catch (_) {
        /* ignore */
      }
    }
  }

  Future<void> _setOutroMinutes(int minutes) async {
    if (minutes == outroMinutes) return;
    setState(() => outroMinutes = minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_outroPrefsKey, minutes);
    if (_outroActive) {
      await _startBedOutro(Duration(minutes: minutes));
    }
  }

  Future<void> _togglePlayPause(bool playing) async {
    if (playing) {
      await _cancelBedOutro();
      await Future.wait([narration.pause(), bed.pause()]);
      return;
    }

    await _cancelBedOutro();
    if (narration.processingState == ProcessingState.completed) {
      await narration.seek(Duration.zero);
    }
    await Future.wait([
      narration.play(),
      if (bedEnabled) bed.play(),
    ]);
  }

  Future<void> _seekTo(Duration next) async {
    final total = narration.duration ?? Duration.zero;
    var clamped = next;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (total > Duration.zero && clamped > total) clamped = total;
    if (narration.processingState == ProcessingState.completed || _outroActive) {
      await _cancelBedOutro();
    }
    await narration.seek(clamped);
    if (!narration.playing &&
        narration.processingState != ProcessingState.completed) {
      await Future.wait([
        narration.play(),
        if (bedEnabled) bed.play(),
      ]);
    }
  }

  Future<void> _seekToSentence(int index) async {
    final total = narration.duration ?? Duration.zero;
    await _seekTo(
      _positionForSentence(sentences: _sentences, index: index, total: total),
    );
  }

  Future<void> _setBedEnabled(bool enabled) async {
    setState(() => bedEnabled = enabled);
    if (!enabled) {
      await _cancelBedOutro(restoreVolume: false);
      await bed.setVolume(0);
      await bed.pause();
      return;
    }
    await bed.setVolume(bedVolume);
    // Explicitly turning on should always start bed audio (UI stays in sync).
    await bed.play();
  }

  Future<void> _setBedVolume(double v) async {
    setState(() => bedVolume = v);
    if (bedEnabled && !_outroActive) {
      await bed.setVolume(v);
    }
  }

  Future<void> _setPlaySpeed(double v) async {
    setState(() => playSpeed = v);
    await narration.setSpeed(v);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtOutroRemain(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 3600);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _maybeScrollToSentence(int index) {
    if (!textExpanded || index == _lastScrolledSentence) return;
    _lastScrolledSentence = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keyFor(index).currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
        alignment: 0.35,
      );
    });
  }

  List<Widget> _metaChips() {
    final chips = <Widget>[];
    final voice = widget.voiceName?.trim();
    if (voice != null && voice.isNotEmpty) {
      chips.add(_MetaChip(
        icon: Icons.record_voice_over_outlined,
        label: voice,
        accent: true,
      ));
    }
    final core = widget.core?.trim();
    final theme = widget.theme?.trim();
    if (core != null && core.isNotEmpty) {
      chips.add(_MetaChip(icon: Icons.auto_awesome_outlined, label: core));
    } else if (theme != null && theme.isNotEmpty) {
      chips.add(_MetaChip(icon: Icons.spa_outlined, label: theme));
    }
    return chips;
  }

  String _outroMoodLabel(int minutes) {
    final l10n = AppLocalizations.of(context);
    switch (minutes) {
      case 0:
        return l10n.playerOutroMood0;
      case 1:
        return l10n.playerOutroMood1;
      case 5:
        return l10n.playerOutroMood5;
      case 10:
        return l10n.playerOutroMood10;
      case 15:
        return l10n.playerOutroMood15;
      case 30:
        return l10n.playerOutroMood30;
      default:
        return l10n.playerOutroMoodMinutes(minutes);
    }
  }

  Future<void> _openTimerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) {
        return _OutroTimerSheet(
          minutesOptions: _outroMinutesOptions,
          defaultMinutes: _outroMinutesDefault,
          getMinutes: () => outroMinutes,
          getActive: () => _outroActive,
          getEndsAt: () => _outroEndsAt,
          moodLabel: _outroMoodLabel,
          formatRemain: _fmtOutroRemain,
          onSelectMinutes: (m) async {
            await _setOutroMinutes(m);
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  Future<void> _openSpeedSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.paddingOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(AppLocalizations.of(ctx).playerSpeedTitle, style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(ctx).playerSpeedHint,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceDim,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '0.70×',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      Expanded(
                        child: Slider(
                          value: playSpeed,
                          min: 0.7,
                          max: 1.2,
                          divisions: 10,
                          label: '${playSpeed.toStringAsFixed(2)}×',
                          onChanged: (v) async {
                            await _setPlaySpeed(v);
                            setModal(() {});
                          },
                        ),
                      ),
                      Text(
                        '1.20×',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Text(
                    AppLocalizations.of(ctx).playerSpeedCurrent(playSpeed.toStringAsFixed(2)),
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openBedSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) {
        // Local mirror so Switch / opacity rebuild immediately (parent setState
        // alone does not refresh this sheet's StatefulBuilder).
        var sheetEnabled = bedEnabled;
        var sheetVolume = bedVolume;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.paddingOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.music_note_outlined,
                          size: 18, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).playerBedTrack(_bedTrackLabel(AppLocalizations.of(context))),
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: sheetEnabled,
                        onChanged: (v) async {
                          setModal(() => sheetEnabled = v);
                          await _setBedEnabled(v);
                          if (!ctx.mounted) return;
                          setModal(() {
                            sheetEnabled = bedEnabled;
                            sheetVolume = bedVolume;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: sheetEnabled ? 1 : 0.4,
                    child: Row(
                      children: [
                        const Icon(Icons.volume_mute,
                            size: 16, color: AppColors.onSurfaceDim),
                        Expanded(
                          child: Slider(
                            value: sheetVolume,
                            min: 0.04,
                            max: 0.35,
                            divisions: 31,
                            label: '${(sheetVolume * 100).round()}%',
                            onChanged: sheetEnabled
                                ? (v) async {
                                    setModal(() => sheetVolume = v);
                                    await _setBedVolume(v);
                                    if (!ctx.mounted) return;
                                    setModal(() => sheetVolume = bedVolume);
                                  }
                                : null,
                          ),
                        ),
                        Text(
                          '${(sheetVolume * 100).round()}%',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _outroTimer?.cancel();
    _narrationStateSub?.cancel();
    unawaited(_cacheProgressSub?.cancel() ?? Future<void>.value());
    _cacheProgressSub = null;
    final store = widget.localStore;
    final id = widget.storyId;
    final cachingId = _playbackCachingStoryId;
    if (store != null && cachingId != null) {
      unawaited(store.media.markReadyIfComplete(cachingId));
      store.media.endPlaybackCaching(cachingId);
      _playbackCachingStoryId = null;
    }
    if (store != null && id != null) {
      try {
        final pos = narration.position;
        final total = narration.duration;
        if (total != null &&
            total.inMilliseconds > 0 &&
            pos.inMilliseconds >= total.inMilliseconds - 1500) {
          unawaited(store.playback.clear(id));
        } else if (pos.inMilliseconds > 0) {
          unawaited(store.playback.savePositionMs(id, pos.inMilliseconds));
        }
      } catch (_) {}
    }
    _passageScroll.dispose();
    narration.dispose();
    bed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final outroRemain = _outroEndsAt?.difference(DateTime.now());

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_persistProgress());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).playerTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFFFB4AB)),
                      ),
                    ),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppLocalizations.of(context).playerStatusLive,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ModePill(
                              label: AppLocalizations.of(context).playerModePicture,
                              selected: showText,
                              onTap: () => setState(() => showText = true),
                            ),
                            _ModePill(
                              label: AppLocalizations.of(context).playerModeAudio,
                              selected: !showText,
                              onTap: () => setState(() => showText = false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!textExpanded) ...[
                    const SizedBox(height: 10),
                    AspectRatio(
                      aspectRatio: 1.6,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A2A3F),
                              Color(0xFF164F4A),
                              Color(0xFF2A1F18),
                            ],
                          ),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -24,
                              top: -16,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.lanternGlow,
                                ),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.nightlight_round,
                                    size: 44,
                                    color: AppColors.primary.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    AppLocalizations.of(context).playerWarmLight,
                                    style: tt.titleMedium?.copyWith(
                                      color: AppColors.primarySoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else
                    const SizedBox(height: 4),
                  Text(
                    widget.title,
                    maxLines: textExpanded ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.headlineMedium?.copyWith(
                      fontSize: textExpanded ? 20 : 24,
                    ),
                  ),
                  if (!textExpanded) ...[
                    const SizedBox(height: 2),
                    Text(AppLocalizations.of(context).playerBrandLine, style: tt.bodyMedium),
                    if (_metaChips().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _metaChips(),
                      ),
                    ],
                  ],
                    const SizedBox(height: 10),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: showText ? 1 : 0.28,
                        duration: const Duration(milliseconds: 280),
                        child: _buildPassageCard(tt),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildDock(tt, outroRemain),
          ],
        ),
      ),
    );
  }

  Widget _buildPassageCard(TextTheme tt) {
    return StreamBuilder<Duration>(
      stream: narration.positionStream,
      builder: (context, snap) {
        final pos = _scrubbing
            ? Duration(milliseconds: _scrubMs.round())
            : (snap.data ?? Duration.zero);
        final total = narration.duration ?? Duration.zero;
        final idx = _sentenceIndexForPosition(
          sentences: _sentences,
          position: pos,
          total: total,
        );
        _maybeScrollToSentence(idx);

        final current = _sentences.isEmpty ? widget.body : _sentences[idx];
        final next = (idx + 1 < _sentences.length)
            ? _sentences[idx + 1]
            : (widget.softHook?.trim().isNotEmpty == true
                ? widget.softHook!.trim()
                : null);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_stories, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).playerCoRead,
                    style: tt.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    textExpanded
                        ? AppLocalizations.of(context).playerFullText
                        : AppLocalizations.of(context).playerFollowAlong,
                    style: tt.bodySmall?.copyWith(color: AppColors.onSurfaceDim),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        textExpanded = !textExpanded;
                        if (!textExpanded) _lastScrolledSentence = -1;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.secondary,
                    ),
                    child: Text(
                      textExpanded
                          ? AppLocalizations.of(context).playerCollapse
                          : AppLocalizations.of(context).playerExpand,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!textExpanded)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.08),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          child: SingleChildScrollView(
                            key: ValueKey<int>(idx),
                            child: Text(
                              current,
                              style: tt.bodyLarge?.copyWith(
                                height: 1.65,
                                color: AppColors.primarySoft,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (next != null && next.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          child: Text(
                            next,
                            key: ValueKey<String>('next-$idx'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceDim.withValues(alpha: 0.72),
                              height: 1.45,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: _passageScroll,
                    itemCount: _sentences.length,
                    itemBuilder: (context, i) {
                      final active = i == idx;
                      return KeyedSubtree(
                        key: _keyFor(i),
                        child: InkWell(
                          onTap: () => _seekToSentence(i),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeInOutCubic,
                            style: (tt.bodyLarge ?? const TextStyle()).copyWith(
                              height: 1.6,
                              fontSize: active ? 17 : 15,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.w400,
                              color: active
                                  ? AppColors.primarySoft
                                  : AppColors.onSurfaceDim.withValues(
                                      alpha: 0.75,
                                    ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              child: Text(_sentences[i]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDock(TextTheme tt, Duration? outroRemain) {
    return Material(
      color: AppColors.background,
      elevation: 8,
      shadowColor: Colors.black54,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<Duration>(
                stream: narration.positionStream,
                builder: (context, snap) {
                  final streamPos = snap.data ?? Duration.zero;
                  final total = narration.duration ?? Duration.zero;
                  final maxMs = total.inMilliseconds <= 0
                      ? 1.0
                      : total.inMilliseconds.toDouble();
                  final pos = _scrubbing
                      ? Duration(milliseconds: _scrubMs.round())
                      : streamPos;
                  final value =
                      (_scrubbing ? _scrubMs : streamPos.inMilliseconds.toDouble())
                          .clamp(0.0, maxMs);
                  final remain = total > pos ? total - pos : Duration.zero;
                  final centerBits = <String>[];
                  if (total > Duration.zero) {
                    centerBits.add(AppLocalizations.of(context).playerRemain(_fmt(remain)));
                  }
                  if (_outroActive &&
                      outroRemain != null &&
                      !outroRemain.isNegative) {
                    centerBits.add(AppLocalizations.of(context).playerBedFading);
                  } else if (outroMinutes <= 0) {
                    centerBits.add(AppLocalizations.of(context).playerOutroOff);
                  } else {
                    centerBits.add(AppLocalizations.of(context).playerOutroMinutes(outroMinutes));
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            _fmt(pos),
                            style: tt.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              centerBits.join(' · '),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: AppColors.onSurfaceDim,
                              ),
                            ),
                          ),
                          Text(
                            total > Duration.zero ? _fmt(total) : '--:--',
                            style: tt.bodySmall,
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: value,
                          min: 0,
                          max: maxMs,
                          onChangeStart: (v) {
                            setState(() {
                              _scrubbing = true;
                              _scrubMs = v;
                            });
                          },
                          onChanged: (v) => setState(() => _scrubMs = v),
                          onChangeEnd: (v) async {
                            await _seekTo(Duration(milliseconds: v.round()));
                            if (!mounted) return;
                            setState(() {
                              _scrubbing = false;
                              _scrubMs = v;
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              StreamBuilder<PlayerState>(
                stream: narration.playerStateStream,
                builder: (context, snap) {
                  final playing =
                      (snap.data?.playing ?? false) || _outroActive;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _DockAction(
                        icon: Icons.alarm_outlined,
                        label: outroMinutes <= 0
                            ? AppLocalizations.of(context).playerOutroOffShort
                            : AppLocalizations.of(context).playerOutroMinutesShort(outroMinutes),
                        onTap: _openTimerSheet,
                      ),
                      _DockAction(
                        icon: Icons.speed,
                        label: '${playSpeed.toStringAsFixed(2)}×',
                        onTap: _openSpeedSheet,
                      ),
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.lanternGlow,
                              blurRadius: 22,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _togglePlayPause(playing),
                            child: SizedBox(
                              width: 68,
                              height: 68,
                              child: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 36,
                                color: AppColors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _DockAction(
                        icon: bedEnabled
                            ? Icons.music_note_outlined
                            : Icons.music_off_outlined,
                        label: bedEnabled
                            ? _bedTrackLabel(AppLocalizations.of(context))
                            : AppLocalizations.of(context).playerBedOff,
                        onTap: _openBedSheet,
                      ),
                      _DockAction(
                        icon: showText
                            ? Icons.menu_book_rounded
                            : Icons.menu_book_outlined,
                        label: AppLocalizations.of(context).playerScript,
                        onTap: () => setState(() => showText = !showText),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for bed-outro delay; ticks so remaining time updates live.
class _OutroTimerSheet extends StatefulWidget {
  const _OutroTimerSheet({
    required this.minutesOptions,
    required this.defaultMinutes,
    required this.getMinutes,
    required this.getActive,
    required this.getEndsAt,
    required this.moodLabel,
    required this.formatRemain,
    required this.onSelectMinutes,
  });

  final List<int> minutesOptions;
  final int defaultMinutes;
  final int Function() getMinutes;
  final bool Function() getActive;
  final DateTime? Function() getEndsAt;
  final String Function(int minutes) moodLabel;
  final String Function(Duration d) formatRemain;
  final Future<void> Function(int minutes) onSelectMinutes;

  @override
  State<_OutroTimerSheet> createState() => _OutroTimerSheetState();
}

class _OutroTimerSheetState extends State<_OutroTimerSheet> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticks = widget.minutesOptions;
    final minutes = widget.getMinutes();
    var idx = ticks.indexOf(minutes);
    if (idx < 0) {
      idx = ticks.indexOf(widget.defaultMinutes).clamp(0, ticks.length - 1);
    }
    final active = widget.getActive();
    final endsAt = widget.getEndsAt();
    final remain = endsAt?.difference(DateTime.now());
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppLocalizations.of(context).playerTimerTitle, style: tt.titleMedium),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).playerTimerSubtitle,
            style: tt.bodySmall?.copyWith(
              color: AppColors.onSurfaceDim,
            ),
          ),
          if (active && remain != null && !remain.isNegative) ...[
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).playerTimerFading(widget.formatRemain(remain)),
              style: tt.bodySmall?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.alarm_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context).playerTimerDelay, style: tt.labelLarge),
              const Spacer(),
              Text(
                widget.moodLabel(minutes),
                style: tt.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surfaceHighest,
              thumbColor: AppColors.primaryContainer,
              overlayColor: AppColors.primary.withValues(alpha: 0.18),
              activeTickMarkColor: AppColors.onPrimary,
              inactiveTickMarkColor: AppColors.onSurfaceDim,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: idx.toDouble(),
              min: 0,
              max: (ticks.length - 1).toDouble(),
              divisions: ticks.length - 1,
              onChanged: (v) async {
                await widget.onSelectMinutes(ticks[v.round()]);
                if (mounted) setState(() {});
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final m in ticks)
                  Text(
                    m == 0 ? AppLocalizations.of(context).playerOutroOffShort : '$m',
                    style: tt.labelSmall?.copyWith(
                      color: m == minutes
                          ? AppColors.primary
                          : AppColors.onSurfaceDim,
                      fontWeight:
                          m == minutes ? FontWeight.w700 : FontWeight.w500,
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

class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppColors.onSurfaceMuted),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceDim,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.secondary : AppColors.onSurfaceDim,
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: accent ? AppColors.secondary : AppColors.onSurfaceDim,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: accent ? AppColors.secondary : AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}
