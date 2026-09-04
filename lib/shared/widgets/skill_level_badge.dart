import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
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

/// A neutral badge indicating that a session has no skill-level restriction.
class AllSkillLevelsBadge extends StatelessWidget {
  const AllSkillLevelsBadge({
    required this.label,
    this.compact = false,
    super.key,
  });

  final String label;

  /// When `true`, uses tighter horizontal/vertical padding.
  final bool compact;

  @override
  Widget build(BuildContext context) => _Badge(
    label: label,
    color: Theme.of(context).extension<AppPalette>()!.mutedForeground,
    compact: compact,
  );
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
