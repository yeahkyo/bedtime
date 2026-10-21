import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persist last successful suggestion chips per age_band.
class ChipCache {
  static String _kKey(String kind, String ageBand) => 'create_chips_${kind}_$ageBand';

  static Future<void> save(String kind, String ageBand, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey(kind, ageBand), jsonEncode(items));
  }

  static Future<List<Map<String, dynamic>>?> load(String kind, String ageBand) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey(kind, ageBand));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }
}
