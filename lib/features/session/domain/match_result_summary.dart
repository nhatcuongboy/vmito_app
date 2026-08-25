import 'dart:convert';

import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';

class MatchResultSummary {
  const MatchResultSummary({this.first, this.second, this.winner});

  final int? first;
  final int? second;
  final int? winner;

  bool get hasScore => first != null || second != null;
}

/// Decodes both score shapes produced by the app and the legacy web editor.
MatchResultSummary matchResult(
  Match match, {
  CourtDirection direction = CourtDirection.horizontal,
}) {
  final raw = match.score;
  if (raw == null || raw.isEmpty) return const MatchResultSummary();
  try {
    final decoded = jsonDecode(raw);
    final teams = matchTeamIds(match, direction);
    int? first;
    int? second;
    if (decoded is List) {
      final scores = <String, int>{
        for (final row in decoded.whereType<Map<String, dynamic>>())
          if (row['playerId'] is String && row['score'] is num)
            row['playerId'] as String: (row['score'] as num).toInt(),
      };
      first = teams.first.map((id) => scores[id]).whereType<int>().firstOrNull;
      second = teams.second
          .map((id) => scores[id])
          .whereType<int>()
          .firstOrNull;
    } else if (decoded is Map<String, dynamic>) {
      first = (decoded['pair1'] as num?)?.toInt();
      second = (decoded['pair2'] as num?)?.toInt();
    }
    return MatchResultSummary(
      first: first,
      second: second,
      winner: match.isDraw
          ? null
          : _winner(match, teams) ?? _winnerFromScores(first, second),
    );
  } on Object {
    return const MatchResultSummary();
  }
}

({List<String> first, List<String> second}) matchTeamIds(
  Match match,
  CourtDirection direction,
) {
  final ids = match.orderedPlayerIds;
  if (ids.length <= 2) {
    return (
      first: ids.take(1).toList(growable: false),
      second: ids.skip(1).toList(growable: false),
    );
  }
  if (direction == CourtDirection.vertical) {
    return (
      first: [for (var index = 0; index < ids.length; index += 2) ids[index]],
      second: [for (var index = 1; index < ids.length; index += 2) ids[index]],
    );
  }
  final split = (ids.length / 2).ceil();
  return (
    first: ids.take(split).toList(growable: false),
    second: ids.skip(split).toList(growable: false),
  );
}

int? _winner(
  Match match,
  ({List<String> first, List<String> second}) teams,
) {
  if (match.winnerIds == null) return null;
  try {
    final raw = jsonDecode(match.winnerIds!);
    if (raw is! List || raw.isEmpty) return null;
    return raw.whereType<String>().any(teams.first.contains)
        ? 1
        : raw.whereType<String>().any(teams.second.contains)
        ? 2
        : null;
  } on Object {
    return null;
  }
}

int? _winnerFromScores(int? first, int? second) {
  if (first == null || second == null || first == second) return null;
  return first > second ? 1 : 2;
}
