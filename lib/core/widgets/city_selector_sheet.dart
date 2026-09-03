import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
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
      useSafeArea: true,
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

    final colorScheme = Theme.of(context).colorScheme;
    return AppReactiveForm(
      formGroup: _form,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          return FractionallySizedBox(
            heightFactor: isWide ? .68 : .82,
            alignment: Alignment.bottomCenter,
            child: Center(
              child: ConstrainedBox(
                key: const Key('city-selector-sheet-content'),
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.sm,
                        AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.citySelectorTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            key: const Key('city-selector-close'),
                            tooltip: l10n.commonClose,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(AppIcons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Material(
                        color: colorScheme.primary.withValues(alpha: .08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: const Key('city-selector-current-location'),
                          onTap: _isLocating
                              ? null
                              : () => unawaited(_useCurrentLocation(cities)),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              child: Row(
                                children: [
                                  if (_isLocating)
                                    const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    Icon(
                                      AppIcons.myLocation,
                                      color: colorScheme.primary,
                                      size: 20,
                                    ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      _isLocating
                                          ? l10n.citySelectorLocating
                                          : l10n.citySelectorUseCurrentLocation,
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (!_isLocating)
                                    Icon(
                                      AppIcons.chevronRight,
                                      color: colorScheme.primary,
                                      size: 18,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_hasLocationError)
                      Container(
                        key: const Key('city-selector-location-error'),
                        margin: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          0,
                        ),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.warning,
                              color: colorScheme.onErrorContainer,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.citySelectorLocationError,
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: ReactiveTextField<String>(
                        key: const Key('city-selector-search'),
                        formControlName: _searchControl,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: l10n.citySelectorSearchHint,
                          prefixIcon: const Icon(AppIcons.search, size: 20),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: .55),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (preference.showNewAddress && units.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (preference.showNewAddress && units.hasError)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          l10n.citySelectorUsingFallback,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
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
          );
        },
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
