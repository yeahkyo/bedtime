import 'package:drift/drift.dart';

import '../../api/client.dart';
import '../db/app_database.dart';
import '../network_errors.dart';

class StoryRepository {
  StoryRepository({
    required this.db,
    required this.api,
    required this.userId,
  });

  final AppDatabase db;
  final ApiClient api;
  final int userId;

  Future<List<Map<String, dynamic>>> loadCached() async {
    final rows = await (db.select(db.cachedStories)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
    return rows.map(_rowToMap).toList();
  }

  Future<Map<String, dynamic>?> getCached(int storyId) async {
    final row = await (db.select(db.cachedStories)
          ..where((t) => t.userId.equals(userId) & t.id.equals(storyId)))
        .getSingleOrNull();
    return row == null ? null : _rowToMap(row);
  }

  /// Stale-while-revalidate: returns cached immediately via [onCached], then
  /// refreshes from API. Returns the freshest list available.
  Future<List<Map<String, dynamic>>> refresh({
    void Function(List<Map<String, dynamic>> cached)? onCached,
    void Function(String message)? onNetworkError,
  }) async {
    final cached = await loadCached();
    onCached?.call(cached);

    try {
      final remote = await api.listStories();
      final maps = remote.cast<Map<String, dynamic>>();
      await replaceAll(maps);
      return maps;
    } catch (e) {
      if (e is ApiException && e.unauthorized) rethrow;
      onNetworkError?.call(friendlyNetworkError(e));
      return cached;
    }
  }

  Future<void> upsertOne(Map<String, dynamic> story) async {
    final id = _asId(story['id']);
    if (id == null) return;
    await db.into(db.cachedStories).insertOnConflictUpdate(_companion(story, id));
  }

  Future<void> replaceAll(List<Map<String, dynamic>> stories) async {
    await db.transaction(() async {
      await (db.delete(db.cachedStories)..where((t) => t.userId.equals(userId))).go();
      for (final s in stories) {
        final id = _asId(s['id']);
        if (id == null) continue;
        await db.into(db.cachedStories).insertOnConflictUpdate(_companion(s, id));
      }
    });
  }

  CachedStoriesCompanion _companion(Map<String, dynamic> s, int id) {
    final now = DateTime.now();
    return CachedStoriesCompanion.insert(
      userId: userId,
      id: id,
      title: Value(s['title'] as String? ?? ''),
      language: Value(s['language'] as String? ?? 'zh'),
      theme: Value(s['theme'] as String?),
      body: Value(s['body'] as String? ?? ''),
      status: Value(s['status'] as String? ?? ''),
      source: Value(s['source'] as String? ?? 'manual'),
      softHook: Value(s['soft_hook'] as String?),
      audioUrl: Value(s['audio_url'] as String?),
      durationMinutes: Value(s['duration_minutes'] as int? ?? 5),
      seriesId: Value(_asId(s['series_id'])),
      episodeNo: Value(_asId(s['episode_no'])),
      childId: Value(_asId(s['child_id'])),
      progress: Value(s['progress'] as String?),
      errorMessage: Value(s['error_message'] as String?),
      voiceName: Value(s['voice_name'] as String?),
      developmentFocusLabel: Value(s['development_focus_label'] as String?),
      storyProvider: Value(s['story_provider'] as String?),
      speechProvider: Value(s['speech_provider'] as String?),
      speechModel: Value(s['speech_model'] as String?),
      syncedAt: now,
    );
  }

  Map<String, dynamic> _rowToMap(CachedStory row) {
    return {
      'id': row.id,
      'title': row.title,
      'language': row.language,
      'theme': row.theme,
      'body': row.body,
      'status': row.status,
      'source': row.source,
      'soft_hook': row.softHook,
      'audio_url': row.audioUrl,
      'duration_minutes': row.durationMinutes,
      'series_id': row.seriesId,
      'episode_no': row.episodeNo,
      'child_id': row.childId,
      'progress': row.progress,
      'error_message': row.errorMessage,
      'voice_name': row.voiceName,
      'development_focus_label': row.developmentFocusLabel,
      'story_provider': row.storyProvider,
      'speech_provider': row.speechProvider,
      'speech_model': row.speechModel,
    };
  }

  int? _asId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
