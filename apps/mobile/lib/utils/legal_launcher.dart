import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/legal_urls.dart';
import '../l10n/app_localizations.dart';

Future<bool> openLegalDocument(BuildContext context, LegalDocument doc) async {
  final locale = Localizations.localeOf(context);
  final uri = Uri.parse(legalUrl(doc, locale));
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.legalOpenFailed)),
    );
  }
  return ok;
}

Future<bool> openSupportEmail({String? subject}) {
  return launchUrl(
    supportMailtoUri(subject: subject),
    mode: LaunchMode.externalApplication,
  );
}
