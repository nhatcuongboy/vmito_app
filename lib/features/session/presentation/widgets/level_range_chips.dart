import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// `Yếu- → TB-`, the skill band a session accepts.
///
/// The bounds come from [levelRange], which orders by **display rank**, not by
/// the numeric ids: `BEGINNER_MINUS` is 9 and `BEGINNER_PLUS` is 10, and both
/// sit around `BEGINNER` (1). Sorting `[1, 9, 10]` numerically would render
/// "Yếu → Yếu+" and hide that weaker players are welcome.
///
/// An empty list, or a list containing every supported level, is rendered as
/// the explicit "all levels" badge used by the web session card.
class LevelRangeChips extends StatelessWidget {
  const LevelRangeChips({required this.requiredLevels, super.key});

  final List<int> requiredLevels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final isDark = theme.brightness == Brightness.dark;
    final allLevels =
        requiredLevels.isEmpty ||
        validLevels.every(requiredLevels.toSet().contains);
    if (allLevels) {
      const lightPurple = Color(0xFF7C3AED);
      const darkPurple = Color(0xFFC4B5FD);
      final chipColor = isDark ? darkPurple : lightPurple;
      return _LevelChip(
        key: const Key('session-all-levels-badge'),
        label: AppLocalizations.of(context).sessionAllLevels,
        color: chipColor,
      );
    }

    final range = levelRange(requiredLevels);
    if (range == null) return const SizedBox.shrink();

    final lowest = levelShortLabel(range.lowest);
    final highest = levelShortLabel(range.highest);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LevelChip(label: lowest!, color: theme.colorScheme.primary),
        if (range.highest != range.lowest) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Icon(
              AppIcons.arrowForward,
              size: 12,
              color: palette.mutedForeground,
            ),
          ),
          _LevelChip(label: highest!, color: palette.warning),
        ],
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.color,
    super.key,
  }) : border = null;

  final String label;
  final Color color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: border ?? Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
