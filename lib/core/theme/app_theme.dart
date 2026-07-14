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
    final scheme = ColorScheme.fromSeed(
      seedColor:
          brightness == Brightness.dark ? _seedDark : _seedLight,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(centerTitle: true),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
