import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/home/application/home_discovery_presets.dart';
import 'package:vmito_app/features/home/application/home_search_suggestions.dart';
import 'package:vmito_app/features/home/domain/discovery_suggestion.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_featured_kind_label.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_section_header.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_skeleton_tile.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_suggestion_tile.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A short preview of the tab's preset list, with "see all" opening the full
/// list on Home. Hidden when the preset has nothing to show.
class HomeSearchFeaturedSection extends ConsumerWidget {
  const HomeSearchFeaturedSection({
    required this.tab,
    required this.onSeeAll,
    required this.onOpen,
    this.showTopGap = false,
    super.key,
  });

  final HomeDiscoveryTab tab;
  final VoidCallback onSeeAll;
  final ValueChanged<DiscoverySuggestion> onOpen;

  /// Separates this section from recent searches above it.
  final bool showTopGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final featured = ref.watch(homeSearchFeaturedProvider(tab));
    final city = ref.watch(
      locationPreferencesControllerProvider.select(
        (preferences) => preferences.preferredCity,
      ),
    );
    final kind = ref.watch(homeDiscoveryPresetsProvider).kindOf(tab);
    final items = featured.value;
    if (items != null && items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTopGap)
          SizedBox(
            height: AppSpacing.sm,
            child: ColoredBox(
              color: Theme.of(context).extension<AppPalette>()!.muted,
            ),
          ),
        HomeSearchSectionHeader(
          title: kind.label(l10n, city: city),
          action: items == null
              ? null
              : TextButton(
                  key: const Key('home-search-featured-see-all'),
                  onPressed: onSeeAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.homeSearchSeeAll),
                      const Icon(AppIcons.chevronRight, size: 18),
                    ],
                  ),
                ),
        ),
        if (items != null)
          for (final suggestion in items)
            HomeSearchSuggestionTile(
              suggestion: suggestion,
              onTap: () => onOpen(suggestion),
            )
        else if (featured.hasError && !featured.isLoading)
          _FailedRow(
            onRetry: () => ref.invalidate(homeSearchFeaturedProvider(tab)),
          )
        else
          for (var index = 0; index < 3; index++)
            const HomeSearchSkeletonTile(),
      ],
    );
  }
}

class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).extension<AppPalette>()!.mutedForeground;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(AppIcons.error, size: 18, color: muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.homeSearchFeaturedFailed,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          TextButton(
            key: const Key('home-search-featured-retry'),
            onPressed: onRetry,
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
