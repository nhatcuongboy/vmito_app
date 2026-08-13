import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class TournamentBrowseState {
  const TournamentBrowseState({
    this.tournaments = const [],
    this.search = '',
    this.city,
    this.isLoading = false,
    this.error,
  });

  final List<TournamentSummary> tournaments;
  final String search;
  final String? city;
  final bool isLoading;
  final Object? error;
}

class TournamentBrowseController extends Notifier<TournamentBrowseState> {
  @override
  TournamentBrowseState build() => const TournamentBrowseState();

  Future<void> load({
    String? search,
    String? city,
    bool clearCity = false,
  }) async {
    final activeSearch = search ?? state.search;
    final activeCity = clearCity ? null : city ?? state.city;
    state = TournamentBrowseState(
      tournaments: state.tournaments,
      search: activeSearch,
      city: activeCity,
      isLoading: true,
    );
    try {
      final tournaments = await ref
          .read(tournamentServiceProvider)
          .browse(search: activeSearch, city: activeCity);
      state = TournamentBrowseState(
        tournaments: tournaments,
        search: activeSearch,
        city: activeCity,
      );
    } on Object catch (error) {
      state = TournamentBrowseState(
        search: activeSearch,
        city: activeCity,
        error: error,
      );
    }
  }
}

final tournamentBrowseControllerProvider =
    NotifierProvider<TournamentBrowseController, TournamentBrowseState>(
      TournamentBrowseController.new,
    );
