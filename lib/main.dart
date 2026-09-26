import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/countdown_screen.dart';
import 'screens/active_sos_screen.dart';
import 'screens/offline_sos_screen.dart';
import 'screens/resolution_screen.dart';
import 'admin/admin_dashboard.dart';
import 'admin/victim_detail_screen.dart';
import 'services/supabase_service.dart';
import 'services/location_service.dart';
import 'services/connectivity_service.dart';

// ── Environment variables (loaded from .env via --dart-define-from-file) ──
// Run the app with:
//   flutter run --dart-define-from-file=.env
// Build with:
//   flutter build apk --dart-define-from-file=.env
//
// Values come from .env at the project root (never committed to git).
// See .env.example for the required keys.
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);
// ──────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait – SOS apps should not rotate unexpectedly.
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

  // Check credentials before attempting to initialize.
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const _MissingEnvApp());
    return;
  }

  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
    );
  } catch (e) {
    runApp(_InitErrorApp(error: e.toString()));
    return;
  }

  // Start connectivity monitoring and request location permission.
  await ConnectivityService.instance.init();
  await LocationService.instance.init();

  runApp(const AidPulsateApp());
}

// ── Shown when --dart-define-from-file=.env was not passed ────────────────
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
                  'Copy .env.example → .env and fill in your Supabase URL and anon key.',
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

// ── Shown when Supabase.initialize throws ─────────────────────────────────
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
                  'Check that SUPABASE_URL in your .env is the bare project URL '
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

class AidPulsateApp extends StatefulWidget {
  const AidPulsateApp({super.key});

  @override
  State<AidPulsateApp> createState() => _AidPulsateAppState();
}

class _AidPulsateAppState extends State<AidPulsateApp> {
  // Determine the correct first screen based on an existing session.
  // If the user was already logged in, Supabase restores the session on init.
  String get _initialRoute {
    final session = SupabaseService.instance.auth.currentSession;
    return session != null ? AppRoutes.home : AppRoutes.login;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AidPulsate',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: _initialRoute,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case AppRoutes.signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());

      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case AppRoutes.countdown:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, __, ___) => const CountdownScreen(),
          // Fade-in so the overlay feels intentional.
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 200),
        );

      case AppRoutes.activeSOS:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ActiveSOSScreen(
            eventId: args?['eventId'] as String? ?? '',
            startTime: args?['startTime'] as DateTime? ?? DateTime.now(),
          ),
        );

      case AppRoutes.offlineSOS:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => OfflineSOSScreen(
            eventId: args?['eventId'] as String? ?? '',
            startTime: args?['startTime'] as DateTime? ?? DateTime.now(),
          ),
        );

      case AppRoutes.resolution:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ResolutionScreen(
            startTime: args?['startTime'] as DateTime? ?? DateTime.now(),
            endTime: args?['endTime'] as DateTime? ?? DateTime.now(),
            trackedPoints: args?['trackedPoints'] as int? ?? 0,
            method: args?['method'] as String? ?? 'Online',
          ),
        );

      case AppRoutes.adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboard());

      case AppRoutes.adminVictimDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => VictimDetailScreen(
            eventId: args?['eventId'] as String? ?? '',
            victimName: args?['victimName'] as String? ?? 'Unknown',
          ),
        );

      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
