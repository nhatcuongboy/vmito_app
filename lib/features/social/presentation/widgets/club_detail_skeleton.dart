import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/social/presentation/widgets/club_about_tab_skeleton.dart';
import 'package:vmito_app/features/social/presentation/widgets/club_header_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';
import 'package:vmito_app/shared/widgets/detail_hero_header.dart';

/// Loading placeholder for the first club-detail request.
///
/// Mirrors `_ClubDetail`'s geometry — hero sized to `_heroHeight` (220dp),
/// identity block, pinned tab bar, then the default "Giới thiệu" tab — so
/// nothing jumps when the data lands. The back button is real, not a
/// placeholder: a slow request must not trap the user on this screen.
class ClubDetailSkeleton extends StatelessWidget {
  const ClubDetailSkeleton({super.key});

  static const _heroHeight = 220.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeAreaTop = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        key: const Key('club-detail-skeleton'),
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
                    ClubIdentitySkeleton(),
                    ClubTabBarSkeleton(),
                    ClubAboutTabSkeleton(),
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
                key: const Key('club-back-button'),
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
      context.go(AppRoutes.clubs);
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
