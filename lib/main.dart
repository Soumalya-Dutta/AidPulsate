import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/supabase_service.dart';
import 'services/location_service.dart';
import 'services/connectivity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only — SOS apps should not rotate unexpectedly.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  if (!AppConfig.isConfigured) {
    runApp(const _MissingEnvApp());
    return;
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    runApp(_InitErrorApp(error: e.toString()));
    return;
  }

  await ConnectivityService.instance.init();
  await LocationService.instance.init();

  runApp(const AidPulsateApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// Error screens (shown before the widget tree is ready)
// ─────────────────────────────────────────────────────────────────────────────

class _MissingEnvApp extends StatelessWidget {
  const _MissingEnvApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFD32F2F),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 64),
                SizedBox(height: 24),
                Text(
                  'Missing Supabase credentials',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Run the app with:\n\n'
                  'flutter run --dart-define-from-file=.env\n\n'
                  'Copy .env.example → .env and fill in your credentials.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InitErrorApp extends StatelessWidget {
  const _InitErrorApp({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFD32F2F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, color: Colors.white, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Failed to connect to Supabase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Check that SUPABASE_URL is the bare project URL '
                  '(no /rest/v1/ suffix) and that SUPABASE_ANON_KEY is correct.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Root app
// ─────────────────────────────────────────────────────────────────────────────

class AidPulsateApp extends StatefulWidget {
  const AidPulsateApp({super.key});

  @override
  State<AidPulsateApp> createState() => _AidPulsateAppState();
}

class _AidPulsateAppState extends State<AidPulsateApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _ready = false;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _resolveStartup();
  }

  /// Restores any existing session and fetches the admin role before
  /// showing the first screen, so there is no role flash on launch.
  Future<void> _resolveStartup() async {
    try {
      final session = SupabaseService.instance.auth.currentSession;
      if (session != null) {
        await SupabaseService.instance.fetchIsAdmin().timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
        _hasSession = true;
      }
    } catch (_) {
      _hasSession = false;
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorKey: _navigatorKey,
      // _SplashGate is the home widget — it shows a spinner then replaces
      // itself with LoginScreen or HomeScreen once the session check is done.
      home: _SplashGate(ready: _ready, hasSession: _hasSession),
      // Explicit routes table: /login, /signup, /home.
      // MaterialApp.home: serves the splash gate on the initial '/' slot.
      // Named /home ≠ '/' so there is no route-conflict on iOS.
      routes: AppRouter.staticRoutes,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash gate — spinner until session resolved, then navigates to first screen
// ─────────────────────────────────────────────────────────────────────────────

class _SplashGate extends StatelessWidget {
  const _SplashGate({required this.ready, required this.hasSession});
  final bool ready;
  final bool hasSession;

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return Scaffold(
        backgroundColor: kColorBackground,
        body: const Center(
          child: CircularProgressIndicator(color: kColorSOS),
        ),
      );
    }
    // Return the real first screen directly — no named-route push needed.
    // All subsequent navigation uses Navigator.pushNamed / pushReplacementNamed
    // which go through AppRouter.onGenerateRoute.
    return hasSession ? const HomeScreen() : const LoginScreen();
  }
}
