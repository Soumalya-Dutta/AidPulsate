import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';

/// A high-fidelity, ultra-robust Emergency SOS Button.
///
/// Engineered specifically for high-stress emergency response situations:
/// - Immune to hand tremors and micro-finger slips via a generous 80-pixel displacement threshold.
/// - Participates actively in the gesture arena to prevent parent scroll views from stealing the focus.
/// - Delivers responsive tactile haptic feedback on touch activation and successful countdown transitions.
class EmergencyButton extends StatefulWidget {
  const EmergencyButton({
    super.key,
    this.size = 200,
    this.holdDuration = const Duration(milliseconds: 800),
    this.onActivate,
  });

  /// Diameter of the button in logical pixels.
  final double size;

  /// How long the user must hold before activation fires.
  final Duration holdDuration;

  /// Optional override for activation behavior. Defaults to pushing [AppRoutes.countdown].
  final VoidCallback? onActivate;

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton>
    with TickerProviderStateMixin {
  // Gentle pulse ring animation when idle
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  // Active progress feedback animation while holding
  late AnimationController _holdCtrl;

  bool _isHolding = false;
  Offset? _initialPosition;

  @override
  void initState() {
    super.initState();

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

  void _startHold(Offset globalPosition) {
    if (_isHolding) return;
    setState(() {
      _isHolding = true;
      _initialPosition = globalPosition;
    });
    _pulseCtrl.stop();
    _holdCtrl.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _checkDisplacement(Offset globalPosition) {
    if (!_isHolding || _initialPosition == null) return;
    
    // Calculate Euclidean distance to filter out minor finger tremors/slides
    final distance = math.sqrt(
      math.pow(globalPosition.dx - _initialPosition!.dx, 2) +
      math.pow(globalPosition.dy - _initialPosition!.dy, 2)
    );

    // Cancel hold only if finger leaves the safe button vicinity (> 80 logical pixels)
    if (distance > 80.0) {
      _cancelHold();
    }
  }

  void _cancelHold() {
    if (!_isHolding) return;
    setState(() {
      _isHolding = false;
      _initialPosition = null;
    });
    _holdCtrl.reset();
    _pulseCtrl.repeat(reverse: true);
    HapticFeedback.lightImpact();
  }

  void _activate() {
    if (!mounted) return;
    setState(() {
      _isHolding = false;
      _initialPosition = null;
    });
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
      label: 'Emergency SOS button. Press and hold down completely to activate assistance.',
      button: true,
      child: GestureDetector(
        // Absorb pan/drag events so parent widgets like ScrollViews cannot steal the touch gesture
        behavior: HitTestBehavior.opaque,
        onPanDown: (details) => _startHold(details.globalPosition),
        onPanUpdate: (details) => _checkDisplacement(details.globalPosition),
        onPanEnd: (_) => _cancelHold(),
        onPanCancel: () => _cancelHold(),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ambient pulsing ring (visible when idle)
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
                        color: kColorSOS.withOpacity(_pulseOpacity.value),
                      ),
                    ),
                  ),
                ),

              // Solid high-visibility progress bar ring (visible while holding)
              if (_isHolding)
                AnimatedBuilder(
                  animation: _holdCtrl,
                  builder: (_, __) => SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      value: _holdCtrl.value,
                      strokeWidth: 6,
                      backgroundColor: Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(kColorSOS),
                    ),
                  ),
                ),

              // Core action trigger surface
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: _isHolding ? size * 0.92 : size * 0.86,
                height: _isHolding ? size * 0.92 : size * 0.86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHolding ? kColorSOS.withOpacity(0.9) : kColorSOS,
                  boxShadow: [
                    BoxShadow(
                      color: kColorSOS.withOpacity(_isHolding ? 0.55 : 0.35),
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
                      size: size * 0.24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isHolding ? 'HOLDING…' : 'EMERGENCY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.075,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isHolding ? 'Keep holding down' : 'Hold to activate',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: size * 0.05,
                        fontWeight: FontWeight.w500,
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
