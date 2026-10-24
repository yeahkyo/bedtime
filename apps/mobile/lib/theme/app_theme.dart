import 'package:flutter/material.dart';

/// Warm Dial tokens — from `design/all/bedtime_storycraft_warm_dial/DESIGN.md`.
abstract final class AppColors {
  static const background = Color(0xFF0E1322);
  static const surface = Color(0xFF0E1322);
  static const surfaceLow = Color(0xFF161B2A);
  static const surfaceContainer = Color(0xFF1A1F2F);
  static const surfaceHigh = Color(0xFF252939);
  static const surfaceHighest = Color(0xFF2F3445);
  /// Paper card substrate (`surface-paper`).
  static const card = Color(0xFF1C2333);
  static const surfacePaperLayered = Color(0xFF242C3F);
  static const inputWell = Color(0xFF161B2A);

  /// Oat text — never pure white.
  static const onSurface = Color(0xFFEAE6DF);
  static const onSurfaceMuted = Color(0xFF9FA7B8);
  static const onSurfaceDim = Color(0xFF8A93A6);

  /// Incandescent amber lamp.
  static const primary = Color(0xFFE8A87C);
  static const primaryContainer = Color(0xFFE8A87C);
  static const primarySoft = Color(0xFFFFC69F);
  static const onPrimary = Color(0xFF4E2604);
  static const onPrimaryContainer = Color(0xFF693C19);

  /// Dusty mauve accents.
  static const secondary = Color(0xFFF1B7C9);
  static const secondaryContainer = Color(0xFF653A49);
  static const secondaryEdge = Color(0xFF8A5A6A);

  static const tertiary = Color(0xFFD4A373);
  static const outline = Color(0xFF51443C);
  static const outlineSubtle = Color(0x12EAE6DF);
  static const outlineWarm = Color(0xFF51443C);

  static const lanternGlow = Color(0x38E8A87C);
  static const paperShadow = Color(0xA6070A12);
}

abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

ThemeData buildBedtimeTheme() {
  const serif = 'Georgia';
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: serif,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surfaceContainer,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onPrimary,
      tertiary: AppColors.tertiary,
      onSurface: AppColors.onSurface,
      outline: AppColors.outline,
      error: Color(0xFFFFB4AB),
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: const TextStyle(
        fontFamily: serif,
        fontSize: 30,
        fontWeight: FontWeight.w500,
        height: 1.25,
        letterSpacing: -0.3,
        color: AppColors.onSurface,
      ),
      headlineMedium: const TextStyle(
        fontFamily: serif,
        fontSize: 26,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: -0.1,
        color: AppColors.onSurface,
      ),
      titleLarge: const TextStyle(
        fontFamily: serif,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: AppColors.onSurface,
      ),
      titleMedium: const TextStyle(
        fontFamily: serif,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: AppColors.onSurface,
      ),
      bodyLarge: const TextStyle(
        fontFamily: serif,
        fontSize: 16,
        height: 1.6,
        color: AppColors.onSurface,
      ),
      bodyMedium: const TextStyle(
        fontFamily: serif,
        fontSize: 14,
        height: 1.5,
        color: AppColors.onSurfaceMuted,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.4,
        letterSpacing: 0.2,
        color: AppColors.onSurfaceMuted,
      ),
      labelLarge: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: AppColors.onSurface,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: AppColors.onSurfaceMuted,
      ),
      labelSmall: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.onSurfaceMuted,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.onSurface,
      titleTextStyle: TextStyle(
        fontFamily: serif,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.outlineSubtle),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputWell,
      labelStyle: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.onSurfaceDim, fontSize: 14),
      helperStyle: const TextStyle(color: AppColors.onSurfaceDim, fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.outlineSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.outlineSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfacePaperLayered,
      selectedColor: AppColors.primary,
      disabledColor: AppColors.surfaceHigh,
      labelStyle: const TextStyle(color: AppColors.onSurface, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: AppColors.onPrimary, fontSize: 13),
      side: const BorderSide(color: Color(0x40C38D9E)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      showCheckmark: false,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return AppColors.onSurface;
        return AppColors.onSurfaceMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return AppColors.primary;
        return AppColors.surfaceHighest;
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return AppColors.primaryContainer;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return AppColors.onPrimaryContainer;
          return AppColors.onSurfaceMuted;
        }),
        side: const WidgetStatePropertyAll(BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.surfaceHighest,
        disabledForegroundColor: AppColors.onSurfaceDim,
        elevation: 0,
        shadowColor: AppColors.lanternGlow,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(
          fontFamily: serif,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.primary.withValues(alpha: 0.22),
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        final selected = s.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: selected ? AppColors.primary : AppColors.onSurfaceDim,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((s) {
        final selected = s.contains(WidgetState.selected);
        return IconThemeData(
          size: 22,
          color: selected ? AppColors.primary : AppColors.onSurfaceDim,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: AppColors.onSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.surfaceHighest,
      thumbColor: AppColors.primarySoft,
      overlayColor: AppColors.lanternGlow,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outlineSubtle, thickness: 1),
  );
}
