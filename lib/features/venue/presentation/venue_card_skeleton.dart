import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Loading placeholder matching the image-first venue-card layout.
class VenueCardSkeleton extends StatelessWidget {
  const VenueCardSkeleton({super.key});

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
                    height: 144,
                    child: ColoredBox(color: Colors.white),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _VenueSkeletonBox(
                      key: Key('venue-skeleton-favorite'),
                      width: 36,
                      height: 36,
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _VenueSkeletonBox(width: 62, height: 24, radius: 14),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _VenueSkeletonBox(
                      key: Key('venue-skeleton-logo'),
                      width: 50,
                      height: 50,
                      radius: 25,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _VenueSkeletonBox(width: 156, height: 18),
                          SizedBox(height: 8),
                          _VenueSkeletonBox(width: 196, height: 12),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _VenueSkeletonBox(height: 12),
                              ),
                              SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _VenueSkeletonBox(height: 12),
                              ),
                            ],
                          ),
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

class _VenueSkeletonBox extends StatelessWidget {
  const _VenueSkeletonBox({
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
