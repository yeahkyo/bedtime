import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import 'create_fallbacks.dart';

/// Local pool of theme-spark hint examples.
///
/// Create page always reads from memory/disk/builtin — never waits on network.
/// [syncFromServer] refreshes the pool in the background.
class SeedHintPool {
  SeedHintPool._();

  static const _kPrefix = 'theme_sparks_';
  static final Map<String, List<String>> _memory = {};
  static bool _hydrating = false;
  static bool _syncing = false;

  static String _langKey(String language) =>
      language.startsWith('en') ? 'en' : 'zh';

  static List<String> _builtin(String lang) =>
      lang == 'en' ? kSeedHintExamplesEn : kSeedHintExamplesZh;

  /// Sync read path for create UI. Prefers memory → else builtin.
  static List<String> textsFor(String language) {
    final lang = _langKey(language);
    final cached = _memory[lang];
    if (cached != null && cached.isNotEmpty) return cached;
    return _builtin(lang);
  }

  static String pick({required String language, Random? random}) {
    final pool = textsFor(language);
    final rng = random ?? Random();
    return pool[rng.nextInt(pool.length)];
  }

  static Future<void> hydrateFromDisk() async {
    if (_hydrating) return;
    _hydrating = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final lang in const ['zh', 'en']) {
        final raw = prefs.getString('$_kPrefix$lang');
        if (raw == null || raw.isEmpty) continue;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! List) continue;
          final texts = decoded
              .map((e) => '$e'.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (texts.isNotEmpty) _memory[lang] = texts;
        } catch (_) {
          /* ignore corrupt cache */
        }
      }
    } finally {
      _hydrating = false;
    }
  }

  static Future<void> _save(String lang, List<String> texts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kPrefix$lang', jsonEncode(texts));
    _memory[lang] = List<String>.from(texts);
  }

  /// Best-effort server sync. Safe to fire-and-forget from create prepare.
  static Future<void> syncFromServer(ApiClient api) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await hydrateFromDisk();
      for (final lang in const ['zh', 'en']) {
        try {
          final items = await api.listThemeSparks(language: lang);
          final texts = items
              .map((e) => (e['text'] as String?)?.trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
          if (texts.isNotEmpty) {
            await _save(lang, texts);
          }
        } catch (_) {
          /* keep local / builtin pool */
        }
      }
    } finally {
      _syncing = false;
    }
  }
}
