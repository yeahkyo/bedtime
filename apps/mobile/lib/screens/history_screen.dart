import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import 'player_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> stories = [];
  bool loading = true;
  bool continuing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      stories = await widget.api.listStories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _continueSeries(Map<String, dynamic> s) async {
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
      // Style dials / cast are inherited server-side from episode 1 of the series.
      final story = await widget.api.createStoryAndWait(
        childId: childId,
        theme: (theme == null || theme.isEmpty) ? '温柔的夜晚' : theme,
        language: s['language'] as String? ?? 'zh',
        durationMinutes: s['duration_minutes'] as int? ?? 5,
        softSeriesMode: true,
        seriesId: seriesId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            title: story['title'] as String? ?? 'Story',
            body: story['body'] as String? ?? '',
            audioUrl: story['audio_url'] as String?,
            softHook: story['soft_hook'] as String?,
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => continuing = false);
    }
  }

  void _openPlayer(Map<String, dynamic> s) {
    final status = s['status'] as String? ?? '';
    final audioUrl = s['audio_url'] as String?;
    if (status != 'ready' || audioUrl == null || audioUrl.isEmpty) {
      final msg = status == 'generating'
          ? '故事还在生成中，请下拉刷新后再听'
          : status == 'failed'
              ? (s['error_message'] as String? ?? '故事生成失败')
              : '暂无音频，无法播放';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          title: s['title'] as String? ?? 'Story',
          body: s['body'] as String? ?? '',
          audioUrl: audioUrl,
          softHook: s['soft_hook'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading || continuing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (continuing) ...[
              const SizedBox(height: 12),
              Text('正在续写下一集…', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          BrandHeader(
            eyebrow: 'Lullvale · Library',
            title: '睡前枕边书匣',
            subtitle: stories.isEmpty
                ? '还没有故事，去创作室编织一篇吧'
                : '已生成 ${stories.length} 篇 · 点封面即可伴读',
          ),
          const SizedBox(height: 18),
          if (stories.isEmpty)
            SectionCard(
              title: '空空的书架',
              child: Text(
                '今晚的第一本小书，还在等你按下创作室的金色按钮。',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.secondaryEdge),
              ),
              child: Text(
                '已生成故事（${stories.length}）',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.secondary,
                    ),
              ),
            ),
            const SizedBox(height: 14),
            for (final raw in stories) ...[
              Builder(
                builder: (context) {
                  final s = raw as Map<String, dynamic>;
                  final seriesId = s['series_id'];
                  final ep = s['episode_no'];
                  final hook = (s['soft_hook'] as String?)?.trim();
                  final meta = StringBuffer();
                  if (hook != null && hook.isNotEmpty) {
                    meta.write(hook.length > 42 ? '${hook.substring(0, 42)}…' : hook);
                  } else {
                    meta.write('${s['language'] ?? 'zh'} · ${s['status'] ?? ''}');
                    if (s['duration_minutes'] != null) {
                      meta.write(' · ${s['duration_minutes']} 分钟');
                    }
                  }
                  if (seriesId != null) {
                    meta.write(meta.isEmpty ? '' : ' · ');
                    meta.write('系列 #$seriesId');
                    if (ep != null) meta.write(' 第$ep集');
                  }
                  final status = s['status'] as String? ?? '';
                  final canContinue =
                      seriesId != null && status != 'generating' && status != 'failed';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LibraryStoryTile(
                      title: s['title'] as String? ?? 'Story',
                      meta: meta.toString(),
                      onPlay: () => _openPlayer(s),
                      onContinue: canContinue ? () => _continueSeries(s) : null,
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
