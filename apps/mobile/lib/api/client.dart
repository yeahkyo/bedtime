import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_storage.dart';

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.unauthorized = false,
    this.storyId,
    this.storyFailed = false,
  });

  final String message;
  final int? statusCode;
  final bool unauthorized;
  final int? storyId;

  /// True when the story job itself failed (status=failed), as opposed to a
  /// transient network error while polling.
  final bool storyFailed;

  @override
  String toString() => message;
}

/// Outcome of [ApiClient.tryRefresh] — callers must only clear the session on
/// [RefreshOutcome.unauthorized], never on [RefreshOutcome.network].
enum RefreshOutcome {
  /// New access + refresh saved.
  success,

  /// Server rejected the refresh token (expired / revoked / reuse).
  unauthorized,

  /// Timeout / socket / 5xx — credentials may still be valid; do not log out.
  network,

  /// No refresh token in memory.
  missing,
}

class ApiClient {
  ApiClient({this.token, this.refreshToken, this.onUnauthorized});

  String? token;
  String? refreshToken;
  void Function()? onUnauthorized;

  Future<RefreshOutcome>? _refreshInFlight;

  static const _timeout = Duration(seconds: 20);
  // Story LLM + TTS for 5–8 min targets can exceed 4 minutes end-to-end.
  // Outline + plan + draft (+ TTS) for a new soft series can exceed 7 minutes.
  static const _longTimeout = Duration(seconds: 540);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _u(String path) => Uri.parse('$apiBaseUrl$path');

  Future<Map<String, dynamic>> register({
    required String inviteCode,
    required String phone,
    required String password,
    String? displayName,
  }) async {
    final res = await http
        .post(
          _u('/v1/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'invite_code': inviteCode,
            'phone': phone,
            'password': password,
            if (displayName != null) 'display_name': displayName,
            'preferred_language': 'zh',
          }),
        )
        .timeout(_timeout);
    _ensureAuthResponse(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final res = await http
        .post(
          _u('/v1/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': phone,
            'password': password,
          }),
        )
        .timeout(_timeout);
    _ensureAuthResponse(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refreshSession() async {
    final rt = refreshToken;
    if (rt == null || rt.isEmpty) {
      throw ApiException('登录已失效，请重新进入', statusCode: 401, unauthorized: true);
    }
    final res = await http
        .post(
          _u('/v1/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': rt}),
        )
        .timeout(_timeout);
    if (res.statusCode >= 400) {
      throw ApiException(
        _friendlyError(res.statusCode, res.body),
        statusCode: res.statusCode,
        unauthorized: res.statusCode == 401,
      );
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw ApiException('刷新登录失败', statusCode: 401, unauthorized: true);
    }
    token = access;
    refreshToken = refresh;
    await AuthStorage.save(access: access, refresh: refresh);
    return data;
  }

  Future<void> logout() async {
    final rt = refreshToken;
    try {
      if (rt != null && rt.isNotEmpty) {
        await http
            .post(
              _u('/v1/auth/logout'),
              headers: _headers,
              body: jsonEncode({'refresh_token': rt}),
            )
            .timeout(_timeout);
      }
    } catch (_) {
      /* best-effort */
    }
    token = null;
    refreshToken = null;
    await AuthStorage.clear();
  }

  /// Single-flight refresh. Prefer this over treating all failures as logout.
  Future<RefreshOutcome> tryRefresh() async {
    if (refreshToken == null || refreshToken!.isEmpty) {
      return RefreshOutcome.missing;
    }
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final future = _doRefresh();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<RefreshOutcome> _doRefresh() async {
    try {
      await refreshSession();
      return RefreshOutcome.success;
    } on ApiException catch (e) {
      if (e.unauthorized || e.statusCode == 401) {
        return RefreshOutcome.unauthorized;
      }
      // 5xx / 429 from refresh endpoint — keep session.
      return RefreshOutcome.network;
    } on TimeoutException {
      return RefreshOutcome.network;
    } on SocketException {
      return RefreshOutcome.network;
    } catch (e) {
      final s = e.toString();
      if (s.contains('SocketException') ||
          s.contains('Failed host lookup') ||
          s.contains('Connection refused') ||
          s.contains('timed out') ||
          s.contains('TimeoutException')) {
        return RefreshOutcome.network;
      }
      // Unknown — do not wipe login; treat as transient.
      return RefreshOutcome.network;
    }
  }

  Future<void> _clearAuthTokens() async {
    token = null;
    refreshToken = null;
    await AuthStorage.clear();
  }

  Future<List<dynamic>> listChildren() async {
    final res = await _get(_u('/v1/children'));
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> listCharacters({int? relatedChildId}) async {
    final qp = <String, String>{
      if (relatedChildId != null) 'related_child_id': '$relatedChildId',
    };
    final uri = qp.isEmpty
        ? _u('/v1/characters')
        : _u('/v1/characters').replace(queryParameters: qp);
    final res = await _get(uri);
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCharacter({
    required String kind,
    required String name,
    required int relatedChildId,
    String? relation,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'kind': kind,
      'name': name,
      'related_child_id': relatedChildId,
      if (relation != null) 'relation': relation,
      if (note != null) 'note': note,
    };
    final res = await _post(_u('/v1/characters'), body: jsonEncode(payload));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCharacter({
    required int characterId,
    String? name,
    String? relation,
    String? note,
    bool? enabled,
    int? relatedChildId,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (relation != null) payload['relation'] = relation;
    if (note != null) payload['note'] = note;
    if (enabled != null) payload['enabled'] = enabled;
    if (relatedChildId != null) payload['related_child_id'] = relatedChildId;
    final res = await _patch(
      _u('/v1/characters/$characterId'),
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> deleteCharacter(int characterId) async {
    await _delete(_u('/v1/characters/$characterId'));
  }

  /// Developmental theme kernels (inspiration chips) for an age band.
  Future<List<Map<String, dynamic>>> listKernels({
    String ageBand = '3-5',
    int limit = 12,
    int? childId,
  }) async {
    final qp = <String, String>{
      'age_band': ageBand,
      'limit': '$limit',
      if (childId != null) 'child_id': '$childId',
    };
    final res = await _get(
      _u('/v1/kernels').replace(queryParameters: qp),
      timeout: const Duration(seconds: 8),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  /// Objective world-element suggestion chips.
  Future<List<Map<String, dynamic>>> listElementSuggestions({
    String ageBand = '3-5',
    int limit = 12,
    int? childId,
  }) async {
    final qp = <String, String>{
      'age_band': ageBand,
      'limit': '$limit',
      if (childId != null) 'child_id': '$childId',
    };
    final res = await _get(
      _u('/v1/elements').replace(queryParameters: qp),
      timeout: const Duration(seconds: 8),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getVoicePrefs(int childId) async {
    final res = await _get(_u('/v1/children/$childId/voice-prefs'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createChild({
    required String nickname,
    String? birthDate,
    String? ageBand,
    String gender = 'unspecified',
    String? intro,
    List<String> prefer = const [],
  }) async {
    final payload = <String, dynamic>{
      'nickname': nickname,
      'gender': gender,
      'prefer': prefer,
    };
    if (birthDate != null && birthDate.isNotEmpty) {
      payload['birth_date'] = birthDate;
    } else if (ageBand != null && ageBand.isNotEmpty) {
      payload['age_band'] = ageBand;
    }
    if (intro != null) payload['intro'] = intro;
    final res = await _post(_u('/v1/children'), body: jsonEncode(payload));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateChild({
    required int childId,
    String? nickname,
    String? birthDate,
    String? ageBand,
    String? gender,
    String? intro,
    List<String>? prefer,
  }) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (birthDate != null) body['birth_date'] = birthDate;
    if (ageBand != null) body['age_band'] = ageBand;
    if (gender != null) body['gender'] = gender;
    if (intro != null) body['intro'] = intro;
    if (prefer != null) body['prefer'] = prefer;
    final res = await _patch(_u('/v1/children/$childId'), body: jsonEncode(body));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> deleteChild(int childId) async {
    await _delete(_u('/v1/children/$childId'));
  }

  Future<void> updateVoicePrefs({
    required int childId,
    required String speedTier,
    required String tonePreset,
    required bool likenessBoost,
    int? defaultVoiceId,
  }) async {
    await _patch(
      _u('/v1/children/$childId/voice-prefs'),
      body: jsonEncode({
        'speed_tier': speedTier,
        'tone_preset': tonePreset,
        'likeness_boost': likenessBoost,
        'default_voice_id': defaultVoiceId,
      }),
    );
  }

  Future<Map<String, dynamic>> ensureSystemVoice() async {
    final res = await _post(_u('/v1/voices/system-default'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listVoices() async {
    final res = await _get(_u('/v1/voices'));
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateVoice({
    required int voiceId,
    required String name,
  }) async {
    final res = await _patch(_u('/v1/voices/$voiceId'), body: jsonEncode({'name': name}));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cloneVoice({
    required List<int> bytes,
    required String filename,
    required String name,
    required String language,
  }) async {
    Future<http.Response> sendOnce() async {
      final req = http.MultipartRequest('POST', _u('/v1/voices/clone'));
      if (token != null) {
        req.headers['Authorization'] = 'Bearer $token';
      }
      req.fields['consent'] = 'true';
      req.fields['name'] = name;
      req.fields['language'] = language;
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await req.send().timeout(_longTimeout);
      return http.Response.fromStream(streamed).timeout(_longTimeout);
    }

    final res = await _send(sendOnce);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listStories() async {
    final res = await _get(_u('/v1/stories'));
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStory(int storyId) async {
    final res = await _get(_u('/v1/stories/$storyId'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Enqueue generation (returns quickly with status=generating).
  Future<Map<String, dynamic>> createStory({
    required int childId,
    required String theme,
    required String language,
    required int durationMinutes,
    int? voiceId,
    List<Map<String, dynamic>> audiences = const [],
    List<int> characterIds = const [],
    String wonder = 'soft',
    String dialogue = 'some',
  }) async {
    final res = await _post(
      _u('/v1/stories'),
      body: jsonEncode({
        'child_id': childId,
        'theme': theme,
        'language': language,
        'duration_minutes': durationMinutes,
        'voice_id': voiceId,
        'audiences': audiences,
        'character_ids': characterIds,
        'wonder': wonder,
        'dialogue': dialogue,
      }),
      timeout: const Duration(seconds: 45),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Create + poll until ready/failed. [onProgress] receives progress stage string.
  Future<Map<String, dynamic>> createStoryAndWait({
    required int childId,
    required String theme,
    required String language,
    required int durationMinutes,
    int? voiceId,
    List<Map<String, dynamic>> audiences = const [],
    List<int> characterIds = const [],
    String wonder = 'soft',
    String dialogue = 'some',
    void Function(String progress)? onProgress,
  }) async {
    final created = await createStory(
      childId: childId,
      theme: theme,
      language: language,
      durationMinutes: durationMinutes,
      voiceId: voiceId,
      audiences: audiences,
      characterIds: characterIds,
      wonder: wonder,
      dialogue: dialogue,
    );
    final status = created['status'] as String? ?? '';
    if (status == 'ready') return created;
    final id = created['id'] as int?;
    if (status == 'failed') {
      throw ApiException(
        created['error_message'] as String? ?? '故事生成失败',
        storyId: id,
        storyFailed: true,
      );
    }
    if (id == null) {
      throw ApiException('故事创建失败', storyFailed: true);
    }
    return waitForStory(id, onProgress: onProgress);
  }

  /// Re-enqueue a failed story (no extra story quota charge).
  Future<Map<String, dynamic>> retryStory(int storyId) async {
    final res = await _post(
      _u('/v1/stories/$storyId/retry'),
      timeout: const Duration(seconds: 45),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> retryStoryAndWait(
    int storyId, {
    void Function(String progress)? onProgress,
  }) async {
    final created = await retryStory(storyId);
    final status = created['status'] as String? ?? '';
    if (status == 'ready') return created;
    final id = created['id'] as int? ?? storyId;
    if (status == 'failed') {
      throw ApiException(
        created['error_message'] as String? ?? '故事生成失败',
        storyId: id,
        storyFailed: true,
      );
    }
    return waitForStory(id, onProgress: onProgress);
  }

  Future<Map<String, dynamic>> waitForStory(
    int id, {
    void Function(String progress)? onProgress,
  }) async {
    onProgress?.call('queued');
    final deadline = DateTime.now().add(_longTimeout);
    var consecutiveNetworkErrors = 0;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        final story = await getStory(id);
        consecutiveNetworkErrors = 0;
        final st = story['status'] as String? ?? '';
        final prog = story['progress'] as String? ?? st;
        onProgress?.call(prog);
        if (st == 'ready') return story;
        if (st == 'failed') {
          throw ApiException(
            story['error_message'] as String? ?? '故事生成失败',
            storyId: id,
            storyFailed: true,
          );
        }
      } on ApiException catch (e) {
        if (e.unauthorized || e.storyFailed) rethrow;
        consecutiveNetworkErrors++;
        if (consecutiveNetworkErrors >= 5) {
          throw ApiException(
            '网络不稳定，生成可能仍在进行。可稍后在「故事」刷新，或点继续等待',
            storyId: id,
          );
        }
      } on TimeoutException {
        consecutiveNetworkErrors++;
        if (consecutiveNetworkErrors >= 5) {
          throw ApiException(
            '网络超时，生成可能仍在进行。可稍后刷新或点继续等待',
            storyId: id,
          );
        }
      } on SocketException {
        consecutiveNetworkErrors++;
        if (consecutiveNetworkErrors >= 5) {
          throw ApiException(
            '网络不可用，生成可能仍在进行。恢复网络后可点继续等待',
            storyId: id,
          );
        }
      }
    }
    throw ApiException(
      '等待故事生成超时，可在「故事」里查看是否已完成',
      storyId: id,
    );
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _get(_u('/v1/account/me'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> quota() async {
    final res = await _get(_u('/v1/account/quota'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void _ensureAuthResponse(http.Response res) {
    if (res.statusCode < 400) return;
    throw ApiException(_friendlyError(res.statusCode, res.body), statusCode: res.statusCode);
  }

  void _ensure(http.Response res) {
    if (res.statusCode < 400) return;
    if (res.statusCode == 401) {
      throw ApiException('登录已失效，请重新进入', statusCode: 401, unauthorized: true);
    }
    throw ApiException(_friendlyError(res.statusCode, res.body), statusCode: res.statusCode);
  }

  Future<http.Response> _get(Uri uri, {Duration? timeout}) async {
    return _send(() => http.get(uri, headers: _headers).timeout(timeout ?? _timeout));
  }

  Future<http.Response> _post(Uri uri, {Object? body, Duration? timeout}) async {
    return _send(
      () => http
          .post(uri, headers: _headers, body: body)
          .timeout(timeout ?? _timeout),
    );
  }

  Future<http.Response> _patch(Uri uri, {Object? body, Duration? timeout}) async {
    return _send(
      () => http
          .patch(uri, headers: _headers, body: body)
          .timeout(timeout ?? _timeout),
    );
  }

  Future<http.Response> _delete(Uri uri, {Duration? timeout}) async {
    return _send(() => http.delete(uri, headers: _headers).timeout(timeout ?? _timeout));
  }

  Future<http.Response> _send(Future<http.Response> Function() once) async {
    var res = await once();
    if (res.statusCode != 401) {
      _ensure(res);
      return res;
    }
    final outcome = await tryRefresh();
    if (outcome == RefreshOutcome.success) {
      res = await once();
      if (res.statusCode == 401) {
        // Access still rejected after a fresh pair — treat as hard logout.
        await _clearAuthTokens();
        onUnauthorized?.call();
        throw ApiException('登录已失效，请重新进入', statusCode: 401, unauthorized: true);
      }
      _ensure(res);
      return res;
    }
    if (outcome == RefreshOutcome.unauthorized ||
        outcome == RefreshOutcome.missing) {
      await _clearAuthTokens();
      onUnauthorized?.call();
      throw ApiException('登录已失效，请重新进入', statusCode: 401, unauthorized: true);
    }
    // Network blip while renewing — keep stored refresh; surface a soft error.
    throw ApiException('网络不稳定，请稍后重试', statusCode: res.statusCode);
  }

  static String _friendlyError(int statusCode, String body) {
    final detail = _extractDetail(body);
    if (detail != null && detail.isNotEmpty) {
      return detail.length > 160 ? '${detail.substring(0, 160)}…' : detail;
    }
    if (statusCode == 403) return '没有权限执行该操作';
    if (statusCode == 404) return '未找到相关内容';
    if (statusCode == 429) return '请求过于频繁，请稍后再试';
    if (statusCode >= 500) return '服务暂时不可用，请稍后再试';
    return '请求失败 ($statusCode)';
  }

  static String? _extractDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) return first['msg'].toString();
          return first.toString();
        }
      }
    } catch (_) {}
    return null;
  }
}
