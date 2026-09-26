import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around the Supabase client.
///
/// All auth calls go through here so screens stay decoupled from the SDK.
/// Replace [supabaseUrl] and [supabaseAnonKey] with your project values from:
///   Supabase Dashboard → Project Settings → API
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  // ── Client accessor ───────────────────────────────────────────────────────
  SupabaseClient get client => Supabase.instance.client;

  GoTrueClient get auth => client.auth;

  /// The currently signed-in user, or null if not authenticated.
  User? get currentUser => auth.currentUser;

  /// Stream that emits [AuthState] events (sign-in, sign-out, token refresh…).
  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  // ── Sign in ───────────────────────────────────────────────────────────────
  /// Signs in with email + password.
  /// Throws [AuthException] on failure (wrong credentials, email not confirmed…).
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return auth.signInWithPassword(email: email, password: password);
  }

  // ── Sign up ───────────────────────────────────────────────────────────────
  /// Registers a new user.
  ///
  /// Stores [fullName] in `user_metadata.full_name` (safe for display only).
  /// Stores [role] in `user_metadata.role` for client-side UI routing.
  ///
  /// ⚠️  SECURITY NOTE: `user_metadata` is user-editable and is NOT safe for
  /// RLS policies.  For server-enforced role checks, use a Supabase Edge
  /// Function or a database trigger to copy the role into `app_metadata`
  /// (service-role only).  See admin_design_spec.md for the full auth plan.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role, // 'victim' | 'admin'
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

  // ── Password reset ────────────────────────────────────────────────────────
  /// Sends a password-reset email.
  /// Supabase delivers the magic link; the user clicks it and is redirected
  /// to your app via the deep-link URL you set in the dashboard under
  /// Authentication → URL Configuration → Redirect URLs.
  Future<void> resetPassword(String email) {
    return auth.resetPasswordForEmail(email);
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> signOut() => auth.signOut();
}
