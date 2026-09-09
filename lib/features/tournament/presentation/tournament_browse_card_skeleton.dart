import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Loading placeholder matching the tournament browse-card layout.
class TournamentBrowseCardSkeleton extends StatelessWidget {
  const TournamentBrowseCardSkeleton({super.key});

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
                    height: 140,
                    child: ColoredBox(color: Colors.white),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _TournamentSkeletonBox(
                      key: Key('tournament-skeleton-status'),
                      width: 76,
                      height: 26,
                      radius: 14,
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _TournamentSkeletonBox(
                      key: Key('tournament-skeleton-favorite'),
                      width: 36,
                      height: 36,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TournamentSkeletonBox(width: 196, height: 18),
                    SizedBox(height: AppSpacing.sm),
                    _TournamentSkeletonBox(width: 164, height: 12),
                    SizedBox(height: AppSpacing.xs),
                    _TournamentSkeletonBox(width: 186, height: 12),
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

class _TournamentSkeletonBox extends StatelessWidget {
  const _TournamentSkeletonBox({
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
