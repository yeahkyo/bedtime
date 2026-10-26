import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:umeng_apm_sdk/umeng_apm_sdk.dart';
import 'package:umeng_common_sdk/umeng_common_sdk.dart';

import '../config.dart';

/// Binding required by Umeng APM (also used so [AppConfig] can load assets first).
class BedtimeApmWidgetsFlutterBinding extends ApmWidgetsFlutterBinding {
  static WidgetsBinding ensureInitialized() {
    // Same pattern as ApmWidgetsFlutterBinding — construct once from main().
    BedtimeApmWidgetsFlutterBinding();
    return WidgetsBinding.instance;
  }
}

NavigatorObserver? _apmNavigatorObserver;

NavigatorObserver? get umengApmNavigatorObserver => _apmNavigatorObserver;

bool get umengApmShouldInit {
  if (kIsWeb) return false;
  if (!AppConfig.isLoaded) return false;
  return umengApmConfigured;
}

/// Call after [AppConfig.load]. Uses existing binding (do not re-create).
Future<void> runAppWithOptionalUmengApm(
  FutureOr<Widget> Function(NavigatorObserver? observer) buildApp,
) async {
  if (!umengApmShouldInit) {
    final app = await buildApp(null);
    runApp(app);
    return;
  }

  final sdk = UmengApmSdk(
    name: '',
    bver: '',
    enableLog: kDebugMode,
    enableTrackingPageFps: false,
    enableTrackingPagePerf: false,
    // Binding already created in main() so rootBundle could load config.
    initFlutterBinding: () => WidgetsBinding.instance,
  );

  sdk.init(
    appRunner: (observer) async {
      _apmNavigatorObserver = observer;
      try {
        final info = await PackageInfo.fromPlatform();
        sdk.name = info.packageName;
        sdk.bver = '${info.version}+${info.buildNumber}';
      } catch (_) {
        sdk.name = 'bedtime_mobile';
        sdk.bver = '0.0.0+0';
      }
      _initUmengCommon();
      return buildApp(observer);
    },
  );
}

void _initUmengCommon() {
  if (kIsWeb) return;
  final androidKey = umengAndroidAppKey.trim();
  final iosKey = umengIosAppKey.trim();
  final android = androidKey.isNotEmpty ? androidKey : iosKey;
  final ios = iosKey.isNotEmpty ? iosKey : androidKey;
  if (android.isEmpty && ios.isEmpty) return;

  try {
    final conf = UmConfig(android, ios, umengChannel, null);
    UmengCommonSdk.initCommonNew(conf);
    UmengCommonSdk.setPageCollectionModeManual();
  } catch (e, st) {
    debugPrint('Umeng Common init failed: $e\n$st');
  }
}
