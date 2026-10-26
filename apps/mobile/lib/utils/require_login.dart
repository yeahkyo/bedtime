import 'package:flutter/material.dart';

import '../api/client.dart';
import '../screens/auth_screen.dart';

bool apiHasSession(ApiClient api) {
  final access = api.token;
  final refresh = api.refreshToken;
  return (access != null && access.isNotEmpty) ||
      (refresh != null && refresh.isNotEmpty);
}

bool apiHasAccessToken(ApiClient api) {
  final access = api.token;
  return access != null && access.isNotEmpty;
}

/// Pushes [AuthScreen]; returns true if the user signed in successfully.
///
/// Closing via the dismiss control (X) returns false so callers keep the
/// guest browsing session.
Future<bool> pushLoginScreen(BuildContext context, ApiClient api) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => AuthScreen(
        api: api,
        allowDismiss: true,
        onSuccess: () {
          if (Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop(true);
          }
        },
      ),
    ),
  );
  return result == true;
}

/// If already signed in, returns true. Otherwise opens login and returns the result.
Future<bool> requireLogin(BuildContext context, ApiClient api) async {
  if (apiHasAccessToken(api)) return true;
  return pushLoginScreen(context, api);
}
