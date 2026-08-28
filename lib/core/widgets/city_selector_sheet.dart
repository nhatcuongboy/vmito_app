import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/location/device_geocoding_service.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/city_selector_results.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class CitySelection {
  const CitySelection(this.city);

  final String? city;
}

Future<CitySelection?> showCitySelectorSheet(BuildContext context) =>
    showModalBottomSheet<CitySelection>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CitySelectorSheet(),
    );

class CitySelectorSheet extends ConsumerStatefulWidget {
  const CitySelectorSheet({super.key});

  @override
  ConsumerState<CitySelectorSheet> createState() => _CitySelectorSheetState();
}

class _CitySelectorSheetState extends ConsumerState<CitySelectorSheet> {
  static const _searchControl = 'search';
  late final FormGroup _form;
  bool _isLocating = false;
  bool _hasLocationError = false;

  @override
  void initState() {
    super.initState();
    _form = FormGroup({_searchControl: FormControl<String>(value: '')});
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preference = ref.watch(locationPreferencesControllerProvider);
    final units = ref.watch(newAdminUnitsProvider);
    final apiCities = switch (units) {
      AsyncData<List<NewAdminUnit>>(:final value) => value.map(
        (unit) => unit.city,
      ),
      _ => const <String>[],
    };
    final cities = sortCitiesWithPopularFirst(
      preference.showNewAddress && apiCities.isNotEmpty
          ? apiCities
          : legacyCities(),
    );

    return ReactiveForm(
      formGroup: _form,
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: .82,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Text(
                      l10n.citySelectorTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ListTile(
                    key: const Key('city-selector-current-location'),
                    leading: _isLocating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.myLocation),
                    title: Text(
                      _isLocating
                          ? l10n.citySelectorLocating
                          : l10n.citySelectorUseCurrentLocation,
                    ),
                    textColor: Theme.of(context).colorScheme.primary,
                    iconColor: Theme.of(context).colorScheme.primary,
                    onTap: _isLocating
                        ? null
                        : () => unawaited(_useCurrentLocation(cities)),
                  ),
                  if (_hasLocationError)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        l10n.citySelectorLocationError,
                        key: const Key('city-selector-location-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: ReactiveTextField<String>(
                      key: const Key('city-selector-search'),
                      formControlName: _searchControl,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.citySelectorSearchHint,
                        prefixIcon: const Icon(AppIcons.search),
                      ),
                    ),
                  ),
                  if (preference.showNewAddress && units.isLoading)
                    const LinearProgressIndicator(),
                  if (preference.showNewAddress && units.hasError)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Text(l10n.citySelectorUsingFallback),
                    ),
                  Expanded(
                    child: CitySelectorResults(
                      searchControlName: _searchControl,
                      cities: cities,
                      selectedCity: preference.preferredCity,
                      onSelected: _select,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _select(String? city) => Navigator.of(context).pop(CitySelection(city));

  Future<void> _useCurrentLocation(List<String> cities) async {
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
      if (city == null) throw const DeviceGeocodingException();
      if (mounted) _select(city);
    } on Object {
      if (mounted) setState(() => _hasLocationError = true);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }
}
