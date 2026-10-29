import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight create-story defaults (not a full form draft).
///
/// Persists options families tend to reuse night to night: listeners, cast
/// (`cast_set` + `character_ids`), duration, wonder, dialogue. Inspiration
/// text stays session-only. Cast is only restored when `cast_set` is true so
/// accidental empty lists do not disable listener-twin defaults.
class CreatePrefs {
  CreatePrefs._();

  static String _key(int userId) => 'create_prefs_$userId';
  static String _legacyDraftKey(int userId) => 'create_draft_$userId';

  static Future<Map<String, dynamic>?> load(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    // Drop the old full-form draft if present.
    await prefs.remove(_legacyDraftKey(userId));
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

  static Future<void> save(int userId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyDraftKey(userId));
    await prefs.setString(_key(userId), jsonEncode(data));
  }

  static Future<void> clear(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
    await prefs.remove(_legacyDraftKey(userId));
  }
}
