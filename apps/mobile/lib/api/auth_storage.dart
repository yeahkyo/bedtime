import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  AuthStorage._();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _legacyTokenKey = 'token';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<({String? access, String? refresh})> load() async {
    var access = await _secure.read(key: _accessKey);
    var refresh = await _secure.read(key: _refreshKey);

    // Migrate legacy SharedPreferences token once.
    if ((access == null || access.isEmpty) && (refresh == null || refresh.isEmpty)) {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_legacyTokenKey);
      if (legacy != null && legacy.isNotEmpty) {
        access = legacy;
        await prefs.remove(_legacyTokenKey);
        await _secure.write(key: _accessKey, value: legacy);
      }
    }
    return (access: access, refresh: refresh);
  }

  static Future<void> save({required String access, required String refresh}) async {
    await _secure.write(key: _accessKey, value: access);
    await _secure.write(key: _refreshKey, value: refresh);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyTokenKey);
  }

  static Future<void> clear() async {
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyTokenKey);
  }
}
