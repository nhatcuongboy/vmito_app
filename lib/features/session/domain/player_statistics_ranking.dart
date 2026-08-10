import 'dart:math' as math;

import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

enum PlayerStatisticsSortField {
  playerNumber,
  name,
  gender,
  level,
  totalMatches,
  wins,
  losses,
  winRate,
  averagePointDifferential,
  totalShuttlecocks,
}

enum StatisticsSortDirection { ascending, descending }

class PlayerStatisticsSort {
  const PlayerStatisticsSort(this.field, this.direction);
  final PlayerStatisticsSortField field;
  final StatisticsSortDirection direction;
}

class PlayerRankingResult {
  const PlayerRankingResult({
    required this.players,
    required this.pointDifferentialEligibleGroups,
    required this.pointDifferentialTiebreakPlayerIds,
  });
  final List<PlayerStatistics> players;
  final Set<String> pointDifferentialEligibleGroups;
  final Set<String> pointDifferentialTiebreakPlayerIds;
}

class MvpGroup {
  const MvpGroup({required this.players, required this.minMatches});
  final List<PlayerStatistics> players;
  final int minMatches;
}

int mvpMinimumMatches(List<PlayerStatistics> players) {
  final maxMatches = players.fold<int>(
    0,
    (value, player) => math.max(value, player.totalMatches),
  );
  if (maxMatches <= 0) return 1;
  return math.max(1, math.min(3, (maxMatches * .5).ceil()));
}

PlayerRankingResult rankPlayerStatistics(List<PlayerStatistics> players) {
  final primary = [...players]
    ..sort((a, b) {
      final rate = b.winRate.compareTo(a.winRate);
      return rate != 0 ? rate : b.wins.compareTo(a.wins);
    });
  final ranked = <PlayerStatistics>[];
  final eligibleGroups = <String>{};
  final tiebreakIds = <String>{};

  for (var start = 0; start < primary.length;) {
    final key = _primaryKey(primary[start]);
    var end = start + 1;
    while (end < primary.length && _primaryKey(primary[end]) == key) {
      end++;
    }
    final group = primary.sublist(start, end);
    final usePointDifference =
        group.length > 1 &&
        group.every((player) => player.averagePointDifferential != null);
    if (usePointDifference) {
      eligibleGroups.add(key);
      if (group.map((e) => e.averagePointDifferential).toSet().length > 1) {
        tiebreakIds.addAll(group.map((e) => e.playerId));
      }
    }
    group.sort((a, b) {
      if (usePointDifference) {
        final difference = b.averagePointDifferential!.compareTo(
          a.averagePointDifferential!,
        );
        if (difference != 0) return difference;
      }
      final matches = b.totalMatches.compareTo(a.totalMatches);
      if (matches != 0) return matches;
      return (a.name ?? '').compareTo(b.name ?? '');
    });
    ranked.addAll(group);
    start = end;
  }
  return PlayerRankingResult(
    players: ranked,
    pointDifferentialEligibleGroups: eligibleGroups,
    pointDifferentialTiebreakPlayerIds: tiebreakIds,
  );
}

MvpGroup calculateMvp(
  List<PlayerStatistics> players, {
  Gender? gender,
}) {
  final minMatches = mvpMinimumMatches(players);
  final eligible = players
      .where(
        (player) =>
            player.totalMatches >= minMatches &&
            player.wins > 0 &&
            player.winRate > 0 &&
            (gender == null || player.gender == gender),
      )
      .toList(growable: false);
  if (eligible.isEmpty) {
    return MvpGroup(players: const [], minMatches: minMatches);
  }
  final ranking = rankPlayerStatistics(eligible);
  final leader = ranking.players.first;
  return MvpGroup(
    players: ranking.players
        .where((player) => _isTied(player, leader, ranking))
        .toList(growable: false),
    minMatches: minMatches,
  );
}

List<PlayerStatistics> sortPlayerStatistics(
  List<PlayerStatistics> players,
  PlayerStatisticsSort? sort,
) {
  if (sort == null) {
    final minimum = mvpMinimumMatches(players);
    final eligible = players
        .where((player) => player.totalMatches >= minimum && player.wins > 0)
        .toList();
    final ineligible = players
        .where((player) => player.totalMatches < minimum || player.wins == 0)
        .toList();
    return [
      ...rankPlayerStatistics(eligible).players,
      ...rankPlayerStatistics(ineligible).players,
    ];
  }
  final result = [...players]
    ..sort((a, b) {
      final comparison = _compareField(a, b, sort.field);
      return sort.direction == StatisticsSortDirection.ascending
          ? comparison
          : -comparison;
    });
  return result;
}

bool _isTied(
  PlayerStatistics first,
  PlayerStatistics second,
  PlayerRankingResult ranking,
) {
  if (first.winRate != second.winRate ||
      first.wins != second.wins ||
      first.totalMatches != second.totalMatches) {
    return false;
  }
  return !ranking.pointDifferentialEligibleGroups.contains(
        _primaryKey(first),
      ) ||
      first.averagePointDifferential == second.averagePointDifferential;
}

String _primaryKey(PlayerStatistics player) =>
    '${player.winRate}:${player.wins}';

int _compareField(
  PlayerStatistics a,
  PlayerStatistics b,
  PlayerStatisticsSortField field,
) => switch (field) {
  PlayerStatisticsSortField.playerNumber => a.playerNumber.compareTo(
    b.playerNumber,
  ),
  PlayerStatisticsSortField.name => (a.name ?? '').compareTo(b.name ?? ''),
  PlayerStatisticsSortField.gender => (a.gender?.name ?? '').compareTo(
    b.gender?.name ?? '',
  ),
  PlayerStatisticsSortField.level => _nullableCompare(
    a.level == null ? null : levelRank(a.level!),
    b.level == null ? null : levelRank(b.level!),
  ),
  PlayerStatisticsSortField.totalMatches => a.totalMatches.compareTo(
    b.totalMatches,
  ),
  PlayerStatisticsSortField.wins => a.wins.compareTo(b.wins),
  PlayerStatisticsSortField.losses => a.losses.compareTo(b.losses),
  PlayerStatisticsSortField.winRate => a.winRate.compareTo(b.winRate),
  PlayerStatisticsSortField.averagePointDifferential => _nullableCompare(
    a.averagePointDifferential,
    b.averagePointDifferential,
  ),
  PlayerStatisticsSortField.totalShuttlecocks => _nullableCompare(
    a.totalShuttlecocks,
    b.totalShuttlecocks,
  ),
};

int _nullableCompare<T extends Comparable<T>>(T? a, T? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
