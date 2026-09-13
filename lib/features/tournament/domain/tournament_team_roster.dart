import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

/// Pure roster rules for the Teams manage panel (vmito-fe `TeamsPanel.tsx` and
/// `lib/tournament/teamRoster.ts`).
extension TournamentRegistrationRoster on TournamentRegistration {
  String? get singlePlayerId => player?.id ?? tournamentPlayerId;

  /// Pair members, or the lone player of a legacy single registration.
  List<String> get memberIds =>
      pairMemberIds.isNotEmpty ? pairMemberIds : [?singlePlayerId];

  /// Web order: player name, pair name, then member names joined with " & ".
  String? get displayName =>
      player?.name ??
      pairName ??
      (pairMembers.isEmpty ? null : pairMembers.join(' & '));
}

/// Names of the *other* registrations in the same category that already
/// contain [playerId]. A player may only belong to one team per category.
List<String> otherTeamAssignments(
  List<TournamentRegistration> registrations,
  String playerId, {
  String? exceptRegistrationId,
  String unknownName = '',
}) => [
  for (final registration in registrations)
    if (registration.id != exceptRegistrationId &&
        registration.memberIds.contains(playerId))
      registration.displayName ?? unknownName,
];

/// Player ids already registered in an individual category, to hide them from
/// the "select from roster" list.
Set<String> registeredPlayerIds(List<TournamentRegistration> registrations) => {
  for (final registration in registrations) ?registration.singlePlayerId,
};
