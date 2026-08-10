import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';

/// Persists whether courts show shirt numbers or names.
///
/// Ports `useCourtDisplayModeStore`. It is a preference, not session state:
/// a host who runs six courts by number wants that on every session, and
/// losing it on every app restart is the kind of small friction that adds up
/// across a three-hour evening.
abstract interface class CourtDisplayModeRepository {
  String? readCourtDisplayModeName();

  Future<void> writeCourtDisplayModeName(String name);
}

class SharedPreferencesCourtDisplayModeRepository
    implements CourtDisplayModeRepository {
  const SharedPreferencesCourtDisplayModeRepository(this._preferences);

  final SharedPreferences _preferences;

  static const _key = 'vmito.court_display_mode';

  @override
  String? readCourtDisplayModeName() => _preferences.getString(_key);

  @override
  Future<void> writeCourtDisplayModeName(String name) async {
    await _preferences.setString(_key, name);
  }
}

final courtDisplayModeRepositoryProvider = Provider<CourtDisplayModeRepository>(
  (ref) => const _NullCourtDisplayModeRepository(),
);

/// Used until `bootstrap.dart` overrides the real one — and in tests and
/// widget previews, which have no `SharedPreferences`. Forgetting the mode is
/// harmless; crashing over a display toggle is not.
class _NullCourtDisplayModeRepository implements CourtDisplayModeRepository {
  const _NullCourtDisplayModeRepository();

  @override
  String? readCourtDisplayModeName() => null;

  @override
  Future<void> writeCourtDisplayModeName(String name) async {}
}

class CourtDisplayModeController extends Notifier<CourtDisplayMode> {
  @override
  CourtDisplayMode build() {
    final saved = ref
        .read(courtDisplayModeRepositoryProvider)
        .readCourtDisplayModeName();
    for (final mode in CourtDisplayMode.values) {
      if (mode.name == saved) return mode;
    }
    // Names read better on a first visit; a host discovers numbers when they
    // need the density.
    return CourtDisplayMode.name;
  }

  Future<void> select(CourtDisplayMode mode) async {
    state = mode;
    await ref
        .read(courtDisplayModeRepositoryProvider)
        .writeCourtDisplayModeName(mode.name);
  }

  Future<void> toggle() => select(
    state == CourtDisplayMode.name
        ? CourtDisplayMode.number
        : CourtDisplayMode.name,
  );
}

final courtDisplayModeControllerProvider =
    NotifierProvider<CourtDisplayModeController, CourtDisplayMode>(
      CourtDisplayModeController.new,
    );
