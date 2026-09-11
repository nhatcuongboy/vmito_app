import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';

/// The pulsing map-pin badge from `CourtCallModal.tsx`'s `courtCallPulse`
/// keyframe: scale 1 -> 1.04 with an expanding, fading ring shadow, on an
/// 1.8s ease-in-out loop (two 900ms half-cycles here via `repeat(reverse:
/// true)`).
class CourtCallPulseBadge extends StatefulWidget {
  const CourtCallPulseBadge({super.key});

  @override
  State<CourtCallPulseBadge> createState() => _CourtCallPulseBadgeState();
}

class _CourtCallPulseBadgeState extends State<CourtCallPulseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    unawaited(_controller.repeat(reverse: true));
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brandSurface = isDark
        ? const Color(0xFF183028)
        : const Color(0xFFE2F3E8);
    final accent = isDark ? AppColors.brandDark : theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Transform.scale(
          scale: 1 + 0.04 * t,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brandSurface,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.18 * (1 - t),
                  ),
                  spreadRadius: 12 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Icon(AppIcons.mapPin, size: 44, color: accent),
    );
  }
}
