import 'package:drift/drift.dart';

import '../../api/client.dart';
import '../db/app_database.dart';
import '../network_errors.dart';

class VoiceRepository {
  VoiceRepository({
    required this.db,
    required this.api,
    required this.userId,
  });

  final AppDatabase db;
  final ApiClient api;
  final int userId;

  Future<List<Map<String, dynamic>>> loadCached() async {
    final rows = await (db.select(db.cachedVoices)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)]))
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
      final remote = await api.listVoices();
      final maps = remote.cast<Map<String, dynamic>>();
      await replaceAll(maps);
      return maps;
    } catch (e) {
      if (e is ApiException && e.unauthorized) rethrow;
      onNetworkError?.call(friendlyNetworkError(e));
      return cached;
    }
  }

  Future<void> replaceAll(List<Map<String, dynamic>> voices) async {
    await db.transaction(() async {
      await (db.delete(db.cachedVoices)..where((t) => t.userId.equals(userId))).go();
      for (final v in voices) {
        final id = _asId(v['id']);
        if (id == null) continue;
        await db.into(db.cachedVoices).insertOnConflictUpdate(_companion(v, id));
      }
    });
  }

  Future<Map<String, dynamic>?> loadVoicePrefs(int childId) async {
    final row = await (db.select(db.cachedVoicePrefs)
          ..where((t) => t.userId.equals(userId) & t.childId.equals(childId)))
        .getSingleOrNull();
    if (row == null) return null;
    return {
      'speed_tier': row.speedTier,
      'tone_preset': row.tonePreset,
      'likeness_boost': row.likenessBoost,
      'default_voice_id': row.defaultVoiceId,
    };
  }

  Future<void> saveVoicePrefs(int childId, Map<String, dynamic> prefs) async {
    await db.into(db.cachedVoicePrefs).insertOnConflictUpdate(
          CachedVoicePrefsCompanion.insert(
            userId: userId,
            childId: childId,
            speedTier: Value(prefs['speed_tier'] as String? ?? 'medium'),
            tonePreset: Value(prefs['tone_preset'] as String? ?? 'gentle'),
            likenessBoost: Value(prefs['likeness_boost'] as bool? ?? false),
            defaultVoiceId: Value(_asId(prefs['default_voice_id'])),
            syncedAt: DateTime.now(),
          ),
        );
  }

  Future<Map<String, dynamic>?> refreshVoicePrefs(
    int childId, {
    void Function(Map<String, dynamic>? cached)? onCached,
  }) async {
    final cached = await loadVoicePrefs(childId);
    onCached?.call(cached);
    try {
      final remote = await api.getVoicePrefs(childId);
      await saveVoicePrefs(childId, remote);
      return remote;
    } catch (_) {
      return cached;
    }
  }

  CachedVoicesCompanion _companion(Map<String, dynamic> v, int id) {
    return CachedVoicesCompanion.insert(
      userId: userId,
      id: id,
      name: v['name'] as String? ?? '',
      kind: Value(v['kind'] as String? ?? ''),
      language: Value(v['language'] as String? ?? 'zh'),
      provider: Value(v['provider'] as String? ?? ''),
      providerVoiceId: Value(v['provider_voice_id'] as String? ?? ''),
      speechModel: Value(v['speech_model'] as String?),
      speedTier: Value(v['speed_tier'] as String? ?? 'medium'),
      speed: Value((v['speed'] as num?)?.toDouble() ?? 1.0),
      enabled: Value(v['enabled'] as bool? ?? true),
      description: Value(v['description'] as String?),
      sortOrder: Value(v['sort_order'] as int? ?? 0),
      previewAudioUrl: Value(v['preview_audio_url'] as String?),
      syncedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> _rowToMap(CachedVoice row) {
    return {
      'id': row.id,
      'name': row.name,
      'kind': row.kind,
      'language': row.language,
      'provider': row.provider,
      'provider_voice_id': row.providerVoiceId,
      'speech_model': row.speechModel,
      'speed_tier': row.speedTier,
      'speed': row.speed,
      'enabled': row.enabled,
      'description': row.description,
      'sort_order': row.sortOrder,
      'preview_audio_url': row.previewAudioUrl,
    };
  }

  int? _asId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
