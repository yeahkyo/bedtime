// Patches native splash logo size + Y-position to match Flutter SplashLayout.
//
// Standalone (no Flutter imports) so `dart run` works outside the engine.
// Keep constants in sync with lib/splash/splash_theme.dart.
//
// Run after regenerating splash assets:
//   dart run flutter_native_splash:create
//   dart run tool/patch_native_splash.dart
//
// ignore_for_file: avoid_print

import 'dart:io';

/// Must match [SplashLayout.logoCenterFraction].
const logoCenterFraction = 0.36;

/// Must match [SplashColors.logoSize] (+ frame is Flutter-only; native = image size).
const logoSizePt = 88.0;

void main() {
  _patchIosStoryboard();
  _patchAndroidLaunchBackground();
  print(
    'Patched native splash: ${logoSizePt.toInt()}pt @ '
    '${logoCenterFraction * 100}% screen height.',
  );
}

void _patchIosStoryboard() {
  final file = File('ios/Runner/Base.lproj/LaunchScreen.storyboard');
  if (!file.existsSync()) {
    print('Skip iOS: ${file.path} not found');
    return;
  }

  var xml = file.readAsStringSync();

  // Prefer aspect-fit so explicit width/height constraints control on-screen size.
  xml = xml.replaceAll(
    'contentMode="center" image="LaunchImage"',
    'contentMode="scaleAspectFit" image="LaunchImage"',
  );

  const constraintsStart = '<constraints>';
  const constraintsEnd = '</constraints>';
  final start = xml.indexOf(constraintsStart);
  final end = xml.indexOf(constraintsEnd, start);
  if (start < 0 || end < 0) {
    print('Skip iOS: constraints block not found');
    return;
  }

  final multiplier = logoCenterFraction * 2;
  final size = logoSizePt.toStringAsFixed(0);
  final replacement = '''
<constraints>
    <constraint firstItem="tWc-Dq-wcI" firstAttribute="bottom" secondItem="Ze5-6b-2t3" secondAttribute="bottom" id="RPx-PI-7Xg"/>
    <constraint firstItem="tWc-Dq-wcI" firstAttribute="top" secondItem="Ze5-6b-2t3" secondAttribute="top" id="SdS-ul-q2q"/>
    <constraint firstAttribute="trailing" secondItem="tWc-Dq-wcI" secondAttribute="trailing" id="Swv-Gf-Rwn"/>
    <constraint firstItem="tWc-Dq-wcI" firstAttribute="leading" secondItem="Ze5-6b-2t3" secondAttribute="leading" id="kV7-tw-vXt"/>
    <constraint firstItem="YRO-k0-Ey4" firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX" id="Bdg-logo-cx"/>
    <constraint firstItem="YRO-k0-Ey4" firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY" multiplier="$multiplier" id="Bdg-logo-cy"/>
    <constraint firstItem="YRO-k0-Ey4" firstAttribute="width" constant="$size" id="Bdg-logo-w"/>
    <constraint firstItem="YRO-k0-Ey4" firstAttribute="height" constant="$size" id="Bdg-logo-h"/>
</constraints>''';

  xml = xml.replaceRange(start, end + constraintsEnd.length, replacement);
  file.writeAsStringSync(xml);
  print('Patched ${file.path}');
}

void _patchAndroidLaunchBackground() {
  const paths = [
    'android/app/src/main/res/drawable/launch_background.xml',
    'android/app/src/main/res/drawable-v21/launch_background.xml',
  ];

  // Place a logoSize-tall slot whose vertical center sits at logoCenterFraction.
  // Slot top = center - size/2; use top gravity + margin via inset height math:
  // height of region from top covering down to logo bottom =
  //   logoCenterFraction * 100 + (logo half as % of a ~800dp phone) — instead use
  // fixed dp size + gravity that pins center via percentage container.
  //
  // Container from top with height = logoCenterFraction*100 + halfLogoInPercent is awkward.
  // Simpler: full-bleed item with gravity center|top and top inset via height region:
  // Region height H% from top, bitmap centered in region → logo center at H/2 %.
  // Want center at 36% → region height 72% from top, gravity top.
  // Region from top with height = 2× center fraction → bitmap center at logoCenterFraction.
  // Splash PNG density buckets are written to ~logoSizePt dp by regenerate script.
  final regionPercent = (logoCenterFraction * 2 * 100).round(); // 72
  final content = '''
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <bitmap android:gravity="fill" android:src="@drawable/background"/>
    </item>
    <item
        android:width="match_parent"
        android:height="$regionPercent%p"
        android:gravity="top|center_horizontal">
        <bitmap android:gravity="center" android:src="@drawable/splash"/>
    </item>
</layer-list>
''';

  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) {
      print('Skip Android: $path not found');
      continue;
    }
    file.writeAsStringSync(content);
    print('Patched $path');
  }
}
