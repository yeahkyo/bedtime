import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import 'create_fallbacks.dart';

/// One theme-spark hint candidate (server id when synced; null for builtin).
class SeedHint {
  const SeedHint({this.id, required this.text});

  final int? id;
  final String text;

  String get usedKey => id != null ? 'id:$id' : 't:${text.trim()}';
}

/// Local pool of theme-spark hint examples.
///
/// Create page always reads from memory/disk/builtin — never waits on network.
/// [syncFromServer] refreshes the pool in the background.
/// Hints submitted with [theme_source]=hint are remembered via [markUsed] and
/// skipped by [pick] until the pool would otherwise be empty.
class SeedHintPool {
  SeedHintPool._();

  static const _kPrefix = 'theme_sparks_v2_';
  static const _kUsedPrefix = 'theme_sparks_used_';
  static final Map<String, List<SeedHint>> _memory = {};
  static final Map<String, Set<String>> _used = {};
  static bool _hydrating = false;
  static bool _syncing = false;

  static String _langKey(String language) =>
      language.startsWith('en') ? 'en' : 'zh';

  static List<SeedHint> _builtin(String lang) {
    final texts = lang == 'en' ? kSeedHintExamplesEn : kSeedHintExamplesZh;
    return [for (final t in texts) SeedHint(text: t)];
  }

  /// Sync read path for create UI. Prefers memory → else builtin.
  static List<SeedHint> itemsFor(String language) {
    final lang = _langKey(language);
    final cached = _memory[lang];
    if (cached != null && cached.isNotEmpty) return cached;
    return _builtin(lang);
  }

  static List<String> textsFor(String language) =>
      itemsFor(language).map((e) => e.text).toList();

  static Set<String> _usedFor(String lang) =>
      _used.putIfAbsent(lang, () => <String>{});

  static List<SeedHint> _available(String lang) {
    final used = _usedFor(lang);
    final all = itemsFor(lang);
    final open = all.where((e) => !used.contains(e.usedKey)).toList();
    if (open.isNotEmpty) return open;
    // Pool exhausted — allow reuse so create never loses hints.
    used.clear();
    unawaited(_persistUsed(lang));
    return all;
  }

  /// Pick a random unused hint for the seed-field placeholder.
  static SeedHint pick({required String language, Random? random}) {
    final lang = _langKey(language);
    final pool = _available(lang);
    final rng = random ?? Random();
    return pool[rng.nextInt(pool.length)];
  }

  /// After a successful create with theme_source=hint.
  static Future<void> markUsed(SeedHint hint, {required String language}) async {
    final lang = _langKey(language);
    final used = _usedFor(lang);
    used.add(hint.usedKey);
    // Also key by text so builtin↔server id flips still suppress the phrase.
    final t = hint.text.trim();
    if (t.isNotEmpty) used.add('t:$t');
    await _persistUsed(lang);
  }

  static Future<void> _persistUsed(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '$_kUsedPrefix$lang',
      _usedFor(lang).toList()..sort(),
    );
  }

  static Future<void> hydrateFromDisk() async {
    if (_hydrating) return;
    _hydrating = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final lang in const ['zh', 'en']) {
        final usedRaw = prefs.getStringList('$_kUsedPrefix$lang');
        if (usedRaw != null && usedRaw.isNotEmpty) {
          _used[lang] = usedRaw.toSet();
        }

        final raw = prefs.getString('$_kPrefix$lang');
        if (raw == null || raw.isEmpty) {
          // Migrate v1 text-only cache if present.
          final legacy = prefs.getString('theme_sparks_$lang');
          if (legacy != null && legacy.isNotEmpty) {
            try {
              final decoded = jsonDecode(legacy);
              if (decoded is List) {
                final items = decoded
                    .map((e) => '$e'.trim())
                    .where((e) => e.isNotEmpty)
                    .map((t) => SeedHint(text: t))
                    .toList();
                if (items.isNotEmpty) {
                  _memory[lang] = items;
                  await _save(lang, items);
                }
              }
            } catch (_) {
              /* ignore */
            }
          }
          continue;
        }
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! List) continue;
          final items = <SeedHint>[];
          for (final e in decoded) {
            if (e is Map) {
              final text = '${e['text'] ?? ''}'.trim();
              if (text.isEmpty) continue;
              final idRaw = e['id'];
              final id = idRaw is int
                  ? idRaw
                  : int.tryParse('$idRaw');
              items.add(SeedHint(id: id, text: text));
            } else {
              final text = '$e'.trim();
              if (text.isNotEmpty) items.add(SeedHint(text: text));
            }
          }
          if (items.isNotEmpty) _memory[lang] = items;
        } catch (_) {
          /* ignore corrupt cache */
        }
      }
    } finally {
      _hydrating = false;
    }
  }

  static Future<void> _save(String lang, List<SeedHint> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = [
      for (final h in items)
        {
          if (h.id != null) 'id': h.id,
          'text': h.text,
        },
    ];
    await prefs.setString('$_kPrefix$lang', jsonEncode(payload));
    _memory[lang] = List<SeedHint>.from(items);
  }

  /// Best-effort server sync. Safe to fire-and-forget from create prepare.
  /// Server already omits sparks this user used as hints when possible.
  static Future<void> syncFromServer(ApiClient api) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await hydrateFromDisk();
      for (final lang in const ['zh', 'en']) {
        try {
          final rows = await api.listThemeSparks(language: lang);
          final items = <SeedHint>[];
          for (final e in rows) {
            final text = (e['text'] as String?)?.trim() ?? '';
            if (text.isEmpty) continue;
            final idRaw = e['id'];
            final id = idRaw is int ? idRaw : int.tryParse('$idRaw');
            items.add(SeedHint(id: id, text: text));
          }
          if (items.isNotEmpty) {
            await _save(lang, items);
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
