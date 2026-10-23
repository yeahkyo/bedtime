import 'package:drift/drift.dart';

import '../db/app_database.dart';

class PlaybackRepository {
  PlaybackRepository({
    required this.db,
    required this.userId,
  });

  final AppDatabase db;
  final int userId;

  Future<int?> getPositionMs(int storyId) async {
    final row = await (db.select(db.playbackProgress)
          ..where((t) => t.userId.equals(userId) & t.storyId.equals(storyId)))
        .getSingleOrNull();
    if (row == null || row.positionMs <= 0) return null;
    return row.positionMs;
  }

  Future<void> savePositionMs(int storyId, int positionMs) async {
    if (positionMs <= 0) {
      await clear(storyId);
      return;
    }
    await db.into(db.playbackProgress).insertOnConflictUpdate(
          PlaybackProgressCompanion.insert(
            userId: userId,
            storyId: storyId,
            positionMs: Value(positionMs),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> clear(int storyId) async {
    await (db.delete(db.playbackProgress)
          ..where((t) => t.userId.equals(userId) & t.storyId.equals(storyId)))
        .go();
  }
}
