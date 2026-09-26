import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import 'location_service.dart';
import 'connectivity_service.dart';

/// Handles the full SOS lifecycle against Supabase.
///
///  createEvent()   → inserts into sos_events, starts GPS tracking
///  resolveEvent()  → updates sos_events.status = 'resolved', stops tracking
///
/// Location pings are inserted automatically every [pingInterval] while
/// the event is active.
class SOSService {
  SOSService._();
  static final SOSService instance = SOSService._();

  static const pingInterval = Duration(seconds: 10);

  SupabaseClient get _db => SupabaseService.instance.client;
  String? get _userId => SupabaseService.instance.currentUser?.id;

  // Active event state.
  String? _activeEventId;
  String? _activeRefId;
  int _seq = 0;
  Timer? _pingTimer;
  StreamSubscription<Position>? _locationSub;

  String? get activeEventId => _activeEventId;
  String? get activeRefId   => _activeRefId;
  bool   get hasActiveEvent => _activeEventId != null;

  // ── Create event ───────────────────────────────────────────────────────────
  /// Inserts a new `sos_events` row and starts sending location pings.
  /// Returns the [eventId] (UUID) from Supabase.
  Future<String> createEvent() async {
    final uid = _userId;
    if (uid == null) throw StateError('No authenticated user');

    // Get initial position (best-effort; may be null if GPS unavailable).
    Position? pos;
    try {
      pos = await LocationService.instance.current
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      pos = LocationService.instance.lastPosition;
    }

    final isOnline = ConnectivityService.instance.isOnline;

    final row = await _db
        .from('sos_events')
        .insert({
          'user_id':       uid,
          'status':        'active',
          'transmission':  isOnline ? 'online' : 'sms',
          'initial_lat':   pos?.latitude,
          'initial_lng':   pos?.longitude,
        })
        .select('id, ref_id')
        .single();

    _activeEventId = row['id'] as String;
    _activeRefId   = row['ref_id'] as String? ?? _activeEventId;
    _seq = 0;

    // Insert the first ping immediately if we have a position.
    if (pos != null) await _insertPing(pos);

    // Start periodic pings.
    _startPingTimer();

    return _activeEventId!;
  }

  // ── Resolve event ──────────────────────────────────────────────────────────
  /// Marks the event as resolved and stops GPS tracking.
  Future<void> resolveEvent({String? note}) async {
    final eventId = _activeEventId;
    if (eventId == null) return;

    _stopPingTimer();

    await _db.from('sos_events').update({
      'status':          'resolved',
      'resolved_at':     DateTime.now().toIso8601String(),
      'resolution_note': note,
    }).eq('id', eventId);

    _activeEventId = null;
    _activeRefId   = null;
    _seq = 0;
  }

  // ── Insert a single ping ───────────────────────────────────────────────────
  Future<void> _insertPing(Position pos) async {
    final eventId = _activeEventId;
    final uid     = _userId;
    if (eventId == null || uid == null) return;

    _seq++;
    await _db.from('location_pings').insert({
      'event_id': eventId,
      'user_id':  uid,
      'lat':      pos.latitude,
      'lng':      pos.longitude,
      'accuracy': pos.accuracy,
      'altitude': pos.altitude,
      'speed':    pos.speed,
      'heading':  pos.heading,
      'source':   'gps',
      'seq':      _seq,
    });
  }

  // ── Periodic ping timer ────────────────────────────────────────────────────
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) async {
      Position? pos;
      try {
        pos = await LocationService.instance.current
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        pos = LocationService.instance.lastPosition;
      }
      if (pos != null) await _insertPing(pos);
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _locationSub?.cancel();
    _locationSub = null;
  }
}
