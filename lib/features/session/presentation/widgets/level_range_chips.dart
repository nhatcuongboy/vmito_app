import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// `Yếu- → TB-`, the skill band a session accepts.
///
/// The bounds come from [levelRange], which orders by **display rank**, not by
/// the numeric ids: `BEGINNER_MINUS` is 9 and `BEGINNER_PLUS` is 10, and both
/// sit around `BEGINNER` (1). Sorting `[1, 9, 10]` numerically would render
/// "Yếu → Yếu+" and hide that weaker players are welcome.
///
/// Renders nothing when the list is empty — that means *all levels welcome*,
/// and inventing a range would state a restriction the host never set.
class LevelRangeChips extends StatelessWidget {
  const LevelRangeChips({required this.requiredLevels, super.key});

  final List<int> requiredLevels;

  @override
  Widget build(BuildContext context) {
    final range = levelRange(requiredLevels);
    if (range == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
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
              Icons.arrow_forward_rounded,
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
  const _LevelChip({required this.label, required this.color});

  final String label;
  final Color color;

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
