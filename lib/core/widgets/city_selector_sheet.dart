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
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

class CitySelection {
  const CitySelection(this.city, {LocationSelectionType? type})
    : type =
          type ??
          (city != null
              ? LocationSelectionType.city
              : LocationSelectionType.all);

  const CitySelection.city(String this.city)
    : type = LocationSelectionType.city;
  const CitySelection.all() : city = null, type = LocationSelectionType.all;
  const CitySelection.other() : city = null, type = LocationSelectionType.other;

  final String? city;
  final LocationSelectionType type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CitySelection &&
          runtimeType == other.runtimeType &&
          city == other.city &&
          type == other.type;

  @override
  int get hashCode => city.hashCode ^ type.hashCode;
}

Future<CitySelection?> showCitySelectorSheet(
  BuildContext context, {
  bool isOnboarding = false,
}) => showModalBottomSheet<CitySelection>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: !isOnboarding,
  isDismissible: !isOnboarding,
  enableDrag: !isOnboarding,
  useSafeArea: true,
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
    return AppReactiveForm<void>(
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
                    AppSheetHeader(
                      title: widget.isOnboarding
                          ? l10n.cityOnboardingTitle
                          : l10n.citySelectorTitle,
                      subtitle: widget.isOnboarding
                          ? l10n.cityOnboardingDescription
                          : null,
                      showCloseButton: !widget.isOnboarding,
                      closeButtonKey: const Key('city-selector-close'),
                    ),
                    // Search bar + location chip on the same horizontal row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ReactiveTextField<String>(
                              key: const Key('city-selector-search'),
                              formControlName: _searchControl,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: l10n.citySelectorSearchHint,
                                prefixIcon: const Icon(
                                  AppIcons.search,
                                  size: 20,
                                ),
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
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // Compact location chip
                          Tooltip(
                            message: _isLocating
                                ? l10n.citySelectorLocating
                                : l10n.citySelectorUseCurrentLocation,
                            child: InkWell(
                              key: const Key('city-selector-current-location'),
                              onTap: _isLocating
                                  ? null
                                  : () =>
                                        unawaited(_useCurrentLocation(cities)),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              child: Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: .1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Center(
                                  child: _isLocating
                                      ? SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.primary,
                                          ),
                                        )
                                      : Icon(
                                          AppIcons.myLocation,
                                          color: colorScheme.primary,
                                          size: 20,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_hasLocationError)
                      Container(
                        key: const Key('city-selector-location-error'),
                        margin: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.xs,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.warning,
                              color: colorScheme.onErrorContainer,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                l10n.citySelectorLocationError,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onErrorContainer,
                                    ),
                              ),
                            ),
                          ],
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
                          AppSpacing.xs,
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
                        selectionType: preference.selectionType,
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

  void _select(CitySelection selection) => Navigator.of(context).pop(selection);

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
      if (city != null) {
        if (mounted) _select(CitySelection.city(city));
      } else {
        if (mounted) _select(const CitySelection.other());
      }
    } on Object {
      if (mounted) setState(() => _hasLocationError = true);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }
}
