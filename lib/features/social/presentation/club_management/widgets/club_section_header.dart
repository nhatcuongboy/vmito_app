import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_card_parts.dart';

/// Section title for the club management tabs.
///
/// Deliberately smaller than the app bar title and no bigger than a card
/// title — the old `titleLarge` header out-shouted both. The count sits right
/// after the title instead of drifting at the far edge.
class ClubSectionHeader extends StatelessWidget {
  const ClubSectionHeader({
    required this.icon,
    required this.title,
    this.count,
    this.needsAttention = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final int? count;

  /// Tints the count for sections that hold work waiting on the user.
  final bool needsAttention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = clubPaletteOf(theme);
    final countColor = needsAttention
        ? palette.warning
        : palette.mutedForeground;
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.mutedForeground),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            constraints: const BoxConstraints(minWidth: 22),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: needsAttention
                  ? palette.warning.withValues(alpha: 0.14)
                  : palette.muted,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: countColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
