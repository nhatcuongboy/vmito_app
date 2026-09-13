import 'package:vmito_app/features/tournament/domain/tournament_category_type.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_scoring_rules.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Display label for a backend `CategoryType`. Unknown values fall back to the
/// raw wire string rather than hiding the category.
String tournamentCategoryTypeLabel(
  AppLocalizations l10n,
  String type,
) => switch (type) {
  TournamentCategoryType.mensSingle => l10n.tournamentCategoryTypeMensSingle,
  TournamentCategoryType.womensSingle =>
    l10n.tournamentCategoryTypeWomensSingle,
  TournamentCategoryType.mensDouble => l10n.tournamentCategoryTypeMensDouble,
  TournamentCategoryType.womensDouble =>
    l10n.tournamentCategoryTypeWomensDouble,
  TournamentCategoryType.mixedDouble => l10n.tournamentCategoryTypeMixedDouble,
  TournamentCategoryType.custom => l10n.tournamentCategoryTypeCustom,
  _ => type,
};

/// Short format label used on the public detail tab.
String tournamentFormatLabel(
  AppLocalizations l10n,
  TournamentCategoryFormat format,
) => switch (format) {
  TournamentCategoryFormat.roundRobin => l10n.tournamentDetailRoundRobin,
  TournamentCategoryFormat.singleElimination =>
    l10n.tournamentDetailSingleElimination,
  TournamentCategoryFormat.roundRobinToSingleElimination =>
    l10n.tournamentDetailRoundRobinPlayoff,
  TournamentCategoryFormat.doubleElimination =>
    l10n.tournamentDetailDoubleElimination,
};

/// Format name and description from the web format wizard.
(String, String) tournamentFormatCopy(
  AppLocalizations l10n,
  TournamentCategoryFormat format,
) => switch (format) {
  TournamentCategoryFormat.roundRobin => (
    l10n.tournamentFormatRoundRobinName,
    l10n.tournamentFormatRoundRobinDescription,
  ),
  TournamentCategoryFormat.singleElimination => (
    l10n.tournamentFormatSingleEliminationName,
    l10n.tournamentFormatSingleEliminationDescription,
  ),
  TournamentCategoryFormat.doubleElimination => (
    l10n.tournamentFormatDoubleEliminationName,
    l10n.tournamentFormatDoubleEliminationDescription,
  ),
  TournamentCategoryFormat.roundRobinToSingleElimination => (
    l10n.tournamentFormatRoundRobinToSeName,
    l10n.tournamentFormatRoundRobinToSeDescription,
  ),
};

/// Tiebreaker label and description by wire id. The public tab keeps its own
/// shorter copy for the four defaults, matching the web public tab.
(String, String) tournamentTiebreakerCopy(
  AppLocalizations l10n,
  String id,
) => switch (id) {
  'total_points' => (
    l10n.tournamentTiebreakerTotalPoints,
    l10n.tournamentTiebreakerTotalPointsDesc,
  ),
  'game_differential' => (
    l10n.tournamentTiebreakerGameDifferential,
    l10n.tournamentTiebreakerGameDifferentialDesc,
  ),
  'total_wins' => (
    l10n.tournamentTiebreakerTotalWins,
    l10n.tournamentTiebreakerTotalWinsDesc,
  ),
  'point_differential' => (
    l10n.tournamentTiebreakerPointDifferential,
    l10n.tournamentTiebreakerPointDifferentialDesc,
  ),
  'head_to_head' => (
    l10n.tournamentTiebreakerHeadToHead,
    l10n.tournamentTiebreakerHeadToHeadDesc,
  ),
  'matchups' => (
    l10n.tournamentTiebreakerMatchups,
    l10n.tournamentTiebreakerMatchupsDesc,
  ),
  'average_game_differential' => (
    l10n.tournamentTiebreakerAverageGameDifferential,
    l10n.tournamentTiebreakerAverageGameDifferentialDesc,
  ),
  'most_games_for' => (
    l10n.tournamentTiebreakerMostGamesFor,
    l10n.tournamentTiebreakerMostGamesForDesc,
  ),
  'highest_average_games_for' => (
    l10n.tournamentTiebreakerHighestAverageGamesFor,
    l10n.tournamentTiebreakerHighestAverageGamesForDesc,
  ),
  'least_games_against' => (
    l10n.tournamentTiebreakerLeastGamesAgainst,
    l10n.tournamentTiebreakerLeastGamesAgainstDesc,
  ),
  'lowest_average_games_against' => (
    l10n.tournamentTiebreakerLowestAverageGamesAgainst,
    l10n.tournamentTiebreakerLowestAverageGamesAgainstDesc,
  ),
  'least_matches_forfeited' => (
    l10n.tournamentTiebreakerLeastMatchesForfeited,
    l10n.tournamentTiebreakerLeastMatchesForfeitedDesc,
  ),
  'least_losses' => (
    l10n.tournamentTiebreakerLeastLosses,
    l10n.tournamentTiebreakerLeastLossesDesc,
  ),
  'highest_game_ratio' => (
    l10n.tournamentTiebreakerHighestGameRatio,
    l10n.tournamentTiebreakerHighestGameRatioDesc,
  ),
  'points_for' => (
    l10n.tournamentTiebreakerPointsFor,
    l10n.tournamentTiebreakerPointsForDesc,
  ),
  'points_against' => (
    l10n.tournamentTiebreakerPointsAgainst,
    l10n.tournamentTiebreakerPointsAgainstDesc,
  ),
  'point_differential_detail' => (
    l10n.tournamentTiebreakerPointDifferentialDetail,
    l10n.tournamentTiebreakerPointDifferentialDetailDesc,
  ),
  'average_point_differential' => (
    l10n.tournamentTiebreakerAveragePointDifferential,
    l10n.tournamentTiebreakerAveragePointDifferentialDesc,
  ),
  'least_points_against' => (
    l10n.tournamentTiebreakerLeastPointsAgainst,
    l10n.tournamentTiebreakerLeastPointsAgainstDesc,
  ),
  'lowest_average_points_against' => (
    l10n.tournamentTiebreakerLowestAveragePointsAgainst,
    l10n.tournamentTiebreakerLowestAveragePointsAgainstDesc,
  ),
  'most_points_for' => (
    l10n.tournamentTiebreakerMostPointsFor,
    l10n.tournamentTiebreakerMostPointsForDesc,
  ),
  'highest_average_points_for' => (
    l10n.tournamentTiebreakerHighestAveragePointsFor,
    l10n.tournamentTiebreakerHighestAveragePointsForDesc,
  ),
  _ => (id, ''),
};

/// Public detail tab label: its own copy for the defaults, then the catalogue.
String tournamentTiebreakerLabel(
  AppLocalizations l10n,
  Map<String, dynamic> item,
) {
  final id = item['id']?.toString() ?? '';
  return switch (id) {
    'total_points' => l10n.tournamentDetailTiebreakerTotalPoints,
    'game_differential' => l10n.tournamentDetailTiebreakerGameDifferential,
    'total_wins' => l10n.tournamentDetailTiebreakerTotalWins,
    'point_differential' => l10n.tournamentDetailTiebreakerPointDifferential,
    '' => item['label']?.toString() ?? '—',
    _ => tournamentTiebreakerCopy(l10n, id).$1,
  };
}

/// Wizard wording ("Best of 3").
String tournamentBestOfLabel(AppLocalizations l10n, String matchFormat) =>
    switch (matchFormat) {
      'BEST_OF_1' => l10n.tournamentFormatBestOf1,
      'BEST_OF_5' => l10n.tournamentFormatBestOf5,
      _ => l10n.tournamentFormatBestOf3,
    };

/// Scoring-rules wording ("3 set").
String tournamentSetCountLabel(AppLocalizations l10n, String matchFormat) =>
    switch (matchFormat) {
      'BEST_OF_1' => l10n.tournamentScoringBestOf1,
      'BEST_OF_5' => l10n.tournamentScoringBestOf5,
      _ => l10n.tournamentScoringBestOf3,
    };

String tournamentSeedingLabel(AppLocalizations l10n, String method) =>
    switch (method) {
      'random' => l10n.tournamentFormatSeedingRandom,
      'ranking' => l10n.tournamentFormatSeedingRanking,
      _ => l10n.tournamentFormatSeedingManual,
    };

String tournamentKnockoutRoundLabel(AppLocalizations l10n, String round) =>
    switch (round) {
      'F' => l10n.tournamentFormatRoundFinal,
      'SF' => l10n.tournamentFormatRoundSemifinal,
      'QF' => l10n.tournamentFormatRoundQuarterfinal,
      'R16' => l10n.tournamentFormatRoundOf16,
      _ => l10n.tournamentFormatRoundThirdPlace,
    };

String tournamentScoringPresetLabel(AppLocalizations l10n, String? id) =>
    switch (id) {
      'BWF_21' => l10n.tournamentScoringPresetBwf21,
      'CLASSIC_15' => l10n.tournamentScoringPresetClassic15,
      'RALLY_15' => l10n.tournamentScoringPresetRally15,
      'SHORT_11' => l10n.tournamentScoringPresetShort11,
      'PICKLEBALL_11' => l10n.tournamentScoringPresetPickleball11,
      'PICKLEBALL_15' => l10n.tournamentScoringPresetPickleball15,
      'PICKLEBALL_21' => l10n.tournamentScoringPresetPickleball21,
      _ => l10n.tournamentScoringPresetCustom,
    };

(String, String) tournamentScoringStageCopy(
  AppLocalizations l10n,
  ScoringStage stage,
) => switch (stage) {
  ScoringStage.group => (
    l10n.tournamentScoringStageGroup,
    l10n.tournamentScoringStageHintGroup,
  ),
  ScoringStage.knockout => (
    l10n.tournamentScoringStageKnockout,
    l10n.tournamentScoringStageHintKnockout,
  ),
  ScoringStage.finalRound => (
    l10n.tournamentScoringStageFinal,
    l10n.tournamentScoringStageHintFinal,
  ),
};
