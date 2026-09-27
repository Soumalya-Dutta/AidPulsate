import 'package:flutter/material.dart';

import '../../screens/login_screen.dart';
import '../../screens/signup_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/countdown_screen.dart';
import '../../screens/active_sos_screen.dart';
import '../../screens/offline_sos_screen.dart';
import '../../screens/resolution_screen.dart';
import '../../admin/admin_dashboard.dart';
import '../../admin/victim_detail_screen.dart';
import 'route_guard.dart';

/// All named routes for AidPulsate in one place.
///
/// Usage in MaterialApp:
///   routes:          AppRouter.staticRoutes,
///   onGenerateRoute: AppRouter.onGenerateRoute,
class AppRouter {
  AppRouter._();

  // ── Route name constants ──────────────────────────────────────────────────
  static const login           = '/login';
  static const signup          = '/signup';
  static const home            = '/home';
  static const countdown       = '/countdown';
  static const activeSOS       = '/sos/active';
  static const offlineSOS      = '/sos/offline';
  static const resolution      = '/resolution';
  static const adminDashboard  = '/admin';
  static const adminVictimDetail = '/admin/victim';

  // ── Static routes (resolved before onGenerateRoute) ──────────────────────
  // Registered here so Flutter web resolves them after a hard refresh, and
  // so iOS named-route pushes to '/home' do not conflict with MaterialApp.home.
  static Map<String, WidgetBuilder> get staticRoutes => {
    login:  (_) => const LoginScreen(),
    signup: (_) => const SignupScreen(),
    home:   (_) => const HomeScreen(),
  };

  // ── Dynamic routes (args + guards) ───────────────────────────────────────
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ── Public ────────────────────────────────────────────────────────────
      case home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );

      // ── Countdown — fade-in transition ────────────────────────────────────
      case countdown:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, __, ___) => const CountdownScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 200),
        );

      // ── Active SOS (online) ───────────────────────────────────────────────
      case activeSOS:
        final args = _args(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ActiveSOSScreen(
            eventId:   args?['eventId']   as String?   ?? '',
            startTime: args?['startTime'] as DateTime? ?? DateTime.now(),
          ),
        );

      // ── Offline SOS (SMS fallback) ────────────────────────────────────────
      case offlineSOS:
        final args = _args(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OfflineSOSScreen(
            eventId:   args?['eventId']   as String?   ?? '',
            startTime: args?['startTime'] as DateTime? ?? DateTime.now(),
          ),
        );

      // ── Resolution summary ────────────────────────────────────────────────
      case resolution:
        final args = _args(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ResolutionScreen(
            startTime:     args?['startTime']     as DateTime? ?? DateTime.now(),
            endTime:       args?['endTime']       as DateTime? ?? DateTime.now(),
            trackedPoints: args?['trackedPoints'] as int?      ?? 0,
            method:        args?['method']        as String?   ?? 'Online',
          ),
        );

      // ── Admin — guarded ───────────────────────────────────────────────────
      case adminDashboard:
        return RouteGuard.adminOnly(
          settings: settings,
          builder: (_) => const AdminDashboard(),
        );

      case adminVictimDetail:
        final args = _args(settings);
        return RouteGuard.adminOnly(
          settings: settings,
          builder: (_) => VictimDetailScreen(
            eventId:     args?['eventId']     as String? ?? '',
            victimName:  args?['victimName']  as String? ?? 'Unknown',
          ),
        );

      // ── Fallback ──────────────────────────────────────────────────────────
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Map<String, dynamic>? _args(RouteSettings s) =>
      s.arguments as Map<String, dynamic>?;
}
