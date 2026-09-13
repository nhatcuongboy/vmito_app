import 'dart:math';

import 'package:vmito_app/features/tournament/domain/tournament_category_type.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

/// Where a Teams row links to on the web: a player page or a team page.
enum TournamentTeamTarget { player, team }

/// One row of a category card on the Teams tab.
class TournamentTeamRow {
  const TournamentTeamRow({
    required this.id,
    this.name,
    this.code,
    this.target,
    this.members = const [],
  });

  final String id;

  /// Null when nothing resolves a name — the UI shows "unknown".
  final String? name;

  /// Null when the row cannot be linked (an unresolved singles registration).
  final String? code;
  final TournamentTeamTarget? target;
  final List<String> members;
}

class TournamentTeamCategory {
  const TournamentTeamCategory({
    required this.id,
    required this.title,
    required this.rows,
  });

  final String id;
  final String title;
  final List<TournamentTeamRow> rows;
}

/// One entry in the "all players" view.
class TournamentTeamPlayer {
  const TournamentTeamPlayer({
    required this.id,
    required this.name,
    required this.code,
    required this.categories,
    this.image,
  });

  final String id;
  final String name;
  final String code;
  final String? image;
  final List<String> categories;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return name.toLowerCase().contains(normalized) ||
        code.toLowerCase().contains(normalized) ||
        categories.any((c) => c.toLowerCase().contains(normalized));
  }
}

class TournamentTeams {
  const TournamentTeams({required this.categories, required this.players});

  final List<TournamentTeamCategory> categories;
  final List<TournamentTeamPlayer> players;
}

const _legacyCodeLength = 8;

/// Port of `getUniqueLegacyTournamentPlayerCode` (vmito-fe
/// `lib/tournament/codes.ts`): the shortest lowercase id prefix, at least 8
/// characters, that no other id shares. Deep links resolve by this prefix, so
/// it must match the web exactly.
String uniqueLegacyTournamentCode(String id, List<String> ids) {
  final normalizedIds = ids.map((value) => value.toLowerCase()).toList();
  final normalized = id.toLowerCase();
  var length = min(_legacyCodeLength, id.length);
  while (length < id.length) {
    final candidate = normalized.substring(0, length);
    if (normalizedIds.where((v) => v.startsWith(candidate)).length <= 1) {
      return candidate;
    }
    length += 1;
  }
  return normalized;
}

/// Port of the Teams tab pipeline in vmito-fe `TournamentPageShell.tsx`.
TournamentTeams buildTournamentTeams({
  required List<TournamentCategory> categories,
  required List<TournamentPlayer> roster,
  required Map<String, List<TournamentRegistration>> registrationsByCategory,
}) {
  final rosterIds = [for (final player in roster) player.id];
  final playerById = {for (final player in roster) player.id: player};
  final playerCodeById = {
    for (final player in roster)
      player.id: (player.code?.trim().isNotEmpty ?? false)
          ? player.code!.trim()
          : uniqueLegacyTournamentCode(player.id, rosterIds),
  };
  final registrationIds = [
    for (final registrations in registrationsByCategory.values)
      for (final registration in registrations) registration.id,
  ];

  final playerCategories = <String, Set<String>>{};
  final blocks = <TournamentTeamCategory>[];
  for (final category in categories) {
    final registrations = registrationsByCategory[category.id] ?? const [];
    final isSingles = TournamentCategoryType.isSingles(category.type);
    for (final registration in registrations) {
      for (final id in [
        registration.player?.id,
        registration.tournamentPlayerId,
        ...registration.pairMemberIds,
      ]) {
        if (id != null) {
          playerCategories.putIfAbsent(id, () => {}).add(category.name);
        }
      }
    }
    blocks.add(
      TournamentTeamCategory(
        id: category.id,
        title: category.name,
        rows: [
          for (final registration in registrations)
            ..._rowsFor(
              registration,
              isSingles: isSingles,
              playerById: playerById,
              playerCodeById: playerCodeById,
              registrationIds: registrationIds,
            ),
        ],
      ),
    );
  }

  return TournamentTeams(
    categories: blocks..sort((a, b) => a.title.compareTo(b.title)),
    players: [
      for (final player in roster)
        TournamentTeamPlayer(
          id: player.id,
          name: player.name,
          code: playerCodeById[player.id]!,
          image: player.image,
          categories: (playerCategories[player.id]?.toList() ?? [])..sort(),
        ),
    ]..sort((a, b) => a.name.compareTo(b.name)),
  );
}

List<TournamentTeamRow> _rowsFor(
  TournamentRegistration registration, {
  required bool isSingles,
  required Map<String, TournamentPlayer> playerById,
  required Map<String, String> playerCodeById,
  required List<String> registrationIds,
}) {
  final members = [
    for (final (index, id) in registration.pairMemberIds.indexed)
      playerById[id]?.name ??
          (index < registration.pairMembers.length
              ? registration.pairMembers[index]
              : null),
  ].whereType<String>().toList(growable: false);
  final fallbackName =
      registration.pairName ??
      registration.player?.name ??
      (members.isEmpty ? null : members.join(' & '));

  if (!isSingles) {
    return [
      TournamentTeamRow(
        id: registration.id,
        name: fallbackName,
        code: uniqueLegacyTournamentCode(registration.id, registrationIds),
        target: TournamentTeamTarget.team,
        members: members,
      ),
    ];
  }

  final resolved = <String, TournamentPlayer>{};
  final direct =
      registration.player ?? playerById[registration.tournamentPlayerId];
  if (direct != null) resolved[direct.id] = direct;
  for (final id in registration.pairMemberIds) {
    if (playerById[id] case final player?) resolved[player.id] = player;
  }
  if (resolved.isEmpty) {
    return [
      TournamentTeamRow(
        id: registration.id,
        name: fallbackName,
        members: members,
      ),
    ];
  }
  return [
    for (final player in resolved.values)
      TournamentTeamRow(
        id: player.id,
        name: player.name,
        code:
            playerCodeById[player.id] ??
            player.id
                .substring(0, min(_legacyCodeLength, player.id.length))
                .toLowerCase(),
        target: TournamentTeamTarget.player,
      ),
  ];
}
