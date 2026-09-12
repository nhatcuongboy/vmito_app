import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/location/device_geocoding_service.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/city_selector_current_location_button.dart';
import 'package:vmito_app/core/widgets/city_selector_field_tile.dart';
import 'package:vmito_app/core/widgets/city_selector_popular_chips.dart';
import 'package:vmito_app/core/widgets/city_selector_ward_field.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/area_picker_sheets.dart';

class CitySelection {
  const CitySelection(
    this.city, {
    LocationSelectionType? type,
    this.wards = const {},
  }) : type =
           type ??
           (city != null
               ? LocationSelectionType.city
               : LocationSelectionType.all);

  const CitySelection.city(String this.city, {this.wards = const {}})
    : type = LocationSelectionType.city;
  const CitySelection.all()
    : city = null,
      wards = const {},
      type = LocationSelectionType.all;
  const CitySelection.other()
    : city = null,
      wards = const {},
      type = LocationSelectionType.other;

  final String? city;
  final Set<String> wards;
  final LocationSelectionType type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CitySelection &&
          runtimeType == other.runtimeType &&
          city == other.city &&
          type == other.type &&
          const SetEquality<String>().equals(wards, other.wards);

  @override
  int get hashCode =>
      city.hashCode ^ type.hashCode ^ const SetEquality<String>().hash(wards);
}

Future<CitySelection?> showCitySelectorSheet(
  BuildContext context, {
  bool isOnboarding = false,
}) => showModalBottomSheet<CitySelection>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: false,
  isDismissible: !isOnboarding,
  enableDrag: !isOnboarding,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => PopScope(
    canPop: !isOnboarding,
    child: CitySelectorSheet(isOnboarding: isOnboarding),
  ),
);

class CitySelectorSheet extends ConsumerStatefulWidget {
  const CitySelectorSheet({
    this.isOnboarding = false,
    super.key,
  });

  final bool isOnboarding;

  @override
  ConsumerState<CitySelectorSheet> createState() => _CitySelectorSheetState();
}

class _CitySelectorSheetState extends ConsumerState<CitySelectorSheet> {
  String? _city;
  Set<String> _wards = const {};
  LocationSelectionType _pendingType = LocationSelectionType.all;
  bool _isLocating = false;
  bool _hasLocationError = false;
  bool _seeded = false;

  void _seedFromPreference(LocationPreferences preference) {
    if (_seeded) return;
    _seeded = true;
    _city = preference.preferredCity;
    _wards = preference.preferredWards;
    _pendingType = preference.selectionType ?? LocationSelectionType.all;
  }

  List<String> _cities(
    LocationPreferences preference,
    AsyncValue<List<NewAdminUnit>> units,
  ) {
    final apiCities = switch (units) {
      AsyncData<List<NewAdminUnit>>(:final value) => value.map(
        (unit) => unit.city,
      ),
      _ => const <String>[],
    };
    return sortCitiesWithPopularFirst(
      preference.showNewAddress && apiCities.isNotEmpty
          ? apiCities
          : legacyCities(),
    );
  }

  List<String> _wardsForCity(String? city, List<NewAdminUnit> units) {
    final normalized = normalizeCityName(city ?? '');
    return units
        .where((unit) => normalizeCityName(unit.city) == normalized)
        .expand((unit) => unit.wards)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preference = ref.watch(locationPreferencesControllerProvider);
    _seedFromPreference(preference);
    final unitsState = ref.watch(newAdminUnitsProvider);
    final units = unitsState.value ?? const <NewAdminUnit>[];
    final cities = _cities(preference, unitsState);
    final wards = _wardsForCity(_city, units);
    final isCitySpecific = _pendingType == LocationSelectionType.city;
    final isOther = _pendingType == LocationSelectionType.other;

    return KeyedSubtree(
      key: const Key('city-selector-sheet-content'),
      child: AppFilterSheetScaffold(
        title: l10n.citySelectorTitle,
        subtitle: widget.isOnboarding ? l10n.cityOnboardingDescription : null,
        showCloseButton: !widget.isOnboarding,
        closeButtonKey: const Key('city-selector-close'),
        showActiveCount: false,
        resetLabel: l10n.citySelectorReset,
        applyLabel: l10n.citySelectorApply,
        resetButtonKey: const Key('city-selector-reset'),
        applyButtonKey: const Key('city-selector-apply'),
        onReset: _reset,
        onApply: _apply,
        fitContent: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CitySelectorFieldTile(
              key: const Key('city-selector-province-field'),
              icon: AppIcons.location,
              label: isCitySpecific && _city != null
                  ? _city!
                  : l10n.citySelectorAllPlaces,
              hasValue: isCitySpecific && _city != null,
              onClear: isCitySpecific && _city != null
                  ? () => _onCityPicked(null)
                  : null,
              onTap: () => _pickCity(cities),
            ),
            const SizedBox(height: AppSpacing.md),
            CitySelectorPopularChips(
              selectedCity: isCitySpecific ? _city : null,
              onSelected: _onCityPicked,
            ),
            const SizedBox(height: AppSpacing.md),
            CitySelectorWardField(
              wards: _wards,
              enabled: isCitySpecific && _city != null,
              onTap: () => _pickWards(wards),
              onClear: () => _onWardsPicked(const {}),
              onRemove: _removeWard,
            ),
            const SizedBox(height: AppSpacing.lg),
            CitySelectorCurrentLocationButton(
              isLocating: _isLocating,
              hasError: _hasLocationError,
              onPressed: () => unawaited(_useCurrentLocation(cities, units)),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('city-selector-other'),
              onPressed: _selectOther,
              icon: const Icon(AppIcons.location, size: 18),
              label: Text(l10n.citySelectorOther),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: isOther
                    ? Theme.of(context).colorScheme.primary
                    : null,
                side: isOther
                    ? BorderSide(color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.citySelectorOtherDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  void _onCityPicked(String? city) => setState(() {
    _city = city;
    _wards = const {};
    _pendingType = city == null
        ? LocationSelectionType.all
        : LocationSelectionType.city;
  });

  void _onWardsPicked(Set<String> wards) => setState(() => _wards = {...wards});

  void _removeWard(String ward) =>
      setState(() => _wards = {..._wards}..remove(ward));

  void _selectOther() => setState(() {
    _city = null;
    _wards = const {};
    _pendingType = LocationSelectionType.other;
  });

  void _reset() => setState(() {
    _city = null;
    _wards = const {};
    _pendingType = LocationSelectionType.all;
  });

  Future<void> _pickCity(List<String> cities) async {
    final result = await showCityPickerSheet(
      context,
      cities: cities,
      selectedCity: _city,
    );
    if (!mounted || result == null) return;
    if (result.city != _city) _onCityPicked(result.city);
  }

  Future<void> _pickWards(List<String> wards) async {
    final result = await showWardPickerSheet(
      context,
      city: _city,
      wards: wards,
      selected: _wards,
    );
    if (result != null) _onWardsPicked(result);
  }

  void _apply() {
    final selection = switch (_pendingType) {
      LocationSelectionType.city when _city != null => CitySelection.city(
        _city!,
        wards: _wards,
      ),
      LocationSelectionType.other => const CitySelection.other(),
      _ => const CitySelection.all(),
    };
    Navigator.of(context).pop(selection);
  }

  Future<void> _useCurrentLocation(
    List<String> cities,
    List<NewAdminUnit> units,
  ) async {
    setState(() {
      _isLocating = true;
      _hasLocationError = false;
    });
    try {
      final coordinates = await ref.read(deviceLocationServiceProvider).call();
      final placemark = await ref
          .read(deviceReverseGeocoderProvider)
          .call(coordinates);
      final city = matchCityFromAddress(
        cities: cities,
        addressParts: placemark.parts,
      );
      final ward = city == null
          ? null
          : matchWardFromAddress(
              wards: _wardsForCity(city, units),
              addressParts: placemark.parts,
            );
      if (mounted) {
        setState(() {
          if (city != null) {
            _city = city;
            _wards = ward == null ? const {} : {ward};
            _pendingType = LocationSelectionType.city;
          } else {
            _city = null;
            _wards = const {};
            _pendingType = LocationSelectionType.other;
          }
        });
      }
    } on Object {
      if (mounted) setState(() => _hasLocationError = true);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }
}
