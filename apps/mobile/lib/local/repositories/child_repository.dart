import 'dart:convert';

import 'package:drift/drift.dart';

import '../../api/client.dart';
import '../db/app_database.dart';
import '../network_errors.dart';

class ChildRepository {
  ChildRepository({
    required this.db,
    required this.api,
    required this.userId,
  });

  final AppDatabase db;
  final ApiClient api;
  final int userId;

  Future<List<Map<String, dynamic>>> loadCached() async {
    final rows = await (db.select(db.cachedChildren)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows.map(_rowToMap).toList();
  }

  Future<List<Map<String, dynamic>>> refresh({
    void Function(List<Map<String, dynamic>> cached)? onCached,
    void Function(String message)? onNetworkError,
  }) async {
    final cached = await loadCached();
    onCached?.call(cached);
    try {
      final remote = await api.listChildren();
      final maps = remote.cast<Map<String, dynamic>>();
      await replaceAll(maps);
      return maps;
    } catch (e) {
      if (e is ApiException && e.unauthorized) rethrow;
      onNetworkError?.call(friendlyNetworkError(e));
      return cached;
    }
  }

  Future<void> upsertOne(Map<String, dynamic> child) async {
    final id = _asId(child['id']);
    if (id == null) return;
    await db.into(db.cachedChildren).insertOnConflictUpdate(_companion(child, id));
  }

  Future<void> replaceAll(List<Map<String, dynamic>> children) async {
    await db.transaction(() async {
      await (db.delete(db.cachedChildren)..where((t) => t.userId.equals(userId))).go();
      for (final c in children) {
        final id = _asId(c['id']);
        if (id == null) continue;
        await db.into(db.cachedChildren).insertOnConflictUpdate(_companion(c, id));
      }
    });
  }

  Future<void> remove(int childId) async {
    await (db.delete(db.cachedChildren)
          ..where((t) => t.userId.equals(userId) & t.id.equals(childId)))
        .go();
  }

  CachedChildrenCompanion _companion(Map<String, dynamic> c, int id) {
    final prefer = (c['prefer'] as List<dynamic>? ?? []).cast<String>();
    return CachedChildrenCompanion.insert(
      userId: userId,
      id: id,
      nickname: c['nickname'] as String? ?? '',
      birthDate: Value(c['birth_date'] as String?),
      ageBand: Value(c['age_band'] as String? ?? '3-5'),
      gender: Value(c['gender'] as String? ?? 'unspecified'),
      intro: Value(c['intro'] as String?),
      interestsJson: Value(jsonEncode(prefer)),
      syncedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> _rowToMap(CachedChildrenData row) {
    List<String> prefer = const [];
    try {
      final decoded = jsonDecode(row.interestsJson);
      if (decoded is List) prefer = decoded.cast<String>();
    } catch (_) {}
    return {
      'id': row.id,
      'nickname': row.nickname,
      'birth_date': row.birthDate,
      'age_band': row.ageBand,
      'gender': row.gender,
      'intro': row.intro,
      'prefer': prefer,
    };
  }

  int? _asId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
