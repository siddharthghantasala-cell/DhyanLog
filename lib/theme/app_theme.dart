import 'package:flutter/material.dart';

import '../models/participant.dart';
import 'tokens.dart';

/// Distinct color schemes per mode so a glance tells preceptor and abhyasi
/// apart. Preceptor = warm saffron (leading); abhyasi = calm teal; neutral =
/// indigo (pre-login). Each is generated for both light and dark brightness.
class AppTheme {
  static const Color abhyasiSeed = Color(0xFF00897B); // teal
  static const Color preceptorSeed = Color(0xFFF57C00); // saffron
  static const Color neutralSeed = Color(0xFF5E35B1); // indigo

  /// Seed colour for a role (so light + dark can be built from one source).
  static Color seedForRole(ParticipantRole role) =>
      role.canLead ? preceptorSeed : abhyasiSeed;

  static ThemeData light(Color seed) => _build(seed, Brightness.light);
  static ThemeData dark(Color seed) => _build(seed, Brightness.dark);

  // Convenience light themes (kept for existing call sites / tests).
  static ThemeData get neutral => light(neutralSeed);
  static ThemeData forRole(ParticipantRole role) => light(seedForRole(role));

  static ThemeData _build(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
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
          minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
