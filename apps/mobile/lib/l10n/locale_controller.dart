import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app language: zh_CN | zh_TW | en
class LocaleController extends ChangeNotifier {
  LocaleController._();

  static final LocaleController instance = LocaleController._();

  static const _prefsKey = 'app_locale';
  static const supported = <Locale>[
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
    Locale('en'),
  ];

  Locale _locale = const Locale('zh', 'CN');
  bool _ready = false;

  Locale get locale => _locale;
  bool get ready => _ready;

  static String codeOf(Locale locale) {
    if (locale.languageCode == 'en') return 'en';
    if (locale.languageCode == 'zh' && locale.countryCode == 'TW') {
      return 'zh_TW';
    }
    return 'zh_CN';
  }

  static Locale parse(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'en':
        return const Locale('en');
      case 'zh_TW':
        return const Locale('zh', 'TW');
      case 'zh_CN':
      default:
        return const Locale('zh', 'CN');
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = parse(prefs.getString(_prefsKey));
    _ready = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final next = parse(codeOf(locale));
    if (_locale == next) return;
    _locale = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, codeOf(next));
    notifyListeners();
  }
}
