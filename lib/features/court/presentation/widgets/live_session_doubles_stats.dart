import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// Men's/women's/mixed doubles breakdown chips for the current player,
/// computed client-side from their match history in this session.
class LiveSessionDoublesStats extends StatelessWidget {
  const LiveSessionDoublesStats({
    required this.session,
    required this.player,
    required this.matches,
    super.key,
  });
  final Session session;
  final SessionPlayer player;
  final List<Match> matches;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    var men = 0;
    var women = 0;
    var mixed = 0;
    final roster = {for (final item in session.players) item.id: item};
    for (final match in matches.where((item) => item.players.length == 4)) {
      final ordered = [...match.players]
        ..sort((a, b) => a.position.compareTo(b.position));
      final index = ordered.indexWhere((item) => item.playerId == player.id);
      if (index < 0) continue;
      final partnerIndex = switch (index) {
        0 => 1,
        1 => 0,
        2 => 3,
        _ => 2,
      };
      final partner = roster[ordered[partnerIndex].playerId];
      if (player.gender == Gender.male && partner?.gender == Gender.male) {
        men++;
      } else if (player.gender == Gender.female &&
          partner?.gender == Gender.female) {
        women++;
      } else {
        mixed++;
      }
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final values = [
      (
        l10n.playerLiveMensDoubles,
        men,
        dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
      ),
      (
        l10n.playerLiveWomensDoubles,
        women,
        dark ? const Color(0xFFF472B6) : const Color(0xFFBE185D),
      ),
      (
        l10n.playerLiveMixedDoubles,
        mixed,
        dark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
      ),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final value in values)
          _DoublesBadge(label: value.$1, count: value.$2, color: value.$3),
      ],
    );
  }
}

class _DoublesBadge extends StatelessWidget {
  const _DoublesBadge({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = count > 0;
    final tone = active ? color : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1,
              )
            : theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: active
              ? color.withValues(alpha: .5)
              : theme.colorScheme.outlineVariant.withValues(alpha: .4),
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.users, size: 15, color: tone),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: tone),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: .18) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: tone,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
