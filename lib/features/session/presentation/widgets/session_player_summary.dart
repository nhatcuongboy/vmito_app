import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Playing/waiting counts plus the roster as level-tagged chips.
class SessionPlayerSummary extends StatelessWidget {
  const SessionPlayerSummary({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    final playing = session.playingPlayers.length;
    final waiting = session.waitingPlayers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Pill(
              label: l10n.sessionPlayingCount(playing),
              color: palette.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            _Pill(
              label: l10n.sessionWaitingCount(waiting),
              color: palette.info,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final player in session.players)
              Chip(
                label: Text(
                  player.level == null
                      ? l10n.playerName(player)
                      : '${l10n.playerName(player)} · '
                            '${l10n.levelName(player.level!)}',
                ),
                labelStyle: theme.textTheme.labelSmall,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style:
            Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
