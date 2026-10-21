import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.unauthorized = false,
    this.storyId,
  });

  final String message;
  final int? statusCode;
  final bool unauthorized;
  final int? storyId;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.token, this.onUnauthorized});

  String? token;
  void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 20);
  // Story LLM + TTS for 5–8 min targets can exceed 4 minutes end-to-end.
  // Outline + plan + draft (+ TTS) for a new soft series can exceed 7 minutes.
  static const _longTimeout = Duration(seconds: 540);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _u(String path) => Uri.parse('$apiBaseUrl$path');

  Future<Map<String, dynamic>> devLogin() async {
    final res = await http
        .post(
          _u('/v1/auth/dev-login'),
          headers: _headers,
          body: jsonEncode({
            'display_name': 'Dev Parent',
            'preferred_language': 'zh',
          }),
        )
        .timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listChildren() async {
    final res = await http.get(_u('/v1/children'), headers: _headers).timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as List<dynamic>;
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
    final res = await http
        .get(_u('/v1/kernels').replace(queryParameters: qp), headers: _headers)
        .timeout(const Duration(seconds: 8));
    _ensure(res);
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
    final res = await http
        .get(_u('/v1/elements').replace(queryParameters: qp), headers: _headers)
        .timeout(const Duration(seconds: 8));
    _ensure(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getVoicePrefs(int childId) async {
    final res = await http
        .get(_u('/v1/children/$childId/voice-prefs'), headers: _headers)
        .timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createChild({
    required String nickname,
    String? birthDate,
    String? ageBand,
    String gender = 'unspecified',
    String? intro,
    List<String> interests = const [],
  }) async {
    final payload = <String, dynamic>{
      'nickname': nickname,
      'gender': gender,
      'interests': interests,
    };
    if (birthDate != null && birthDate.isNotEmpty) {
      payload['birth_date'] = birthDate;
    } else if (ageBand != null && ageBand.isNotEmpty) {
      payload['age_band'] = ageBand;
    }
    if (intro != null) payload['intro'] = intro;
    final res = await http
        .post(
          _u('/v1/children'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateChild({
    required int childId,
    String? nickname,
    String? birthDate,
    String? ageBand,
    String? gender,
    String? intro,
    List<String>? interests,
  }) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (birthDate != null) body['birth_date'] = birthDate;
    if (ageBand != null) body['age_band'] = ageBand;
    if (gender != null) body['gender'] = gender;
    if (intro != null) body['intro'] = intro;
    if (interests != null) body['interests'] = interests;
    final res = await http
        .patch(
          _u('/v1/children/$childId'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> updateVoicePrefs({
    required int childId,
    required String speedTier,
    required String tonePreset,
    required bool likenessBoost,
    int? defaultVoiceId,
  }) async {
    final res = await http
        .patch(
          _u('/v1/children/$childId/voice-prefs'),
          headers: _headers,
          body: jsonEncode({
            'speed_tier': speedTier,
            'tone_preset': tonePreset,
            'likeness_boost': likenessBoost,
            'default_voice_id': defaultVoiceId,
          }),
        )
        .timeout(_timeout);
    _ensure(res);
  }

  Future<Map<String, dynamic>> ensureSystemVoice() async {
    final res =
        await http.post(_u('/v1/voices/system-default'), headers: _headers).timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listVoices() async {
    final res = await http.get(_u('/v1/voices'), headers: _headers).timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateVoice({
    required int voiceId,
    required String name,
  }) async {
    final res = await http
        .patch(
          _u('/v1/voices/$voiceId'),
          headers: _headers,
          body: jsonEncode({'name': name}),
        )
        .timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cloneVoice({
    required List<int> bytes,
    required String filename,
    required String name,
    required String language,
  }) async {
    final req = http.MultipartRequest('POST', _u('/v1/voices/clone'));
    if (token != null) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.fields['consent'] = 'true';
    req.fields['name'] = name;
    req.fields['language'] = language;
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send().timeout(_longTimeout);
    final res = await http.Response.fromStream(streamed).timeout(_longTimeout);
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listStories() async {
    final res = await http.get(_u('/v1/stories'), headers: _headers).timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStory(int storyId) async {
    final res = await http.get(_u('/v1/stories/$storyId'), headers: _headers).timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Enqueue generation (returns quickly with status=generating).
  Future<Map<String, dynamic>> createStory({
    required int childId,
    required String theme,
    required String language,
    required int durationMinutes,
    int? voiceId,
    bool softSeriesMode = false,
    int? seriesId,
    int episodeCount = 4,
    List<String> keywords = const [],
    List<String> values = const [],
    String? developmentFocus,
    String? storyElementId,
    String childCastRole = 'auto',
    String? recap,
    String plotDrive = 'light',
    String imagery = 'balanced',
    String wonder = 'soft',
    String windDown = 'gentle',
    String dialogue = 'some',
    String leadIn = 'soft',
  }) async {
    final res = await http
        .post(
          _u('/v1/stories'),
          headers: _headers,
          body: jsonEncode({
            'child_id': childId,
            'theme': theme,
            'language': language,
            'duration_minutes': durationMinutes,
            'voice_id': voiceId,
            'soft_series_mode': softSeriesMode || seriesId != null,
            if (seriesId != null) 'series_id': seriesId,
            'episode_count': episodeCount,
            'keywords': keywords,
            'values': values,
            'development_focus': developmentFocus,
            if (storyElementId != null && storyElementId.isNotEmpty)
              'story_element_id': storyElementId,
            'child_cast_role': childCastRole,
            'recap': recap,
            'plot_drive': plotDrive,
            'imagery': imagery,
            'wonder': wonder,
            'wind_down': windDown,
            'dialogue': dialogue,
            'lead_in': leadIn,
            'source': 'manual',
          }),
        )
        .timeout(const Duration(seconds: 45));
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Create + poll until ready/failed. [onProgress] receives progress stage string.
  Future<Map<String, dynamic>> createStoryAndWait({
    required int childId,
    required String theme,
    required String language,
    required int durationMinutes,
    int? voiceId,
    bool softSeriesMode = false,
    int? seriesId,
    int episodeCount = 4,
    List<String> keywords = const [],
    List<String> values = const [],
    String? developmentFocus,
    String? storyElementId,
    String childCastRole = 'auto',
    String? recap,
    String plotDrive = 'light',
    String imagery = 'balanced',
    String wonder = 'soft',
    String windDown = 'gentle',
    String dialogue = 'some',
    String leadIn = 'soft',
    void Function(String progress)? onProgress,
  }) async {
    final created = await createStory(
      childId: childId,
      theme: theme,
      language: language,
      durationMinutes: durationMinutes,
      voiceId: voiceId,
      softSeriesMode: softSeriesMode,
      seriesId: seriesId,
      episodeCount: episodeCount,
      keywords: keywords,
      values: values,
      developmentFocus: developmentFocus,
      storyElementId: storyElementId,
      childCastRole: childCastRole,
      recap: recap,
      plotDrive: plotDrive,
      imagery: imagery,
      wonder: wonder,
      windDown: windDown,
      dialogue: dialogue,
      leadIn: leadIn,
    );
    final status = created['status'] as String? ?? '';
    if (status == 'ready') return created;
    final id = created['id'] as int?;
    if (status == 'failed') {
      throw ApiException(
        created['error_message'] as String? ?? '故事生成失败',
        storyId: id,
      );
    }
    if (id == null) {
      throw ApiException('故事创建失败');
    }
    return waitForStory(id, onProgress: onProgress);
  }

  /// Re-enqueue a failed story (no extra story quota charge).
  Future<Map<String, dynamic>> retryStory(int storyId) async {
    final res = await http
        .post(_u('/v1/stories/$storyId/retry'), headers: _headers)
        .timeout(const Duration(seconds: 45));
    _ensure(res);
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
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final story = await getStory(id);
      final st = story['status'] as String? ?? '';
      final prog = story['progress'] as String? ?? st;
      onProgress?.call(prog);
      if (st == 'ready') return story;
      if (st == 'failed') {
        throw ApiException(
          story['error_message'] as String? ?? '故事生成失败',
          storyId: id,
        );
      }
    }
    throw ApiException(
      '等待故事生成超时，可在「故事」里查看是否已完成',
      storyId: id,
    );
  }

  Future<Map<String, dynamic>> me() async {
    final res = await http.get(_u('/v1/account/me'), headers: _headers).timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> quota() async {
    final res = await http.get(_u('/v1/account/quota'), headers: _headers).timeout(_timeout);
    _ensure(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void _ensure(http.Response res) {
    if (res.statusCode < 400) return;
    if (res.statusCode == 401) {
      token = null;
      onUnauthorized?.call();
      throw ApiException('登录已失效，请重新进入', statusCode: 401, unauthorized: true);
    }
    throw ApiException(_friendlyError(res.statusCode, res.body), statusCode: res.statusCode);
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
