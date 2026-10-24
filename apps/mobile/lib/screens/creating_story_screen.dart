import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
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
  String progressText = '已提交，排队中…';
  String? errorText;
  bool waiting = true;
  bool retrying = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStory;
    if (initial != null) {
      final st = initial['status'] as String? ?? '';
      final prog = initial['progress'] as String? ?? st;
      progressText = _progressLabel(prog);
      if (st == 'ready') {
        waiting = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openPlayer(initial);
        });
        return;
      }
      if (st == 'failed') {
        waiting = false;
        errorText = initial['error_message'] as String? ?? '故事生成失败';
        return;
      }
    }
    unawaited(_wait());
  }

  Future<void> _wait() async {
    setState(() {
      waiting = true;
      errorText = null;
      progressText = '已提交，排队中…';
    });
    try {
      final story = await widget.api.waitForStory(
        widget.storyId,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => progressText = _progressLabel(p));
        },
      );
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await _openPlayer(story);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        waiting = false;
        errorText = friendlyNetworkError(e);
      });
    }
  }

  Future<void> _retry() async {
    if (retrying) return;
    setState(() {
      retrying = true;
      errorText = null;
      waiting = true;
      progressText = '正在重新生成…';
    });
    try {
      final story = await widget.api.retryStoryAndWait(
        widget.storyId,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => progressText = _progressLabel(p));
        },
      );
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await _openPlayer(story);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        waiting = false;
        errorText = friendlyNetworkError(e);
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

  String _progressLabel(String progress) {
    switch (progress) {
      case 'queued':
        return '排队中…';
      case 'series_outline':
        return '正在构思系列大纲…';
      case 'episode_plan':
        return '正在构思今晚情节…';
      case 'draft':
        return '正在写故事正文…';
      case 'tts':
        return '正在生成朗读音频…';
      case 'ready':
        return '完成，准备播放…';
      case 'failed':
        return '生成失败';
      default:
        return '生成中（$progress）…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final failed = errorText != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('创作中'),
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '返回故事列表',
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
                failed ? '这次没能完成' : '正在为今晚写故事',
                style: tt.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                failed
                    ? '可以重试，或先回列表，稍后再打开这篇故事。'
                    : '云端正在写正文并录制朗读，通常需要一两分钟。',
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
                failed ? errorText! : progressText,
                textAlign: TextAlign.center,
                style: tt.titleMedium,
              ),
              const SizedBox(height: 28),
              SectionCard(
                title: failed ? '接下来可以' : '生成时你可以',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!failed) ...[
                      _hintRow(
                        context,
                        Icons.play_circle_outline,
                        '完成后会自动进入播放页，开始朗读。',
                      ),
                      const SizedBox(height: 12),
                      _hintRow(
                        context,
                        Icons.cloud_done_outlined,
                        '创作在云端继续；关掉本页也不影响。',
                      ),
                      const SizedBox(height: 12),
                      _hintRow(
                        context,
                        Icons.menu_book_outlined,
                        '返回「故事」列表可随时查看进度，或稍后再听。',
                      ),
                    ] else ...[
                      _hintRow(
                        context,
                        Icons.refresh_rounded,
                        '点下方重试，会继续这篇故事，不额外占用额度。',
                      ),
                      const SizedBox(height: 12),
                      _hintRow(
                        context,
                        Icons.menu_book_outlined,
                        '也可以先回列表，稍后再打开或重试。',
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              if (failed) ...[
                AmberCta(
                  label: retrying ? '重试中…' : '重新生成',
                  busy: retrying,
                  icon: Icons.refresh_rounded,
                  onPressed: retrying ? null : _retry,
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: _backToStories,
                child: Text(failed ? '返回故事列表' : '先回故事列表'),
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
