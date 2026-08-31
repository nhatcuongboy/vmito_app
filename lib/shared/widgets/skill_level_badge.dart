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
class SkillLevelBadge extends StatelessWidget {
  const SkillLevelBadge({required this.level, super.key});

  final int level;

  @override
  Widget build(BuildContext context) => _Badge(
    label: AppLocalizations.of(context).levelName(level),
    color: _colorFor(level),
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
  const AllSkillLevelsBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => _Badge(
    label: label,
    color: Theme.of(context).extension<AppPalette>()!.mutedForeground,
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + 2,
      vertical: 4,
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
