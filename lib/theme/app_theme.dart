import 'package:flutter/material.dart';

/// Controller global sederhana untuk mengatur Dark / Light Mode
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark);

  bool get isDark => value == ThemeMode.dark;

  void toggleTheme() {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}

final ThemeController appThemeController = ThemeController();

/// Material Design 3 (M3) — Opsi A: Hijau Teal (Seed #1F6F5C)
/// Selaras dengan palet warna projek kuliah (ut-modul-mandiri)
class AppTheme {
  // Palet Gelap (Default M3 Dark Mode)
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF5EDBBB),
    onPrimary: Color(0xFF00382C),
    primaryContainer: Color(0xFF005141),
    onPrimaryContainer: Color(0xFF7DF8D6),
    secondary: Color(0xFFB2CCC2),
    onSecondary: Color(0xFF1E352E),
    secondaryContainer: Color(0xFF344C44),
    onSecondaryContainer: Color(0xFFCEE9DE),
    tertiary: Color(0xFFA9CBE2),
    onTertiary: Color(0xFF0E3446),
    tertiaryContainer: Color(0xFF284B5E),
    onTertiaryContainer: Color(0xFFC5E7FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF191C1B),
    onSurface: Color(0xFFE1E3E0),
    surfaceContainerLowest: Color(0xFF141716),
    surfaceContainerLow: Color(0xFF1D201F),
    surfaceContainer: Color(0xFF232725),
    surfaceContainerHigh: Color(0xFF2D312F),
    surfaceContainerHighest: Color(0xFF3F4945),
    onSurfaceVariant: Color(0xFFBFC9C3),
    outline: Color(0xFF89938E),
    outlineVariant: Color(0xFF3F4945),
  );

  // Palet Terang (M3 Light Mode)
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF006B57),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF7DF8D6),
    onPrimaryContainer: Color(0xFF002019),
    secondary: Color(0xFF4B635B),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFCDE9DE),
    onSecondaryContainer: Color(0xFF072019),
    tertiary: Color(0xFF416277),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFC5E7FF),
    onTertiaryContainer: Color(0xFF001E2E),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFBFDFA),
    onSurface: Color(0xFF191C1B),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF3F7F2),
    surfaceContainer: Color(0xFFEDF1EC),
    surfaceContainerHigh: Color(0xFFE7EBE6),
    surfaceContainerHighest: Color(0xFFDBE5DF),
    onSurfaceVariant: Color(0xFF3F4945),
    outline: Color(0xFF6F7975),
    outlineVariant: Color(0xFFBFC9C3),
  );

  static ThemeData get darkTheme => _buildTheme(darkColorScheme);
  static ThemeData get lightTheme => _buildTheme(lightColorScheme);

  static ThemeData _buildTheme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
