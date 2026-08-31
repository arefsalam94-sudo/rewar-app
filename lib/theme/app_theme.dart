import 'package:flutter/material.dart';

/// App-wide Light and Dark themes from the authoritative F design files.
class AppTheme {
  AppTheme._();

  /// Light color scheme, mapped from the token table in `DESIGN light.md`.
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF00624D),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF187C64),
    onPrimaryContainer: Color(0xFFBEFFE8),
    secondary: Color(0xFF516257),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD4E7D8),
    onSecondaryContainer: Color(0xFF57685D),
    tertiary: Color(0xFF3F5774),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF57708D),
    onTertiaryContainer: Color(0xFFEBF2FF),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFF9F9F9),
    onSurface: Color(0xFF1B1B1B),
    onSurfaceVariant: Color(0xFF3E4945),
    surfaceDim: Color(0xFFDADADA),
    surfaceBright: Color(0xFFF9F9F9),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF3F3F3),
    surfaceContainer: Color(0xFFEEEEEE),
    surfaceContainerHigh: Color(0xFFE8E8E8),
    surfaceContainerHighest: Color(0xFFE2E2E2),
    outline: Color(0xFF6E7A74),
    outlineVariant: Color(0xFFBDC9C3),
    inverseSurface: Color(0xFF303030),
    onInverseSurface: Color(0xFFF1F1F1),
    inversePrimary: Color(0xFF7ED7BB),
    surfaceTint: Color(0xFF006B55),
  );

  /// Dark color scheme, mapped from the token table in `DESIGN dark.md`
  /// ("Lush Horizon: Moonlit").
  ///
  /// Currently applied only to the Login screen, via its light/dark toggle —
  /// the app's `MaterialApp` is still locked to `ThemeMode.light`.
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFD0FFDC),
    onPrimary: Color(0xFF00391E),
    primaryContainer: Color(0xFF2AF598),
    onPrimaryContainer: Color(0xFF006C3F),
    secondary: Color(0xFFAACCD4),
    onSecondary: Color(0xFF12353B),
    secondaryContainer: Color(0xFF2A4C52),
    onSecondaryContainer: Color(0xFF99BBC2),
    tertiary: Color(0xFFE3F8F7),
    onTertiary: Color(0xFF213434),
    tertiaryContainer: Color(0xFFC6DBDB),
    onTertiaryContainer: Color(0xFF4E6161),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF101415),
    // Pure white, per `DESIGN dark.md`: "Typography: Pure white or
    // high-purity off-white is used to ensure legibility against the dark,
    // moody backgrounds."
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFFFFFFFF),
    surfaceDim: Color(0xFF101415),
    surfaceBright: Color(0xFF363A3B),
    surfaceContainerLowest: Color(0xFF0B0F10),
    surfaceContainerLow: Color(0xFF191C1E),
    surfaceContainer: Color(0xFF1D2022),
    surfaceContainerHigh: Color(0xFF272A2C),
    surfaceContainerHighest: Color(0xFF323537),
    // `outline` is deliberately WHITE in this design: it was previously a
    // grey-green and got used for helper text, rendering it unreadable.
    // When used for its real purpose — a border or stroke — it must be
    // applied at 10-15% opacity (`AppColors.darkBorderOpacity`). A solid,
    // fully opaque white border is wrong.
    outline: Color(0xFFFFFFFF),
    // Soft dividers between list items, also at low opacity.
    outlineVariant: Color(0xFFD5DDD7),
    inverseSurface: Color(0xFFE0E3E5),
    onInverseSurface: Color(0xFF2D3133),
    inversePrimary: Color(0xFF006D3F),
    surfaceTint: Color(0xFF00E38A),
  );

  /// Dark theme using the font for the given locale.
  static ThemeData darkForLocale(Locale locale) =>
      _buildDark(fontFamilyForCode(locale.languageCode));

  static ThemeData _buildDark(String? fontFamily) => ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: darkColorScheme,
    scaffoldBackgroundColor: darkColorScheme.surface,
  );

  /// Font family per language: English → Corbel, Kurdish → Rudaw,
  /// Arabic → Dubai.
  ///
  /// Rudaw must be present in `assets/fonts/` and registered in
  /// `pubspec.yaml` to render; until then Kurdish falls back to a system font.
  static String? fontFamilyForCode(String code) {
    switch (code) {
      case 'ku':
        return null;
      case 'ar':
        return 'Dubai';
      default:
        return 'Plus Jakarta Sans';
    }
  }

  /// Light theme using the font for the given locale.
  static ThemeData lightForLocale(Locale locale) =>
      _buildLight(fontFamilyForCode(locale.languageCode));

  /// Default light theme (Corbel) — used where no locale is available.
  static ThemeData get light => _buildLight('Plus Jakarta Sans');

  static ThemeData _buildLight(String? fontFamily) => ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: lightColorScheme,
    scaffoldBackgroundColor: lightColorScheme.surface,
  );
}
