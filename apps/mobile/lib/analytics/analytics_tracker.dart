import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/client.dart';

/// Fire-and-forget product analytics (self-hosted API). Not Umeng.
///
/// Failed batches are re-queued (bounded retries). Each event carries an
/// [idempotency_key] so server-side retries do not double-count.
class AnalyticsTracker {
  AnalyticsTracker._();

  static final AnalyticsTracker instance = AnalyticsTracker._();

  static const _maxQueue = 200;
  static const _maxAttempts = 3;
  static const _batchSize = 50;

  ApiClient? _api;
  final List<_QueuedEvent> _queue = [];
  bool _flushing = false;
  String? _appVersion;
  String? _platform;
  Timer? _debounce;
  Timer? _retryTimer;
  int _seq = 0;
  final _rng = Random();

  void bind(ApiClient api) {
    _api = api;
  }

  void unbind(ApiClient api) {
    if (identical(_api, api)) {
      _api = null;
      clearQueue();
    }
  }

  /// Drop pending events (logout / 401). Avoids attributing a prior session's
  /// buffer to the next signed-in user.
  void clearQueue() {
    _debounce?.cancel();
    _retryTimer?.cancel();
    _queue.clear();
  }

  Future<void> _ensureMeta() async {
    if (_appVersion != null && _platform != null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _appVersion = 'unknown';
    }
    if (kIsWeb) {
      _platform = 'web';
    } else if (Platform.isIOS) {
      _platform = 'ios';
    } else if (Platform.isAndroid) {
      _platform = 'android';
    } else {
      _platform = Platform.operatingSystem;
    }
  }

  String _newIdempotencyKey(String name) {
    _seq += 1;
    final ts = DateTime.now().toUtc().microsecondsSinceEpoch;
    final salt = _rng.nextInt(1 << 20);
    // Keep under server max_length 64.
    final raw = '$name-$ts-$_seq-$salt';
    return raw.length <= 64 ? raw : raw.substring(0, 64);
  }

  /// Enqueue a whitelisted event. No-op when not authenticated.
  void track(
    String name, {
    int? storyId,
    Map<String, dynamic>? props,
  }) {
    final api = _api;
    if (api == null || api.token == null) return;
    unawaited(_enqueue(name, storyId: storyId, props: props));
  }

  Future<void> _enqueue(
    String name, {
    int? storyId,
    Map<String, dynamic>? props,
  }) async {
    await _ensureMeta();
    final payload = <String, dynamic>{
      'name': name,
      if (storyId != null) 'story_id': storyId,
      if (props != null && props.isNotEmpty) 'props': props,
      'client_ts': DateTime.now().toUtc().toIso8601String(),
      if (_appVersion != null) 'app_version': _appVersion,
      if (_platform != null) 'platform': _platform,
      'idempotency_key': _newIdempotencyKey(name),
    };
    _queue.add(_QueuedEvent(payload: payload));
    while (_queue.length > _maxQueue) {
      _queue.removeAt(0);
    }
    _scheduleFlush(const Duration(milliseconds: 400));
    if (_queue.length >= 10) {
      _debounce?.cancel();
      unawaited(flush());
    }
  }

  void _scheduleFlush(Duration delay) {
    _debounce?.cancel();
    _debounce = Timer(delay, () {
      unawaited(flush());
    });
  }

  void _scheduleRetry(int attempt) {
    _retryTimer?.cancel();
    final seconds = min(30, 1 << (attempt.clamp(0, 4)));
    _retryTimer = Timer(Duration(seconds: seconds), () {
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    if (_flushing) return;
    final api = _api;
    if (api == null || api.token == null || _queue.isEmpty) return;
    _flushing = true;
    try {
      while (_queue.isNotEmpty && api.token != null) {
        final batch = _queue.take(_batchSize).toList(growable: false);
        _queue.removeRange(0, batch.length);
        final wire = batch.map((e) => e.payload).toList(growable: false);
        try {
          await api.postAnalyticsEvents(wire);
        } on ApiException catch (e) {
          if (e.unauthorized) {
            // Session gone; do not retry under a later user.
            clearQueue();
            break;
          }
          _requeueFailed(batch);
          break;
        } catch (_) {
          _requeueFailed(batch);
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void _requeueFailed(List<_QueuedEvent> batch) {
    final retryable = <_QueuedEvent>[];
    for (final e in batch) {
      e.attempts += 1;
      if (e.attempts < _maxAttempts) {
        retryable.add(e);
      }
    }
    if (retryable.isEmpty) return;
    _queue.insertAll(0, retryable);
    final nextAttempt = retryable.map((e) => e.attempts).reduce(max);
    _scheduleRetry(nextAttempt);
  }
}

class _QueuedEvent {
  _QueuedEvent({required this.payload});

  final Map<String, dynamic> payload;
  int attempts = 0;
}
