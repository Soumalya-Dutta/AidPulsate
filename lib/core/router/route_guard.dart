import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/supabase_service.dart';

/// Centralised route-level access control.
class RouteGuard {
  RouteGuard._();

  /// Wraps a route builder with an admin check.
  /// Evaluates the admin status dynamically inside the builder to prevent race conditions.
  static Route<dynamic> adminOnly({
    required RouteSettings settings,
    required WidgetBuilder builder,
  }) {
    return MaterialPageRoute(
      settings: settings,
      builder: (ctx) {
        // We evaluate isAdmin HERE, inside the builder, so it's always the latest state.
        final isAdmin = SupabaseService.instance.isAdmin;
        debugPrint('🛡️ RouteGuard: Checking access for ${settings.name}. isAdmin=$isAdmin');
        
        if (isAdmin) {
          return builder(ctx);
        } else {
          return const _AccessDeniedScreen();
        }
      },
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.currentUser;
    final email = user?.email ?? 'Not logged in';
    final uid = user?.id ?? 'No UID';
    final serviceIsAdmin = SupabaseService.instance.isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gpp_maybe_outlined, color: Color(0xFFD32F2F), size: 80),
              const SizedBox(height: 24),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF121212)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your account does not have administrator privileges.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF5F6368)),
              ),
              const SizedBox(height: 40),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SESSION DIAGNOSTICS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const Divider(),
                    _DiagnosticRow(label: 'Email', value: email),
                    _DiagnosticRow(label: 'UID', value: uid),
                    _DiagnosticRow(label: 'Service isAdmin Getter', value: serviceIsAdmin.toString()),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF121212),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Return to Home', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await SupabaseService.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                  }
                },
                child: const Text('Sign Out & Switch Account', style: TextStyle(color: Color(0xFFD32F2F))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
