import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Read-only player card with the matches the player appears in.
class TournamentPlayerDetails extends ConsumerWidget {
  const TournamentPlayerDetails({required this.player, super.key});
  final TournamentPlayer player;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final matches = ref.watch(tournamentPlayerMatchesProvider(player.id));
    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final value in [
            player.code,
            player.email,
            player.phone,
            player.userName,
            player.levelDescription,
            player.notes,
          ])
            if (value?.isNotEmpty == true) ListTile(title: Text(value!)),
          Text(
            l.tournamentPlayerMatches,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          matches.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => TextButton(
              onPressed: () =>
                  ref.invalidate(tournamentPlayerMatchesProvider(player.id)),
              child: Text(l.commonRetry),
            ),
            data: (items) => Column(
              children: [
                if (items.isEmpty)
                  ListTile(title: Text(l.tournamentResourceEmpty)),
                for (final match in items)
                  ListTile(
                    title: Text(
                      '${match.matchCode ?? match.matchNumber} · ${match.round}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
