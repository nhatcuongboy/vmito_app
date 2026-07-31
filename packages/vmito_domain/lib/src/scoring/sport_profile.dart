/// Sport profiles and scoring presets.
///
/// Ported from `vmito-fe/src/lib/tournament/sports.ts`. Only the parts the
/// scoring engine needs are here; labels and match durations belong with the UI.
library;

enum SportType { badminton, pickleball }

enum MatchFormat { bestOf1, bestOf3, bestOf5 }

/// Default rally-scoring parameters for a sport, or one of its presets.
class RallyScoringDefaults {
  const RallyScoringDefaults({
    required this.pointsToWin,
    required this.winByTwo,
    required this.pointCap,
    required this.matchFormat,
    this.id,
  });

  final int pointsToWin;
  final bool winByTwo;

  /// Hard ceiling: at this score the set ends regardless of the margin.
  /// Null means no ceiling.
  final int? pointCap;

  final MatchFormat matchFormat;

  /// Preset identifier, e.g. `BWF_21`. Null for ad-hoc values.
  final String? id;
}

/// `BADMINTON_PRESETS[0]` on web — also the badminton default. Named so the
/// profile below can reference it: a list index is not a const expression.
const _bwf21 = RallyScoringDefaults(
  id: 'BWF_21',
  pointsToWin: 21,
  winByTwo: true,
  pointCap: 30,
  matchFormat: MatchFormat.bestOf3,
);

/// `PICKLEBALL_PRESETS[0]` — the pickleball default.
const _pickleball11 = RallyScoringDefaults(
  id: 'PICKLEBALL_11',
  pointsToWin: 11,
  winByTwo: true,
  pointCap: null,
  matchFormat: MatchFormat.bestOf1,
);

const _badmintonPresets = <RallyScoringDefaults>[
  _bwf21,
  RallyScoringDefaults(
    id: 'CLASSIC_15',
    pointsToWin: 15,
    winByTwo: true,
    pointCap: null,
    matchFormat: MatchFormat.bestOf3,
  ),
  RallyScoringDefaults(
    id: 'RALLY_15',
    pointsToWin: 15,
    winByTwo: true,
    pointCap: 21,
    matchFormat: MatchFormat.bestOf3,
  ),
  RallyScoringDefaults(
    id: 'SHORT_11',
    pointsToWin: 11,
    winByTwo: true,
    pointCap: 15,
    matchFormat: MatchFormat.bestOf3,
  ),
];

const _pickleballPresets = <RallyScoringDefaults>[
  _pickleball11,
  RallyScoringDefaults(
    id: 'PICKLEBALL_15',
    pointsToWin: 15,
    winByTwo: true,
    pointCap: null,
    matchFormat: MatchFormat.bestOf1,
  ),
  RallyScoringDefaults(
    id: 'PICKLEBALL_21',
    pointsToWin: 21,
    winByTwo: true,
    pointCap: null,
    matchFormat: MatchFormat.bestOf1,
  ),
];

class TournamentSportProfile {
  const TournamentSportProfile({
    required this.sportType,
    required this.defaultScoring,
    required this.scoringPresets,
  });

  final SportType sportType;

  /// The first preset in the list, matching `BADMINTON_PRESETS[0]` on web.
  final RallyScoringDefaults defaultScoring;
  final List<RallyScoringDefaults> scoringPresets;
}

const tournamentSportProfiles = <SportType, TournamentSportProfile>{
  SportType.badminton: TournamentSportProfile(
    sportType: SportType.badminton,
    defaultScoring: _bwf21,
    scoringPresets: _badmintonPresets,
  ),
  SportType.pickleball: TournamentSportProfile(
    sportType: SportType.pickleball,
    defaultScoring: _pickleball11,
    scoringPresets: _pickleballPresets,
  ),
};

/// Anything that is not pickleball is treated as badminton — including null.
/// Mirrors `normalizeSportType`; do not "improve" it into a throw.
SportType normalizeSportType(SportType? sportType) =>
    sportType == SportType.pickleball
    ? SportType.pickleball
    : SportType.badminton;

TournamentSportProfile getTournamentSportProfile(SportType? sportType) =>
    tournamentSportProfiles[normalizeSportType(sportType)]!;
