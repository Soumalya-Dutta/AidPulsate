import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';

/// Simulated SOS event model – replace with Supabase realtime data.
class _SOSEvent {
  _SOSEvent({
    required this.id,
    required this.victimName,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.isOnline,
  });

  final String id;
  final String victimName;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final bool isOnline;
  bool isResolved = false;
}

/// Admin dashboard: real-time alert list with status chips.
/// In production this subscribes to a Supabase Realtime channel
/// on the `sos_events` table.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final List<_SOSEvent> _events = [];
  Timer? _simulationTimer;
  int _newAlertCount = 0;

  static final _names = [
    'Maria G.',
    'Aisha T.',
    'Lin W.',
    'Priya K.',
    'Fatima H.',
    'Sofia R.',
    'Amara D.',
  ];

  @override
  void initState() {
    super.initState();
    _addSimulatedEvent(); // First event on load.
    // Simulate a new incoming event every 20 seconds.
    _simulationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      _addSimulatedEvent();
    });
  }

  void _addSimulatedEvent() {
    final rng = math.Random();
    final event = _SOSEvent(
      id: 'AP-${(rng.nextInt(90000) + 10000)}-X',
      victimName: _names[rng.nextInt(_names.length)],
      lat: 40.7128 + (rng.nextDouble() - 0.5) * 0.1,
      lng: -74.0060 + (rng.nextDouble() - 0.5) * 0.1,
      timestamp: DateTime.now(),
      isOnline: rng.nextBool(),
    );
    setState(() {
      _events.insert(0, event);
      _newAlertCount++;
    });
    // Auto-dismiss new-alert badge after 4 s.
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _newAlertCount = 0);
    });
  }

  void _resolveEvent(String id) {
    setState(() {
      final idx = _events.indexWhere((e) => e.id == id);
      if (idx != -1) _events[idx].isResolved = true;
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = _events.where((e) => !e.isResolved).toList();
    final resolved = _events.where((e) => e.isResolved).toList();

    return Scaffold(
      backgroundColor: kColorBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, textTheme),
          _buildStatsRow(active.length, resolved.length),
          if (active.isNotEmpty) ...[
            _buildSectionHeader(textTheme, 'Active Alerts', kColorSOS,
                badge: active.length),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _AlertTile(
                  event: active[i],
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.adminVictimDetail,
                    arguments: {
                      'eventId': active[i].id,
                      'victimName': active[i].victimName,
                    },
                  ),
                  onResolve: () => _resolveEvent(active[i].id),
                ),
                childCount: active.length,
              ),
            ),
          ],
          if (resolved.isNotEmpty) ...[
            _buildSectionHeader(textTheme, 'Resolved', kColorSafe),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _AlertTile(
                  event: resolved[i],
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.adminVictimDetail,
                    arguments: {
                      'eventId': resolved[i].id,
                      'victimName': resolved[i].victimName,
                    },
                  ),
                  onResolve: null,
                ),
                childCount: resolved.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
      // Floating "new alert" badge.
      floatingActionButton: _newAlertCount > 0
          ? FloatingActionButton.extended(
              onPressed: null,
              backgroundColor: kColorSOS,
              icon: const Icon(Icons.notifications_active, color: Colors.white),
              label: Text(
                '$_newAlertCount New Alert${_newAlertCount > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, TextTheme textTheme) {
    return SliverAppBar(
      backgroundColor: kColorBackground,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: kColorSOS,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AidPulsate Admin',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: kColorBorder),
      ),
    );
  }

  SliverToBoxAdapter _buildStatsRow(int active, int resolved) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            _StatChip(
              label: 'Active',
              value: '$active',
              color: kColorSOS,
              icon: Icons.sos,
            ),
            const SizedBox(width: 12),
            _StatChip(
              label: 'Resolved',
              value: '$resolved',
              color: kColorSafe,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(width: 12),
            _StatChip(
              label: 'Total',
              value: '${active + resolved}',
              color: kColorInfo,
              icon: Icons.list_alt_outlined,
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(
      TextTheme textTheme, String title, Color color,
      {int? badge}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Alert tile ─────────────────────────────────────────────────────────────
class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.event,
    required this.onTap,
    required this.onResolve,
  });

  final _SOSEvent event;
  final VoidCallback onTap;
  final VoidCallback? onResolve;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isResolved = event.isResolved;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isResolved
                ? kColorSurface
                : kColorSOS.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isResolved ? kColorBorder : kColorSOS.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              // Avatar / status indicator.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isResolved
                      ? kColorSafe.withValues(alpha: 0.12)
                      : kColorSOS.withValues(alpha: 0.12),
                ),
                child: Icon(
                  isResolved ? Icons.check_rounded : Icons.sos,
                  color: isResolved ? kColorSafe : kColorSOS,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Main info.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          event.victimName,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Online / offline chip.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: event.isOnline
                                ? kColorInfo.withValues(alpha: 0.1)
                                : kColorWarning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event.isOnline ? 'Online' : 'SMS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color:
                                  event.isOnline ? kColorInfo : kColorWarning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.id}  ·  ${_timeAgo(event.timestamp)}',
                      style: textTheme.labelSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.lat.toStringAsFixed(4)}, ${event.lng.toStringAsFixed(4)}',
                      style: textTheme.labelSmall?.copyWith(color: kColorInfo),
                    ),
                  ],
                ),
              ),
              // Actions.
              Column(
                children: [
                  IconButton(
                    tooltip: 'View Details',
                    icon: const Icon(Icons.chevron_right),
                    color: kColorTextSecondary,
                    onPressed: onTap,
                  ),
                  if (onResolve != null)
                    IconButton(
                      tooltip: 'Mark Resolved',
                      icon: const Icon(Icons.check_circle_outline),
                      color: kColorSafe,
                      onPressed: onResolve,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat chip ──────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: kColorTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
