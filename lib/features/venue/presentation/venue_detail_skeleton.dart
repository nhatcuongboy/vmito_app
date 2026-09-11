import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';
import 'package:vmito_app/shared/widgets/detail_hero_header.dart';

@Preview(
  name: 'Venue detail loading · Light',
  group: 'Venues',
  size: Size(390, 844),
)
Widget venueDetailSkeletonLightPreview() => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const VenueDetailSkeleton(),
);

@Preview(
  name: 'Venue detail loading · Dark',
  group: 'Venues',
  size: Size(390, 844),
)
Widget venueDetailSkeletonDarkPreview() => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const VenueDetailSkeleton(),
);

/// Loading placeholder for the first venue-detail request.
///
/// Mirrors `VenueDetailContent`'s geometry — hero sized to `_heroHeight`
/// (220dp, keep in sync with the private constant there), then info/about/
/// pricing cards — so nothing jumps when the data lands. The back button is
/// real, not a placeholder: a slow request must not trap the user on this
/// screen.
class VenueDetailSkeleton extends StatelessWidget {
  const VenueDetailSkeleton({super.key});

  static const _heroHeight = 220.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeAreaTop = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        key: const Key('venue-detail-skeleton'),
        children: [
          Semantics(
            container: true,
            label: l10n.commonLoading,
            child: const ExcludeSemantics(
              child: SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: _heroHeight, child: _HeroPlaceholder()),
                    _VenueDetailCards(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: safeAreaTop,
            left: 0,
            width: DetailHeroHeader.leadingWidth,
            height: kToolbarHeight,
            child: Padding(
              padding: DetailHeroHeader.leadingPadding,
              child: DetailHeroHeaderButton(
                key: const Key('venue-back-button'),
                icon: AppIcons.chevronLeft,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                pinned: false,
                size: DetailHeroHeader.backButtonSize,
                hitTargetSize: AppSizes.minTapTarget,
                iconSize: DetailHeroHeader.backIconSize,
                onPressed: () => _back(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.venues);
    }
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = skeletonPalette(theme);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.brandSurface,
            theme.colorScheme.surfaceContainerHighest,
            palette.muted,
          ],
        ),
      ),
    );
  }
}

class _VenueDetailCards extends StatelessWidget {
  const _VenueDetailCards();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoCardSkeleton(),
            SizedBox(height: AppSpacing.md),
            _AboutCardSkeleton(),
            SizedBox(height: AppSpacing.md),
            _PricingCardSkeleton(),
          ],
        ),
      ),
    ),
  );
}

class _InfoCardSkeleton extends StatelessWidget {
  const _InfoCardSkeleton();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeletonBox(width: 200, height: 20),
            SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 19, height: 19),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: AppSkeletonBox(height: 14)),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppSkeletonBox(height: 58, radius: AppRadius.xl),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppSkeletonBox(height: 58, radius: AppRadius.xl),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AboutCardSkeleton extends StatelessWidget {
  const _AboutCardSkeleton();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeletonBox(width: 120, height: 18),
            SizedBox(height: AppSpacing.md),
            AppSkeletonBox(height: 14),
            SizedBox(height: AppSpacing.xs),
            AppSkeletonBox(height: 14),
            SizedBox(height: AppSpacing.xs),
            AppSkeletonBox(width: 180, height: 14),
          ],
        ),
      ),
    ),
  );
}

class _PricingCardSkeleton extends StatelessWidget {
  const _PricingCardSkeleton();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeletonBox(width: 100, height: 18),
            SizedBox(height: AppSpacing.md),
            VenuePricingRowsSkeleton(),
          ],
        ),
      ),
    ),
  );
}

/// Placeholder for one `_PricingGroupCard`'s worth of rows.
///
/// Deliberately not wrapped in its own [AppShimmer] so callers can compose it
/// under whichever shimmer pass fits their context — the top-level
/// [VenueDetailSkeleton] nests it inside [_PricingCardSkeleton]'s shimmer,
/// while `_PricingCard`'s own `loading` branch wraps it directly.
class VenuePricingRowsSkeleton extends StatelessWidget {
  const VenuePricingRowsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = skeletonPalette(theme);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: const AppSkeletonBox(width: 64, height: 14),
          ),
          for (var index = 0; index < 2; index++)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: index == 0
                    ? null
                    : Border(top: BorderSide(color: palette.border)),
              ),
              child: const Row(
                children: [
                  Expanded(child: AppSkeletonBox(width: 80, height: 14)),
                  SizedBox(width: AppSpacing.sm),
                  AppSkeletonBox(width: 70, height: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
