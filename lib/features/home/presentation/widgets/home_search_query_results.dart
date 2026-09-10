import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/home/domain/discovery_suggestion.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_section_header.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_skeleton_tile.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_suggestion_tile.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// What the search screen shows while the user is typing: a row that runs
/// the full search, then entity suggestions for the keyword.
///
/// Rows from the previous keyword stay on screen while the next request is
/// in flight, under a thin progress bar, so typing does not flash the list
/// between rows and a spinner.
class HomeSearchQueryResults extends StatelessWidget {
  const HomeSearchQueryResults({
    required this.query,
    required this.items,
    required this.isFetching,
    required this.hasFailed,
    required this.onSubmit,
    required this.onSuggestion,
    super.key,
  });

  final String query;
  final List<DiscoverySuggestion> items;
  final bool isFetching;
  final bool hasFailed;
  final VoidCallback onSubmit;
  final ValueChanged<DiscoverySuggestion> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showMessage = !isFetching && items.isEmpty && query.length >= 2;
    return Column(
      children: [
        SizedBox(
          height: 2,
          child: isFetching ? const LinearProgressIndicator() : null,
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              _SubmitRow(query: query, onTap: onSubmit),
              const Divider(height: 1),
              if (items.isNotEmpty) ...[
                HomeSearchSectionHeader(title: l10n.homeSearchSuggestionsLabel),
                for (final suggestion in items)
                  HomeSearchSuggestionTile(
                    suggestion: suggestion,
                    query: query,
                    onTap: () => onSuggestion(suggestion),
                  ),
              ] else if (isFetching) ...[
                const SizedBox(height: AppSpacing.sm),
                for (var index = 0; index < 3; index++)
                  const HomeSearchSkeletonTile(),
              ],
              if (showMessage)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    hasFailed
                        ? l10n.homeSearchSuggestionsFailed
                        : l10n.homeSearchNoSuggestions,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).extension<AppPalette>()!.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubmitRow extends StatelessWidget {
  const _SubmitRow({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = AppLocalizations.of(context).homeSearchSeeAllResults(query);
    // Embolden the keyword inside the localized sentence, wherever the
    // translation puts it.
    final at = label.indexOf(query);
    final emphasis = TextStyle(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    return InkWell(
      key: const Key('home-search-submit-suggestion'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Icon(AppIcons.search, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  at < 0
                      ? TextSpan(text: label)
                      : TextSpan(
                          children: [
                            TextSpan(text: label.substring(0, at)),
                            TextSpan(text: query, style: emphasis),
                            TextSpan(text: label.substring(at + query.length)),
                          ],
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Icon(
                AppIcons.arrowForward,
                size: 18,
                color: theme.extension<AppPalette>()!.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
