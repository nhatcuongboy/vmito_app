import 'dart:math';

import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

/// Wire values of the backend `CategoryType` enum. `TournamentCategory.type`
/// stays a raw string so an unknown future value never fails to parse.
abstract final class TournamentCategoryType {
  static const mensSingle = 'MENS_SINGLE';
  static const womensSingle = 'WOMENS_SINGLE';
  static const mensDouble = 'MENS_DOUBLE';
  static const womensDouble = 'WOMENS_DOUBLE';
  static const mixedDouble = 'MIXED_DOUBLE';
  static const custom = 'CUSTOM';

  static const List<String> values = [
    mensSingle,
    womensSingle,
    mensDouble,
    womensDouble,
    mixedDouble,
    custom,
  ];

  static bool isSingles(String type) =>
      type == mensSingle || type == womensSingle;
}

/// Mirror of the backend's `registrationConfigForType`: the type decides the
/// registration mode and team size for every type except CUSTOM.
({TournamentRegistrationMode mode, int teamSize}) registrationConfigForType(
  String type, {
  TournamentRegistrationMode customMode = TournamentRegistrationMode.team,
  int? customTeamSize,
}) {
  if (TournamentCategoryType.isSingles(type)) {
    return (mode: TournamentRegistrationMode.individual, teamSize: 1);
  }
  if (type != TournamentCategoryType.custom) {
    return (mode: TournamentRegistrationMode.team, teamSize: 2);
  }
  return customMode == TournamentRegistrationMode.individual
      ? (mode: customMode, teamSize: 1)
      : (mode: customMode, teamSize: max(2, customTeamSize ?? 2));
}
