import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

/// Centralised route-level access control.
///
/// Usage inside onGenerateRoute:
///   return RouteGuard.adminOnly(
///     settings: settings,
///     builder: (_) => const AdminDashboard(),
///   );
class RouteGuard {
  RouteGuard._();

  /// Wraps a route builder with an admin check.
  /// Non-admins are redirected to [_AccessDeniedScreen].
  static Route<dynamic> adminOnly({
    required RouteSettings settings,
    required WidgetBuilder builder,
  }) {
    return MaterialPageRoute(
      settings: settings,
      builder: (ctx) => SupabaseService.instance.isAdmin
          ? builder(ctx)
          : const _AccessDeniedScreen(),
    );
  }

  /// Returns true when the current user is authenticated.
  static bool get isAuthenticated =>
      SupabaseService.instance.currentUser != null;

  /// Returns true when the current user is an admin.
  static bool get isAdmin => SupabaseService.instance.isAdmin;
}

// ── Access-denied screen ──────────────────────────────────────────────────
class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFD32F2F),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF121212),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This area is restricted to admins only.\nSign in with an admin account to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF5F6368),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

