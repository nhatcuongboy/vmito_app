import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

@Preview(
  name: 'Tournament browse card loading · Light',
  group: 'Tournaments',
  size: Size(390, 320),
)
Widget tournamentBrowseCardSkeletonLightPreview() => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: TournamentBrowseCardSkeleton(),
    ),
  ),
);

@Preview(
  name: 'Tournament browse card loading · Dark',
  group: 'Tournaments',
  size: Size(390, 320),
)
Widget tournamentBrowseCardSkeletonDarkPreview() => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: TournamentBrowseCardSkeleton(),
    ),
  ),
);

/// Loading placeholder matching the tournament browse-card layout.
///
/// The [Card] chrome (border + surface) stays static; only the cover block and
/// the content bars pulse, so the card reads as a settled frame with loading
/// content rather than one flashing slab.
class TournamentBrowseCardSkeleton extends StatelessWidget {
  const TournamentBrowseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    clipBehavior: Clip.antiAlias,
    child: AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 140,
                child: AppSkeletonBox(radius: 0),
              ),
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: AppSkeletonBox(
                  key: Key('tournament-skeleton-status'),
                  width: 76,
                  height: 24,
                  radius: AppRadius.pill,
                ),
              ),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: AppSkeletonBox(
                  key: Key('tournament-skeleton-favorite'),
                  width: 36,
                  height: 36,
                  radius: AppRadius.pill,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 210, height: 17),
                SizedBox(height: AppSpacing.xs),
                AppSkeletonBox(width: 150, height: 17),
                SizedBox(height: AppSpacing.sm),
                _MetadataLine(width: 180),
                SizedBox(height: AppSpacing.xs),
                _MetadataLine(width: 150),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Leading icon dot + text bar, mirroring the real card's `_MetadataLine`.
class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const AppSkeletonBox(width: 18, height: 18),
      const SizedBox(width: AppSpacing.xs),
      AppSkeletonBox(width: width, height: 12),
    ],
  );
}
