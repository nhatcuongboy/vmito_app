import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/social/domain/club_browse_filters.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_area_filter_section.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

/// The "Lọc nhóm" filter sheet for club/CLB browsing ("Tìm nhóm").
///
/// Runs on the same shared filter-sheet infrastructure as
/// `SessionFilterSheet` (`showAppFilterSheet` + `AppFilterSheetScaffold` +
/// `AppFilterSection` + `AppFilterOptionGroup`), including the common
/// `AppAreaFilterSection` for "Khu vực" — see that widget for why club
/// filtering and session filtering share one area picker.
class ClubFilterSheet extends ConsumerStatefulWidget {
  const ClubFilterSheet({required this.initial, super.key});

  final ClubBrowseFilters initial;

  @override
  ConsumerState<ClubFilterSheet> createState() => _ClubFilterSheetState();
}

class _ClubFilterSheetState extends ConsumerState<ClubFilterSheet> {
  late final FormGroup _form;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _form = FormGroup({
      ClubBrowseFilterControl.city: FormControl<String>(value: initial.city),
      ClubBrowseFilterControl.districts: FormControl<Set<String>>(
        value: {...initial.districts},
      ),
      ClubBrowseFilterControl.activeDays: FormControl<Set<int>>(
        value: {...initial.activeDays},
      ),
      ClubBrowseFilterControl.activePeriods:
          FormControl<Set<ClubActivityPeriod>>(
            value: {...initial.activePeriods},
          ),
      ClubBrowseFilterControl.levels: FormControl<Set<int>>(
        value: {...initial.levels},
      ),
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  T? _value<T>(String name) => _form.control(name).value as T?;

  void _toggleSet<T>(String name, T value) {
    final control = _form.control(name) as FormControl<Set<T>>;
    final next = {...?control.value};
    next.contains(value) ? next.remove(value) : next.add(value);
    control.value = next;
  }

  void _apply() {
    final selectedCity = _value<String>(ClubBrowseFilterControl.city);
    final locNotifier = ref.read(
      locationPreferencesControllerProvider.notifier,
    );
    if (selectedCity != null && selectedCity.trim().isNotEmpty) {
      unawaited(locNotifier.selectCity(selectedCity));
    } else {
      unawaited(locNotifier.selectAll());
    }
    Navigator.of(context).pop(_filtersFromForm(selectedCity));
  }

  void _reset() {
    final city = ref.read(locationPreferencesControllerProvider).preferredCity;
    _form.reset(
      value: {
        ClubBrowseFilterControl.city: city,
        ClubBrowseFilterControl.districts: <String>{},
        ClubBrowseFilterControl.activeDays: <int>{},
        ClubBrowseFilterControl.activePeriods: <ClubActivityPeriod>{},
        ClubBrowseFilterControl.levels: <int>{},
      },
    );
    _form.markAsUntouched();
    final locNotifier = ref.read(
      locationPreferencesControllerProvider.notifier,
    );
    if (city != null && city.trim().isNotEmpty) {
      unawaited(locNotifier.selectCity(city));
    } else {
      unawaited(locNotifier.selectAll());
    }
    Navigator.of(context).pop(widget.initial.reset(preferredCity: city));
  }

  ClubBrowseFilters _filtersFromForm(String? preferredCity) {
    final city = _value<String>(ClubBrowseFilterControl.city);
    return ClubBrowseFilters(
      city: city,
      cityIsDefault: city == preferredCity,
      districts:
          _value<Set<String>>(ClubBrowseFilterControl.districts) ?? const {},
      activeDays:
          _value<Set<int>>(ClubBrowseFilterControl.activeDays) ?? const {},
      activePeriods:
          _value<Set<ClubActivityPeriod>>(
            ClubBrowseFilterControl.activePeriods,
          ) ??
          const {},
      levels: _value<Set<int>>(ClubBrowseFilterControl.levels) ?? const {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preference = ref.watch(locationPreferencesControllerProvider);
    final unitsState = ref.watch(newAdminUnitsProvider);
    final units = unitsState.value ?? const <NewAdminUnit>[];
    final apiCities = units.map((unit) => unit.city);
    final cities = sortCitiesWithPopularFirst(
      preference.showNewAddress && apiCities.isNotEmpty
          ? apiCities
          : (units.isNotEmpty ? apiCities : legacyCities()),
    );
    final preferredCity = preference.preferredCity;

    return AppReactiveForm<void>(
      formGroup: _form,
      child: ReactiveFormConsumer(
        builder: (context, _, child) {
          final pending = _filtersFromForm(preferredCity);
          return AppFilterSheetScaffold(
            title: l10n.clubFilterTitle,
            activeCount: pending.activeCount,
            activeCountLabel: '${pending.activeCount}',
            resetLabel: l10n.sessionFiltersReset,
            applyLabel: l10n.sessionFiltersSearch,
            resetButtonKey: const Key('club-filter-reset'),
            applyButtonKey: const Key('club-filter-apply'),
            closeButtonKey: const Key('club-filter-close'),
            showActiveCount: false,
            onReset: _reset,
            onApply: _apply,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Khu vực — shared component, identical to the session filter.
                AppAreaFilterSection(
                  key: const Key('club-filter-area-section'),
                  form: _form,
                  cityControlName: ClubBrowseFilterControl.city,
                  districtsControlName: ClubBrowseFilterControl.districts,
                  cities: cities,
                  units: units,
                  selectedCount:
                      pending.districts.length +
                      (pending.city != null && !pending.cityIsDefault ? 1 : 0),
                  cityPickerKey: const Key('club-filter-city'),
                  districtPickerKey: const Key('club-filter-districts'),
                ),
                AppFilterSection(
                  key: const Key('club-filter-activity-time-section'),
                  title: l10n.clubFilterActivityTime,
                  icon: AppIcons.clock,
                  selectedCount:
                      (pending.activeDays.isEmpty ? 0 : 1) +
                      (pending.activePeriods.isEmpty ? 0 : 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReactiveValueListenableBuilder<Set<int>>(
                        formControlName: ClubBrowseFilterControl.activeDays,
                        builder: (context, control, _) => Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (var value = 1; value <= 7; value++)
                              AppFilterChip(
                                key: Key(
                                  'club-filter-weekday-${value % 7}',
                                ),
                                label: MaterialLocalizations.of(
                                  context,
                                ).narrowWeekdays[value % 7],
                                selected:
                                    control.value?.contains(value % 7) ?? false,
                                onSelected: (_) => _toggleSet(
                                  ClubBrowseFilterControl.activeDays,
                                  value % 7,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.clubFilterPeriodLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ReactiveValueListenableBuilder<Set<ClubActivityPeriod>>(
                        formControlName: ClubBrowseFilterControl.activePeriods,
                        builder: (context, control, _) =>
                            AppFilterOptionGroup<ClubActivityPeriod>(
                              values: ClubActivityPeriod.values,
                              selected: control.value ?? const {},
                              label: (period) => _periodLabel(l10n, period),
                              itemKey: (period) =>
                                  Key('club-filter-period-${period.name}'),
                              onSelected: (period) => _toggleSet(
                                ClubBrowseFilterControl.activePeriods,
                                period,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                AppFilterSection(
                  key: const Key('club-filter-level-section'),
                  title: l10n.sessionFilterLevel,
                  icon: AppIcons.award,
                  selectedCount: pending.levels.length,
                  showDivider: false,
                  child: ReactiveValueListenableBuilder<Set<int>>(
                    formControlName: ClubBrowseFilterControl.levels,
                    builder: (context, control, _) => AppFilterOptionGroup<int>(
                      values: const [9, 1, 10, 2, 3, 4, 5, 6, 7, 8],
                      selected: control.value ?? const {},
                      label: l10n.levelName,
                      itemKey: (level) => Key('club-filter-level-$level'),
                      onSelected: (level) =>
                          _toggleSet(ClubBrowseFilterControl.levels, level),
                    ),
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

String _periodLabel(AppLocalizations l10n, ClubActivityPeriod period) =>
    switch (period) {
      ClubActivityPeriod.morning => l10n.sessionFilterMorning,
      ClubActivityPeriod.afternoon => l10n.sessionFilterAfternoon,
      ClubActivityPeriod.evening => l10n.sessionFilterEvening,
    };
