import 'dart:async';

import 'package:flutter/material.dart';

import '../analytics/analytics_tracker.dart';
import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../local/local_store.dart';
import '../local/network_errors.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import 'player_screen.dart';

/// Full-screen wait state after enqueueing a story.
///
/// Back /「先回故事列表」return to the previous route (story list when opened
/// via [Navigator.pushReplacement] from create). Generation continues on the
/// server; the list can show progress.
class CreatingStoryScreen extends StatefulWidget {
  const CreatingStoryScreen({
    super.key,
    required this.api,
    required this.storyId,
    this.localStore,
    this.initialStory,
  });

  final ApiClient api;
  final int storyId;
  final LocalStore? localStore;
  final Map<String, dynamic>? initialStory;

  @override
  State<CreatingStoryScreen> createState() => _CreatingStoryScreenState();
}

class _CreatingStoryScreenState extends State<CreatingStoryScreen> {
  /// Progress code from API (`queued`, `draft`, …) — localized in [build].
  String progressKey = 'queued';
  String? errorText;
  bool waiting = true;
  bool retrying = false;
  bool _useFailedFallback = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStory;
    if (initial != null) {
      final st = initial['status'] as String? ?? '';
      final prog = initial['progress'] as String? ?? st;
      progressKey = prog;
      if (st == 'ready') {
        waiting = false;
        AnalyticsTracker.instance.bind(widget.api);
        AnalyticsTracker.instance.track('story_ready', storyId: widget.storyId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openPlayer(initial);
        });
        return;
      }
      if (st == 'failed') {
        waiting = false;
        AnalyticsTracker.instance.bind(widget.api);
        AnalyticsTracker.instance.track(
          'story_failed',
          storyId: widget.storyId,
          props: {'error_class': 'generate_failed'},
        );
        final msg = (initial['error_message'] as String?)?.trim();
        if (msg == null || msg.isEmpty) {
          _useFailedFallback = true;
          errorText = null;
        } else {
          errorText = msg;
        }
        return;
      }
    }
    unawaited(_wait());
  }

  Future<void> _wait() async {
    setState(() {
      waiting = true;
      errorText = null;
      _useFailedFallback = false;
      progressKey = 'queued';
    });
    try {
      final story = await widget.api.waitForStory(
        widget.storyId,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => progressKey = p);
        },
      );
      AnalyticsTracker.instance.bind(widget.api);
      AnalyticsTracker.instance.track('story_ready', storyId: widget.storyId);
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await _openPlayer(story);
    } catch (e) {
      final failed = e is ApiException && e.storyFailed;
      AnalyticsTracker.instance.bind(widget.api);
      AnalyticsTracker.instance.track(
        'story_failed',
        storyId: widget.storyId,
        props: {
          'error_class': failed ? 'generate_failed' : 'wait_error',
        },
      );
      if (!mounted) return;
      setState(() {
        waiting = false;
        errorText = friendlyNetworkError(e);
        _useFailedFallback = false;
      });
    }
  }

  Future<void> _retry() async {
    if (retrying) return;
    setState(() {
      retrying = true;
      errorText = null;
      _useFailedFallback = false;
      waiting = true;
      progressKey = 'retrying';
    });
    try {
      final story = await widget.api.retryStoryAndWait(
        widget.storyId,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => progressKey = p);
        },
      );
      AnalyticsTracker.instance.bind(widget.api);
      AnalyticsTracker.instance.track('story_ready', storyId: widget.storyId);
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await _openPlayer(story);
    } catch (e) {
      final failed = e is ApiException && e.storyFailed;
      AnalyticsTracker.instance.bind(widget.api);
      AnalyticsTracker.instance.track(
        'story_failed',
        storyId: widget.storyId,
        props: {
          'error_class': failed ? 'generate_failed' : 'wait_error',
        },
      );
      if (!mounted) return;
      setState(() {
        waiting = false;
        errorText = friendlyNetworkError(e);
        _useFailedFallback = false;
      });
    } finally {
      if (mounted) setState(() => retrying = false);
    }
  }

  Future<void> _openPlayer(Map<String, dynamic> story) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlayerScreen.fromStory(
          story,
          localStore: widget.localStore,
        ),
      ),
    );
  }

  void _backToStories() {
    Navigator.of(context).pop();
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
        return l10n.storyProgressReadyPlay;
      case 'failed':
        return l10n.storyProgressFailed;
      case 'retrying':
        return l10n.storyRetrying;
      default:
        return l10n.storyProgressGenerating(progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final failed = errorText != null || _useFailedFallback;
    final displayError = errorText ??
        (_useFailedFallback ? l10n.storyGenerateFailed : null);
    final progressText = progressKey == 'queued' && waiting
        ? l10n.storySubmittedQueued
        : _progressLabel(l10n, progressKey);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.creatingTitle),
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.creatingBackTooltip,
          onPressed: _backToStories,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandMark(),
              const SizedBox(height: 18),
              Text(
                failed ? l10n.creatingHeadlineFail : l10n.creatingHeadlineOk,
                style: tt.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                failed ? l10n.creatingBodyFail : l10n.creatingBodyOk,
                style: tt.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 36),
              Center(
                child: failed
                    ? Icon(
                        Icons.cloud_off_outlined,
                        size: 56,
                        color: AppColors.secondary.withValues(alpha: 0.9),
                      )
                    : const SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                failed ? displayError! : progressText,
                textAlign: TextAlign.center,
                style: tt.titleMedium,
              ),
              const SizedBox(height: 28),
              SectionCard(
                title: failed
                    ? l10n.creatingHintsFailTitle
                    : l10n.creatingHintsOkTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!failed) ...[
                      _hintRow(
                        context,
                        Icons.play_circle_outline,
                        l10n.creatingHintAutoPlay,
                      ),
                      const SizedBox(height: 12),
                      _hintRow(
                        context,
                        Icons.cloud_done_outlined,
                        l10n.creatingHintCloud,
                      ),
                      const SizedBox(height: 12),
                      _hintRow(
                        context,
                        Icons.menu_book_outlined,
                        l10n.creatingHintList,
                      ),
                    ] else ...[
                      _hintRow(
                        context,
                        Icons.refresh_rounded,
                        l10n.creatingHintRetry,
                      ),
                      const SizedBox(height: 12),
                      _hintRow(
                        context,
                        Icons.menu_book_outlined,
                        l10n.creatingHintBackLater,
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              if (failed) ...[
                AmberCta(
                  label: retrying ? l10n.creatingRetrying : l10n.creatingRetry,
                  busy: retrying,
                  icon: Icons.refresh_rounded,
                  onPressed: retrying ? null : _retry,
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: _backToStories,
                child: Text(
                  failed ? l10n.creatingBackFailed : l10n.creatingBackOk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hintRow(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primarySoft),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
