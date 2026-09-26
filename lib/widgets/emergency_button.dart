import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';

/// A large, prominent, always-visible Emergency Button.
///
/// Features:
/// - Persistent red panic button with a pulsing ring animation.
/// - Long-press (default 800 ms) triggers the SOS countdown.
/// - Press-and-hold progress arc shows remaining hold time visually.
/// - Optional [onActivate] callback; if null, navigates to countdown route.
/// - Fully accessible via [Semantics].
///
/// Usage:
/// ```dart
/// EmergencyButton()                    // navigates to AppRoutes.countdown
/// EmergencyButton(onActivate: myFn)    // custom handler
/// EmergencyButton(size: 180)           // custom size
/// ```
class EmergencyButton extends StatefulWidget {
  const EmergencyButton({
    super.key,
    this.size = 200,
    this.holdDuration = const Duration(milliseconds: 800),
    this.onActivate,
  });

  /// Diameter of the button in logical pixels.
  final double size;

  /// How long the user must hold before [onActivate] fires.
  final Duration holdDuration;

  /// Override the action on activation. Defaults to pushing [AppRoutes.countdown].
  final VoidCallback? onActivate;

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton>
    with TickerProviderStateMixin {
  // Outer pulse ring.
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  // Progress arc while holding.
  late AnimationController _holdCtrl;

  bool _isHolding = false;

  @override
  void initState() {
    super.initState();

    // Pulse: slow gentle throb when idle.
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Hold progress arc.
    _holdCtrl = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
    _holdCtrl.addStatusListener(_onHoldStatus);
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _activate();
    }
  }

  void _startHold() {
    setState(() => _isHolding = true);
    _pulseCtrl.stop();
    _holdCtrl.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _cancelHold() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    _holdCtrl.reset();
    _pulseCtrl.repeat(reverse: true);
    HapticFeedback.lightImpact();
  }

  void _activate() {
    if (!mounted) return;
    setState(() => _isHolding = false);
    _holdCtrl.reset();
    _pulseCtrl.repeat(reverse: true);
    HapticFeedback.heavyImpact();

    if (widget.onActivate != null) {
      widget.onActivate!();
    } else {
      Navigator.pushNamed(context, AppRoutes.countdown);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _holdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return Semantics(
      label: 'Emergency SOS button. Hold to activate.',
      button: true,
      child: GestureDetector(
        onTapDown: (_) => _startHold(),
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        onLongPressCancel: _cancelHold,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring (shown when idle).
              if (!_isHolding)
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseScale.value,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kColorSOS.withValues(alpha: _pulseOpacity.value),
                      ),
                    ),
                  ),
                ),

              // Progress arc (shown while holding).
              if (_isHolding)
                AnimatedBuilder(
                  animation: _holdCtrl,
                  builder: (_, __) => SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      value: _holdCtrl.value,
                      strokeWidth: 5,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),

              // Core button circle.
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: _isHolding ? size * 0.92 : size * 0.86,
                height: _isHolding ? size * 0.92 : size * 0.86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHolding
                      ? kColorSOS.withValues(alpha: 0.88)
                      : kColorSOS,
                  boxShadow: [
                    BoxShadow(
                      color: kColorSOS.withValues(
                          alpha: _isHolding ? 0.55 : 0.35),
                      blurRadius: _isHolding ? 36 : 24,
                      spreadRadius: _isHolding ? 10 : 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sos,
                      color: Colors.white,
                      size: size * 0.22,
                    ),
                    SizedBox(height: size * 0.03),
                    Text(
                      _isHolding ? 'HOLD…' : 'EMERGENCY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.07,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                      ),
                    ),
                    SizedBox(height: size * 0.01),
                    Text(
                      _isHolding ? 'Release to cancel' : 'Hold to activate',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: size * 0.055,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
