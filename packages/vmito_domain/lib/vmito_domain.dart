/// Business rules ported from `vmito-fe`, in pure Dart.
///
/// This package must never depend on Flutter, dio, or any generated wire type.
/// That constraint is what keeps `dart test` at a few seconds and stops a
/// scoring rule from quietly importing a widget.
///
/// Everything here is pinned by characterization fixtures shared with the
/// TypeScript — see `docs/TESTING.md`.
library;

export 'src/notifications/court_call.dart';

export 'src/reference/player_level.dart';
export 'src/scoring/rally.dart';
export 'src/scoring/sport_profile.dart';
