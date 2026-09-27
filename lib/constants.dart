import 'package:flutter/material.dart';

import 'core/router/app_router.dart';

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

// ── Admin palette (Dark Mode) ──────────────────────────────────────────────
const kColorAdminBackground = Color(0xFF121212);
const kColorAdminSurface = Color(0xFF1E1E1E);
const kColorAdminBorder = Color(0xFF2C2C2C);
const kColorAcknowledged = Color(0xFFF57C00);

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
  static const login             = AppRouter.login;
  static const signup            = AppRouter.signup;
  static const home              = AppRouter.home;
  static const countdown         = AppRouter.countdown;
  static const activeSOS         = AppRouter.activeSOS;
  static const offlineSOS        = AppRouter.offlineSOS;
  static const resolution        = AppRouter.resolution;
  static const adminDashboard    = AppRouter.adminDashboard;
  static const adminVictimDetail = AppRouter.adminVictimDetail;
}
