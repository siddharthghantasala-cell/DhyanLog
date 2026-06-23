import 'package:flutter/material.dart';

import '../models/participant.dart';

/// Distinct color schemes per mode so a glance tells preceptor and abhyasi
/// apart. Preceptor = warm saffron/indigo (leading); abhyasi = calm teal.
class AppTheme {
  static final ThemeData abhyasi = _build(const Color(0xFF00897B)); // teal
  static final ThemeData preceptor = _build(const Color(0xFFF57C00)); // saffron

  /// Pre-login / neutral theme.
  static final ThemeData neutral = _build(const Color(0xFF5E35B1)); // indigo

  static ThemeData forRole(ParticipantRole role) {
    return role.canLead ? preceptor : abhyasi;
  }

  static ThemeData _build(Color seed) {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: true,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
