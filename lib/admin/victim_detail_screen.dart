import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';

/// A simulated location ping on the victim's trail.
class _LocationPing {
  _LocationPing({
    required this.lat,
    required this.lng,
    required this.timestamp,
  });
  final double lat;
  final double lng;
  final DateTime timestamp;
}

/// Admin screen: shows the victim's location trail, event metadata,
/// and a timeline of pings. Wires to Supabase Realtime in production.
class VictimDetailScreen extends StatefulWidget {
  const VictimDetailScreen({
    super.key,
    required this.eventId,
    required this.victimName,
  });

  final String eventId;
  final String victimName;

  @override
  State<VictimDetailScreen> createState() => _VictimDetailScreenState();
}

class _VictimDetailScreenState extends State<VictimDetailScreen>
    with SingleTickerProviderStateMixin {
  final List<_LocationPing> _pings = [];
  Timer? _pingTimer;

  // Path animation.
  late AnimationController _pathController;

  @override
  void initState() {
    super.initState();

    _pathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Seed with a few historical pings.
    final rng = math.Random();
    double lat = 40.7128;
    double lng = -74.0060;
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      lat += (rng.nextDouble() - 0.5) * 0.0003;
      lng += (rng.nextDouble() - 0.5) * 0.0003;
      _pings.add(_LocationPing(
        lat: lat,
        lng: lng,
        timestamp: now.subtract(Duration(minutes: i * 5)),
      ));
    }

    // Simulate a new ping every 5 seconds.
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final last = _pings.last;
      final rng2 = math.Random();
      _pings.add(_LocationPing(
        lat: last.lat + (rng2.nextDouble() - 0.5) * 0.0002,
        lng: last.lng + (rng2.nextDouble() - 0.5) * 0.0002,
        timestamp: DateTime.now(),
      ));
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pathController.dispose();
    _pingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lastPing = _pings.isNotEmpty ? _pings.last : null;

    return Scaffold(
      backgroundColor: kColorBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, textTheme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLiveMap(textTheme),
                  const SizedBox(height: 16),
                  _buildStatusCard(textTheme, lastPing),
                  const SizedBox(height: 16),
                  _buildPingTimeline(textTheme),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar(BuildContext context, TextTheme textTheme) {
    return SliverAppBar(
      backgroundColor: kColorSOS,
      foregroundColor: Colors.white,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.victimName,
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            widget.eventId,
            style: textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Chip(
            backgroundColor: Colors.white24,
            label: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            avatar: const Icon(Icons.fiber_manual_record,
                color: Colors.white, size: 8),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // ── Simulated live map ─────────────────────────────────────────────────────
  Widget _buildLiveMap(TextTheme textTheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 260,
        color: const Color(0xFFE8F5E9),
        child: Stack(
          children: [
            // Grid.
            CustomPaint(
              size: const Size(double.infinity, 260),
              painter: _GridPainter(),
            ),
            // Movement path.
            AnimatedBuilder(
              animation: _pathController,
              builder: (_, __) => CustomPaint(
                size: const Size(double.infinity, 260),
                painter: _PathPainter(
                  pings: _pings,
                  pulseValue: _pathController.value,
                ),
              ),
            ),
            // Map label.
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kColorBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined, size: 12, color: kColorInfo),
                    const SizedBox(width: 4),
                    Text(
                      'Live Location Trail',
                      style: textTheme.labelSmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            // Ping count badge.
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kColorSOS.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_pings.length} pings',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status card ────────────────────────────────────────────────────────────
  Widget _buildStatusCard(TextTheme textTheme, _LocationPing? lastPing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: kColorSOS, size: 20),
              const SizedBox(width: 8),
              Text('Last Known Location',
                  style: textTheme.titleLarge?.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          if (lastPing != null) ...[
            _DetailRow(
                label: 'Latitude',
                value: lastPing.lat.toStringAsFixed(6)),
            _DetailRow(
                label: 'Longitude',
                value: lastPing.lng.toStringAsFixed(6)),
            _DetailRow(
                label: 'Last Ping',
                value: _formatTime(lastPing.timestamp)),
            _DetailRow(
                label: 'Total Pings',
                value: '${_pings.length}'),
          ],
        ],
      ),
    );
  }

  // ── Ping timeline ──────────────────────────────────────────────────────────
  Widget _buildPingTimeline(TextTheme textTheme) {
    final reversed = _pings.reversed.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: kColorInfo, size: 20),
              const SizedBox(width: 8),
              Text('Location Timeline',
                  style: textTheme.titleLarge?.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          ...reversed.asMap().entries.map((entry) {
            final i = entry.key;
            final ping = entry.value;
            final isFirst = i == 0;
            final isLast = i == reversed.length - 1;
            return _TimelineItem(
              ping: ping,
              isFirst: isFirst,
              isLast: isLast,
              index: _pings.length - i,
            );
          }),
          if (_pings.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${_pings.length - 10} earlier pings…',
                style: textTheme.labelSmall?.copyWith(color: kColorTextSecondary),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── Custom painters ────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
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

class _PathPainter extends CustomPainter {
  _PathPainter({required this.pings, required this.pulseValue});
  final List<_LocationPing> pings;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (pings.isEmpty) return;

    // Map lat/lng to canvas coordinates (simple linear mapping for demo).
    final latMin = pings.map((p) => p.lat).reduce(math.min) - 0.0005;
    final latMax = pings.map((p) => p.lat).reduce(math.max) + 0.0005;
    final lngMin = pings.map((p) => p.lng).reduce(math.min) - 0.0005;
    final lngMax = pings.map((p) => p.lng).reduce(math.max) + 0.0005;

    Offset toCanvas(double lat, double lng) {
      final x = (lng - lngMin) / (lngMax - lngMin) * size.width;
      // Latitude increases upward, canvas y increases downward.
      final y = (1 - (lat - latMin) / (latMax - latMin)) * size.height;
      return Offset(x, y);
    }

    // Draw path.
    final pathPaint = Paint()
      ..color = kColorSOS.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < pings.length; i++) {
      final pt = toCanvas(pings[i].lat, pings[i].lng);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path, pathPaint);

    // Draw ping dots.
    for (int i = 0; i < pings.length; i++) {
      final pt = toCanvas(pings[i].lat, pings[i].lng);
      canvas.drawCircle(pt, 3, Paint()..color = kColorInfo);
    }

    // Draw live pulse on last point.
    final last = toCanvas(pings.last.lat, pings.last.lng);
    for (int ring = 0; ring < 2; ring++) {
      final t = (pulseValue + ring * 0.5) % 1.0;
      canvas.drawCircle(
        last,
        t * 20,
        Paint()
          ..color = kColorSOS.withValues(alpha: (1 - t) * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(last, 6, Paint()..color = kColorSOS);
    canvas.drawCircle(
        last, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.pulseValue != pulseValue || old.pings.length != pings.length;
}

// ── Small reusable widgets ─────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: kColorTextSecondary, fontSize: 13)),
          Text(value,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: kColorTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  )),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.ping,
    required this.isFirst,
    required this.isLast,
    required this.index,
  });

  final _LocationPing ping;
  final bool isFirst;
  final bool isLast;
  final int index;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline spine.
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: kColorBorder,
                    ),
                  )
                else
                  const SizedBox(height: 8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? kColorSOS : kColorInfo,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: kColorBorder,
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTime(ping.timestamp),
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isFirst ? kColorSOS : kColorTextPrimary,
                    ),
                  ),
                  Text(
                    '#$index  ${ping.lat.toStringAsFixed(5)}, ${ping.lng.toStringAsFixed(5)}',
                    style: textTheme.labelSmall
                        ?.copyWith(color: kColorTextSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
