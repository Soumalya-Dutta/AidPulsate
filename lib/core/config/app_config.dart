/// Centralised environment configuration.
///
/// Values are injected at compile time via `--dart-define` or
/// `--dart-define-from-file=.env`.
///
/// Run:   flutter run  --dart-define-from-file=.env
/// Build: flutter build apk --dart-define-from-file=.env
///
/// See .env.example for required keys.
class AppConfig {
  AppConfig._();

  // ── Supabase ──────────────────────────────────────────────────────────────
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rvprpcyjdcgvydesjjee.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_2F36JuSXzS5bfjqQM8i6zg_g2nIhA1r',
  );

  // ── Validation ────────────────────────────────────────────────────────────
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // ── App metadata ──────────────────────────────────────────────────────────
  static const appName = 'AidPulsate';
  static const appVersion = '1.0.0';
}
