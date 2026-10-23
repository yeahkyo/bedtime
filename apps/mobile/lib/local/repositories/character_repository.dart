import 'package:drift/drift.dart';

import '../../api/client.dart';
import '../db/app_database.dart';
import '../network_errors.dart';

class CharacterRepository {
  CharacterRepository({
    required this.db,
    required this.api,
    required this.userId,
  });

  final AppDatabase db;
  final ApiClient api;
  final int userId;

  Future<List<Map<String, dynamic>>> loadCached({int? relatedChildId}) async {
    final q = db.select(db.cachedCharacters)
      ..where((t) => t.userId.equals(userId));
    if (relatedChildId != null) {
      q.where((t) => t.relatedChildId.equals(relatedChildId));
    }
    q.orderBy([
      (t) => OrderingTerm.asc(t.kind),
      (t) => OrderingTerm.asc(t.id),
    ]);
    final rows = await q.get();
    return rows.map(_rowToMap).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> refresh({
    int? relatedChildId,
    void Function(List<Map<String, dynamic>> cached)? onCached,
    void Function(String message)? onNetworkError,
  }) async {
    final cached = await loadCached(relatedChildId: relatedChildId);
    onCached?.call(cached);
    try {
      final remote = await api.listCharacters(relatedChildId: relatedChildId);
      final maps = remote.cast<Map<String, dynamic>>();
      if (relatedChildId != null) {
        await replaceForChild(relatedChildId, maps);
      } else {
        await replaceAll(maps);
      }
      return maps;
    } catch (e) {
      if (e is ApiException && e.unauthorized) rethrow;
      onNetworkError?.call(friendlyNetworkError(e));
    }
    return cached;
  }

  Future<void> replaceAll(List<Map<String, dynamic>> characters) async {
    await db.transaction(() async {
      await (db.delete(db.cachedCharacters)
            ..where((t) => t.userId.equals(userId)))
          .go();
      for (final c in characters) {
        final id = _asId(c['id']);
        if (id == null) continue;
        await db.into(db.cachedCharacters).insertOnConflictUpdate(_companion(c, id));
      }
    });
  }

  Future<void> replaceForChild(
    int relatedChildId,
    List<Map<String, dynamic>> characters,
  ) async {
    await db.transaction(() async {
      await (db.delete(db.cachedCharacters)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.relatedChildId.equals(relatedChildId),
            ))
          .go();
      for (final c in characters) {
        final id = _asId(c['id']);
        if (id == null) continue;
        await db.into(db.cachedCharacters).insertOnConflictUpdate(_companion(c, id));
      }
    });
  }

  CachedCharactersCompanion _companion(Map<String, dynamic> c, int id) {
    return CachedCharactersCompanion.insert(
      userId: userId,
      id: id,
      kind: c['kind'] as String? ?? 'person',
      name: c['name'] as String? ?? '',
      relatedChildId: Value(_asId(c['related_child_id'])),
      relation: Value(c['relation'] as String?),
      note: Value(c['note'] as String?),
      listenerChildId: Value(_asId(c['listener_child_id'])),
      enabled: Value(c['enabled'] as bool? ?? true),
      syncedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> _rowToMap(CachedCharacter row) {
    return {
      'id': row.id,
      'kind': row.kind,
      'name': row.name,
      'related_child_id': row.relatedChildId,
      'relation': row.relation,
      'note': row.note,
      'listener_child_id': row.listenerChildId,
      'enabled': row.enabled,
    };
  }

  int? _asId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
