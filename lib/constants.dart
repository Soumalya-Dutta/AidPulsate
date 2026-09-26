import 'package:flutter/material.dart';

// ── Colour palette ─────────────────────────────────────────────────────────
const kColorSOS = Color(0xFFD32F2F);
const kColorSafe = Color(0xFF2E7D32);
const kColorWarning = Color(0xFFFBC02D);
const kColorInfo = Color(0xFF1976D2);
const kColorBackground = Color(0xFFFFFFFF);
const kColorSurface = Color(0xFFF8F9FA);
const kColorBorder = Color(0xFFE0E0E0);
const kColorTextPrimary = Color(0xFF121212);
const kColorTextSecondary = Color(0xFF5F6368);

// ── App theme ───────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kColorSOS,
      surface: kColorBackground,
    ),
    scaffoldBackgroundColor: kColorBackground,
    textTheme: const TextTheme(
      // Display Large – countdown numbers
      displayLarge: TextStyle(
        fontSize: 72,
        fontWeight: FontWeight.bold,
        color: kColorTextPrimary,
      ),
      // Headline Medium – SOS status
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: kColorTextPrimary,
      ),
      // Title Large – screen titles
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: kColorTextPrimary,
      ),
      // Body Large – descriptions
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: kColorTextPrimary,
      ),
      // Label Small – metadata
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: kColorTextSecondary,
        letterSpacing: 0.4,
      ),
    ),
  );
}

// ── Named routes ────────────────────────────────────────────────────────────
class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/';
  static const countdown = '/countdown';
  static const activeSOS = '/sos/active';
  static const offlineSOS = '/sos/offline';
  static const resolution = '/resolution';
  static const adminDashboard = '/admin';
  static const adminVictimDetail = '/admin/victim';
}
