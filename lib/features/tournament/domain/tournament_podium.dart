import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

enum TournamentPodiumState { decided, provisional, inProgress, empty }

class TournamentPodiumEntry {
  const TournamentPodiumEntry({
    required this.rank,
    required this.label,
    this.playerNames,
    this.detail,
    this.tied = false,
  });

  final int rank;
  final String label;
  final String? playerNames;
  final String? detail;
  final bool tied;
}

class TournamentCategoryPodium {
  const TournamentCategoryPodium({
    required this.category,
    required this.state,
    required this.entries,
  });

  final TournamentCategory category;
  final TournamentPodiumState state;
  final List<TournamentPodiumEntry> entries;
}

TournamentCategoryPodium computeTournamentPodium({
  required TournamentCategory category,
  required List<TournamentMatch> matches,
  required List<TournamentStandingGroup> standings,
}) {
  final categoryMatches = matches
      .where((match) => match.categoryId == category.id)
      .toList(growable: false);
  final playoffMatches = categoryMatches
      .where((match) => match.groupId == null)
      .toList(growable: false);

  if (playoffMatches.isNotEmpty) {
    final finalMatch = playoffMatches
        .where((match) => match.round.toUpperCase() == 'F')
        .firstOrNull;
    final thirdPlaceMatch = playoffMatches
        .where((match) => match.round.toUpperCase() == '3RD')
        .firstOrNull;
    if (finalMatch?.status == TournamentMatchStatus.finished &&
        finalMatch?.winnerId != null) {
      final winnerPosition = _winnerPosition(finalMatch!);
      final entries = <TournamentPodiumEntry>[
        _entry(finalMatch, winnerPosition, 1, detail: finalMatch.score),
        _entry(finalMatch, winnerPosition == 1 ? 2 : 1, 2),
      ];
      if (thirdPlaceMatch?.status == TournamentMatchStatus.finished &&
          thirdPlaceMatch?.winnerId != null) {
        entries.add(
          _entry(
            thirdPlaceMatch!,
            _winnerPosition(thirdPlaceMatch),
            3,
            detail: thirdPlaceMatch.score,
          ),
        );
      } else if (thirdPlaceMatch == null) {
        final semifinals = playoffMatches.where(
          (match) =>
              match.round.toUpperCase() == 'SF' &&
              match.status == TournamentMatchStatus.finished &&
              match.winnerId != null,
        );
        for (final semifinal in semifinals) {
          final loserPosition = _winnerPosition(semifinal) == 1 ? 2 : 1;
          entries.add(_entry(semifinal, loserPosition, 3, tied: true));
        }
      }
      return TournamentCategoryPodium(
        category: category,
        state: TournamentPodiumState.decided,
        entries: entries,
      );
    }
    return TournamentCategoryPodium(
      category: category,
      state: TournamentPodiumState.inProgress,
      entries: const [],
    );
  }

  final rows = standings.expand((group) => group.rows).toList();
  final playedRows = rows.where((row) => row.hasResult).toList();
  final expectsPlayoffs = switch (category.format) {
    TournamentCategoryFormat.roundRobin => false,
    _ => true,
  };
  if (expectsPlayoffs) {
    return TournamentCategoryPodium(
      category: category,
      state: playedRows.isEmpty
          ? TournamentPodiumState.empty
          : TournamentPodiumState.inProgress,
      entries: const [],
    );
  }
  if (playedRows.isEmpty) {
    return TournamentCategoryPodium(
      category: category,
      state: TournamentPodiumState.empty,
      entries: const [],
    );
  }

  rows.sort(_compareStandings);
  final entries = rows
      .take(3)
      .indexed
      .map((indexed) {
        final (index, row) = indexed;
        return TournamentPodiumEntry(
          rank: index + 1,
          label: row.registration.teamLabel,
          playerNames: row.registration.playerNames,
        );
      })
      .toList(growable: false);
  final groupMatches = categoryMatches.where((match) => match.groupId != null);
  final allFinished =
      groupMatches.isNotEmpty &&
      groupMatches.every(
        (match) =>
            match.status == TournamentMatchStatus.finished ||
            match.status == TournamentMatchStatus.cancelled,
      );
  return TournamentCategoryPodium(
    category: category,
    state: allFinished
        ? TournamentPodiumState.decided
        : TournamentPodiumState.provisional,
    entries: entries,
  );
}

int _compareStandings(TournamentStanding first, TournamentStanding second) =>
    second.points.compareTo(first.points) != 0
    ? second.points.compareTo(first.points)
    : second.pointDifference.compareTo(first.pointDifference) != 0
    ? second.pointDifference.compareTo(first.pointDifference)
    : second.pointsFor.compareTo(first.pointsFor) != 0
    ? second.pointsFor.compareTo(first.pointsFor)
    : second.matchesWon.compareTo(first.matchesWon) != 0
    ? second.matchesWon.compareTo(first.matchesWon)
    : second.matchesPlayed.compareTo(first.matchesPlayed);

int _winnerPosition(TournamentMatch match) =>
    match.participants
        .where((participant) => participant.registrationId == match.winnerId)
        .firstOrNull
        ?.position ??
    1;

TournamentPodiumEntry _entry(
  TournamentMatch match,
  int position,
  int rank, {
  String? detail,
  bool tied = false,
}) {
  final registration = match.side(position);
  return TournamentPodiumEntry(
    rank: rank,
    label: registration?.teamLabel ?? '—',
    playerNames: registration?.playerNames,
    detail: detail,
    tied: tied,
  );
}
