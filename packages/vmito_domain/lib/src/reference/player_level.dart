/// Player skill levels.
///
/// Ported from `vmito-fe/src/constants/levels.ts` and the `PlayerLevel` enum in
/// `src/lib/api/types.ts`.
///
/// **The numeric values are not the display order.** `BEGINNER_MINUS` is 9 and
/// `BEGINNER_PLUS` is 10, but they sit either side of `BEGINNER` (1):
///
/// ```text
/// display:  9   1   10  2   3   4   5   6   7   8
/// label:    Yếu- Yếu Yếu+ TBY TB- TB  TB+ Khá BC  CN
/// ```
///
/// So sorting a level list numerically is wrong. `[1, 9, 10]` sorts to
/// `9, 1, 10` — "Yếu- → Yếu+", not "Yếu → Yếu+". Use [sortByRank]; never
/// `list..sort()`.
///
/// This is also why a level is always an `int` and never a Dart enum: a
/// generated enum would renumber these and the error would be silent.
library;

/// One entry in the level table.
class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.code,
    required this.shortLabel,
    required this.rank,
  });

  /// The wire value, as stored on players and sessions.
  final int id;

  /// Stable identifier, e.g. `Y_MINUS`.
  final String code;

  /// Vietnamese short label shown on chips, e.g. `Yếu-`.
  final String shortLabel;

  /// Position in display order, 0-based. Not the id, and not `sortOrder`
  /// from the web table — only the relative order matters.
  final int rank;
}

/// In display order. Index equals rank.
const levelDefinitions = <LevelDefinition>[
  LevelDefinition(id: 9, code: 'Y_MINUS', shortLabel: 'Yếu-', rank: 0),
  LevelDefinition(id: 1, code: 'Y', shortLabel: 'Yếu', rank: 1),
  LevelDefinition(id: 10, code: 'Y_PLUS', shortLabel: 'Yếu+', rank: 2),
  LevelDefinition(id: 2, code: 'TBY', shortLabel: 'TBY', rank: 3),
  LevelDefinition(id: 3, code: 'TB_MINUS', shortLabel: 'TB-', rank: 4),
  LevelDefinition(id: 4, code: 'TB', shortLabel: 'TB', rank: 5),
  LevelDefinition(id: 5, code: 'TB_PLUS', shortLabel: 'TB+', rank: 6),
  LevelDefinition(id: 6, code: 'KHA', shortLabel: 'Khá', rank: 7),
  LevelDefinition(id: 7, code: 'BC', shortLabel: 'BC', rank: 8),
  LevelDefinition(id: 8, code: 'CN', shortLabel: 'CN', rank: 9),
];

final Map<int, LevelDefinition> _byId = {
  for (final definition in levelDefinitions) definition.id: definition,
};

/// Every valid level id, in display order.
List<int> get validLevels => [for (final d in levelDefinitions) d.id];

LevelDefinition? levelDefinition(int level) => _byId[level];

/// Display position, or null when the level is not in the table.
int? levelRank(int level) => _byId[level]?.rank;

/// `Yếu-`, or null for an unknown level.
///
/// Returning null rather than the raw number is deliberate: a stray `12` on a
/// chip looks like data, while an absent chip looks like missing data.
String? levelShortLabel(int level) => _byId[level]?.shortLabel;

/// Sorts by display rank. Unknown levels go last, keeping their relative order.
///
/// Mirrors `sortLevelsByRank`, including the fallback to "last" for anything
/// not in the table.
List<int> sortByRank(Iterable<int> levels) {
  return [...levels]..sort((a, b) {
    final rankA = levelRank(a) ?? _unknownRank;
    final rankB = levelRank(b) ?? _unknownRank;
    return rankA.compareTo(rankB);
  });
}

/// The lowest and highest level in display order, for a range chip.
///
/// Returns null when [levels] is empty — an empty `requiredLevels` means "all
/// levels welcome", which the UI must render as no restriction rather than as
/// a range.
({int lowest, int highest})? levelRange(Iterable<int> levels) {
  final known = sortByRank(levels.where(_byId.containsKey));
  if (known.isEmpty) return null;
  return (lowest: known.first, highest: known.last);
}

/// Sorts after every known level. `sortOrder` in the web table tops out at 80,
/// so any large constant works; this keeps arithmetic away from the max int.
const int _unknownRank = 1 << 20;
