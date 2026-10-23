import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../api/client.dart';
import '../../config.dart';
import '../db/app_database.dart';

/// Disk cache for story narration audio. Keyed by [storyId] (not URL).
///
/// Primary path: [LockCachingAudioSource] while playing (see player).
/// [enqueueDownload] is prefetch-only and skips ids currently being cached
/// by playback so we never double-download.
class MediaCache {
  MediaCache({
    required this.db,
    required this.api,
    required this.userId,
  });

  final AppDatabase db;
  final ApiClient api;
  final int userId;

  static const maxEntries = 20;
  static const maxBytes = 500 * 1024 * 1024; // ~500MB

  /// Shared across [MediaCache] instances for the same [userId].
  /// [LocalStore.open] / [LocalStore.openOrBootstrap] each build a new
  /// facade; without process-wide sets, playback vs prefetch races reopen.
  static final Map<int, Set<int>> _prefetchingByUser = {};
  static final Map<int, Set<int>> _playbackCachingByUser = {};

  Set<int> get _prefetching =>
      _prefetchingByUser.putIfAbsent(userId, () => <int>{});

  /// Story ids currently filled by LockCaching during playback.
  Set<int> get _playbackCaching =>
      _playbackCachingByUser.putIfAbsent(userId, () => <int>{});

  Future<Directory> _userDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'media', '$userId'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Final cache file used by LockCaching and offline [setFilePath].
  /// Use a real audio extension — iOS AVPlayer rejects unknown ones (e.g. `.audio` → -11828).
  Future<File> cacheFileFor(int storyId) async {
    final dir = await _userDir();
    return File(p.join(dir.path, '$storyId.mp3'));
  }

  /// Drop a bad/incomplete cache entry so the next play can re-fetch.
  Future<void> invalidate(int storyId) async {
    try {
      final file = await cacheFileFor(storyId);
      await _deleteCacheFiles(file.path);
      // Legacy extension from earlier builds.
      final legacy = File(p.join((await _userDir()).path, '$storyId.audio'));
      await _deleteCacheFiles(legacy.path);
    } catch (_) {}
    await (db.delete(db.mediaFiles)
          ..where((t) => t.userId.equals(userId) & t.storyId.equals(storyId)))
        .go();
  }

  void beginPlaybackCaching(int storyId) {
    _playbackCaching.add(storyId);
  }

  void endPlaybackCaching(int storyId) {
    _playbackCaching.remove(storyId);
  }

  /// Returns a playable local path when the full file is on disk.
  Future<String?> localPathIfReady(int storyId) async {
    final expected = await cacheFileFor(storyId);
    final part = File('${expected.path}.part');

    final row = await (db.select(db.mediaFiles)
          ..where((t) => t.userId.equals(userId) & t.storyId.equals(storyId)))
        .getSingleOrNull();
    if (row != null && row.ready) {
      final file = File(row.localPath);
      final rowPart = File('${row.localPath}.part');
      final ok = await file.exists() &&
          await file.length() > 0 &&
          !await rowPart.exists();
      // Old `.audio` caches break iOS; force re-cache as `.mp3`.
      final legacyExt = p.extension(row.localPath).toLowerCase() == '.audio';
      if (ok && !legacyExt) {
        return row.localPath;
      }
      await invalidate(storyId);
    }

    // Recover after LockCaching finished but DB row was never written
    // (process killed right after rename).
    if (await expected.exists() &&
        await expected.length() > 0 &&
        !await part.exists()) {
      await markReady(storyId, sizeBytes: await expected.length());
      return expected.path;
    }
    return null;
  }

  Future<void> markReady(int storyId, {required int sizeBytes}) async {
    final file = await cacheFileFor(storyId);
    if (!await file.exists() || sizeBytes <= 0) return;
    final part = File('${file.path}.part');
    if (await part.exists()) return;

    await db.into(db.mediaFiles).insertOnConflictUpdate(
          MediaFilesCompanion.insert(
            userId: userId,
            storyId: storyId,
            localPath: file.path,
            sizeBytes: Value(sizeBytes),
            lastPlayedAt: Value(DateTime.now()),
            ready: const Value(true),
          ),
        );
    await _enforceLru();
  }

  /// If the LockCaching file is complete, mark ready (call on progress=1 / dispose).
  Future<void> markReadyIfComplete(int storyId) async {
    try {
      final file = await cacheFileFor(storyId);
      final part = File('${file.path}.part');
      if (await file.exists() &&
          await file.length() > 0 &&
          !await part.exists()) {
        await markReady(storyId, sizeBytes: await file.length());
      }
    } catch (_) {}
  }

  Future<void> touchPlayed(int storyId) async {
    final existing = await (db.select(db.mediaFiles)
          ..where((t) => t.userId.equals(userId) & t.storyId.equals(storyId)))
        .getSingleOrNull();
    if (existing == null) return;
    await (db.update(db.mediaFiles)
          ..where((t) => t.userId.equals(userId) & t.storyId.equals(storyId)))
        .write(MediaFilesCompanion(lastPlayedAt: Value(DateTime.now())));
  }

  /// Prefetch only — never call this for the story currently playing.
  void enqueueDownload({
    required int storyId,
    required String? audioUrl,
  }) {
    if (audioUrl == null || audioUrl.isEmpty) return;
    if (_playbackCaching.contains(storyId)) return;
    if (_prefetching.contains(storyId)) return;
    unawaited(_download(storyId: storyId, audioUrl: audioUrl));
  }

  /// Bearer only for our API host / relative media — never for S3 presigns.
  Map<String, String> downloadHeaders(String resolvedUrl) {
    final headers = <String, String>{};
    final token = api.token;
    if (token == null || token.isEmpty) return headers;
    try {
      final media = Uri.parse(resolvedUrl);
      final apiUri = Uri.parse(apiBaseUrl);
      final sameHost = media.host.isNotEmpty &&
          apiUri.host.isNotEmpty &&
          media.host == apiUri.host;
      if (sameHost || !resolvedUrl.startsWith('http')) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers;
  }

  Future<void> _download({
    required int storyId,
    required String audioUrl,
  }) async {
    if (_playbackCaching.contains(storyId) || _prefetching.contains(storyId)) {
      return;
    }
    final existing = await localPathIfReady(storyId);
    if (existing != null) {
      await touchPlayed(storyId);
      return;
    }
    _prefetching.add(storyId);
    File? tmp;
    try {
      if (_playbackCaching.contains(storyId)) return;

      final url = _resolveUrl(audioUrl);
      if (url == null) return;

      Future<http.Response> getOnce(Map<String, String> headers) {
        return http.get(Uri.parse(url), headers: headers).timeout(
              const Duration(minutes: 5),
            );
      }

      var headers = downloadHeaders(url);
      var res = await getOnce(headers);
      if ((res.statusCode == 401 || res.statusCode == 403) &&
          headers.containsKey('Authorization')) {
        res = await getOnce(const {});
      }
      // Playback may have started LockCaching on the final path while we fetched.
      if (_playbackCaching.contains(storyId)) return;
      if (res.statusCode >= 400 || res.bodyBytes.isEmpty) return;

      final file = await cacheFileFor(storyId);
      final part = File('${file.path}.part');
      // Write to a sibling temp file, then rename — never touch LockCaching's
      // `.mp3` / `.part` mid-play (strategy 2).
      tmp = File('${file.path}.prefetch');
      await tmp.writeAsBytes(res.bodyBytes, flush: true);
      if (_playbackCaching.contains(storyId) ||
          await part.exists() ||
          await file.exists()) {
        await tmp.delete();
        tmp = null;
        return;
      }
      await tmp.rename(file.path);
      tmp = null;
      if (_playbackCaching.contains(storyId) || await part.exists()) {
        // Playback owns this id; do not register prefetch as ready.
        return;
      }
      await markReady(storyId, sizeBytes: res.bodyBytes.length);
    } catch (_) {
      // Prefetch is best-effort.
    } finally {
      if (tmp != null) {
        try {
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
      }
      _prefetching.remove(storyId);
    }
  }

  Future<void> prefetchReadyStories(
    List<Map<String, dynamic>> stories, {
    int limit = 5,
  }) async {
    try {
      final results = await Connectivity().checkConnectivity();
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (offline) return;
    } catch (_) {}

    var n = 0;
    for (final s in stories) {
      if (n >= limit) break;
      final status = s['status'] as String? ?? '';
      final id = _asId(s['id']);
      final url = s['audio_url'] as String?;
      if (status != 'ready' || id == null || url == null || url.isEmpty) continue;
      if (_playbackCaching.contains(id)) continue;
      final local = await localPathIfReady(id);
      if (local != null) continue;
      enqueueDownload(storyId: id, audioUrl: url);
      n++;
    }
  }

  Future<void> _enforceLru() async {
    final rows = await (db.select(db.mediaFiles)
          ..where((t) => t.userId.equals(userId) & t.ready.equals(true)))
        .get();
    if (rows.isEmpty) return;

    rows.sort((a, b) {
      final at = a.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });

    var totalBytes = rows.fold<int>(0, (sum, r) => sum + r.sizeBytes);
    var count = rows.length;
    for (final row in rows) {
      if (count <= maxEntries && totalBytes <= maxBytes) break;
      if (_playbackCaching.contains(row.storyId)) continue;
      try {
        await _deleteCacheFiles(row.localPath);
      } catch (_) {}
      await (db.delete(db.mediaFiles)
            ..where(
              (t) => t.userId.equals(userId) & t.storyId.equals(row.storyId),
            ))
          .go();
      totalBytes -= row.sizeBytes;
      count--;
    }
  }

  Future<void> _deleteCacheFiles(String localPath) async {
    final f = File(localPath);
    if (await f.exists()) await f.delete();
    final part = File('$localPath.part');
    if (await part.exists()) await part.delete();
    final mime = File('$localPath.mime');
    if (await mime.exists()) await mime.delete();
    final prefetch = File('$localPath.prefetch');
    if (await prefetch.exists()) await prefetch.delete();
  }

  Future<void> clearAllFiles() async {
    final rows = await (db.select(db.mediaFiles)
          ..where((t) => t.userId.equals(userId)))
        .get();
    for (final row in rows) {
      try {
        await _deleteCacheFiles(row.localPath);
      } catch (_) {}
    }
    try {
      final dir = await _userDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
    await (db.delete(db.mediaFiles)..where((t) => t.userId.equals(userId))).go();
    _playbackCachingByUser.remove(userId);
    _prefetchingByUser.remove(userId);
  }

  String? _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '$apiBaseUrl$url';
  }

  int? _asId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
