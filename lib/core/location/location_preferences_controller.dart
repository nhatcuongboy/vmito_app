import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vmito_app/core/location/city_names.dart';

enum LocationSelectionType {
  all,
  city,
  other;

  bool get isAll => this == LocationSelectionType.all;
  bool get isCity => this == LocationSelectionType.city;
  bool get isOther => this == LocationSelectionType.other;
}

/// Browser/device scoped discovery preferences. They deliberately contain no
/// user id, so signing out never resets a user's chosen area or address mode.
class LocationPreferences {
  const LocationPreferences({
    this.preferredCity,
    this.selectionType,
    this.onboardingCompleted = false,
    this.showNewAddress = true,
    this.isRestored = false,
  });

  final String? preferredCity;
  final LocationSelectionType? selectionType;
  final bool onboardingCompleted;
  final bool showNewAddress;
  final bool isRestored;

  LocationPreferences copyWith({
    String? preferredCity,
    bool clearPreferredCity = false,
    LocationSelectionType? selectionType,
    bool clearSelectionType = false,
    bool? onboardingCompleted,
    bool? showNewAddress,
    bool? isRestored,
  }) => LocationPreferences(
    preferredCity: clearPreferredCity
        ? null
        : preferredCity ?? this.preferredCity,
    selectionType: clearSelectionType
        ? null
        : selectionType ?? this.selectionType,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    showNewAddress: showNewAddress ?? this.showNewAddress,
    isRestored: isRestored ?? this.isRestored,
  );
}

abstract interface class LocationPreferencesRepository {
  String? readPreferredCity();
  LocationSelectionType? readSelectionType();
  bool? readOnboardingCompleted();
  bool? readShowNewAddress();
  Future<void> write({
    String? preferredCity,
    LocationSelectionType? selectionType,
    required bool onboardingCompleted,
    required bool showNewAddress,
  });
}

class SharedPreferencesLocationPreferencesRepository
    implements LocationPreferencesRepository {
  const SharedPreferencesLocationPreferencesRepository(this._preferences);

  static const _cityKey = 'vmito.preferred_city';
  static const _selectionTypeKey = 'vmito.location_selection_type';
  static const _onboardingKey = 'vmito.location_onboarding_completed';
  static const _newAddressKey = 'vmito.show_new_address';
  final SharedPreferences _preferences;

  @override
  String? readPreferredCity() => _preferences.getString(_cityKey);

  @override
  LocationSelectionType? readSelectionType() {
    final raw = _preferences.getString(_selectionTypeKey);
    return switch (raw) {
      'all' => LocationSelectionType.all,
      'city' => LocationSelectionType.city,
      'other' => LocationSelectionType.other,
      _ => null,
    };
  }

  @override
  bool? readOnboardingCompleted() => _preferences.getBool(_onboardingKey);
  @override
  bool? readShowNewAddress() => _preferences.getBool(_newAddressKey);

  @override
  Future<void> write({
    String? preferredCity,
    LocationSelectionType? selectionType,
    required bool onboardingCompleted,
    required bool showNewAddress,
  }) async {
    if (preferredCity == null) {
      await _preferences.remove(_cityKey);
    } else {
      await _preferences.setString(_cityKey, preferredCity);
    }
    if (selectionType == null) {
      await _preferences.remove(_selectionTypeKey);
    } else {
      await _preferences.setString(_selectionTypeKey, selectionType.name);
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
    final storedCity = _repository.readPreferredCity();
    final normalizedCity = storedCity == null
        ? null
        : normalizeCityName(storedCity);
    final storedType = _repository.readSelectionType();
    final onboardingCompleted = _repository.readOnboardingCompleted() ?? false;

    final LocationSelectionType? selectionType;
    if (storedType != null) {
      selectionType = storedType;
    } else if (storedCity != null && storedCity.trim().isNotEmpty) {
      selectionType = LocationSelectionType.city;
    } else if (onboardingCompleted) {
      selectionType = LocationSelectionType.all;
    } else {
      selectionType = null;
    }

    final effectiveCity = selectionType == LocationSelectionType.city
        ? normalizedCity
        : null;

    state = LocationPreferences(
      preferredCity: effectiveCity,
      selectionType: selectionType,
      onboardingCompleted: onboardingCompleted,
      showNewAddress: _repository.readShowNewAddress() ?? true,
      isRestored: true,
    );
    if (storedType != selectionType || storedCity != effectiveCity) {
      unawaited(_persist());
    }
  }

  Future<void> selectCity(String? city) async {
    if (city == null || city.trim().isEmpty) {
      return selectAll();
    }
    final normalizedCity = normalizeCityName(city);
    if (state.onboardingCompleted &&
        state.selectionType == LocationSelectionType.city &&
        state.preferredCity == normalizedCity) {
      return;
    }
    state = state.copyWith(
      preferredCity: normalizedCity,
      selectionType: LocationSelectionType.city,
      onboardingCompleted: true,
    );
    await _persist();
  }

  Future<void> selectAll() async {
    if (state.onboardingCompleted &&
        state.selectionType == LocationSelectionType.all &&
        state.preferredCity == null) {
      return;
    }
    state = state.copyWith(
      clearPreferredCity: true,
      selectionType: LocationSelectionType.all,
      onboardingCompleted: true,
    );
    await _persist();
  }

  Future<void> selectOther() async {
    if (state.onboardingCompleted &&
        state.selectionType == LocationSelectionType.other &&
        state.preferredCity == null) {
      return;
    }
    state = state.copyWith(
      clearPreferredCity: true,
      selectionType: LocationSelectionType.other,
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
    selectionType: state.selectionType,
    onboardingCompleted: state.onboardingCompleted,
    showNewAddress: state.showNewAddress,
  );
}

final locationPreferencesControllerProvider =
    NotifierProvider<LocationPreferencesController, LocationPreferences>(
      LocationPreferencesController.new,
    );
