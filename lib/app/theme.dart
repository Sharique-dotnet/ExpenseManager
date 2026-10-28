import 'package:flutter/material.dart';

/// Nook design tokens.
abstract final class AppColors {
  static const moss = Color(0xFF2E6B4E);
  static const mossDark = Color(0xFF1F4D37);
  static const mint = Color(0xFFDCEBDD);
  static const coral = Color(0xFFF26B4D);

  /// Coral darkened for small error text (≥ 4.5:1 contrast on light surfaces).
  static const coralText = Color(0xFFB4381F);
  static const sun = Color(0xFFF5C451);
  static const ink = Color(0xFF15181E);
  static const background = Color(0xFFF7F5EF);
  static const white = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF777873);
  static const border = Color(0xFFE6E3DC);
}

/// 4 · 8 · 12 · 16 · 24 spacing scale.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const page = 20.0;
}

abstract final class Radii {
  static const card = 16.0;
  static const button = 14.0;
  static const input = 12.0;
  static const chip = 24.0;
}

const _textTheme = TextTheme(
  // Display 34 / 800
  displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.1),
  // Daily total 30 / 800
  headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1),
  // Screen title 28 / 800
  headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.15),
  // Section heading 18 / 700
  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2),
  // Title / amount 17 / 700
  titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2),
  // Body 16 / 500 and 15 / 500
  bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
  // Caption 13 / 500
  bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
  // Button 16 / 600
  labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
);

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.moss,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.mint,
    onPrimaryContainer: AppColors.mossDark,
    secondary: AppColors.mossDark,
    onSecondary: AppColors.white,
    tertiary: AppColors.sun,
    error: AppColors.coral,
    onError: AppColors.white,
    surface: AppColors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
  );
  final roundedInput = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.input),
    borderSide: const BorderSide(color: AppColors.border),
  );
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    textTheme: _textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
      border: roundedInput,
      enabledBorder: roundedInput,
      focusedBorder: roundedInput.copyWith(borderSide: const BorderSide(color: AppColors.moss, width: 1.6)),
      errorBorder: roundedInput.copyWith(borderSide: const BorderSide(color: AppColors.coral)),
      focusedErrorBorder: roundedInput.copyWith(borderSide: const BorderSide(color: AppColors.coral, width: 1.6)),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: AppColors.moss, fontWeight: FontWeight.w600),
      errorStyle: const TextStyle(color: AppColors.coralText, fontWeight: FontWeight.w500),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.moss,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.moss.withValues(alpha: 0.45),
        disabledForegroundColor: AppColors.white,
        minimumSize: const Size.fromHeight(52),
        shape: buttonShape,
        textStyle: _textTheme.labelLarge,
      ).copyWith(overlayColor: const WidgetStatePropertyAll(AppColors.mossDark)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.moss,
        minimumSize: const Size(48, 48),
        shape: buttonShape,
        textStyle: _textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.white,
        shape: buttonShape,
        textStyle: _textTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.moss,
      foregroundColor: AppColors.white,
      elevation: 2,
      highlightElevation: 4,
      shape: CircleBorder(),
      iconSize: 32,
      sizeConstraints: BoxConstraints.tightFor(width: 64, height: 64),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card + 8))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card + 4)),
      titleTextStyle: _textTheme.titleLarge!.copyWith(color: AppColors.ink),
      contentTextStyle: _textTheme.bodyMedium!.copyWith(color: AppColors.textSecondary),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.moss,
      headerForegroundColor: AppColors.white,
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.white,
      dialBackgroundColor: AppColors.mint,
      hourMinuteColor: AppColors.mint,
      hourMinuteTextColor: AppColors.mossDark,
      dayPeriodColor: AppColors.mint,
      dayPeriodTextColor: AppColors.mossDark,
      dayPeriodBorderSide: BorderSide(color: AppColors.border),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.input)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: _textTheme.bodyMedium!.copyWith(color: AppColors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.input)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.moss),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
  );
}
