import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

class LeaderboardSkeleton extends StatelessWidget {
  const LeaderboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final base = palette.muted;
    final highlight = Theme.of(context).colorScheme.surface;
    return Semantics(
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 30, child: _SkeletonBox(height: 176)),
                SizedBox(width: AppSpacing.sm),
                Expanded(flex: 40, child: _SkeletonBox(height: 216)),
                SizedBox(width: AppSpacing.sm),
                Expanded(flex: 30, child: _SkeletonBox(height: 176)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (var index = 0; index < 8; index++) ...[
              const _SkeletonBox(height: 64),
              const SizedBox(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: SizedBox(height: height),
  );
}
