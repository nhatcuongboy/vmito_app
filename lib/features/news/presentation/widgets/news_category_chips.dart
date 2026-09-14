import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/news/domain/article.dart';
import 'package:vmito_app/features/news/presentation/widgets/news_category_label.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Horizontal scrollable category filter — the mobile-native replacement for
/// the web app's inline chip row, which doesn't need to scroll on desktop.
/// Categories with a zero count are hidden, mirroring the web behaviour.
class NewsCategoryChips extends StatelessWidget {
  const NewsCategoryChips({
    required this.selected,
    required this.counts,
    required this.onSelected,
    super.key,
  });

  final ArticleCategory? selected;
  final Map<ArticleCategory, int> counts;
  final ValueChanged<ArticleCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visibleCategories = ArticleCategory.values
        .where((category) => (counts[category] ?? 0) > 0)
        .toList(growable: false);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: visibleCategories.length + 1,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == 0) {
            return ChoiceChip(
              label: Text(l10n.newsCategoryAll),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            );
          }
          final category = visibleCategories[index - 1];
          return ChoiceChip(
            label: Text(newsCategoryLabel(l10n, category)),
            selected: selected == category,
            onSelected: (_) => onSelected(category),
          );
        },
      ),
    );
  }
}
