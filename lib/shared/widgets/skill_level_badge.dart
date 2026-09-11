import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// A compact, colour-coded badge for a player's skill level.
///
/// The colours follow the same low, middle, and high level bands throughout
/// the product. Use [AllSkillLevelsBadge] when an empty requirement means all
/// skill levels are welcome.
///
/// Set [compact] to `true` to use tighter padding, suited for dense contexts
/// such as member list cards.
class SkillLevelBadge extends StatelessWidget {
  const SkillLevelBadge({required this.level, this.compact = false, super.key});

  final int level;

  /// When `true`, uses tighter horizontal/vertical padding.
  final bool compact;

  @override
  Widget build(BuildContext context) => _Badge(
    label: AppLocalizations.of(context).levelName(level),
    color: _colorFor(level),
    compact: compact,
  );

  Color _colorFor(int value) {
    final rank = levelRank(value);
    if (rank == null) return const Color(0xFF6B7280);
    if (rank <= 3) return const Color(0xFF15803D);
    if (rank <= 6) return const Color(0xFFCA8A04);
    return const Color(0xFFDC2626);
  }
}

/// A badge indicating that a session has no skill-level restriction.
///
/// Matches the "Mọi trình độ" badge on the browse session card
/// (`LevelRangeChips`): a tinted purple pill rather than the solid,
/// rank-coloured fill used by [SkillLevelBadge].
class AllSkillLevelsBadge extends StatelessWidget {
  const AllSkillLevelsBadge({
    required this.label,
    this.compact = false,
    super.key,
  });

  final String label;

  /// When `true`, uses tighter horizontal/vertical padding.
  final bool compact;

  static const _lightPurple = Color(0xFF7C3AED);
  static const _darkPurple = Color(0xFFC4B5FD);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? _darkPurple : _lightPurple;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs + 2 : AppSpacing.sm + 2,
        vertical: compact ? AppSpacing.xxs : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.28)),
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? AppSpacing.xs + 2 : AppSpacing.sm + 2,
      vertical: compact ? AppSpacing.xxs : 4,
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
