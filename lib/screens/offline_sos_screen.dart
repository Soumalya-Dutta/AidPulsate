import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../services/sos_service.dart';

/// Active SOS screen shown when internet is NOT available.
/// Demonstrates that the system is still working via the SMS fallback queue.
class OfflineSOSScreen extends StatefulWidget {
  const OfflineSOSScreen({
    super.key,
    required this.eventId,
    required this.startTime,
  });

  final String eventId;
  final DateTime startTime;

  @override
  State<OfflineSOSScreen> createState() => _OfflineSOSScreenState();
}

class _OfflineSOSScreenState extends State<OfflineSOSScreen>
    with SingleTickerProviderStateMixin {
  int _smsSentCount = 0;
  int _seqNumber = 1;
  String _lastSmsSentLabel = 'Sending first message…';
  String _gatewayStatus = 'Connecting to SMS Gateway';
  bool _isQueuing = true;
  Timer? _smsTimer;

  // Yellow banner blink animation.
  late AnimationController _blinkController;
  late Animation<double> _blinkOpacity;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _blinkOpacity =
        Tween<double>(begin: 0.6, end: 1.0).animate(_blinkController);

    // Simulate SMS being sent every 2 minutes (30s for demo).
    _sendSMSNow();
    _smsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _sendSMSNow();
    });
  }

  void _sendSMSNow() {
    if (!mounted) return;
    setState(() {
      _smsSentCount++;
      _seqNumber++;
      _lastSmsSentLabel = 'Just now';
      _isQueuing = false;
      _gatewayStatus = _smsSentCount == 1
          ? 'Waiting for delivery receipt'
          : 'Delivery confirmed · Awaiting next ping';
    });

    // Update the "x mins ago" label after 60 s.
    Future.delayed(const Duration(seconds: 60), () {
      if (!mounted) return;
      setState(() => _lastSmsSentLabel = '~1 min ago');
    });
    Future.delayed(const Duration(seconds: 120), () {
      if (!mounted) return;
      setState(() => _lastSmsSentLabel = '~2 mins ago');
    });
  }

  Future<void> _onEndSOS() async {
    final confirmed = await _showConfirmationDialog();
    if (!confirmed || !mounted) return;

    HapticFeedback.heavyImpact();

    // Attempt to resolve in Supabase (may still be offline — fire and forget).
    SOSService.instance.resolveEvent().ignore();

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.resolution,
      arguments: {
        'startTime': widget.startTime,
        'endTime': DateTime.now(),
        'trackedPoints': _smsSentCount,
        'method': 'SMS Fallback',
      },
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('End Emergency Session?'),
            content: const Text(
              'This will stop the SMS queue. '
              'Are you sure you are safe?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep Active'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorSafe,
                  foregroundColor: Colors.white,
                ),
                child: const Text('I Am Safe'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _smsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: kColorBackground,
      body: Column(
        children: [
          _buildOfflineHeader(textTheme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConnectivityCard(textTheme),
                  const SizedBox(height: 16),
                  _buildSMSQueueCard(textTheme),
                  const SizedBox(height: 16),
                  _buildPayloadCard(textTheme),
                  const SizedBox(height: 32),
                  _buildEndSOSButton(textTheme),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Yellow offline header ──────────────────────────────────────────────────
  Widget _buildOfflineHeader(TextTheme textTheme) {
    return AnimatedBuilder(
      animation: _blinkOpacity,
      builder: (_, child) => Opacity(opacity: _blinkOpacity.value, child: child),
      child: Container(
        width: double.infinity,
        color: kColorWarning,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          bottom: 16,
          left: 20,
          right: 20,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.black87, size: 22),
            const SizedBox(width: 10),
            Text(
              'SOS ACTIVE (OFFLINE)',
              style: textTheme.headlineMedium?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Connectivity card ──────────────────────────────────────────────────────
  Widget _buildConnectivityCard(TextTheme textTheme) {
    return _InfoCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kColorWarning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.wifi_off, color: kColorWarning, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Internet Unavailable',
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Emergency message queued via SMS Gateway.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: kColorTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SMS queue progress card ────────────────────────────────────────────────
  Widget _buildSMSQueueCard(TextTheme textTheme) {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sms_outlined, color: kColorInfo, size: 20),
              const SizedBox(width: 8),
              Text('SMS Queue Status',
                  style: textTheme.titleLarge?.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          _MetaRow(
            label: 'Last SMS Sent',
            value: _lastSmsSentLabel,
            valueColor: _isQueuing ? kColorWarning : kColorSafe,
          ),
          _MetaRow(
            label: 'Messages Dispatched',
            value: '$_smsSentCount',
          ),
          _MetaRow(
            label: 'Sequence #',
            value: '#$_seqNumber',
          ),
          const SizedBox(height: 12),
          // Status pill.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kColorWarning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kColorWarning),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kColorWarning,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _gatewayStatus,
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Encoded payload preview ────────────────────────────────────────────────
  Widget _buildPayloadCard(TextTheme textTheme) {
    final eventShort = widget.eventId.length > 8
        ? widget.eventId.substring(widget.eventId.length - 8)
        : widget.eventId;
    final ts = (widget.startTime.millisecondsSinceEpoch ~/ 1000).toString();
    // Simulated coordinates (replace with real geolocator values later).
    const lat = '40.712800';
    const lng = '-74.006000';
    final payload = 'AP|$eventShort|$ts|$lat|$lng|$_seqNumber|····';

    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: kColorTextSecondary, size: 18),
              const SizedBox(width: 8),
              Text('Encoded SMS Payload',
                  style: textTheme.titleLarge?.copyWith(
                      fontSize: 16, color: kColorTextSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              payload,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF98C379),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Format: AP | event_id | unix_ts | lat | lng | seq | hmac',
            style: textTheme.labelSmall?.copyWith(color: kColorTextSecondary),
          ),
        ],
      ),
    );
  }

  // ── End SOS button ─────────────────────────────────────────────────────────
  Widget _buildEndSOSButton(TextTheme textTheme) {
    return Semantics(
      label: 'End SOS and mark yourself as safe',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _onEndSOS,
          icon: const Icon(Icons.check_circle_outline, size: 22),
          label: Text(
            'I AM SAFE  /  END SOS',
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: kColorSafe,
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

// ── Reusable widgets ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorBorder),
      ),
      child: child,
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: kColorTextSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: valueColor ?? kColorTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }
}
