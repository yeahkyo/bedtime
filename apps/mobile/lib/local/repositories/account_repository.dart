import 'package:drift/drift.dart';

import '../../api/client.dart';
import '../db/app_database.dart';
import '../network_errors.dart';
import '../user_scope.dart';

class AccountRepository {
  AccountRepository({
    required this.db,
    required this.api,
    required this.userId,
  });

  final AppDatabase db;
  final ApiClient api;
  final int userId;

  Future<Map<String, dynamic>?> loadCached() async {
    final row = await (db.select(db.accountSnapshots)
          ..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
    if (row == null) return null;
    return {
      'id': row.userId,
      'display_name': row.displayName,
      'preferred_language': row.preferredLanguage,
      'quota': {
        'month': row.quotaMonth,
        'story_used': row.storyUsed,
        'story_limit': row.storyLimit,
        'clone_used': row.cloneUsed,
        'clone_limit': row.cloneLimit,
      },
    };
  }

  Future<void> saveSnapshot({
    required Map<String, dynamic> me,
    required Map<String, dynamic> quota,
  }) async {
    final id = _asId(me['id']) ?? userId;
    await UserScope.save(id);
    await db.into(db.accountSnapshots).insertOnConflictUpdate(
          AccountSnapshotsCompanion.insert(
            userId: Value(id),
            displayName: Value(me['display_name'] as String?),
            preferredLanguage: Value(me['preferred_language'] as String? ?? 'zh'),
            quotaMonth: Value(quota['month'] as String?),
            storyUsed: Value(quota['story_used'] as int? ?? 0),
            storyLimit: Value(quota['story_limit'] as int? ?? 0),
            cloneUsed: Value(quota['clone_used'] as int? ?? 0),
            cloneLimit: Value(quota['clone_limit'] as int? ?? 0),
            syncedAt: DateTime.now(),
          ),
        );
  }

  Future<Map<String, dynamic>?> refresh({
    void Function(Map<String, dynamic>? cached)? onCached,
    void Function(String message)? onNetworkError,
  }) async {
    final cached = await loadCached();
    onCached?.call(cached);
    try {
      final me = await api.me();
      final quota = await api.quota();
      await saveSnapshot(me: me, quota: quota);
      return {
        'id': me['id'],
        'display_name': me['display_name'],
        'preferred_language': me['preferred_language'],
        'quota': quota,
      };
    } catch (e) {
      if (e is ApiException && e.unauthorized) rethrow;
      onNetworkError?.call(friendlyNetworkError(e));
      return cached;
    }
  }

  int? _asId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
