import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Compile-time env selector only. Values live in `assets/config/{env}.json`.
///
/// ```bash
/// flutter run                                      # APP_ENV=dev (default)
/// flutter run --dart-define=APP_ENV=staging
/// flutter run --dart-define=APP_ENV=production
/// ```
///
/// Optional override (gitignored): `assets/config/{env}.local.json` merges on top
/// (e.g. LAN IP for devices, Umeng keys for staging).
const String kAppEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

class AppConfig {
  AppConfig._({
    required this.env,
    required this.apiBaseUrl,
    required this.legalHost,
    required this.featureSoftSeries,
    required this.featureVoiceClone,
    required this.umengAndroidAppKey,
    required this.umengIosAppKey,
    required this.umengChannel,
  });

  final String env;
  final String apiBaseUrl;
  final String legalHost;
  final bool featureSoftSeries;
  final bool featureVoiceClone;
  final String umengAndroidAppKey;
  final String umengIosAppKey;
  final String umengChannel;

  static AppConfig? _instance;

  static AppConfig get instance {
    final cfg = _instance;
    if (cfg == null) {
      throw StateError('AppConfig.load() must be called before using config');
    }
    return cfg;
  }

  static bool get isLoaded => _instance != null;

  static Future<void> load({String? env}) async {
    final name = _normalizeEnv(env ?? kAppEnv);
    final basePath = 'assets/config/$name.json';
    final baseRaw = await rootBundle.loadString(basePath);
    final map = Map<String, dynamic>.from(jsonDecode(baseRaw) as Map);

    final localPath = 'assets/config/$name.local.json';
    try {
      final localRaw = await rootBundle.loadString(localPath);
      final local = jsonDecode(localRaw) as Map<String, dynamic>;
      map.addAll(local);
      debugPrint('AppConfig: merged $localPath');
    } catch (_) {
      // Optional overlay missing — expected in CI / fresh clones.
    }

    _instance = AppConfig._(
      env: name,
      apiBaseUrl: _requireString(map, 'api_base_url'),
      legalHost: _stringOr(map, 'legal_host', 'https://huhu.lullvale.com'),
      featureSoftSeries: _boolOr(map, 'feature_soft_series', false),
      featureVoiceClone: _boolOr(map, 'feature_voice_clone', false),
      umengAndroidAppKey: _stringOr(map, 'umeng_android_app_key', ''),
      umengIosAppKey: _stringOr(map, 'umeng_ios_app_key', ''),
      umengChannel: _stringOr(map, 'umeng_channel', name),
    );
    debugPrint(
      'AppConfig: env=$name api=${_instance!.apiBaseUrl} '
      'umeng=${_instance!.umengApmConfigured}',
    );
  }

  bool get umengApmConfigured =>
      umengAndroidAppKey.trim().isNotEmpty || umengIosAppKey.trim().isNotEmpty;

  static String _normalizeEnv(String raw) {
    final v = raw.trim().toLowerCase();
    switch (v) {
      case 'dev':
      case 'development':
        return 'dev';
      case 'staging':
      case 'stage':
        return 'staging';
      case 'production':
      case 'prod':
        return 'production';
      default:
        debugPrint('AppConfig: unknown APP_ENV "$raw", falling back to dev');
        return 'dev';
    }
  }

  static String _requireString(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is! String || v.trim().isEmpty) {
      throw FormatException('config missing non-empty string "$key"');
    }
    return v.trim();
  }

  static String _stringOr(Map<String, dynamic> map, String key, String fallback) {
    final v = map[key];
    if (v is String) return v.trim();
    return fallback;
  }

  static bool _boolOr(Map<String, dynamic> map, String key, bool fallback) {
    final v = map[key];
    if (v is bool) return v;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return fallback;
  }
}

/// API origin from loaded [AppConfig].
String get apiBaseUrl => AppConfig.instance.apiBaseUrl;

/// Phase-1 product gates (must stay aligned with API `FEATURE_*` defaults).
bool get kFeatureSoftSeries => AppConfig.instance.featureSoftSeries;
bool get kFeatureVoiceClone => AppConfig.instance.featureVoiceClone;

String get umengAndroidAppKey => AppConfig.instance.umengAndroidAppKey;
String get umengIosAppKey => AppConfig.instance.umengIosAppKey;
String get umengChannel => AppConfig.instance.umengChannel;

bool get umengApmConfigured => AppConfig.instance.umengApmConfigured;

/// True when pointing at a non-loopback host (heuristic for UX copy).
bool get apiBaseUrlLooksRemote {
  final u = apiBaseUrl.toLowerCase();
  if (u.contains('127.0.0.1') || u.contains('localhost')) return false;
  return u.startsWith('https://') || u.startsWith('http://');
}

/// Resolve API-relative media paths (e.g. `/media/...`) against [apiBaseUrl].
String? resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '$apiBaseUrl$url';
}
