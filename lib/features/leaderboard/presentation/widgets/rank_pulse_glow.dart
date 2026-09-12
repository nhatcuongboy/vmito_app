import 'dart:async';

import 'package:flutter/material.dart';

/// A soft looping halo marking the signed-in user's card on the podium.
///
/// Same shape as `core/widgets/court_call_pulse_badge.dart`: one controller on
/// `repeat(reverse: true)` through an ease-in-out curve. Holds a steady halo
/// instead when the platform asks for reduced motion.
class RankPulseGlow extends StatefulWidget {
  const RankPulseGlow({
    required this.color,
    required this.borderRadius,
    required this.child,
    super.key,
  });

  final Color color;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<RankPulseGlow> createState() => _RankPulseGlowState();
}

class _RankPulseGlowState extends State<RankPulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.16 + 0.16 * _pulse.value),
            blurRadius: 8 + 10 * _pulse.value,
            spreadRadius: 1 + _pulse.value,
          ),
        ],
      ),
      child: child,
    ),
    child: widget.child,
  );
}
