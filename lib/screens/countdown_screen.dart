import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../services/sos_service.dart';
import '../services/connectivity_service.dart';

/// Full-screen modal countdown (5 → 0) that sits between the long-press and
/// the Active SOS screen. 
class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen>
    with SingleTickerProviderStateMixin {
  static const _startCount = 5;

  int _count = _startCount;
  Timer? _timer;
  bool _cancelled = false;
  bool _isSyncing = false;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1.4, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
    _startCountdown();
  }

  void _startCountdown() {
    _scaleController.forward(from: 0);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cancelled || !mounted) {
        timer.cancel();
        return;
      }
      HapticFeedback.lightImpact();
      if (_count <= 1) {
        timer.cancel();
        _triggerSOS();
        return;
      }
      setState(() => _count--);
      _scaleController.forward(from: 0);
    });
  }

  Future<void> _triggerSOS() async {
    if (!mounted || _cancelled) return;

    setState(() => _isSyncing = true);
    final startTime = DateTime.now();
    
    try {
      // Attempt to write to Supabase
      final eventId = await SOSService.instance.createEvent();
      
      if (!mounted || _cancelled) return;

      final isOnline = ConnectivityService.instance.isOnline;
      Navigator.pushReplacementNamed(
        context,
        isOnline ? AppRoutes.activeSOS : AppRoutes.offlineSOS,
        arguments: {
          'eventId': eventId,
          'startTime': startTime,
        },
      );
    } catch (e) {
      debugPrint('❌ [SOS_UI] TRIGGER FAILED: $e');
      if (mounted) {
        setState(() => _isSyncing = false);
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorAdminSurface,
        title: const Text('Emergency Sync Failed', style: TextStyle(color: Colors.white)),
        content: Text(
          'The app could not register your SOS in the cloud database.\n\nError: $error',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Go back to Home
            },
            child: const Text('CANCEL SOS'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kColorSOS),
            onPressed: () {
              Navigator.pop(ctx);
              _triggerSOS(); // Retry
            },
            child: const Text('RETRY SYNC'),
          ),
        ],
      ),
    );
  }

  void _cancel() {
    _cancelled = true;
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_isSyncing,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.9),
        body: SafeArea(
          child: Center(
            child: _isSyncing 
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: kColorSOS),
                    SizedBox(height: 24),
                    Text('SYNCING WITH EMERGENCY CENTER...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ],
                )
              : Column(
                  children: [
                    const Spacer(flex: 2),
                    _buildCounterSection(textTheme),
                    const Spacer(flex: 3),
                    _buildCancelButton(textTheme),
                    const SizedBox(height: 48),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterSection(TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (_, child) =>
              Transform.scale(scale: _scaleAnimation.value, child: child),
          child: Text(
            '$_count',
            style: textTheme.displayLarge?.copyWith(
              fontSize: 120,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'SOS ACTIVATING...',
          style: TextStyle(color: kColorSOS, letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ],
    );
  }

  Widget _buildCancelButton(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _cancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 18)),
        ),
      ),
    );
  }
}
