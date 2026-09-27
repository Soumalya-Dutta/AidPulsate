import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/supabase_service.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';
import '../widgets/emergency_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = ConnectivityService.instance.isOnline;
  bool _gpsActive = LocationService.instance.lastPosition != null;

  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _connectivitySub = ConnectivityService.instance.stream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
    // Check GPS permission state.
    LocationService.instance.init().then((granted) {
      if (mounted) setState(() => _gpsActive = granted);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _onSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kColorSOS,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await SupabaseService.instance.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: kColorBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, textTheme),
            _buildConnectivityRow(context),
            const Spacer(),
            const EmergencyButton(size: 200),
            const Spacer(),
            _buildFooter(textTheme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: kColorSOS,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AidPulsate',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Admin Dashboard',
                icon: const Icon(Icons.admin_panel_settings_outlined),
                color: SupabaseService.instance.isAdmin ? kColorSOS : kColorTextSecondary,
                onPressed: () async {
                  // 🛠️ FIX: Wait for the admin check to complete before navigating
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator(color: kColorSOS)),
                  );
                  
                  await SupabaseService.instance.fetchIsAdmin();
                  
                  if (context.mounted) {
                    Navigator.pop(context); // Remove loader
                    Navigator.pushNamed(context, AppRoutes.adminDashboard);
                  }
                },
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                color: kColorTextSecondary,
                onPressed: () {},
              ),
              IconButton(
                tooltip: 'Sign Out',
                icon: const Icon(Icons.logout),
                color: kColorTextSecondary,
                onPressed: () => _onSignOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectivityRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatusChip(
            dotColor: _isOnline ? kColorSafe : kColorWarning,
            label: _isOnline ? 'Online' : 'Offline',
          ),
          const SizedBox(width: 12),
          _StatusChip(
            dotColor: _gpsActive ? kColorInfo : kColorTextSecondary,
            label: _gpsActive ? 'GPS Active' : 'No GPS',
            icon: Icons.location_on_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        'You are safe. Monitoring is currently inactive.',
        textAlign: TextAlign.center,
        style: textTheme.bodyLarge?.copyWith(color: kColorTextSecondary),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.dotColor,
    required this.label,
    this.icon,
  });

  final Color dotColor;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: dotColor),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: kColorTextPrimary,
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }
}
