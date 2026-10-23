import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last known API user id so offline boot can scope the local DB.
class UserScope {
  UserScope._();

  static const _key = 'local_active_user_id';

  static Future<int?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_key);
    if (id == null || id <= 0) return null;
    return id;
  }

  static Future<void> save(int userId) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, userId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
