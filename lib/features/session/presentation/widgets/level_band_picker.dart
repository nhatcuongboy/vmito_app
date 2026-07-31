import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Picks which skill levels a session accepts.
///
/// Chips are laid out in **display order** (`Yếu- Yếu Yếu+ TBY TB- …`), which
/// is not numeric id order — 9 and 10 are the beginner half-steps and bracket
/// 1. Ordering these by id would present the scale wrong to the one person who
/// most needs it right: the host setting it.
///
/// Selecting nothing means **all levels welcome**, and that is stated rather
/// than left as an empty row a host might read as a broken control.
class LevelBandPicker extends StatelessWidget {
  const LevelBandPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  void _toggle(int level) {
    final next = [...selected];
    if (!next.remove(level)) next.add(level);
    // Kept in display order so the value handed to the API, and any range
    // rendered from it later, is already correct.
    onChanged(sortByRank(next));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.createSessionLevels,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (selected.isEmpty)
                Text(
                  l10n.createSessionLevelsAll,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final definition in levelDefinitions)
              FilterChip(
                label: Text(definition.shortLabel),
                selected: selected.contains(definition.id),
                onSelected: (_) => _toggle(definition.id),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}
