import 'package:flutter/material.dart';

/// Launch screen tokens — from `design/launch/code.html`.
abstract final class SplashColors {
  static const background = Color(0xFF080D1A);
  static const night950 = Color(0xFF060A12);

  static const amberGlow = Color(0xFFF5C76C);
  static const amberSoft = Color(0xFFDEB366);
  static const amberDeep = Color(0xFFC48F43);

  static const parchmentLight = Color(0xFFF5F0E6);
  static const parchmentMuted = Color(0xFFCEC5B4);
  static const parchmentDim = Color(0xFF8F94A6);

  /// Framed icon size in logical px — keep in sync with native splash constraints.
  static const logoSize = 88.0;
  static const logoRadius = 22.0;
  static const logoFramePad = 2.0;
  static const logoInnerRadius = 20.0;

  /// Extra canvas around the frame for ambient glow (not part of native size).
  static const glowPad = 40.0;

  /// Lit lantern (after ignite).
  static const logoAsset = 'assets/branding/splash_logo.png';

  /// Extinguished lantern — native splash + Flutter start frame.
  static const logoDarkAsset = 'assets/branding/splash_logo_dark.png';

  static const studioNameZh = '风息谷工作室';
  static const studioNameEn = 'Lullvale Studio';
}

abstract final class SplashLayout {
  /// Logo **center** Y as a fraction of full screen height.
  ///
  /// Native launch screens use the same anchor — keep in sync with
  /// `tool/patch_native_splash.dart`.
  static const logoCenterFraction = 0.36;

  static const iosLogoCenterYMultiplier = logoCenterFraction * 2;

  /// Outer framed logo edge length (image + gold frame pad).
  static double get framedLogoSize =>
      SplashColors.logoSize + SplashColors.logoFramePad * 2;

  static double logoTopForHeight(double screenHeight) {
    final centerY = screenHeight * logoCenterFraction;
    return centerY - framedLogoSize / 2;
  }
}

/// Motion timing — kept in sync with [BootstrapGate] minimum dwell.
abstract final class SplashMotion {
  /// Hold extinguished logo after native handoff before lighting.
  static const logoOnlyBeat = Duration(milliseconds: 300);

  /// Dark → lit + glow + copy fade (one shared timeline).
  static const igniteDuration = Duration(milliseconds: 1000);

  /// Brief hold after ignite completes before exiting splash.
  static const holdAfterReveal = Duration(milliseconds: 300);

  static Duration get minimumVisible =>
      logoOnlyBeat + igniteDuration + holdAfterReveal;

  static const exitFadeDuration = Duration(milliseconds: 350);

  static const exitFadeCurve = Curves.easeOut;

  /// Lantern + copy lighting ease.
  static const Curve igniteCurve = Curves.easeOut;

  /// Ambient lantern breathe after ignite (matches design ~5s).
  static const glowBreatheDuration = Duration(milliseconds: 5000);
}
