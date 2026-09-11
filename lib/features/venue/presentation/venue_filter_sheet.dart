import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/venue/domain/form/venue_filter_form.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_area_filter_section.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

enum VenueSortOption {
  distance('distance'),
  newest('createdAt'),
  nameAsc('name'),
  priceAsc('hourlyRateFixed'),
  courtsDesc('numberOfCourts');

  const VenueSortOption(this.value);
  final String value;

  static VenueSortOption fromValue(String value) =>
      VenueSortOption.values.firstWhere(
        (option) => option.value == value,
        orElse: () => VenueSortOption.distance,
      );

  String label(AppLocalizations l10n) => switch (this) {
    VenueSortOption.distance => l10n.venueSortDistance,
    VenueSortOption.newest => l10n.venueSortNewest,
    VenueSortOption.nameAsc => l10n.venueSortName,
    VenueSortOption.priceAsc => l10n.venueSortPrice,
    VenueSortOption.courtsDesc => l10n.venueSortCourts,
  };

  IconData get icon => switch (this) {
    VenueSortOption.distance => AppIcons.myLocation,
    VenueSortOption.newest => AppIcons.calendarArrowDown,
    VenueSortOption.nameAsc => AppIcons.sortAlpha,
    VenueSortOption.priceAsc => AppIcons.trendingUp,
    VenueSortOption.courtsDesc => AppIcons.grid2x2,
  };
}

class VenueFilterSheet extends ConsumerStatefulWidget {
  const VenueFilterSheet({
    required this.initial,
    this.preferredCity,
    super.key,
  });

  final VenueFilter initial;
  final String? preferredCity;

  @override
  ConsumerState<VenueFilterSheet> createState() => _VenueFilterSheetState();
}

class _VenueFilterSheetState extends ConsumerState<VenueFilterSheet> {
  late final FormGroup _form;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _form = createVenueFilterForm(widget.initial);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _toggleSet<T>(String name, T value) {
    final control = _form.control(name) as FormControl<Set<T>>;
    final next = {...?control.value};
    next.contains(value) ? next.remove(value) : next.add(value);
    control.value = next;
  }

  void _reset() {
    if (_isSubmitting) return;
    final preferredCity =
        widget.preferredCity ??
        ref.read(locationPreferencesControllerProvider).preferredCity;
    _form.reset(
      value: {
        VenueFilterControl.sports: <VenueSport>{},
        VenueFilterControl.city: preferredCity,
        VenueFilterControl.district: null,
        VenueFilterControl.districts: <String>{},
        VenueFilterControl.courtCount: null,
      },
    );
    _form.markAsUntouched();
    final locNotifier = ref.read(
      locationPreferencesControllerProvider.notifier,
    );
    if (preferredCity != null && preferredCity.trim().isNotEmpty) {
      unawaited(locNotifier.selectCity(preferredCity));
    } else {
      unawaited(locNotifier.selectAll());
    }
    setState(() => _isSubmitting = true);
    Navigator.of(context).pop(
      venueFilterFromForm(
        form: _form,
        initial: widget.initial,
        preferredCity: widget.preferredCity,
      ),
    );
  }

  void _apply() {
    if (_isSubmitting) return;
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    final selectedCity =
        _form.control(VenueFilterControl.city).value as String?;
    final locNotifier = ref.read(
      locationPreferencesControllerProvider.notifier,
    );
    if (selectedCity != null && selectedCity.trim().isNotEmpty) {
      unawaited(locNotifier.selectCity(selectedCity));
    } else {
      unawaited(locNotifier.selectAll());
    }
    setState(() => _isSubmitting = true);
    Navigator.of(context).pop(
      venueFilterFromForm(
        form: _form,
        initial: widget.initial,
        preferredCity: widget.preferredCity,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final scheme = theme.colorScheme;
    final preference = ref.watch(locationPreferencesControllerProvider);
    final unitsState = ref.watch(newAdminUnitsProvider);
    final units = unitsState.value ?? const <NewAdminUnit>[];
    final apiCities = units.map((unit) => unit.city);
    final cities = sortCitiesWithPopularFirst(
      preference.showNewAddress && apiCities.isNotEmpty
          ? apiCities
          : (units.isNotEmpty ? apiCities : legacyCities()),
    );

    return AppReactiveForm<void>(
      formGroup: _form,
      child: ReactiveFormConsumer(
        builder: (context, _, child) {
          final pending = venueFilterFromForm(
            form: _form,
            initial: widget.initial,
            preferredCity: widget.preferredCity,
          );
          final count = pending.activeCount(
            preferredCity: widget.preferredCity,
          );
          return AppFilterSheetScaffold(
            title: l10n.venueFiltersTitle,
            activeCount: count,
            activeCountLabel: l10n.sessionFiltersSelected(count),
            showActiveCount: false,
            resetLabel: l10n.venueFiltersReset,
            applyLabel: l10n.venueFiltersApply,
            resetButtonKey: const Key('venue-filter-reset'),
            applyButtonKey: const Key('venue-filter-apply'),
            closeButtonKey: const Key('venue-filter-close'),
            actionsEnabled: !_isSubmitting,
            onReset: _reset,
            onApply: _apply,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Môn thể thao (Top filter)
                AppFilterSection(
                  title: l10n.sessionFilterSport,
                  icon: AppIcons.court,
                  selectedCount: pending.sports.length,
                  child: ReactiveValueListenableBuilder<Set<VenueSport>>(
                    formControlName: VenueFilterControl.sports,
                    builder: (context, control, _) =>
                        AppFilterOptionGroup<VenueSport>(
                          values: VenueSport.values,
                          selected: control.value ?? const {},
                          label: (sport) => switch (sport) {
                            VenueSport.badminton => l10n.sessionSportBadminton,
                            VenueSport.pickleball =>
                              l10n.sessionSportPickleball,
                          },
                          avatarBuilder: (context, sport, isSelected) =>
                              switch (sport) {
                                VenueSport.badminton => Image.asset(
                                  'assets/icons/shuttlecock.png',
                                  width: 16,
                                  height: 16,
                                ),
                                VenueSport.pickleball => Icon(
                                  Icons.sports_tennis,
                                  size: 16,
                                  color: isSelected
                                      ? scheme.primary
                                      : palette.mutedForeground,
                                ),
                              },
                          itemKey: (sport) => Key(
                            'venue-filter-sport-${sport.name}',
                          ),
                          onSelected: (sport) =>
                              _toggleSet(VenueFilterControl.sports, sport),
                        ),
                  ),
                ),

                // 2. Khu vực — shared component, mirrors "Tìm kèo"
                AppAreaFilterSection(
                  key: const Key('venue-filter-area-section'),
                  form: _form,
                  cityControlName: VenueFilterControl.city,
                  districtsControlName: VenueFilterControl.districts,
                  extraDistrictControlName: VenueFilterControl.district,
                  cities: cities,
                  units: units,
                  selectedCount:
                      pending.districts.length +
                      (pending.city != null && !pending.cityIsDefault ? 1 : 0),
                  cityPickerKey: const Key('venue-filter-city'),
                  districtPickerKey: const Key('venue-filter-districts'),
                ),

                // 3. Số lượng sân
                AppFilterSection(
                  title: l10n.sessionFilterCourtCount,
                  icon: AppIcons.grid2x2,
                  selectedCount: pending.courtCount != null ? 1 : 0,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final courtCount in VenueCourtCountFilter.values)
                        ReactiveValueListenableBuilder<VenueCourtCountFilter>(
                          formControlName: VenueFilterControl.courtCount,
                          builder: (context, control, _) {
                            final isSelected = control.value == courtCount;
                            final isFourPlus =
                                courtCount == VenueCourtCountFilter.fourPlus;
                            final label = isFourPlus
                                ? l10n.sessionFilterFourPlusCourts
                                : l10n.sessionFilterCourtCountValue(
                                    courtCount.minCourts,
                                  );
                            final accessibilityLabel = isFourPlus
                                ? l10n.sessionFilterFourPlusCourtsAccessibility
                                : label;
                            return Semantics(
                              label: accessibilityLabel,
                              selected: isSelected,
                              button: true,
                              child: AppFilterChip(
                                key: Key(
                                  'venue-filter-courts-${courtCount.name}',
                                ),
                                label: label,
                                selected: isSelected,
                                avatar: Icon(
                                  AppIcons.grid2x2,
                                  size: 16,
                                  color: isSelected
                                      ? scheme.primary
                                      : palette.mutedForeground,
                                ),
                                onSelected: (_) => control.value = isSelected
                                    ? null
                                    : courtCount,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
