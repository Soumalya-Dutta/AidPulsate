import 'package:flutter/material.dart';

import '../constants.dart';

/// Shown after an SOS session ends. Summarises start/end times,
/// tracked data points, and the transmission method.
class ResolutionScreen extends StatefulWidget {
  const ResolutionScreen({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.trackedPoints,
    required this.method,
  });

  final DateTime startTime;
  final DateTime endTime;
  final int trackedPoints;
  final String method;

  @override
  State<ResolutionScreen> createState() => _ResolutionScreenState();
}

class _ResolutionScreenState extends State<ResolutionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    // Slight delay before animating in.
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _checkController.forward();
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Duration get _duration => widget.endTime.difference(widget.startTime);

  String get _durationLabel {
    final mins = _duration.inMinutes;
    final secs = _duration.inSeconds % 60;
    if (mins == 0) return '${secs}s';
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: kColorBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildCheckmark(textTheme),
              const SizedBox(height: 40),
              _buildSummaryCard(textTheme),
              const Spacer(flex: 3),
              _buildReturnButton(context, textTheme),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Animated green check ───────────────────────────────────────────────────
  Widget _buildCheckmark(TextTheme textTheme) {
    return AnimatedBuilder(
      animation: _checkController,
      builder: (_, child) => Opacity(
        opacity: _checkOpacity.value,
        child: Transform.scale(scale: _checkScale.value, child: child),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kColorSafe.withValues(alpha: 0.12),
              border: Border.all(color: kColorSafe, width: 3),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: kColorSafe,
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Emergency Session Ended',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              color: kColorSafe,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are safe. Stay aware of your surroundings.',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(color: kColorTextSecondary),
          ),
        ],
      ),
    );
  }

  // ── Summary card ───────────────────────────────────────────────────────────
  Widget _buildSummaryCard(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  color: kColorInfo, size: 20),
              const SizedBox(width: 8),
              Text(
                'Session Summary',
                style: textTheme.titleLarge?.copyWith(fontSize: 16),
              ),
            ],
          ),
          const Divider(height: 24, color: kColorBorder),
          _SummaryRow(
            icon: Icons.play_arrow_rounded,
            iconColor: kColorSOS,
            label: 'Start Time',
            value: _formatTime(widget.startTime),
          ),
          _SummaryRow(
            icon: Icons.stop_rounded,
            iconColor: kColorSafe,
            label: 'End Time',
            value: _formatTime(widget.endTime),
          ),
          _SummaryRow(
            icon: Icons.timer_outlined,
            iconColor: kColorInfo,
            label: 'Duration',
            value: _durationLabel,
          ),
          _SummaryRow(
            icon: Icons.location_on_outlined,
            iconColor: kColorInfo,
            label: 'Total Tracked Points',
            value: '${widget.trackedPoints}',
          ),
          _SummaryRow(
            icon: widget.method.contains('SMS')
                ? Icons.sms_outlined
                : Icons.cloud_done_outlined,
            iconColor: widget.method.contains('SMS')
                ? kColorWarning
                : kColorSafe,
            label: 'Transmission Method',
            value: widget.method,
          ),
        ],
      ),
    );
  }

  // ── Return home button ─────────────────────────────────────────────────────
  Widget _buildReturnButton(BuildContext context, TextTheme textTheme) {
    return Semantics(
      label: 'Return to home screen',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (_) => false,
          ),
          icon: const Icon(Icons.home_outlined, size: 22),
          label: Text(
            'Return to Home',
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: kColorInfo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }
}

// ── Reusable row ────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: kColorTextSecondary,
                    fontSize: 14,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );
  }
}
