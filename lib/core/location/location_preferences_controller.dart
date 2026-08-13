import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Browser/device scoped discovery preferences. They deliberately contain no
/// user id, so signing out never resets a user's chosen area or address mode.
class LocationPreferences {
  const LocationPreferences({
    this.preferredCity,
    this.onboardingCompleted = false,
    this.showNewAddress = true,
    this.isRestored = false,
  });

  final String? preferredCity;
  final bool onboardingCompleted;
  final bool showNewAddress;
  final bool isRestored;

  LocationPreferences copyWith({
    String? preferredCity,
    bool clearPreferredCity = false,
    bool? onboardingCompleted,
    bool? showNewAddress,
    bool? isRestored,
  }) => LocationPreferences(
    preferredCity: clearPreferredCity
        ? null
        : preferredCity ?? this.preferredCity,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    showNewAddress: showNewAddress ?? this.showNewAddress,
    isRestored: isRestored ?? this.isRestored,
  );
}

abstract interface class LocationPreferencesRepository {
  String? readPreferredCity();
  bool? readOnboardingCompleted();
  bool? readShowNewAddress();
  Future<void> write({
    String? preferredCity,
    required bool onboardingCompleted,
    required bool showNewAddress,
  });
}

class SharedPreferencesLocationPreferencesRepository
    implements LocationPreferencesRepository {
  const SharedPreferencesLocationPreferencesRepository(this._preferences);

  static const _cityKey = 'vmito.preferred_city';
  static const _onboardingKey = 'vmito.location_onboarding_completed';
  static const _newAddressKey = 'vmito.show_new_address';
  final SharedPreferences _preferences;

  @override
  String? readPreferredCity() => _preferences.getString(_cityKey);
  @override
  bool? readOnboardingCompleted() => _preferences.getBool(_onboardingKey);
  @override
  bool? readShowNewAddress() => _preferences.getBool(_newAddressKey);

  @override
  Future<void> write({
    String? preferredCity,
    required bool onboardingCompleted,
    required bool showNewAddress,
  }) async {
    if (preferredCity == null) {
      await _preferences.remove(_cityKey);
    } else {
      await _preferences.setString(_cityKey, preferredCity);
    }
    await _preferences.setBool(_onboardingKey, onboardingCompleted);
    await _preferences.setBool(_newAddressKey, showNewAddress);
  }
}

final locationPreferencesRepositoryProvider =
    Provider<LocationPreferencesRepository>(
      (ref) => throw StateError('Location preferences must be configured'),
    );

class LocationPreferencesController extends Notifier<LocationPreferences> {
  @override
  LocationPreferences build() => const LocationPreferences();

  LocationPreferencesRepository get _repository =>
      ref.read(locationPreferencesRepositoryProvider);

  void restore() {
    state = LocationPreferences(
      preferredCity: _repository.readPreferredCity(),
      onboardingCompleted: _repository.readOnboardingCompleted() ?? false,
      showNewAddress: _repository.readShowNewAddress() ?? true,
      isRestored: true,
    );
  }

  Future<void> selectCity(String? city) async {
    state = state.copyWith(
      preferredCity: city,
      clearPreferredCity: city == null,
      onboardingCompleted: true,
    );
    await _persist();
  }

  Future<void> setShowNewAddress({required bool value}) async {
    state = state.copyWith(showNewAddress: value);
    await _persist();
  }

  Future<void> _persist() => _repository.write(
    preferredCity: state.preferredCity,
    onboardingCompleted: state.onboardingCompleted,
    showNewAddress: state.showNewAddress,
  );
}

final locationPreferencesControllerProvider =
    NotifierProvider<LocationPreferencesController, LocationPreferences>(
      LocationPreferencesController.new,
    );
