import 'package:flutter/material.dart';
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
    final values = [
      (l10n.playerLiveMensDoubles, men),
      (l10n.playerLiveWomensDoubles, women),
      (l10n.playerLiveMixedDoubles, mixed),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final value in values)
          Chip(
            avatar: const Icon(Icons.groups_outlined, size: 18),
            label: Text('${value.$1}: ${value.$2}'),
          ),
      ],
    );
  }
}
