/// What a court board is for.
///
/// Mirrors the `mode` prop on `vmito-fe/src/components/court/BadmintonCourt.tsx`.
enum CourtViewMode {
  /// Read-only, for players watching a session.
  display,

  /// The host's board: shows level badges and the announce button.
  manage,

  /// Inside the assign sheet: empty squares are tappable, filled ones clear.
  selection;

  bool get isSelection => this == CourtViewMode.selection;

  /// Whether host-only affordances (levels, announce) are shown.
  bool get isHostView => this == CourtViewMode.manage;
}

/// Whether a court shows player names or shirt numbers.
///
/// A host running six courts reads numbers faster than names; a player looking
/// for their friend wants the name. Ports `useCourtDisplayModeStore`.
enum CourtDisplayMode {
  number,
  name;

  bool get showsName => this == CourtDisplayMode.name;
}
