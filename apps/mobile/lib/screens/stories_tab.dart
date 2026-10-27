import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../config.dart';
import '../local/local_store.dart';
import '../local/network_errors.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import '../utils/require_login.dart';
import 'create_story_screen.dart';
import 'player_screen.dart';

String _storiesLengthMeta(AppLocalizations l10n, Object? rawMinutes) {
  final minutes = rawMinutes is int
      ? rawMinutes
      : int.tryParse('$rawMinutes') ?? 5;
  final canon = minutes <= 4 ? 3 : (minutes <= 7 ? 5 : 10);
  final label = switch (canon) {
    3 => l10n.storiesLengthShort,
    10 => l10n.storiesLengthLong,
    _ => l10n.storiesLengthMedium,
  };
  return l10n.storiesLengthLabel(label, canon);
}

/// Tab 1: story library (newest first) + entry to create flow.
class StoriesTab extends StatefulWidget {
  const StoriesTab({
    super.key,
    required this.api,
    this.localStore,
    this.onRequestLogin,
  });

  final ApiClient api;
  final LocalStore? localStore;
  final Future<bool> Function()? onRequestLogin;

  @override
  State<StoriesTab> createState() => StoriesTabState();
}

class StoriesTabState extends State<StoriesTab> {
  List<dynamic> stories = [];
  bool loading = true;
  bool continuing = false;
  bool retrying = false;
  String? retryProgress;
  Timer? _generatingPoll;
  bool _loadInFlight = false;
  /// Bumped on each load; stale responses are discarded.
  int _loadSeq = 0;
  /// Bottom-nav Stories tab selected. Polling only runs while true.
  bool _tabActive = true;
  final Set<int> _prefetchedReadyIds = {};

  static bool _storyInFlight(dynamic raw) {
    if (raw is! Map) return false;
    final st = '${raw['status'] ?? ''}';
    return st == 'generating' || st == 'text_ready';
  }

  static int? _storyId(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse('$id');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stopGeneratingPoll();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StoriesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localStore != null && widget.localStore == null) {
      _stopGeneratingPoll();
      _prefetchedReadyIds.clear();
      setState(() {
        stories = [];
        loading = false;
        continuing = false;
        retrying = false;
        retryProgress = null;
      });
    } else if (oldWidget.localStore == null && widget.localStore != null) {
      unawaited(_load());
    }
  }

  Future<void> reload() => _load();

  /// Called by [HomeShell] when the Stories bottom tab is selected / left.
  void setTabActive(bool active) {
    if (_tabActive == active) return;
    _tabActive = active;
    if (!active) {
      _stopGeneratingPoll();
    } else {
      _syncGeneratingPoll();
    }
  }

  void _stopGeneratingPoll() {
    _generatingPoll?.cancel();
    _generatingPoll = null;
  }

  void _syncGeneratingPoll() {
    final needsPoll = _tabActive && stories.any(_storyInFlight);
    if (!needsPoll) {
      _stopGeneratingPoll();
      return;
    }
    if (_generatingPoll != null) return;
    _generatingPoll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_tabActive || _loadInFlight) return;
      if (!stories.any(_storyInFlight)) {
        _stopGeneratingPoll();
        return;
      }
      unawaited(_load(quiet: true));
    });
  }

  void _maybePrefetchReady(List<dynamic> list) {
    final store = widget.localStore;
    if (store == null) return;
    final readyMaps = <Map<String, dynamic>>[];
    final readyIds = <int>{};
    for (final row in list) {
      if (row is! Map) continue;
      if ('${row['status'] ?? ''}' != 'ready') continue;
      final id = _storyId(row);
      if (id == null) continue;
      readyIds.add(id);
      if (!_prefetchedReadyIds.contains(id)) {
        readyMaps.add(Map<String, dynamic>.from(row));
      }
    }
    _prefetchedReadyIds
      ..removeWhere((id) => !readyIds.contains(id))
      ..addAll(readyIds);
    if (readyMaps.isEmpty) return;
    unawaited(store.media.prefetchReadyStories(readyMaps));
  }

  Future<void> _load({bool quiet = false}) async {
    if (_loadInFlight && quiet) return;
    final seq = ++_loadSeq;
    _loadInFlight = true;
    if (!quiet) {
      setState(() => loading = stories.isEmpty);
    }
    final store = widget.localStore;
    try {
      if (store != null) {
        try {
          final list = await store.stories.refresh(
            onCached: (cached) {
              if (!mounted || cached.isEmpty || quiet || seq != _loadSeq) return;
              setState(() {
                stories = cached;
                loading = false;
              });
            },
            onNetworkError: (msg) {
              if (!mounted || quiet || seq != _loadSeq) return;
              if (stories.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
          );
          if (!mounted || seq != _loadSeq) return;
          setState(() {
            stories = list;
            if (!quiet) loading = false;
          });
          _maybePrefetchReady(list);
          return;
        } on ApiException catch (e) {
          if (e.unauthorized) {
            _stopGeneratingPoll();
            if (mounted && seq == _loadSeq) {
              setState(() => stories = []);
            }
            return;
          }
          if (mounted && stories.isEmpty && !quiet && seq == _loadSeq) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(friendlyNetworkError(e))),
            );
          }
        } catch (e) {
          if (mounted && stories.isEmpty && !quiet && seq == _loadSeq) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(friendlyNetworkError(e))),
            );
          }
        } finally {
          if (mounted && !quiet && seq == _loadSeq) {
            setState(() => loading = false);
          }
        }
        return;
      }

      if (!apiHasAccessToken(widget.api)) {
        if (mounted && seq == _loadSeq) {
          setState(() {
            stories = [];
            if (!quiet) loading = false;
          });
        }
        return;
      }

      if (!quiet && seq == _loadSeq) setState(() => loading = true);
      try {
        final list = await widget.api.listStories();
        if (!mounted || seq != _loadSeq) return;
        setState(() {
          stories = list;
          if (!quiet) loading = false;
        });
      } on ApiException catch (e) {
        if (e.unauthorized) {
          _stopGeneratingPoll();
          if (mounted && seq == _loadSeq) setState(() => stories = []);
          return;
        }
        if (mounted && !quiet && seq == _loadSeq) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyNetworkError(e))),
          );
        }
      } catch (e) {
        if (mounted && !quiet && seq == _loadSeq) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyNetworkError(e))),
          );
        }
      } finally {
        if (mounted && !quiet && seq == _loadSeq) {
          setState(() => loading = false);
        }
      }
    } finally {
      if (seq == _loadSeq) {
        _loadInFlight = false;
        if (mounted) _syncGeneratingPoll();
      }
    }
  }

  Future<bool> _ensureLogin() async {
    if (apiHasAccessToken(widget.api)) return true;
    final request = widget.onRequestLogin;
    if (request != null) return request();
    return requireLogin(context, widget.api);
  }

  Future<void> _openCreate() async {
    final ok = await _ensureLogin();
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateStoryScreen(
          api: widget.api,
          localStore: widget.localStore,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _continueSeries(Map<String, dynamic> s) async {
    if (!kFeatureSoftSeries) return;
    // Soft-series create fields were removed from the story protocol; open create.
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.storiesSeriesContinueHint)),
    );
    await _openCreate();
  }

  Future<void> _resumeWait(int storyId) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      continuing = true;
      retryProgress = l10n.storyResumeWaiting;
    });
    try {
      final story = await widget.api.waitForStory(
        storyId,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => retryProgress = _progressLabel(AppLocalizations.of(context), p));
        },
      );
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen.fromStory(
            story,
            localStore: widget.localStore,
            analyticsSource: 'continue',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyNetworkError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          continuing = false;
          retryProgress = null;
        });
      }
    }
  }

  void _openPlayer(Map<String, dynamic> s) {
    final l10n = AppLocalizations.of(context);
    final status = s['status'] as String? ?? '';
    final audioUrl = s['audio_url'] as String?;
    if (status != 'ready' || audioUrl == null || audioUrl.isEmpty) {
      final msg = status == 'generating'
          ? l10n.storyStillGenerating
          : status == 'failed'
              ? (s['error_message'] as String? ?? l10n.storyGenerateFailedRetry)
              : l10n.storyNoAudio;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen.fromStory(
          s,
          localStore: widget.localStore,
          analyticsSource: 'list',
        ),
      ),
    );
  }

  String _progressLabel(AppLocalizations l10n, String progress) {
    switch (progress) {
      case 'queued':
        return l10n.storyProgressQueued;
      case 'series_outline':
        return l10n.storyProgressSeriesOutline;
      case 'episode_plan':
        return l10n.storyProgressEpisodePlan;
      case 'draft':
        return l10n.storyProgressDraft;
      case 'tts':
        return l10n.storyProgressTts;
      case 'ready':
        return l10n.storyProgressReady;
      case 'failed':
        return l10n.storyProgressFailed;
      default:
        return l10n.storyProgressGenerating(progress);
    }
  }

  Future<void> _retryStory(Map<String, dynamic> s) async {
    final id = s['id'] as int?;
    if (id == null || retrying) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      retrying = true;
      retryProgress = l10n.storyRetrying;
    });
    try {
      final story = await widget.api.retryStoryAndWait(
        id,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => retryProgress = _progressLabel(AppLocalizations.of(context), p));
        },
      );
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen.fromStory(
            story,
            localStore: widget.localStore,
            analyticsSource: 'retry',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        final resumeId = e is ApiException ? e.storyId : id;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyNetworkError(e)),
            action: resumeId == null
                ? null
                : SnackBarAction(
                    label: AppLocalizations.of(context).storyContinueWaiting,
                    onPressed: () => unawaited(_resumeWait(resumeId)),
                  ),
          ),
        );
        await _load();
      }
    } finally {
      if (mounted) {
        setState(() {
          retrying = false;
          retryProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (continuing || retrying) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              retrying
                  ? (retryProgress ?? l10n.storyRetrying)
                  : l10n.storyContinuingEpisode,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fixed hero (design/story): title block + amber create card — does not scroll.
        _StoriesHeroHeader(
          storyCount: stories.length,
          onCreate: _openCreate,
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.storiesLibraryTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            stories.isEmpty
                                ? l10n.storiesLibraryEmpty
                                : l10n.storiesLibraryCount(stories.length),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (stories.isEmpty)
                        SectionCard(
                          title: l10n.storiesEmptyShelfTitle,
                          child: Text(
                            l10n.storiesEmptyShelfBody,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      else
                        for (final raw in stories) ...[
                          Builder(
                            builder: (context) {
                              final s = raw as Map<String, dynamic>;
                              final seriesId = s['series_id'];
                              final ep = s['episode_no'];
                              final hook = (s['soft_hook'] as String?)?.trim();
                              final meta = StringBuffer();
                              if (hook != null && hook.isNotEmpty) {
                                meta.write(
                                  hook.length > 42 ? '${hook.substring(0, 42)}…' : hook,
                                );
                              } else {
                                meta.write('${s['language'] ?? 'zh'} · ${s['status'] ?? ''}');
                                if (s['duration_minutes'] != null) {
                                  meta.write(
                                    ' · ${_storiesLengthMeta(l10n, s['duration_minutes'])}',
                                  );
                                }
                              }
                              if (kFeatureSoftSeries && seriesId != null) {
                                meta.write(meta.isEmpty ? '' : ' · ');
                                meta.write(l10n.storiesSeriesMeta(seriesId));
                                if (ep != null) meta.write(l10n.storiesEpisodeMeta(ep));
                              }
                              final status = s['status'] as String? ?? '';
                              final failed = status == 'failed';
                              final canRetry = failed;
                              final canContinue = kFeatureSoftSeries &&
                                  seriesId != null &&
                                  status != 'generating' &&
                                  status != 'failed';
                              if (failed) {
                                final err = (s['error_message'] as String?)?.trim();
                                meta.clear();
                                meta.write(
                                  err == null || err.isEmpty
                                      ? l10n.storiesFailedRetry
                                      : l10n.storiesFailedWithError(err),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: LibraryStoryTile(
                                  title: (s['title'] as String?)?.trim().isNotEmpty == true
                                      ? s['title'] as String
                                      : ((s['theme'] as String?)?.trim().isNotEmpty == true
                                          ? s['theme'] as String
                                          : l10n.storiesUntitled),
                                  meta: meta.toString(),
                                  failed: canRetry,
                                  onPlay: () => _openPlayer(s),
                                  onRetry: canRetry ? () => _retryStory(s) : null,
                                  onContinue:
                                      canContinue ? () => _continueSeries(s) : null,
                                ),
                              );
                            },
                          ),
                        ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Fixed top block from design/story: eyebrow + title + amber create CTA card.
class _StoriesHeroHeader extends StatelessWidget {
  const _StoriesHeroHeader({
    required this.storyCount,
    required this.onCreate,
  });

  final int storyCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandMark(),
                    const SizedBox(height: 8),
                    Text(l10n.storiesTitle, style: tt.headlineMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.outline),
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
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lanternGlow,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      storyCount == 0
                          ? l10n.storiesStatusWaitingFirst
                          : l10n.storiesStatusReady,
                      style: tt.labelSmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCreate,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFE8A87C),
                      Color(0xFFD4A373),
                      Color(0xFFF4B251),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59E8A87C),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.storiesCreateEyebrow,
                              style: tt.labelMedium?.copyWith(
                                color: const Color(0xFF693C19),
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.storiesCreateTitle,
                              style: tt.titleLarge?.copyWith(
                                color: const Color(0xFF4E2604),
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.storiesCreateSubtitle,
                              style: tt.bodySmall?.copyWith(
                                color: const Color(0xCC4E2604),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2333),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_stories,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
