import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_suggestion_tile.dart';

/// Placeholder row matching [HomeSearchSuggestionTile]'s geometry, so the
/// list does not jump when real rows arrive.
class HomeSearchSkeletonTile extends StatelessWidget {
  const HomeSearchSkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).extension<AppPalette>()!.muted;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: homeSearchThumbnailSize,
              height: homeSearchThumbnailSize,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(0.7, 14),
                  const SizedBox(height: AppSpacing.sm),
                  bar(0.45, 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
