import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../config.dart';
import '../local/local_store.dart';
import '../local/network_errors.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import 'create_story_screen.dart';
import 'player_screen.dart';

/// Tab 1: story library (newest first) + entry to create flow.
class StoriesTab extends StatefulWidget {
  const StoriesTab({super.key, required this.api, this.localStore});

  final ApiClient api;
  final LocalStore? localStore;

  @override
  State<StoriesTab> createState() => StoriesTabState();
}

class StoriesTabState extends State<StoriesTab> {
  List<dynamic> stories = [];
  bool loading = true;
  bool continuing = false;
  bool retrying = false;
  String? retryProgress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StoriesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localStore == null && widget.localStore != null) {
      unawaited(_load());
    }
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    final store = widget.localStore;
    setState(() => loading = stories.isEmpty);
    if (store != null) {
      try {
        final list = await store.stories.refresh(
          onCached: (cached) {
            if (!mounted || cached.isEmpty) return;
            setState(() {
              stories = cached;
              loading = false;
            });
          },
          onNetworkError: (msg) {
            if (!mounted) return;
            if (stories.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            }
          },
        );
        if (!mounted) return;
        setState(() {
          stories = list;
          loading = false;
        });
        unawaited(store.media.prefetchReadyStories(
          list.cast<Map<String, dynamic>>(),
        ));
        return;
      } on ApiException catch (e) {
        if (e.unauthorized) rethrow;
        if (mounted && stories.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyNetworkError(e))),
          );
        }
      } catch (e) {
        if (mounted && stories.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyNetworkError(e))),
          );
        }
      } finally {
        if (mounted) setState(() => loading = false);
      }
      return;
    }

    setState(() => loading = true);
    try {
      stories = await widget.api.listStories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyNetworkError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openCreate() async {
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
    final seriesId = s['series_id'] as int?;
    final childId = s['child_id'] as int?;
    final status = s['status'] as String? ?? '';
    if (seriesId == null || childId == null) return;
    if (status == 'generating') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('上一集还在生成中，请稍后再续写')),
      );
      return;
    }
    if (status == 'failed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('上一集生成失败，请先重新创作')),
      );
      return;
    }
    final theme = (s['theme'] as String?)?.trim();
    setState(() => continuing = true);
    try {
      final story = await widget.api.createStoryAndWait(
        childId: childId,
        theme: theme ?? '',
        language: s['language'] as String? ?? 'zh',
        durationMinutes: s['duration_minutes'] as int? ?? 5,
        softSeriesMode: true,
        seriesId: seriesId,
      );
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen.fromStory(
            story,
            localStore: widget.localStore,
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        final id = e is ApiException ? e.storyId : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyNetworkError(e)),
            action: id == null
                ? null
                : SnackBarAction(
                    label: '继续等待',
                    onPressed: () => unawaited(_resumeWait(id)),
                  ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => continuing = false);
    }
  }

  Future<void> _resumeWait(int storyId) async {
    setState(() {
      continuing = true;
      retryProgress = '继续等待生成…';
    });
    try {
      final story = await widget.api.waitForStory(
        storyId,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => retryProgress = _progressLabel(p));
        },
      );
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen.fromStory(
            story,
            localStore: widget.localStore,
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
    final status = s['status'] as String? ?? '';
    final audioUrl = s['audio_url'] as String?;
    if (status != 'ready' || audioUrl == null || audioUrl.isEmpty) {
      final msg = status == 'generating'
          ? '故事还在生成中，请下拉刷新后再听'
          : status == 'failed'
              ? (s['error_message'] as String? ?? '故事生成失败，可点重试')
              : '暂无音频，无法播放';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen.fromStory(
          s,
          localStore: widget.localStore,
        ),
      ),
    );
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
        return '完成';
      case 'failed':
        return '生成失败';
      default:
        return '生成中（$progress）…';
    }
  }

  Future<void> _retryStory(Map<String, dynamic> s) async {
    final id = s['id'] as int?;
    if (id == null || retrying) return;
    setState(() {
      retrying = true;
      retryProgress = '正在重新生成…';
    });
    try {
      final story = await widget.api.retryStoryAndWait(
        id,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => retryProgress = _progressLabel(p));
        },
      );
      await widget.localStore?.stories.upsertOne(story);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen.fromStory(
            story,
            localStore: widget.localStore,
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
                    label: '继续等待',
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
    if (continuing || retrying) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              retrying
                  ? (retryProgress ?? '正在重新生成…')
                  : '正在续写下一集…',
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
                            '枕边故事宝盒',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            stories.isEmpty ? '暂无故事' : '按时间倒序 · ${stories.length} 篇',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (stories.isEmpty)
                        SectionCard(
                          title: '空空的书架',
                          child: Text(
                            '今晚的第一本小书，还在等你点上方金色卡片。',
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
                                  meta.write(' · ${s['duration_minutes']} 分钟');
                                }
                              }
                              if (kFeatureSoftSeries && seriesId != null) {
                                meta.write(meta.isEmpty ? '' : ' · ');
                                meta.write('系列 #$seriesId');
                                if (ep != null) meta.write(' 第$ep集');
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
                                meta.write(err == null || err.isEmpty ? '生成失败 · 可重试' : '失败 · $err');
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: LibraryStoryTile(
                                  title: (s['title'] as String?)?.trim().isNotEmpty == true
                                      ? s['title'] as String
                                      : ((s['theme'] as String?)?.trim().isNotEmpty == true
                                          ? s['theme'] as String
                                          : '未完成的故事'),
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
                    Row(
                      children: [
                        Icon(
                          Icons.nightlight_round,
                          size: 16,
                          color: AppColors.primary.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LULLVALE · 晚安枕边书',
                          style: tt.labelLarge?.copyWith(
                            color: AppColors.primarySoft,
                            letterSpacing: 1.1,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('我的枕边故事', style: tt.headlineMedium),
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
                      storyCount == 0 ? '等待第一篇' : '夜光模式已就绪',
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
                              '织梦引擎 · 新章',
                              style: tt.labelMedium?.copyWith(
                                color: const Color(0xFF693C19),
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '创作今晚的新故事',
                              style: tt.titleLarge?.copyWith(
                                color: const Color(0xFF4E2604),
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '定制宝宝专属角色、今夜情绪与助眠音画',
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
