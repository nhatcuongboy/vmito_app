import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Loading placeholder matching the image-first layout of a club browse card.
class ClubBrowseCardSkeleton extends StatelessWidget {
  const ClubBrowseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Semantics(
      container: true,
      label: AppLocalizations.of(context).commonLoading,
      child: Shimmer.fromColors(
        baseColor: palette.muted,
        highlightColor: theme.colorScheme.surface,
        child: const Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 145,
                    child: ColoredBox(color: Colors.white),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _ClubSkeletonBox(
                      key: Key('club-skeleton-favorite'),
                      width: 36,
                      height: 36,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ClubSkeletonBox(
                      key: Key('club-skeleton-logo'),
                      width: 52,
                      height: 52,
                      radius: 26,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ClubSkeletonBox(width: 168, height: 18),
                          SizedBox(height: 8),
                          _ClubSkeletonBox(width: 184, height: 12),
                          SizedBox(height: 6),
                          _ClubSkeletonBox(width: 144, height: 12),
                        ],
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

class _ClubSkeletonBox extends StatelessWidget {
  const _ClubSkeletonBox({
    this.width = double.infinity,
    required this.height,
    this.radius = 999,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: SizedBox(width: width, height: height),
  );
}
