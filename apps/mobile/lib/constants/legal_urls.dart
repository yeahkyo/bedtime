import 'dart:ui' show Locale;

/// Marketing-site origin for privacy / terms (not the API host).
class LegalConfig {
  static const supportEmail = 'support@lullvale.com';

  /// Production legal site. Override with `--dart-define=LEGAL_HOST=...`
  /// (e.g. http://127.0.0.1:8765 while previewing web/legal).
  static const defaultBaseUrl = 'https://huhu.lullvale.com';

  static String get baseUrl => _normalizeBaseUrl(
        const String.fromEnvironment('LEGAL_HOST', defaultValue: defaultBaseUrl),
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
