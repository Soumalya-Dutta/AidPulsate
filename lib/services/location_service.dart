import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Wraps [Geolocator] with permission handling and a broadcast stream.
///
/// Usage:
///   final svc = LocationService.instance;
///   await svc.init();              // request permission
///   svc.stream.listen((pos) { … }); // subscribe to updates
///   final pos = await svc.current; // one-shot
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // Internal broadcast controller so multiple listeners can subscribe.
  final _controller = StreamController<Position>.broadcast();

  StreamSubscription<Position>? _subscription;
  Position? _lastPosition;

  Stream<Position> get stream => _controller.stream;
  Position? get lastPosition => _lastPosition;

  // ── Initialise & request permission ───────────────────────────────────────
  /// Must be called before [stream] or [current].
  /// Returns [true] if location permission was granted.
  Future<bool> init() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  // ── Start continuous updates ───────────────────────────────────────────────
  /// Begins streaming GPS updates and forwarding them to [stream].
  /// Safe to call multiple times — restarts only if not already running.
  void startTracking() {
    if (_subscription != null) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // metres — emit only when moved ≥5 m
    );

    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (pos) {
        _lastPosition = pos;
        _controller.add(pos);
      },
      onError: (e) {
        // Swallow errors; the stream stays alive for the next valid fix.
      },
    );
  }

  // ── Stop continuous updates ────────────────────────────────────────────────
  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
  }

  // ── One-shot current position ──────────────────────────────────────────────
  /// Returns the best available position right now.
  /// Throws if permission is not granted — call [init] first.
  Future<Position> get current => Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

  void dispose() {
    stopTracking();
    _controller.close();
  }
}
