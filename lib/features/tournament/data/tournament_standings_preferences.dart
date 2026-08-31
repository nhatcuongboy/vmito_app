import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TournamentStandingsPreferences {
  Future<bool> readShowPlayerNames();
  Future<void> writeShowPlayerNames({required bool value});
}

class SharedPreferencesTournamentStandingsPreferences
    implements TournamentStandingsPreferences {
  SharedPreferencesTournamentStandingsPreferences([
    SharedPreferencesAsync? store,
  ]) : _store = store ?? SharedPreferencesAsync();

  static const showPlayerNamesKey = 'vmito.standings.showPlayerNames';
  final SharedPreferencesAsync _store;

  @override
  Future<bool> readShowPlayerNames() async =>
      await _store.getBool(showPlayerNamesKey) ?? false;

  @override
  Future<void> writeShowPlayerNames({required bool value}) =>
      _store.setBool(showPlayerNamesKey, value);
}

final tournamentStandingsPreferencesProvider =
    Provider<TournamentStandingsPreferences>(
      (ref) => SharedPreferencesTournamentStandingsPreferences(),
    );
