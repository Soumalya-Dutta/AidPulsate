import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps [Connectivity] with a broadcast stream and a synchronous getter.
///
/// Usage:
///   ConnectivityService.instance.isOnline   // current state
///   ConnectivityService.instance.stream     // live updates
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  Stream<bool> get stream => _controller.stream;

  // ── Initialise ─────────────────────────────────────────────────────────────
  /// Call once (e.g. in main) to start listening.
  Future<void> init() async {
    // Seed with current state.
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasInternet(result);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasInternet(results);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  bool _hasInternet(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
