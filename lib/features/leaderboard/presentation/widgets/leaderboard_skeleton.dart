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
                Expanded(child: _SkeletonBox(height: 174)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: _SkeletonBox(height: 202)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: _SkeletonBox(height: 174)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (var index = 0; index < 7; index++) ...[
              const _SkeletonBox(height: 76),
              const SizedBox(height: AppSpacing.sm),
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
