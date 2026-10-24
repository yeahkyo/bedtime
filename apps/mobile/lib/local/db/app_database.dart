import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    CachedStories,
    CachedChildren,
    CachedCharacters,
    CachedVoices,
    CachedVoicePrefs,
    AccountSnapshots,
    MediaFiles,
    PlaybackProgress,
    StoryFavorites,
    MoodEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(cachedCharacters);
          }
          if (from < 3) {
            await customStatement(
              'ALTER TABLE cached_stories '
              'RENAME COLUMN development_focus_label TO core',
            );
          }
        },
      );

  static QueryExecutor _open() {
    return driftDatabase(name: 'bedtime_local');
  }

  /// Wipe all cached rows for [userId] (call on logout / account switch).
  Future<void> clearUserData(int userId) async {
    await transaction(() async {
      await (delete(cachedStories)..where((t) => t.userId.equals(userId))).go();
      await (delete(cachedChildren)..where((t) => t.userId.equals(userId))).go();
      await (delete(cachedCharacters)..where((t) => t.userId.equals(userId))).go();
      await (delete(cachedVoices)..where((t) => t.userId.equals(userId))).go();
      await (delete(cachedVoicePrefs)..where((t) => t.userId.equals(userId))).go();
      await (delete(accountSnapshots)..where((t) => t.userId.equals(userId))).go();
      await (delete(mediaFiles)..where((t) => t.userId.equals(userId))).go();
      await (delete(playbackProgress)..where((t) => t.userId.equals(userId))).go();
      await (delete(storyFavorites)..where((t) => t.userId.equals(userId))).go();
      await (delete(moodEntries)..where((t) => t.userId.equals(userId))).go();
    });
  }
}
