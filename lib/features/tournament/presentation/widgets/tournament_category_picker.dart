import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The selected category, falling back to the first — the web panels pick
/// `categories[0]` when nothing (or a stale id) is selected.
TournamentCategory? resolveSelectedCategory(
  List<TournamentCategory> categories,
  String? selectedId,
) =>
    categories.where((category) => category.id == selectedId).firstOrNull ??
    categories.firstOrNull;

/// Category switcher shared by the Teams and Format panels. Hidden when there
/// is only one category, as on the web.
class TournamentCategoryPicker extends StatelessWidget {
  const TournamentCategoryPicker({
    required this.categories,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<TournamentCategory> categories;
  final TournamentCategory selected;
  final ValueChanged<TournamentCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    if (categories.length <= 1) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      key: ValueKey(selected.id),
      initialValue: selected.id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).tournamentManageCategories,
      ),
      items: [
        for (final category in categories)
          DropdownMenuItem(
            value: category.id,
            child: Text(category.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) => onChanged(
        categories.firstWhere((category) => category.id == id),
      ),
    );
  }
}

/// Shown by panels that need a category before they can do anything.
class TournamentCategoryRequired extends StatelessWidget {
  const TournamentCategoryRequired({required this.onAction, super.key});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.grid, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.tournamentCategoryRequiredTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.tournamentCategoryRequiredDescription,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onAction,
              child: Text(l10n.tournamentCategoryRequiredAction),
            ),
          ],
        ),
      ),
    );
  }
}
