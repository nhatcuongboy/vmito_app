import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_search_section_header.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Recent searches, collapsed to the newest few.
///
/// The search screen opens with the keyboard up, so a full history (up to 10
/// rows) would push the featured section below the fold. Collapsing keeps it
/// in view; "see all" expands in place because the list is short.
class HomeSearchHistorySection extends StatefulWidget {
  const HomeSearchHistorySection({
    required this.history,
    required this.onSelected,
    required this.onRemove,
    required this.onClear,
    super.key,
  });

  static const collapsedCount = 3;

  final List<String> history;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  State<HomeSearchHistorySection> createState() =>
      _HomeSearchHistorySectionState();
}

class _HomeSearchHistorySectionState extends State<HomeSearchHistorySection> {
  var _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final history = widget.history;
    final canCollapse =
        history.length > HomeSearchHistorySection.collapsedCount;
    final visible = _isExpanded || !canCollapse
        ? history
        : history.take(HomeSearchHistorySection.collapsedCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSearchSectionHeader(
          title: l10n.homeSearchRecent,
          action: TextButton(
            onPressed: widget.onClear,
            child: Text(l10n.homeSearchClearAll),
          ),
        ),
        for (final query in visible)
          _HistoryRow(
            query: query,
            onTap: () => widget.onSelected(query),
            onRemove: () => widget.onRemove(query),
          ),
        if (canCollapse)
          Center(
            child: TextButton.icon(
              key: const Key('home-search-history-toggle'),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              iconAlignment: IconAlignment.end,
              icon: Icon(
                _isExpanded ? AppIcons.chevronUp : AppIcons.chevronDown,
                size: 18,
              ),
              label: Text(
                _isExpanded
                    ? l10n.homeSearchShowLess
                    : l10n.homeSearchSeeAllCount(history.length),
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.extension<AppPalette>()!.mutedForeground;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.screenPadding,
          right: AppSpacing.xs,
        ),
        child: SizedBox(
          height: AppSizes.minTapTarget,
          child: Row(
            children: [
              Icon(AppIcons.searchHistory, size: 20, color: muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).homeSearchRemoveHistory,
                icon: Icon(AppIcons.close, size: 18, color: muted),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
