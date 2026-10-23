import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists create-story form draft across kills / weak network.
class CreateDraft {
  CreateDraft._();

  static String _key(int userId) => 'create_draft_$userId';

  static Future<Map<String, dynamic>?> load(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(int userId, Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(draft));
  }

  static Future<void> clear(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
