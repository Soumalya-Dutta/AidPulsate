import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/supabase_service.dart';

/// Admin dashboard: real-time alert list with status chips.
/// Subscribes live to the Supabase Realtime channel on the `sos_events` table.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Stream<List<Map<String, dynamic>>> _sosStream;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _sosStream = SupabaseService.instance.client
        .from('sos_events')
        .stream(primaryKey: ['id'])
        .order('started_at', ascending: false);
  }

  void _handleRefresh() {
    setState(() {
      _refreshKey++;
      _initStream();
    });
  }

  Future<void> _resolveEvent(String id) async {
    try {
      await SupabaseService.instance.client
          .from('sos_events')
          .update({
            'status': 'resolved',
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: kColorBackground,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_refreshKey),
        stream: _sosStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                  ),
                  ElevatedButton(onPressed: _handleRefresh, child: const Text('Retry')),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kColorSOS));
          }

          final events = snapshot.data!;
          final active = events.where((e) => e['status'] == 'active').toList();
          final resolved = events.where((e) => e['status'] == 'resolved').toList();

          return CustomScrollView(
            slivers: [
              _buildAppBar(context, textTheme),
              _buildStatsRow(active.length, resolved.length),
              
              if (active.isEmpty && resolved.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No events found', style: TextStyle(color: kColorTextSecondary))),
                ),

              if (active.isNotEmpty) ...[
                _buildSectionHeader(textTheme, 'Active Alerts', kColorSOS, badge: active.length),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _AlertTile(
                      eventData: active[i],
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminVictimDetail,
                        arguments: {
                          'eventId': active[i]['id'],
                          'victimName': (active[i]['ref_id'] as String?) ?? 'Anonymous',
                        },
                      ),
                      onResolve: () => _resolveEvent(active[i]['id']),
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
                      eventData: resolved[i],
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminVictimDetail,
                        arguments: {
                          'eventId': resolved[i]['id'],
                          'victimName': (resolved[i]['ref_id'] as String?) ?? 'Anonymous',
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
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, TextTheme textTheme) {
    final canPop = Navigator.canPop(context);
    return SliverAppBar(
      backgroundColor: kColorBackground,
      elevation: 0,
      pinned: true,
      titleSpacing: 0,
      leading: canPop
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))
          : const Center(
              child: Icon(Icons.circle, color: kColorSOS, size: 10),
            ),
      title: Text(
        'Admin Panel',
        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _handleRefresh),
        IconButton(
          tooltip: 'SOS Mode',
          icon: const Icon(Icons.sos_outlined),
          color: kColorSOS,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.home),
        ),
        IconButton(
          tooltip: 'Logout',
          icon: const Icon(Icons.logout),
          onPressed: () => _onSignOut(context),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: kColorBorder),
      ),
    );
  }

  Future<void> _onSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kColorSOS, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await SupabaseService.instance.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      }
    }
  }

  SliverToBoxAdapter _buildStatsRow(int active, int resolved) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            _StatChip(label: 'Active', value: '$active', color: kColorSOS, icon: Icons.sos),
            const SizedBox(width: 8),
            _StatChip(label: 'Done', value: '$resolved', color: kColorSafe, icon: Icons.check_circle),
            const SizedBox(width: 8),
            _StatChip(label: 'Total', value: '${active + resolved}', color: kColorInfo, icon: Icons.list),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(TextTheme textTheme, String title, Color color, {int? badge}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.eventData, required this.onTap, required this.onResolve});
  final Map<String, dynamic> eventData;
  final VoidCallback onTap;
  final VoidCallback? onResolve;

  String _timeAgo(String? timestampStr) {
    if (timestampStr == null) return 'unknown';
    try {
      final dt = DateTime.parse(timestampStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } catch (_) { return 'now'; }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = eventData['status'] as String? ?? 'active';
    final isResolved = status == 'resolved';
    final isOnline = (eventData['transmission'] as String? ?? 'online') == 'online';
    final refId = (eventData['ref_id'] as String?) ?? (eventData['id'] as String? ?? 'SOS');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isResolved ? kColorSurface : kColorSOS.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isResolved ? kColorBorder : kColorSOS.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(isResolved ? Icons.check_circle : Icons.sos, color: isResolved ? kColorSafe : kColorSOS, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            refId.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TransportBadge(isOnline: isOnline),
                      ],
                    ),
                    Text(_timeAgo(eventData['started_at']), style: textTheme.labelSmall),
                  ],
                ),
              ),
              if (onResolve != null)
                IconButton(icon: const Icon(Icons.check_circle_outline, color: kColorSafe), onPressed: onResolve),
              const Icon(Icons.chevron_right, color: kColorTextSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransportBadge extends StatelessWidget {
  const _TransportBadge({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isOnline ? kColorInfo : kColorWarning).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOnline ? 'Online' : 'SMS',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isOnline ? kColorInfo : kColorWarning),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, maxLines: 1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: kColorTextSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
