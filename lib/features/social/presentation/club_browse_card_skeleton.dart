import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

@Preview(
  name: 'Club browse card loading · Light',
  group: 'Clubs',
  size: Size(390, 320),
)
Widget clubBrowseCardSkeletonLightPreview() => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: ClubBrowseCardSkeleton(),
    ),
  ),
);

@Preview(
  name: 'Club browse card loading · Dark',
  group: 'Clubs',
  size: Size(390, 320),
)
Widget clubBrowseCardSkeletonDarkPreview() => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: ClubBrowseCardSkeleton(),
    ),
  ),
);

/// Loading placeholder matching the image-first layout of a club browse card.
///
/// The [Card] chrome stays static; only the cover block and the content bars
/// pulse inside a single [AppShimmer] pass.
class ClubBrowseCardSkeleton extends StatelessWidget {
  const ClubBrowseCardSkeleton({super.key});

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
                height: 145,
                child: AppSkeletonBox(radius: 0),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: AppSkeletonBox(
                  key: Key('club-skeleton-favorite'),
                  width: 36,
                  height: 36,
                  radius: AppRadius.pill,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(
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
                      AppSkeletonBox(width: 190, height: 16),
                      SizedBox(height: AppSpacing.xs),
                      AppSkeletonBox(width: 130, height: 16),
                      SizedBox(height: AppSpacing.sm),
                      _MetaRow(width: 196),
                      SizedBox(height: AppSpacing.xs),
                      _MetaRow(width: 150),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Leading icon dot + text bar, mirroring the real card's `_ClubMetaRow`.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppSkeletonBox(width: 15, height: 15),
      const SizedBox(width: 6),
      Flexible(
        child: Align(
          alignment: Alignment.centerLeft,
          child: AppSkeletonBox(width: width, height: 12),
        ),
      ),
    ],
  );
}
