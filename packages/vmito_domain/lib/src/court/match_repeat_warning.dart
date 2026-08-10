/// Flags player pairings the host has already used too often.
///
/// Direct port of `vmito-fe/src/utils/match-repeat-warning.ts`.
///
/// **Advisory only.** It never blocks a match — the host decides. The web says
/// as much in its own copy ("chỉ để host cân nhắc… không chặn xác nhận trận").
library;

import 'package:vmito_domain/src/court/court_pairs.dart';

/// A finished match, reduced to what pairing history needs.
class PlayedMatch {
  const PlayedMatch({required this.players, required this.direction});

  final List<PositionedPlayer> players;

  /// The direction of the court it was played on — **not** the court being
  /// assigned now. Teams were decided by that court's geometry, so replaying
  /// history under today's direction would mis-pair it.
  final PairDirection direction;
}

/// One player inside a warning.
class RepeatWarningPlayer {
  const RepeatWarningPlayer({required this.id, this.name, this.playerNumber});

  final String id;
  final String? name;
  final int? playerNumber;
}

/// A pair that has met too often, and how often.
class RepeatWarningItem {
  const RepeatWarningItem({
    required this.key,
    required this.players,
    required this.historyCount,
    required this.totalCount,
  });

  /// The two ids, sorted and joined — order-independent, so `p1:p2` and
  /// `p2:p1` are the same relationship.
  final String key;
  final (RepeatWarningPlayer, RepeatWarningPlayer) players;

  /// Times this pair already met.
  final int historyCount;

  /// [historyCount] plus the match being set up now.
  final int totalCount;
}

class MatchRepeatWarning {
  const MatchRepeatWarning({
    required this.repeatedTeammates,
    required this.repeatedOpponents,
  });

  static const none = MatchRepeatWarning(
    repeatedTeammates: [],
    repeatedOpponents: [],
  );

  final List<RepeatWarningItem> repeatedTeammates;
  final List<RepeatWarningItem> repeatedOpponents;

  bool get hasWarning =>
      repeatedTeammates.isNotEmpty || repeatedOpponents.isNotEmpty;
}

/// Warns for a proposed line-up, given what has been played.
///
/// [current] is the line-up being considered; [format] is what the host picked,
/// and is inferred from the head count when null.
MatchRepeatWarning getMatchRepeatWarning(
  Iterable<PlayedMatch> history,
  Iterable<PositionedPlayer> current, {
  PairDirection direction = PairDirection.horizontal,
  CourtFormat? format,
}) {
  final teammateCounts = <String, int>{};
  final opponentCounts = <String, int>{};

  for (final match in history) {
    // Format is deliberately not passed: a historical match records no type,
    // so it is inferred from how many players it had.
    final groups = groupPairs(match.players, match.direction);
    if (groups == null) continue;
    _countRelations(groups, teammateCounts, opponentCounts);
  }

  final groups = groupPairs(current, direction, format);
  if (groups == null) return MatchRepeatWarning.none;

  final teammates = groups.format == CourtFormat.doubles
      ? [
          (groups.pair1[0], groups.pair1[1]),
          (groups.pair2[0], groups.pair2[1]),
        ]
      : const <(PositionedPlayer, PositionedPlayer)>[];

  final opponents = [
    for (final left in groups.pair1)
      for (final right in groups.pair2) (left, right),
  ];

  return MatchRepeatWarning(
    repeatedTeammates: _buildItems(teammates, teammateCounts),
    repeatedOpponents: _buildItems(opponents, opponentCounts),
  );
}

/// Order-independent key for a relationship between two players.
String pairKey(String playerId1, String playerId2) =>
    ([playerId1, playerId2]..sort()).join(':');

void _countRelations(
  CourtPairs groups,
  Map<String, int> teammateCounts,
  Map<String, int> opponentCounts,
) {
  if (groups.format == CourtFormat.doubles) {
    _increment(teammateCounts, pairKey(groups.pair1[0].id, groups.pair1[1].id));
    _increment(teammateCounts, pairKey(groups.pair2[0].id, groups.pair2[1].id));
  }
  for (final left in groups.pair1) {
    for (final right in groups.pair2) {
      _increment(opponentCounts, pairKey(left.id, right.id));
    }
  }
}

void _increment(Map<String, int> counts, String key) =>
    counts[key] = (counts[key] ?? 0) + 1;

/// Keeps only pairs that would be meeting for at least the third time.
///
/// The threshold is `totalCount >= 3`, matching the shipped copy "đã lặp lại
/// **hơn 2 trận**". (`match-repeat-warning.test.ts` on web asserts a warning at
/// 2; that file predates the current threshold, is written for a runner the
/// repo does not install, and does not run.)
List<RepeatWarningItem> _buildItems(
  List<(PositionedPlayer, PositionedPlayer)> relations,
  Map<String, int> historyCounts,
) {
  final items = <RepeatWarningItem>[];
  for (final (left, right) in relations) {
    final key = pairKey(left.id, right.id);
    final historyCount = historyCounts[key] ?? 0;
    final totalCount = historyCount + 1;
    if (totalCount < 3) continue;
    items.add(
      RepeatWarningItem(
        key: key,
        players: (_toWarningPlayer(left), _toWarningPlayer(right)),
        historyCount: historyCount,
        totalCount: totalCount,
      ),
    );
  }
  items.sort((a, b) => b.totalCount.compareTo(a.totalCount));
  return items;
}

RepeatWarningPlayer _toWarningPlayer(PositionedPlayer player) =>
    RepeatWarningPlayer(
      id: player.id,
      name: player.name,
      playerNumber: player.playerNumber,
    );
