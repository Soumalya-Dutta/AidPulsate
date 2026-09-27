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

  // Portrait-only
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

  // Initialize connectivity asynchronously
  unawaited(ConnectivityService.instance.init());

  runApp(const AidPulsateApp());
}

void unawaited(Future<void> future) {}

// ─────────────────────────────────────────────────────────────────────────────
// Error screens (shown only if Supabase SDK fails to initialize)
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
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'Run the app with:\n\nflutter run --dart-define-from-file=.env',
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
                  'Supabase Init Failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                  child: Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'monospace')),
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

  Future<void> _resolveStartup() async {
    try {
      // 1. Initialise Location
      await LocationService.instance.init().timeout(const Duration(seconds: 3), onTimeout: () => false);

      // 2. Background Connection Check (Diagnostic only, not blocking)
      SupabaseService.instance.testConnection();

      // 3. Resolve Session
      final session = SupabaseService.instance.auth.currentSession;
      if (session != null) {
        await SupabaseService.instance.fetchIsAdmin().timeout(const Duration(seconds: 3), onTimeout: () {});
        _hasSession = true;
      }
    } catch (e) {
      debugPrint('Startup warning: $e');
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
      home: _SplashGate(ready: _ready, hasSession: _hasSession),
      routes: AppRouter.staticRoutes,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

class _SplashGate extends StatelessWidget {
  const _SplashGate({required this.ready, required this.hasSession});
  final bool ready;
  final bool hasSession;

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(
        backgroundColor: kColorBackground,
        body: Center(child: CircularProgressIndicator(color: kColorSOS)),
      );
    }
    return hasSession ? const HomeScreen() : const LoginScreen();
  }
}
