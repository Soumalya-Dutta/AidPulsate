import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around the Supabase client with foolproof Super-Admin overrides.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;

  User? get currentUser => auth.currentUser;

  /// Authoritative Admin check. 
  /// This getter is the absolute source of truth for the UI and routing.
  bool get isAdmin {
    final user = currentUser;
    if (user == null) {
      debugPrint('🛡️ isAdmin: User is null, returning false');
      return false;
    }

    final email = (user.email ?? '').trim().toLowerCase();
    final uid = user.id.trim().toLowerCase();

    debugPrint('🛡️ isAdmin check for: email="$email", uid="$uid"');

    // --- 1. HARDCODED SUPER-ADMIN BYPASS (FOOLPROOF) ---
    if (email == 'demo1@gmail.com' || 
        email.startsWith('demo1@') ||
        email.contains('admin') ||
        email.contains('responder') ||
        uid == '8b3ca353-48a5-4bf1-a37e-402ea2cfa390') {
      debugPrint('🛡️ isAdmin: Super-Admin Bypass MATCHED');
      return true;
    }

    // --- 2. CACHED DB STATE ---
    if (_isAdmin) {
      debugPrint('🛡️ isAdmin: Cached _isAdmin is true');
      return true;
    }

    // --- 3. METADATA BACKUP ---
    final metaRole = (user.userMetadata?['role'] as String?) ??
                     (user.appMetadata['role'] as String?);
    if (metaRole == 'admin') {
      debugPrint('🛡️ isAdmin: Metadata role is admin');
      return true;
    }

    debugPrint('🛡️ isAdmin: Access Denied (all checks failed)');
    return false;
  }
  
  bool _isAdmin = false;

  /// Diagnostic tool to verify connectivity.
  Future<String?> testConnection() async {
    try {
      await client.from('profiles').select('id').limit(1).maybeSingle();
      debugPrint('✅ Supabase Connection: SUCCESS');
    } catch (e) {
      debugPrint('⚠️ Supabase Connection probe: $e');
    }
    return null; 
  }

  /// Authoritatively fetches the user's role from the database profiles table.
  Future<void> fetchIsAdmin() async {
    final user = currentUser;
    if (user == null) {
      _isAdmin = false;
      return;
    }

    try {
      final response = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      
      if (response != null) {
        final dbRole = (response['role'] as String? ?? '').toLowerCase();
        _isAdmin = (dbRole == 'admin');
        debugPrint('🛡️ fetchIsAdmin: DB Role is "$dbRole"');
      } else {
        debugPrint('🛡️ fetchIsAdmin: No profile row found in DB.');
      }
    } catch (e) {
      debugPrint('🛡️ fetchIsAdmin: DB lookup failed: $e');
    }
  }

  void clearAdminCache() => _isAdmin = false;

  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await auth.signInWithPassword(email: email, password: password);
    try {
      await fetchIsAdmin().timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {}
    return response;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) {
    return auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
      },
    );
  }

  Future<void> resetPassword(String email) {
    return auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    clearAdminCache();
    await auth.signOut();
  }
}
