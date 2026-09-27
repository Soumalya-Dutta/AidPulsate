/// Centralised environment configuration.
///
/// Values are injected at compile time via `--dart-define-from-file=.env`.
class AppConfig {
  AppConfig._();

  // ── Supabase ──────────────────────────────────────────────────────────────
  // Removed hardcoded URLs to prevent "ghost data" from old projects.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  // ── Validation ────────────────────────────────────────────────────────────
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // ── App metadata ──────────────────────────────────────────────────────────
  static const appName = 'AidPulsate';
  static const appVersion = '1.0.0';
}
