import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/tournament/application/tournament_detail_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_player_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_teams.dart';

/// Roster and registrations for the Teams tab.
///
/// Reuses the shell's detail controller for the tournament id and categories
/// instead of fetching the tournament a second time.
class TournamentTeamsController extends AsyncNotifier<TournamentTeams> {
  TournamentTeamsController(this.idOrSlug);

  final String idOrSlug;

  @override
  Future<TournamentTeams> build() => _load();

  Future<TournamentTeams> _load() async {
    final detail = await ref.read(
      tournamentDetailControllerProvider(idOrSlug).future,
    );
    final tournament = detail.tournament;
    final service = ref.read(tournamentServiceProvider);
    final (roster, registrations) = await (
      ref.read(tournamentPlayerServiceProvider).list(tournament.id),
      Future.wait([
        for (final category in tournament.categories)
          service.registrations(category.id),
      ]),
    ).wait;
    return buildTournamentTeams(
      categories: tournament.categories,
      roster: roster,
      registrationsByCategory: {
        for (final (index, category) in tournament.categories.indexed)
          category.id: registrations[index],
      },
    );
  }

  /// Pull-to-refresh: keeps the current list on screen if the reload fails.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_load);
    if (next.hasValue || !state.hasValue) state = next;
  }
}

// Provider-family declarations are clearer with their inferred Riverpod type.
// ignore: specify_nonobvious_property_types
final tournamentTeamsControllerProvider =
    AsyncNotifierProvider.family<
      TournamentTeamsController,
      TournamentTeams,
      String
    >(TournamentTeamsController.new);
