import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import 'location_service.dart';
import 'connectivity_service.dart';

/// Handles the full SOS lifecycle against Supabase.
class SOSService {
  SOSService._();
  static final SOSService instance = SOSService._();

  SupabaseClient get _db => SupabaseService.instance.client;

  String? _activeEventId;
  String? _activeRefId;
  int _seq = 0;
  StreamSubscription<Position>? _locationSub;
  DateTime? _lastPingTime;

  String? get activeEventId => _activeEventId;
  String? get activeRefId   => _activeRefId;
  bool   get hasActiveEvent => _activeEventId != null;

  Future<String> createEvent() async {
    // Use getUser() — async round-trip to Supabase Auth — to guarantee
    // we have a valid, non-stale session. currentUser can be null for a
    // brief window after hot-restart even when a session exists on disk.
    final userResponse = await _db.auth.getUser();
    final uid = userResponse.user?.id;

    if (uid == null || uid.isEmpty) {
      debugPrint('❌ [SOS] Create failed: No authenticated user found.');
      throw StateError('Not signed in. Please log in and try again.');
    }

    debugPrint('✅ [SOS] Authenticated uid: $uid');

    await LocationService.instance.init();
    LocationService.instance.startTracking();

    Position? pos;
    try {
      pos = await LocationService.instance.current
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      pos = LocationService.instance.lastPosition;
    }

    final isOnline = ConnectivityService.instance.isOnline;
    debugPrint('[SOS] Attempting Supabase insert. Online: $isOnline');

    try {
      final row = await _db
          .from('sos_events')
          .insert({
            'user_id':      uid,
            'status':       'active',
            'transmission': isOnline ? 'online' : 'sms',
            'initial_lat':  pos?.latitude,
            'initial_lng':  pos?.longitude,
          })
          .select('id, ref_id')
          .single();

      _activeEventId = row['id'] as String;
      _activeRefId   = row['ref_id'] as String? ?? _activeEventId;
      _seq = 0;
      _lastPingTime = null;

      debugPrint('✅ [SOS] Event created: $_activeEventId (ref: $_activeRefId)');

      if (pos != null) await _insertPing(pos);
      _startLocationStreaming();

      return _activeEventId!;
    } catch (e) {
      debugPrint('❌ [SOS] INSERT FAILED: $e');
      rethrow;
    }
  }

  Future<void> resolveEvent({String? note}) async {
    final eventId = _activeEventId;
    if (eventId == null) return;

    _stopLocationStreaming();
    LocationService.instance.stopTracking();

    try {
      await _db.from('sos_events').update({
        'status':          'resolved',
        'resolved_at':     DateTime.now().toIso8601String(),
        'resolution_note': note,
      }).eq('id', eventId);
      debugPrint('✅ [SOS] Event resolved on server.');
    } catch (e) {
      debugPrint('❌ [SOS] Failed to resolve event: $e');
    }

    _activeEventId = null;
    _activeRefId   = null;
    _seq = 0;
  }

  Future<void> _insertPing(Position pos) async {
    final eventId = _activeEventId;
    // Read from the cached auth user — if null skip the ping silently.
    final uid = _db.auth.currentUser?.id;
    if (eventId == null || uid == null || uid.isEmpty) return;

    try {
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
      _lastPingTime = DateTime.now();
      debugPrint('📍 [SOS] Ping #$_seq uploaded.');
    } catch (e) {
      debugPrint('⚠️ [SOS] Ping upload failed: $e');
    }
  }

  void _startLocationStreaming() {
    _locationSub?.cancel();
    _locationSub = LocationService.instance.stream.listen((pos) async {
      final now = DateTime.now();
      if (_lastPingTime == null || now.difference(_lastPingTime!) >= const Duration(seconds: 5)) {
        await _insertPing(pos);
      }
    }, onError: (err) => debugPrint('Error in location stream: $err'));
  }

  void _stopLocationStreaming() {
    _locationSub?.cancel();
    _locationSub = null;
  }
}
