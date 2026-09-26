import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../constants.dart';
import '../services/location_service.dart';
import '../services/sos_service.dart';

/// Active SOS screen shown when internet IS available.
/// Shows live location, broadcast status, event reference ID,
/// and the "I Am Safe / End SOS" action.
class ActiveSOSScreen extends StatefulWidget {
  const ActiveSOSScreen({
    super.key,
    required this.eventId,
    required this.startTime,
  });

  final String eventId;
  final DateTime startTime;

  @override
  State<ActiveSOSScreen> createState() => _ActiveSOSScreenState();
}

class _ActiveSOSScreenState extends State<ActiveSOSScreen>
    with TickerProviderStateMixin {
  // Real location from GPS.
  double _lat = 0;
  double _lng = 0;
  bool _hasLocation = false;
  int _trackedPoints = 0;
  String _lastSync = 'Acquiring GPS…';
  StreamSubscription<Position>? _locationSub;

  // Header pulse animation.
  late AnimationController _headerPulse;
  late Animation<double> _headerOpacity;

  // Ripple ping animation.
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();

    // Header flash.
    _headerPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _headerOpacity =
        Tween<double>(begin: 0.7, end: 1.0).animate(_headerPulse);

    // Ripple.
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Subscribe to real GPS updates from LocationService.
    LocationService.instance.startTracking();
    _locationSub = LocationService.instance.stream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _hasLocation = true;
        _trackedPoints++;
        _lastSync = 'Just now';
      });
    });

    // Seed with last known position immediately if available.
    final last = LocationService.instance.lastPosition;
    if (last != null) {
      _lat = last.latitude;
      _lng = last.longitude;
      _hasLocation = true;
    }
  }

  @override
  void dispose() {
    _headerPulse.dispose();
    _rippleController.dispose();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _onEndSOS() async {
    final confirmed = await _showConfirmationDialog();
    if (!confirmed || !mounted) return;

    HapticFeedback.heavyImpact();

    // Resolve the event in Supabase.
    await SOSService.instance.resolveEvent();

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.resolution,
      arguments: {
        'startTime': widget.startTime,
        'endTime': DateTime.now(),
        'trackedPoints': _trackedPoints,
        'method': 'Online',
      },
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('End Emergency Session?'),
            content: const Text(
              'Are you sure you want to end this emergency session? '
              'This will stop location broadcasting and mark the event as resolved.',
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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: kColorBackground,
      body: Column(
        children: [
          _buildSOSHeader(textTheme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLocationCard(textTheme),
                  const SizedBox(height: 16),
                  _buildMetadataCard(textTheme),
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

  // ── Pulsing red header banner ──────────────────────────────────────────────
  Widget _buildSOSHeader(TextTheme textTheme) {
    return AnimatedBuilder(
      animation: _headerOpacity,
      builder: (_, child) => Opacity(
        opacity: _headerOpacity.value,
        child: child,
      ),
      child: Container(
        width: double.infinity,
        color: kColorSOS,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          bottom: 16,
          left: 20,
          right: 20,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sos, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Text(
              'SOS ACTIVE',
              style: textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Location broadcast card ────────────────────────────────────────────────
  Widget _buildLocationCard(TextTheme textTheme) {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: kColorSOS, size: 20),
              const SizedBox(width: 8),
              Text(
                'Broadcasting Live Location',
                style: textTheme.titleLarge?.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Simulated map thumbnail with ripple.
          _buildMapThumbnail(),
          const SizedBox(height: 16),
          _CoordRow(label: 'Lat', value: _hasLocation ? _lat.toStringAsFixed(6) : '—'),
          const SizedBox(height: 4),
          _CoordRow(label: 'Lng', value: _hasLocation ? _lng.toStringAsFixed(6) : '—'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.sync, size: 14, color: kColorSafe),
              const SizedBox(width: 4),
              Text(
                'Last Sync: $_lastSync',
                style: textTheme.labelSmall?.copyWith(color: kColorSafe),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 160,
        color: const Color(0xFFE8F5E9),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Grid lines to suggest a map.
            CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _MapGridPainter(),
            ),
            // Ripple rings.
            AnimatedBuilder(
              animation: _rippleController,
              builder: (_, __) => CustomPaint(
                size: const Size(double.infinity, 160),
                painter: _RipplePainter(_rippleController.value),
              ),
            ),
            // Pin.
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_pin, color: kColorSOS, size: 36),
                SizedBox(height: 2),
                Text(
                  'You',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: kColorSOS,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Event metadata card ────────────────────────────────────────────────────
  Widget _buildMetadataCard(TextTheme textTheme) {
    final duration = DateTime.now().difference(widget.startTime);
    final mins = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: kColorInfo, size: 20),
              const SizedBox(width: 8),
              Text('Event Details', style: textTheme.titleLarge?.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          _MetaRow(label: 'Ref ID', value: widget.eventId),
          _MetaRow(label: 'Elapsed', value: '$mins:$secs'),
          _MetaRow(label: 'Points Tracked', value: '$_trackedPoints'),
          _MetaRow(label: 'Channel', value: 'Online → Supabase'),
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

// ── Custom painters ────────────────────────────────────────────────────────

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC8E6C9)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final radius = t * 60.0;
      final opacity = (1.0 - t) * 0.4;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = kColorSOS.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}

// ── Small reusable widgets ─────────────────────────────────────────────────

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

class _CoordRow extends StatelessWidget {
  const _CoordRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: kColorTextPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;

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
                  color: kColorTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }
}
