import 'dart:async';
import 'dart:io';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_controller.dart';

AppLocalizations get _l10n =>
    lookupAppLocalizations(LocaleController.instance.locale);

/// Short messages for offline / timeout / server failures.
String friendlyNetworkError(Object e) {
  if (e is ApiException) return e.message;
  if (e is TimeoutException) return _l10n.netTimeout;
  if (e is SocketException) return _l10n.netOfflineCached;
  final s = e.toString();
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection refused')) {
    return _l10n.netOfflineCached;
  }
  if (s.contains('TimeoutException') || s.contains('timed out')) {
    return _l10n.netTimeout;
  }
  if (s.length > 120) return '${s.substring(0, 120)}…';
  return s;
}

bool looksLikeOffline(Object e) {
  if (e is SocketException) return true;
  if (e is TimeoutException) return false;
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection refused');
}
