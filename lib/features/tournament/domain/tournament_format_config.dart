import 'dart:convert';

import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

/// Format wizard defaults and the category update payload, ported from vmito-fe
/// `format-wizard/constants.ts` and `TournamentManage.tsx`
/// (`buildFormatUpdatePayload`).
///
/// `formatConfig` stays a JSON map on purpose: the web wizard also edits
/// statistics, standings columns, head-to-head tiebreakers and advanced points
/// that mobile does not expose, and those keys must survive a mobile save.
abstract final class TournamentFormatConfig {
  static const matchFormats = ['BEST_OF_1', 'BEST_OF_3', 'BEST_OF_5'];
  static const seedingMethods = ['manual', 'random', 'ranking'];

  /// Knockout rounds that accept a per-round match format override.
  static const knockoutRounds = ['F', 'SF', 'QF', 'R16'];
  static const thirdPlaceRound = '3RD';

  static const minQualifiersPerGroup = 1;
  static const maxQualifiersPerGroup = 4;
  static const maxStandingPoints = 20;

  /// `AVAILABLE_TIEBREAKERS`; the first four are `DEFAULT_TIEBREAKERS`.
  static const tiebreakerIds = [
    'total_points',
    'game_differential',
    'total_wins',
    'point_differential',
    'head_to_head',
    'matchups',
    'average_game_differential',
    'most_games_for',
    'highest_average_games_for',
    'least_games_against',
    'lowest_average_games_against',
    'least_matches_forfeited',
    'least_losses',
    'highest_game_ratio',
    'points_for',
    'points_against',
    'point_differential_detail',
    'average_point_differential',
    'least_points_against',
    'lowest_average_points_against',
    'most_points_for',
    'highest_average_points_for',
  ];

  /// The wire shape is `{id, label, description}`, where label and description
  /// are web translation keys derived from the id (`total_points` →
  /// `totalPoints` / `totalPointsDesc`).
  static Map<String, dynamic> tiebreaker(String id) {
    final parts = id.split('_');
    final label =
        parts.first +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
    return {'id': id, 'label': label, 'description': '${label}Desc'};
  }

  static Map<String, dynamic> _roundRobinDefaults() => {
    'pointsEarning': 'match_results',
    'winPoints': 2,
    'tiePoints': 0,
    'lossPoints': 1,
    'cancelledMatchPoints': 0,
    'gameWinPoints': 0,
    'gameLossPoints': 0,
    'forfeitWinPoints': 0,
    'forfeitLossPoints': 0,
    'tiebreakers': [for (final id in tiebreakerIds.take(4)) tiebreaker(id)],
    'headToHeadTiebreakers': <Object>[],
    'statistics': [
      {
        'id': 'points',
        'label': 'points',
        'abbreviation': 'P',
        'required': true,
      },
    ],
    'standingsColumns': [
      {'id': 'matches_played', 'label': 'matchesPlayed', 'abbreviation': 'MP'},
      {'id': 'wins', 'label': 'wins', 'abbreviation': 'W'},
      {'id': 'ties', 'label': 'ties', 'abbreviation': 'T'},
      {'id': 'losses', 'label': 'losses', 'abbreviation': 'L'},
      {
        'id': 'points_differential',
        'label': 'pointsDifferential',
        'abbreviation': '+/-',
      },
    ],
  };

  /// `getDefaultConfig`.
  static Map<String, dynamic> defaults(TournamentCategoryFormat format) =>
      switch (format) {
        TournamentCategoryFormat.roundRobin => _roundRobinDefaults(),
        TournamentCategoryFormat.singleElimination => {
          'seedingMethod': 'manual',
          'matchFormat': 'BEST_OF_3',
          'thirdPlaceMatch': false,
        },
        TournamentCategoryFormat.doubleElimination => {
          'seedingMethod': 'manual',
          'matchFormat': 'BEST_OF_3',
          'isTrueDoubleElimination': true,
        },
        TournamentCategoryFormat.roundRobinToSingleElimination => {
          'roundRobin': _roundRobinDefaults(),
          'qualifiersPerGroup': 2,
          'eliminationMatchFormat': 'BEST_OF_3',
          'eliminationSeedingMethod': 'manual',
        },
      };

  /// The config the editor starts from. Stored keys win over defaults, so a
  /// partially filled config (or one saved by an older web build) still
  /// renders every control without losing what was stored.
  static Map<String, dynamic> initial(TournamentCategory category) {
    final stored = _deepCopy(category.formatConfig);
    final merged = {...defaults(category.format), ...stored};
    if (category.format ==
        TournamentCategoryFormat.roundRobinToSingleElimination) {
      final nested = merged['roundRobin'];
      merged['roundRobin'] = {
        ..._roundRobinDefaults(),
        if (nested is Map<String, dynamic>) ...nested,
      };
    }
    return merged;
  }

  /// The map holding the round-robin keys: nested for RR → SE, flat for RR.
  static Map<String, dynamic> roundRobinOf(
    TournamentCategoryFormat format,
    Map<String, dynamic> config,
  ) => format == TournamentCategoryFormat.roundRobinToSingleElimination
      ? config['roundRobin'] as Map<String, dynamic>
      : config;

  static bool hasRoundRobin(TournamentCategoryFormat format) =>
      format == TournamentCategoryFormat.roundRobin ||
      format == TournamentCategoryFormat.roundRobinToSingleElimination;

  /// `buildFormatUpdatePayload`.
  static Map<String, dynamic> updatePayload(
    TournamentCategoryFormat format,
    Map<String, dynamic> config,
    TournamentCategory category,
  ) {
    final base = <String, dynamic>{
      'format': format.wireValue,
      'formatConfig': config,
      'hasGroupStage': hasRoundRobin(format),
    };
    final groupMatchFormat = category.matchFormat ?? 'BEST_OF_3';
    return switch (format) {
      TournamentCategoryFormat.singleElimination => {
        ...base,
        'matchFormat': config['matchFormat'],
        'eliminationMatchFormat': config['matchFormat'],
        'thirdPlaceMatch': config['thirdPlaceMatch'],
      },
      TournamentCategoryFormat.doubleElimination => {
        ...base,
        'formatConfig': {
          ...config,
          'doubleElimination': {
            'isTrueDoubleElimination': config['isTrueDoubleElimination'],
          },
        },
        'matchFormat': config['matchFormat'],
        'eliminationMatchFormat': config['matchFormat'],
      },
      TournamentCategoryFormat.roundRobinToSingleElimination => {
        ...base,
        'matchFormat': groupMatchFormat,
        'eliminationMatchFormat': config['eliminationMatchFormat'],
        'winnersPerGroup': config['qualifiersPerGroup'],
      },
      TournamentCategoryFormat.roundRobin => {
        ...base,
        'matchFormat': groupMatchFormat,
      },
    };
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}
