import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three staggered bursts — centre, then bottom-left, then bottom-right —
/// mirroring the `confetti()` sequence in `vmito-fe/PointsCelebration.tsx`.
const _burstDelays = <double>[0, 0.083, 0.146];
const _burstDuration = Duration(milliseconds: 2400);

/// Downward pull in canvas heights per unit of progress squared.
const _gravity = 1.35;

/// Fraction of the run spent fading out.
const _fadeTail = 0.3;

/// A one-shot confetti burst drawn with a `CustomPainter`.
///
/// Hand-rolled rather than pulling in a package: it keeps the particle colours
/// tied to the medal palette and lets the whole thing collapse to nothing under
/// reduced motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    required this.colors,
    this.particleCount = 72,
    this.seed = 7,
    super.key,
  });

  final List<Color> colors;
  final int particleCount;

  /// Fixed by default so the burst is reproducible in tests.
  final int seed;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _burstDuration);
    _particles = _seedParticles();
  }

  List<_Particle> _seedParticles() {
    final random = math.Random(widget.seed);
    return [
      for (var index = 0; index < widget.particleCount; index++)
        _particleFor(index, random),
    ];
  }

  _Particle _particleFor(int index, math.Random random) {
    final burst = index % _burstDelays.length;
    // Burst 0 fires up from the centre; 1 and 2 fire inward from the corners,
    // the same angles canvas-confetti uses (60deg right, 120deg left).
    final (originX, originY, baseAngle) = switch (burst) {
      0 => (0.5, 0.6, 90.0),
      1 => (0.0, 0.72, 60.0),
      _ => (1.0, 0.72, 120.0),
    };
    final angle =
        (baseAngle + (random.nextDouble() - 0.5) * 70) * math.pi / 180;
    final speed = 0.55 + random.nextDouble() * 0.55;
    return _Particle(
      originX: originX + (random.nextDouble() - 0.5) * 0.12,
      originY: originY,
      velocityX: math.cos(angle) * speed,
      velocityY: -math.sin(angle) * speed,
      size: 4 + random.nextDouble() * 6,
      rotation: random.nextDouble() * math.pi,
      spin: (random.nextDouble() - 0.5) * 10,
      color: widget.colors[random.nextInt(widget.colors.length)],
      delay: _burstDelays[burst],
      swayFrequency: 0.6 + random.nextDouble() * 1.4,
      swayAmplitude: (random.nextDouble() - 0.5) * 0.06,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    if (!_controller.isAnimating && _controller.isDismissed) {
      unawaited(_controller.forward());
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _controller.value,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.originX,
    required this.originY,
    required this.velocityX,
    required this.velocityY,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.color,
    required this.delay,
    required this.swayFrequency,
    required this.swayAmplitude,
  });

  final double originX;
  final double originY;
  final double velocityX;
  final double velocityY;
  final double size;
  final double rotation;
  final double spin;
  final Color color;
  final double delay;
  final double swayFrequency;
  final double swayAmplitude;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final particle in particles) {
      final elapsed = progress - particle.delay;
      if (elapsed <= 0) continue;
      final t = (elapsed / (1 - particle.delay)).clamp(0.0, 1.0);
      final opacity = t > 1 - _fadeTail ? (1 - t) / _fadeTail : 1.0;
      if (opacity <= 0) continue;

      final x =
          (particle.originX +
              particle.velocityX * t +
              math.sin(t * 2 * math.pi * particle.swayFrequency) *
                  particle.swayAmplitude) *
          size.width;
      final y =
          (particle.originY + particle.velocityY * t + _gravity * t * t) *
          size.height;
      if (y > size.height + particle.size) continue;

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(particle.rotation + particle.spin * t);
      paint.color = particle.color.withValues(alpha: opacity);
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size,
              height: particle.size * 0.6,
            ),
            const Radius.circular(1),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.particles != particles;
}
