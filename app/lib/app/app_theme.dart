import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const wineRed = Color(0xFF7A1F2B);
  static const wineAccent = Color(0xFFC24A5C);
  static const _darkBackground = Color(0xFF0E0B0C);
  static const _darkSurface = Color(0xFF171314);

  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    var colorScheme = ColorScheme.fromSeed(
      seedColor: wineRed,
      brightness: brightness,
    );

    if (dark) {
      colorScheme = colorScheme.copyWith(
        primary: wineAccent,
        onPrimary: const Color(0xFFFFF7F8),
        primaryContainer: const Color(0xFF561821),
        onPrimaryContainer: const Color(0xFFFFD9DE),
        surface: _darkSurface,
        surfaceContainerLowest: _darkBackground,
        surfaceContainerLow: const Color(0xFF1B1617),
        surfaceContainer: const Color(0xFF211B1C),
        surfaceContainerHigh: const Color(0xFF2A2224),
        onSurface: const Color(0xFFF7F0F1),
        onSurfaceVariant: const Color(0xFFCDBFC2),
        outline: const Color(0xFF8F797D),
        outlineVariant: const Color(0xFF493B3E),
        error: const Color(0xFFFFB4AB),
      );
    } else {
      colorScheme = colorScheme.copyWith(
        primary: wineRed,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFFFD9DE),
        onPrimaryContainer: const Color(0xFF3F0712),
        surface: const Color(0xFFFFFBFB),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFFAF3F4),
        surfaceContainer: const Color(0xFFF4EDEE),
        surfaceContainerHigh: const Color(0xFFEDE5E7),
        onSurface: const Color(0xFF211A1B),
        onSurfaceVariant: const Color(0xFF5E5053),
        outline: const Color(0xFF79666A),
        outlineVariant: const Color(0xFFDDC2C6),
      );
    }

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // surfaceContainerLowest memberikan latar yang sedikit lebih gelap/terang
      // dari surface, sehingga content panel di atasnya terasa "naik".
      scaffoldBackgroundColor:
          dark ? _darkBackground : colorScheme.surfaceContainerLowest,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
          height: 1.15,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
        bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? _darkSurface : const Color(0xFFFFFBFB),
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: colorScheme.shadow.withAlpha(dark ? 60 : 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
