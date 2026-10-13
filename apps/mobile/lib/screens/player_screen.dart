import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../config.dart';
import '../theme/app_theme.dart';

class _BedTrack {
  const _BedTrack({required this.id, required this.label, required this.asset});

  final String id;
  final String label;
  final String asset;
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.title,
    required this.body,
    this.audioUrl,
    this.softHook,
  });

  final String title;
  final String body;
  final String? audioUrl;
  final String? softHook;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _bedTracks = <_BedTrack>[
    _BedTrack(
      id: 'ambient',
      label: '柔和垫乐',
      asset: 'assets/audio/bed_soft_ambient.mp3',
    ),
    _BedTrack(
      id: 'music_box',
      label: '八音盒',
      asset:
          'assets/audio/denis-pavlov-music-calm-baby-lullaby-sweet-dreams-music-box-397059.mp3',
    ),
  ];

  /// Rotate default bed track across story opens so both get A/B exposure.
  static int _nextBedIndex = 0;

  static const _bedVolumeDefault = 0.14;

  final narration = AudioPlayer();
  // Avoid fighting the narration player for audio-session focus.
  final bed = AudioPlayer(handleInterruptions: false);
  StreamSubscription<PlayerState>? _narrationStateSub;

  late int bedIndex;
  double playSpeed = 1.0;
  double bedVolume = _bedVolumeDefault;
  bool bedEnabled = true;
  bool bedLoading = false;
  /// Design: 绘本伴读 vs 纯听熄屏 — keep text visible by default.
  bool showText = true;
  String? error;

  _BedTrack get _currentBed => _bedTracks[bedIndex];

  @override
  void initState() {
    super.initState();
    bedIndex = _nextBedIndex % _bedTracks.length;
    _nextBedIndex = bedIndex + 1;
    _narrationStateSub = narration.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        bed.pause();
      }
    });
    _load();
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
      await Future.wait([
        narration.setUrl(url),
        bed.setAsset(_currentBed.asset),
      ]);
      if (!mounted) return;
      await bed.setLoopMode(LoopMode.one);
      await bed.setVolume(bedEnabled ? bedVolume : 0);
      await narration.setSpeed(playSpeed);
      await Future.wait([
        narration.play(),
        if (bedEnabled) bed.play(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }
  }

  Future<void> _selectBed(int index) async {
    if (index == bedIndex || bedLoading) return;
    final wasPlaying = narration.playing && bedEnabled;
    setState(() {
      bedIndex = index;
      bedLoading = true;
    });
    try {
      await bed.setAsset(_currentBed.asset);
      if (!mounted) return;
      await bed.setLoopMode(LoopMode.one);
      await bed.setVolume(bedEnabled ? bedVolume : 0);
      if (wasPlaying) {
        await bed.play();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => bedLoading = false);
    }
  }

  Future<void> _togglePlayPause(bool playing) async {
    if (playing) {
      await Future.wait([narration.pause(), bed.pause()]);
    } else {
      await Future.wait([
        narration.play(),
        if (bedEnabled) bed.play(),
      ]);
    }
  }

  Future<void> _seekBy(Duration delta) async {
    final pos = narration.position;
    final total = narration.duration ?? Duration.zero;
    var next = pos + delta;
    if (next < Duration.zero) next = Duration.zero;
    if (total > Duration.zero && next > total) next = total;
    await narration.seek(next);
  }

  Future<void> _setBedEnabled(bool enabled) async {
    setState(() => bedEnabled = enabled);
    if (!enabled) {
      await bed.setVolume(0);
      await bed.pause();
      return;
    }
    await bed.setVolume(bedVolume);
    if (narration.playing) {
      await bed.play();
    }
  }

  Future<void> _setBedVolume(double v) async {
    setState(() => bedVolume = v);
    if (bedEnabled) {
      await bed.setVolume(v);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _narrationStateSub?.cancel();
    narration.dispose();
    bed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('伴读播放'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(error!, style: const TextStyle(color: Color(0xFFFFB4AB))),
            ),
          // Status + reading mode (from design; 纯听 = dim story text)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    Text(
                      '床头暖灯 · 伴睡夜播中',
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
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
          const SizedBox(height: 16),
          // Illustration plate (decorative — no cover art yet)
          AspectRatio(
            aspectRatio: 1.15,
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
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x50000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -20,
                    child: Container(
                      width: 140,
                      height: 140,
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
                          size: 56,
                          color: AppColors.primary.withValues(alpha: 0.85),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '枕边暖光',
                          style: tt.titleMedium?.copyWith(color: AppColors.primarySoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(widget.title, style: tt.headlineMedium),
          const SizedBox(height: 4),
          Text('Lullvale · 睡前伴读', style: tt.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.graphic_eq,
                label: '倍速 ${playSpeed.toStringAsFixed(2)}×',
                accent: true,
              ),
              _MetaChip(
                icon: Icons.music_note,
                label: bedEnabled ? _currentBed.label : '无垫乐',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Story passage card
          AnimatedOpacity(
            opacity: showText ? 1 : 0.28,
            duration: const Duration(milliseconds: 280),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.body,
                    style: tt.bodyLarge?.copyWith(
                      height: 1.7,
                      color: AppColors.primarySoft,
                    ),
                  ),
                  if (widget.softHook != null && widget.softHook!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '轻柔伏笔',
                      style: tt.labelLarge?.copyWith(color: AppColors.secondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.softHook!,
                      style: tt.bodyMedium?.copyWith(color: AppColors.onSurfaceDim),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Timeline
          StreamBuilder<Duration>(
            stream: narration.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final total = narration.duration ?? Duration.zero;
              final maxMs = total.inMilliseconds <= 0
                  ? 1.0
                  : total.inMilliseconds.toDouble();
              final value = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
              final remain = total > pos ? total - pos : Duration.zero;
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
                      const Spacer(),
                      Text(
                        total > Duration.zero ? '余 ${_fmt(remain)}' : '—',
                        style: tt.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        total > Duration.zero ? _fmt(total) : '--:--',
                        style: tt.bodySmall,
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: value,
                      min: 0,
                      max: maxMs,
                      onChanged: (v) => narration.seek(Duration(milliseconds: v.round())),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          // Transport
          StreamBuilder<PlayerState>(
            stream: narration.playerStateStream,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundCtrl(
                    icon: Icons.replay_10,
                    onTap: () => _seekBy(const Duration(seconds: -15)),
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
                            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 36,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _RoundCtrl(
                    icon: Icons.forward_10,
                    onTap: () => _seekBy(const Duration(seconds: 15)),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Text('播放倍速（不重合成）', style: tt.labelLarge),
          Slider(
            value: playSpeed,
            min: 0.7,
            max: 1.2,
            divisions: 10,
            label: playSpeed.toStringAsFixed(2),
            onChanged: (v) async {
              setState(() => playSpeed = v);
              await narration.setSpeed(v);
            },
          ),
          const SizedBox(height: 8),
          // Ambient mixer strip (design-aligned)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop_outlined, size: 18, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bedEnabled
                            ? '摇篮背景音 · ${_currentBed.label}'
                            : '摇篮背景音 · 已关闭',
                        style: tt.labelLarge?.copyWith(color: AppColors.onSurface),
                      ),
                    ),
                    Switch(
                      value: bedEnabled,
                      onChanged: _setBedEnabled,
                    ),
                  ],
                ),
                if (bedEnabled) ...[
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [
                      for (var i = 0; i < _bedTracks.length; i++)
                        ButtonSegment<int>(
                          value: i,
                          label: Text(_bedTracks[i].label),
                          enabled: !bedLoading,
                        ),
                    ],
                    selected: {bedIndex},
                    onSelectionChanged: (set) => _selectBed(set.first),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.volume_mute, size: 16, color: AppColors.onSurfaceDim),
                      Expanded(
                        child: Slider(
                          value: bedVolume,
                          min: 0.04,
                          max: 0.35,
                          divisions: 31,
                          label: '${(bedVolume * 100).round()}%',
                          onChanged: _setBedVolume,
                        ),
                      ),
                      Text(
                        '${(bedVolume * 100).round()}%',
                        style: tt.bodySmall?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
          Icon(icon, size: 13, color: accent ? AppColors.secondary : AppColors.onSurfaceDim),
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

class _RoundCtrl extends StatelessWidget {
  const _RoundCtrl({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.onSurface, size: 26),
        ),
      ),
    );
  }
}
