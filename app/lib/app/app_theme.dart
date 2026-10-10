import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const wineRed = Color(0xFF7A1F2B);

  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: wineRed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF121011)
          : const Color(0xFFFAF8F8),
      appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    );
  }
}
