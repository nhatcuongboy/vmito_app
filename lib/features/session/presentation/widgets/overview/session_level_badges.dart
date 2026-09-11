import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/reference/presentation/level_descriptions_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/skill_level_badge.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Row of required-skill-level badges (or an "all levels" badge) plus an
/// info button opening the level descriptions sheet.
class SessionLevelBadges extends StatelessWidget {
  const SessionLevelBadges({required this.levels, super.key});

  final List<int> levels;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sorted = sortByRank(levels.toSet());
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (sorted.isEmpty)
          AllSkillLevelsBadge(
            key: const Key('host-overview-all-levels'),
            label: l10n.sessionFormAllLevels,
          )
        else
          for (final level in sorted)
            SkillLevelBadge(
              key: ValueKey('host-overview-level-$level'),
              level: level,
            ),
        IconButton(
          key: const Key('host-overview-level-info'),
          tooltip: l10n.levelDescriptionsTitle,
          onPressed: () => unawaited(showLevelDescriptions(context)),
          icon: const Icon(AppIcons.info, size: 17),
          color: Theme.of(context).colorScheme.primary,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
