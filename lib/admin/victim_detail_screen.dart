import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../services/supabase_service.dart';

/// Live location ping pulled directly from the Supabase location_pings table.
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

/// Admin screen: shows the victim's genuine real-time location trail, 
/// event metadata, and a timeline of pings using a Supabase Realtime stream.
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
  late final Stream<List<Map<String, dynamic>>> _pingsStream;

  // Path pulsing pulse value controller
  late AnimationController _pathController;

  @override
  void initState() {
    super.initState();

    _pathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Set up a real-time stream subscription on location_pings table for this specific event
    _pingsStream = SupabaseService.instance.client
        .from('location_pings')
        .stream(primaryKey: ['id'])
        .eq('event_id', widget.eventId)
        .order('seq', ascending: true);
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _pingsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: kColorBackground,
            appBar: AppBar(backgroundColor: kColorSOS, title: const Text('Error Loading')),
            body: Center(child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error stream sync: ${snapshot.error}'),
            )),
          );
        }

        final rawPings = snapshot.data ?? [];
        final List<_LocationPing> pings = rawPings.map((p) {
          final latVal = (p['lat'] as num?)?.toDouble() ?? 0.0;
          final lngVal = (p['lng'] as num?)?.toDouble() ?? 0.0;
          DateTime time;
          try {
            time = DateTime.parse(p['created_at'] as String);
          } catch (_) {
            time = DateTime.now();
          }
          return _LocationPing(lat: latVal, lng: lngVal, timestamp: time);
        }).toList();

        final lastPing = pings.isNotEmpty ? pings.last : null;

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
                      _buildLiveMap(textTheme, pings),
                      const SizedBox(height: 16),
                      _buildStatusCard(textTheme, lastPing, pings.length),
                      const SizedBox(height: 16),
                      _buildPingTimeline(textTheme, pings),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  // ── Live map ───────────────────────────────────────────────────────────────
  Widget _buildLiveMap(TextTheme textTheme, List<_LocationPing> pings) {
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
            if (pings.isNotEmpty)
              AnimatedBuilder(
                animation: _pathController,
                builder: (_, __) => CustomPaint(
                  size: const Size(double.infinity, 260),
                  painter: _PathPainter(
                    pings: pings,
                    pulseValue: _pathController.value,
                  ),
                ),
              )
            else
              const Center(
                child: Text(
                  'No geographic coordinates broad-casted yet.',
                  style: TextStyle(color: kColorTextSecondary, fontWeight: FontWeight.w500),
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
                  color: Colors.white.withOpacity(0.9),
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
                  color: kColorSOS.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${pings.length} pings',
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
  Widget _buildStatusCard(TextTheme textTheme, _LocationPing? lastPing, int totalPings) {
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
                label: 'Last Ping Recv',
                value: _formatTime(lastPing.timestamp)),
            _DetailRow(
                label: 'Total Real Pings',
                value: '$totalPings'),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Waiting for incoming GPS streaming broadcast payload...', style: TextStyle(color: kColorTextSecondary, fontSize: 13)),
            )
          ],
        ],
      ),
    );
  }

  // ── Ping timeline ──────────────────────────────────────────────────────────
  Widget _buildPingTimeline(TextTheme textTheme, List<_LocationPing> pings) {
    final reversed = pings.reversed.take(10).toList();

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
              Text('Location Timeline (Latest 10)',
                  style: textTheme.titleLarge?.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          if (pings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Timeline empty.', style: TextStyle(color: kColorTextSecondary)),
            ),
          ...reversed.asMap().entries.map((entry) {
            final i = entry.key;
            final ping = entry.value;
            final isFirst = i == 0;
            final isLast = i == reversed.length - 1;
            return _TimelineItem(
              ping: ping,
              isFirst: isFirst,
              isLast: isLast,
              index: pings.length - i,
            );
          }),
          if (pings.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${pings.length - 10} earlier pings stored in Supabase…',
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

    // Map lat/lng to canvas coordinates
    final latMin = pings.map((p) => p.lat).reduce(math.min) - 0.0005;
    final latMax = pings.map((p) => p.lat).reduce(math.max) + 0.0005;
    final lngMin = pings.map((p) => p.lng).reduce(math.min) - 0.0005;
    final lngMax = pings.map((p) => p.lng).reduce(math.max) + 0.0005;

    final double latDiff = (latMax - latMin) == 0 ? 0.001 : (latMax - latMin);
    final double lngDiff = (lngMax - lngMin) == 0 ? 0.001 : (lngMax - lngMin);

    Offset toCanvas(double lat, double lng) {
      final x = (lng - lngMin) / lngDiff * size.width;
      final y = (1 - (lat - latMin) / latDiff) * size.height;
      return Offset(x, y);
    }

    // Draw path.
    final pathPaint = Paint()
      ..color = kColorSOS.withOpacity(0.5)
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
          ..color = kColorSOS.withOpacity((1 - t) * 0.5)
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
