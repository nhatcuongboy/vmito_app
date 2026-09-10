import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

@Preview(
  name: 'Venue card loading · Light',
  group: 'Venues',
  size: Size(390, 320),
)
Widget venueCardSkeletonLightPreview() => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: VenueCardSkeleton(),
    ),
  ),
);

@Preview(
  name: 'Venue card loading · Dark',
  group: 'Venues',
  size: Size(390, 320),
)
Widget venueCardSkeletonDarkPreview() => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: VenueCardSkeleton(),
    ),
  ),
);

/// Loading placeholder matching the image-first venue-card layout.
///
/// The [Card] chrome stays static; only the cover block and the content bars
/// pulse inside a single [AppShimmer] pass.
class VenueCardSkeleton extends StatelessWidget {
  const VenueCardSkeleton({super.key});

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
                height: 144,
                child: AppSkeletonBox(radius: 0),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: AppSkeletonBox(
                  key: Key('venue-skeleton-favorite'),
                  width: 36,
                  height: 36,
                  radius: AppRadius.pill,
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: AppSkeletonBox(
                  width: 62,
                  height: 24,
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
                      AppSkeletonBox(width: 180, height: 16),
                      SizedBox(height: AppSpacing.xs),
                      AppSkeletonBox(width: 120, height: 16),
                      SizedBox(height: AppSpacing.sm),
                      _AddressBlock(),
                      SizedBox(height: AppSpacing.sm),
                      _MetaRow(),
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

/// Leading location icon + a two-line address, mirroring the real card.
class _AddressBlock extends StatelessWidget {
  const _AddressBlock();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppSkeletonBox(width: 16, height: 16),
      SizedBox(width: 5),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeletonBox(height: 12),
            SizedBox(height: AppSpacing.xxs),
            AppSkeletonBox(width: 160, height: 12),
          ],
        ),
      ),
    ],
  );
}

/// Two meta items (opening hours + court count), each an icon dot + label bar.
class _MetaRow extends StatelessWidget {
  const _MetaRow();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: _MetaItem()),
      SizedBox(width: AppSpacing.md),
      Expanded(child: _MetaItem()),
    ],
  );
}

class _MetaItem extends StatelessWidget {
  const _MetaItem();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      AppSkeletonBox(width: 16, height: 16),
      SizedBox(width: 5),
      Expanded(child: AppSkeletonBox(height: 12)),
    ],
  );
}
