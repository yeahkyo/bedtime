import 'dart:ui' show Locale;

import '../config.dart';

/// Marketing-site origin for privacy / terms (not the API host).
class LegalConfig {
  static const supportEmail = 'support@lullvale.com';

  /// Default when config has not loaded yet (should not happen after main()).
  static const defaultBaseUrl = 'https://huhu.lullvale.com';

  /// From `assets/config/{env}.json` → `legal_host`.
  static String get baseUrl => _normalizeBaseUrl(
        AppConfig.isLoaded ? AppConfig.instance.legalHost : defaultBaseUrl,
      );

  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return defaultBaseUrl;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed.replaceAll(RegExp(r'/+$'), '');
    }
    return 'https://$trimmed'.replaceAll(RegExp(r'/+$'), '');
  }
}

enum LegalDocument {
  privacy('privacy'),
  terms('terms');

  const LegalDocument(this.pathSegment);
  final String pathSegment;
}

/// Maps app locale → legal HTML filename stem (en | zh-Hans | zh-Hant).
String legalLangCode(Locale locale) {
  if (locale.languageCode == 'zh') {
    if (locale.countryCode == 'TW' || locale.scriptCode == 'Hant') {
      return 'zh-Hant';
    }
    return 'zh-Hans';
  }
  return 'en';
}

String legalUrl(LegalDocument doc, Locale locale) {
  final lang = legalLangCode(locale);
  return '${LegalConfig.baseUrl}/legal/${doc.pathSegment}/$lang.html';
}

Uri supportMailtoUri({String? subject}) {
  return Uri(
    scheme: 'mailto',
    path: LegalConfig.supportEmail,
    query: subject != null ? 'subject=${Uri.encodeComponent(subject)}' : null,
  );
}
