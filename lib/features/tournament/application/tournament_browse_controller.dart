import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class TournamentBrowseState {
  const TournamentBrowseState({
    this.tournaments = const [],
    this.search = '',
    this.isLoading = false,
    this.error,
  });

  final List<TournamentSummary> tournaments;
  final String search;
  final bool isLoading;
  final Object? error;
}

class TournamentBrowseController extends Notifier<TournamentBrowseState> {
  @override
  TournamentBrowseState build() => const TournamentBrowseState();

  Future<void> load({String? search}) async {
    final activeSearch = search ?? state.search;
    state = TournamentBrowseState(
      tournaments: state.tournaments,
      search: activeSearch,
      isLoading: true,
    );
    try {
      final tournaments = await ref
          .read(tournamentServiceProvider)
          .browse(search: activeSearch);
      state = TournamentBrowseState(
        tournaments: tournaments,
        search: activeSearch,
      );
    } on Object catch (error) {
      state = TournamentBrowseState(search: activeSearch, error: error);
    }
  }
}

final tournamentBrowseControllerProvider =
    NotifierProvider<TournamentBrowseController, TournamentBrowseState>(
      TournamentBrowseController.new,
    );
