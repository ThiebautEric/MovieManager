import 'package:flutter/material.dart';

/// Thèmes clair et sombre (Material 3), accordés à l'identité
/// « The Yellow Frame » : jaune cadre en sombre, or profond en clair.
class AppTheme {
  const AppTheme._();

  /// Jaune signature du logo (mode sombre).
  static const _seedDark = Color(0xFFF2C40F);

  /// Or profond, plus contrasté sur fond clair.
  static const _seedLight = Color(0xFFB8890B);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    var scheme = ColorScheme.fromSeed(
      seedColor:
          brightness == Brightness.dark ? _seedDark : _seedLight,
      brightness: brightness,
    );
    if (brightness == Brightness.dark) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceDim: Colors.black,
        surfaceBright: const Color(0xFF1A1A1A),
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF111111),
        surfaceContainerHigh: const Color(0xFF181818),
        surfaceContainerHighest: const Color(0xFF222222),
      );
    }
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          brightness == Brightness.dark ? Colors.black : null,
      appBarTheme: const AppBarTheme(centerTitle: true),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
