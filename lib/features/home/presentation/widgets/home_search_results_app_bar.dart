import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/home/application/home_discovery_presets.dart';
import 'package:vmito_app/features/home/domain/home_search_outcome.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_featured_kind_label.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_header_backdrop.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_field.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Home's app bar while it shows a search outcome: the typed keyword as a
/// tappable pill, or the preset's title. Back restores the browse list.
class HomeSearchResultsAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  const HomeSearchResultsAppBar({
    required this.outcome,
    required this.onExit,
    required this.onSearch,
    super.key,
  });

  final HomeSearchOutcome outcome;
  final VoidCallback onExit;
  final VoidCallback onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final outcome = this.outcome;
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: const HomeHeaderBackdrop(),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        key: const Key('home-search-exit-results'),
        tooltip: l10n.homeSearchExitResults,
        icon: const Icon(AppIcons.arrowBack),
        onPressed: onExit,
      ),
      titleSpacing: 0,
      title: switch (outcome) {
        HomeSearchQuery(:final query) => _QueryPill(
          query: query,
          onTap: onSearch,
        ),
        HomeSearchPreset(:final tab) => Text(
          ref
              .watch(homeDiscoveryPresetsProvider)
              .kindOf(tab)
              .label(
                l10n,
                city: ref.watch(
                  locationPreferencesControllerProvider.select(
                    (preferences) => preferences.preferredCity,
                  ),
                ),
              ),
          key: const Key('home-search-result-preset'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      },
      actions: switch (outcome) {
        HomeSearchQuery() => const [
          SizedBox(width: AppSpacing.screenPadding),
        ],
        HomeSearchPreset() => [
          IconButton(
            key: const Key('home-search-result-search'),
            tooltip: l10n.homeSearchTooltip,
            icon: const Icon(AppIcons.search),
            onPressed: onSearch,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      },
    );
  }
}

class _QueryPill extends StatelessWidget {
  const _QueryPill({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Same shape and fill as the search screen's field, so tapping it back
    // into search feels like the same control gaining focus.
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).homeSearchTooltip,
      child: InkWell(
        key: const Key('home-search-result-query'),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          height: HomeSearchField.height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            children: [
              const Icon(AppIcons.search, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
