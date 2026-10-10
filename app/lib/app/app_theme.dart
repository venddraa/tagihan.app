import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const wineRed = Color(0xFF7A1F2B);
  static const _darkBackground = Color(0xFF100D0E);
  static const _darkSurface = Color(0xFF181314);

  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    var colorScheme = ColorScheme.fromSeed(
      seedColor: wineRed,
      brightness: brightness,
    );

    if (brightness == Brightness.dark) {
      colorScheme = colorScheme.copyWith(
        primary: wineRed,
        onPrimary: Colors.white,
        primaryContainer: wineRed,
        onPrimaryContainer: Colors.white,
        surface: _darkSurface,
        onSurface: const Color(0xFFF4EEEE),
        onSurfaceVariant: const Color(0xFFC8BDBF),
        outlineVariant: const Color(0xFF403638),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? _darkBackground
          : const Color(0xFFFAF8F8),
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.dark
            ? _darkSurface
            : const Color(0xFFFAF8F8),
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    );
  }
}
