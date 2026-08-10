import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/reference/presentation/level_descriptions_sheet.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Roster, capacity facts and the accepted skill band — the lower half of the
/// web app's `SessionDetailBody`.
class SessionDetailStats extends StatelessWidget {
  const SessionDetailStats({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Crawled posts have no managed roster — the whole block would be an
        // empty state that means nothing.
        if (!session.isCrawled) ...[
          _Participants(session: session),
          Divider(height: AppSpacing.lg * 2, color: palette.border),
        ],
        _FactGrid(session: session),
        const SizedBox(height: AppSpacing.md),
        _LevelRow(requiredLevels: session.requiredLevels),
      ],
    );
  }
}

class _Participants extends StatelessWidget {
  const _Participants({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final players = session.approvedPlayers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              AppIcons.clubs,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.sessionParticipantsQuestion,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${players.length}/${session.capacity}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        if (players.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.muted,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              l10n.sessionNoPlayersYet,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final player in players) _PlayerChip(player: player),
            ],
          ),
      ],
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.player});

  final SessionPlayer player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final level = player.level;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: palette.muted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        level == null
            ? l10n.playerName(player)
            : '${l10n.playerName(player)} · ${l10n.levelName(level)}',
        style: theme.textTheme.labelMedium,
      ),
    );
  }
}

/// Courts, capacity, registrations and shuttlecock, two per row.
class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final approved = session.approvedPlayers;
    final male = approved.where((p) => p.gender == Gender.male).length;
    final female = approved.where((p) => p.gender == Gender.female).length;

    final courtNumbers = session.orderedCourts
        .map((court) => court.courtNumber)
        .join(', ');

    final facts = <Widget>[
      if (!session.isCrawled)
        _Fact(
          icon: AppIcons.grid,
          label: l10n.sessionCourtCount(session.numberOfCourts),
          suffix: courtNumbers.isEmpty ? null : '($courtNumbers)',
        ),
      if (!session.isCrawled && session.capacity > 0)
        _Fact(
          icon: AppIcons.clubs,
          label: l10n.sessionMaxPlayers(session.capacity),
        ),
      if (!session.isCrawled)
        _Fact(
          icon: AppIcons.notes,
          label: l10n.sessionRegisteredCount(session.playerCount),
          detail: male > 0 || female > 0
              ? l10n.sessionGenderBreakdown(male, female)
              : null,
        ),
      if (session.shuttlecock case final brand? when brand.trim().isNotEmpty)
        _Fact(
          icon: AppIcons.sessions,
          label: l10n.sessionShuttlecock(brand.trim()),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm + 4,
          children: [
            for (final fact in facts) SizedBox(width: width, child: fact),
          ],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    this.suffix,
    this.detail,
  });

  final IconData icon;
  final String label;

  /// Rendered muted next to [label], e.g. the court numbers `(1, 2)`.
  final String? suffix;

  /// A second, smaller line under [label].
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    if (suffix != null)
                      TextSpan(
                        text: ' $suffix',
                        style: TextStyle(color: palette.mutedForeground),
                      ),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One badge per accepted level, in display rank order.
///
/// An empty [requiredLevels] means *all levels welcome* — rendered as a single
/// neutral badge, never as a range, so the screen never states a restriction
/// the host did not set.
class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.requiredLevels});

  final List<int> requiredLevels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final levels = sortByRank(requiredLevels.toSet());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          AppIcons.shield,
          size: 20,
          color: levels.isEmpty
              ? palette.mutedForeground
              : theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: levels.isEmpty
                ? [
                    _LevelBadge(
                      label: l10n.sessionAllLevels,
                      color: palette.mutedForeground,
                    ),
                  ]
                : [
                    for (final level in levels)
                      if (levelShortLabel(level) != null)
                        _LevelBadge(
                          label: l10n.levelName(level),
                          color: theme.colorScheme.primary,
                        ),
                  ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: l10n.levelDescriptionsTitle,
          icon: const Icon(AppIcons.info, size: 18),
          visualDensity: VisualDensity.compact,
          color: theme.colorScheme.primary,
          onPressed: () => unawaited(showLevelDescriptions(context)),
        ),
      ],
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + 2,
      vertical: 3,
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
