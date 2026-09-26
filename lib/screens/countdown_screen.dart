import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../services/sos_service.dart';
import '../services/connectivity_service.dart';

/// Full-screen modal countdown (5 → 0) that sits between the long-press and
/// the Active SOS screen. Cancelling here is always safe and immediate.
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

  // Scale animation for the number pop.
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

    final startTime = DateTime.now();
    String eventId;

    try {
      eventId = await SOSService.instance.createEvent();
    } catch (_) {
      // If Supabase insert fails (e.g. offline), generate a local ID.
      eventId = 'AP-${DateTime.now().millisecondsSinceEpoch % 100000}-X';
    }

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
      // Back gesture also counts as cancel.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.88),
        body: SafeArea(
          child: Column(
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
        Text(
          'SOS ACTIVATING...',
          style: textTheme.headlineMedium?.copyWith(
            color: kColorSOS,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Release to cancel',
          style: textTheme.bodyLarge?.copyWith(
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Semantics(
        label: 'Cancel SOS activation',
        button: true,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _cancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white24,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.white30),
              ),
              elevation: 0,
            ),
            child: Text(
              'CANCEL',
              style: textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
