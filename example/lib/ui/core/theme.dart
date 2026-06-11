import 'package:flutter/material.dart';

/// Centralised Material 3 theme for the example app.
class AppTheme {
  const AppTheme._();

  static const seedColor = Color(0xFF1565C0);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seedColor);
    return ThemeData(
      colorScheme: scheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
