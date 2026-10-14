import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
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
    this.audioUrl,
    this.softHook,
    this.theme,
    this.voiceName,
    this.developmentFocusLabel,
  });

  final String title;
  final String body;
  final String? audioUrl;
  final String? softHook;
  final String? theme;
  final String? voiceName;
  final String? developmentFocusLabel;

  /// Convenience for story JSON from API / list.
  factory PlayerScreen.fromStory(Map<String, dynamic> story) {
    return PlayerScreen(
      title: story['title'] as String? ?? 'Story',
      body: story['body'] as String? ?? '',
      audioUrl: story['audio_url'] as String?,
      softHook: story['soft_hook'] as String?,
      theme: story['theme'] as String?,
      voiceName: story['voice_name'] as String?,
      developmentFocusLabel: story['development_focus_label'] as String?,
    );
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _bedTrack = _BedTrack(
    id: 'music_box',
    label: '八音盒',
    asset:
        'assets/audio/denis-pavlov-music-calm-baby-lullaby-sweet-dreams-music-box-397059.mp3',
  );

  static const _bedVolumeDefault = 0.14;
  static const _outroMinutesOptions = <int>[1, 5, 10, 30, 60];
  static const _outroMinutesDefault = 5;
  static const _outroFade = Duration(seconds: 20);
  static const _outroPrefsKey = 'bed_outro_minutes';
  static const _outroTick = Duration(milliseconds: 200);

  final narration = AudioPlayer();
  final bed = AudioPlayer(handleInterruptions: false);
  StreamSubscription<PlayerState>? _narrationStateSub;
  Timer? _outroTimer;
  final _passageScroll = ScrollController();
  final Map<int, GlobalKey> _sentenceKeys = {};

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

  Future<void> _load() async {
    final url = _resolveUrl(widget.audioUrl);
    if (url == null) {
      if (!mounted) return;
      setState(() => error = '暂无音频');
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

      await Future.wait([
        narration.setUrl(url),
        bed.setAsset(_bedTrack.asset),
      ]);
      if (!mounted) return;
      await bed.setLoopMode(LoopMode.one);
      await bed.setVolume(bedEnabled ? bedVolume : 0);
      await narration.setSpeed(playSpeed);
      if (mounted) setState(() {});
      await Future.wait([
        narration.play(),
        if (bedEnabled) bed.play(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }
  }

  Future<void> _onNarrationCompleted() async {
    if (!bedEnabled) {
      await bed.pause();
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
    if (narration.playing || _outroActive) {
      await bed.play();
    }
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
    final focus = widget.developmentFocusLabel?.trim();
    final theme = widget.theme?.trim();
    if (focus != null && focus.isNotEmpty) {
      chips.add(_MetaChip(icon: Icons.auto_awesome_outlined, label: focus));
    } else if (theme != null && theme.isNotEmpty) {
      chips.add(_MetaChip(icon: Icons.spa_outlined, label: theme));
    }
    return chips;
  }

  Future<void> _openTimerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final remain = _outroEndsAt?.difference(DateTime.now());
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
                  Text('故事结束后', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    '背景音再播多久后渐弱结束（不中途打断旁白）。',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceDim,
                        ),
                  ),
                  if (_outroActive && remain != null && !remain.isNegative) ...[
                    const SizedBox(height: 8),
                    Text(
                      '背景音正慢慢停下 · 剩余 ${_fmtOutroRemain(remain)}',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _outroMinutesOptions)
                        ChoiceChip(
                          label: Text('$m 分钟'),
                          selected: outroMinutes == m,
                          onSelected: (_) async {
                            await _setOutroMinutes(m);
                            setModal(() {});
                            if (mounted) setState(() {});
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
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
                  Text('朗读倍速', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    '只改变故事朗读速度，背景音乐不受影响。不会重新合成音频。',
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
                    '当前 ${playSpeed.toStringAsFixed(2)}×',
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
                      const Icon(Icons.water_drop_outlined,
                          size: 18, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '摇篮背景音 · ${_bedTrack.label}',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: bedEnabled,
                        onChanged: (v) async {
                          await _setBedEnabled(v);
                          setModal(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: bedEnabled ? 1 : 0.4,
                    child: Row(
                      children: [
                        const Icon(Icons.volume_mute,
                            size: 16, color: AppColors.onSurfaceDim),
                        Expanded(
                          child: Slider(
                            value: bedVolume,
                            min: 0.04,
                            max: 0.35,
                            divisions: 31,
                            label: '${(bedVolume * 100).round()}%',
                            onChanged: bedEnabled
                                ? (v) async {
                                    await _setBedVolume(v);
                                    setModal(() {});
                                  }
                                : null,
                          ),
                        ),
                        Text(
                          '${(bedVolume * 100).round()}%',
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
    _passageScroll.dispose();
    narration.dispose();
    bed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final outroRemain = _outroEndsAt?.difference(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('伴读'),
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
                                  '床头暖灯 · 伴睡夜播中',
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
                              label: '绘本伴读',
                              selected: showText,
                              onTap: () => setState(() => showText = true),
                            ),
                            _ModePill(
                              label: '纯听',
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
                                    '枕边暖光',
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
                    Text('呼呼 · 枕边故事', style: tt.bodyMedium),
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
                    '亲子同屏伴读',
                    style: tt.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    textExpanded ? '全文' : '字句平滑随行',
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
                    child: Text(textExpanded ? '收起' : '查看全文'),
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
                    centerBits.add('剩余 ${_fmt(remain)}');
                  }
                  if (_outroActive &&
                      outroRemain != null &&
                      !outroRemain.isNegative) {
                    centerBits.add('背景音正慢慢停下');
                  } else {
                    centerBits.add('结束后再播$outroMinutes分钟');
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
                        icon: Icons.bedtime_outlined,
                        label: '$outroMinutes分钟',
                        onTap: _openTimerSheet,
                      ),
                      _DockAction(
                        icon: Icons.graphic_eq,
                        label: '${playSpeed.toStringAsFixed(2)}×',
                        onTap: _openSpeedSheet,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
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
                            ? Icons.water_drop_outlined
                            : Icons.water_drop,
                        label: bedEnabled ? _bedTrack.label : '已关',
                        onTap: _openBedSheet,
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
        width: 72,
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
