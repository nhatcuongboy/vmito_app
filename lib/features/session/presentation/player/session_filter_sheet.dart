import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/input_formatters.dart';
import 'package:vmito_app/features/session/domain/browse_session_filters.dart';
import 'package:vmito_app/features/session/domain/form/browse_session_filter_form.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

class SessionFilterSheet extends ConsumerStatefulWidget {
  const SessionFilterSheet({required this.initial, super.key});

  final BrowseSessionFilters initial;

  @override
  ConsumerState<SessionFilterSheet> createState() => _SessionFilterSheetState();
}

class _SessionFilterSheetState extends ConsumerState<SessionFilterSheet> {
  late final FormGroup _form;
  DeviceCoordinates? _coordinates;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _coordinates =
        initial.nearMe && initial.latitude != null && initial.longitude != null
        ? DeviceCoordinates(
            latitude: initial.latitude!,
            longitude: initial.longitude!,
          )
        : null;
    _form = FormGroup(
      {
        BrowseFilterControl.date: FormControl<DateTime>(value: initial.date),
        BrowseFilterControl.timeRanges: FormControl<Set<SessionTimeRange>>(
          value: {...initial.timeRanges},
        ),
        BrowseFilterControl.hasSlots: FormControl<bool>(
          value: initial.hasSlots,
        ),
        BrowseFilterControl.nearMe: FormControl<bool>(value: initial.nearMe),
        BrowseFilterControl.source: FormControl<SessionSource>(
          value: initial.source,
        ),
        BrowseFilterControl.city: FormControl<String>(value: initial.city),
        BrowseFilterControl.districts: FormControl<Set<String>>(
          value: {...initial.districts},
        ),
        BrowseFilterControl.sports: FormControl<Set<SessionSport>>(
          value: {...initial.sports},
        ),
        BrowseFilterControl.courtCount: FormControl<SessionCourtCountFilter>(
          value: initial.courtCount,
        ),
        BrowseFilterControl.levels: FormControl<Set<int>>(
          value: {...initial.levels},
        ),
        BrowseFilterControl.minFee: FormControl<int>(
          value: initial.minFee,
          validators: [Validators.required, Validators.min(0)],
        ),
        BrowseFilterControl.maxFee: FormControl<int>(
          value: initial.maxFee,
          validators: [Validators.required, Validators.min(0)],
        ),
        BrowseFilterControl.splitEvenly: FormControl<bool>(
          value: initial.splitEvenly,
        ),
      },
      validators: [Validators.delegate(validateBrowseFeeRange)],
    );
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

  Future<void> _toggleNearMe() async {
    final control =
        _form.control(BrowseFilterControl.nearMe) as FormControl<bool>;
    if (control.value ?? false) {
      _coordinates = null;
      control.value = false;
      return;
    }
    setState(() => _isLocating = true);
    try {
      final coordinates = await ref.read(deviceLocationServiceProvider).call();
      if (!mounted) return;
      _coordinates = coordinates;
      control.value = true;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).sessionFilterLocationDenied,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _apply() {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    final selectedCity = _value<String>(BrowseFilterControl.city);
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
    final reset = widget.initial.reset(preferredCity: city);
    _coordinates = null;
    _form.reset(
      value: {
        BrowseFilterControl.date: reset.date,
        BrowseFilterControl.timeRanges: <SessionTimeRange>{},
        BrowseFilterControl.hasSlots: false,
        BrowseFilterControl.nearMe: false,
        BrowseFilterControl.source: SessionSource.all,
        BrowseFilterControl.city: reset.city,
        BrowseFilterControl.districts: <String>{},
        BrowseFilterControl.sports: <SessionSport>{},
        BrowseFilterControl.courtCount: null,
        BrowseFilterControl.levels: <int>{},
        BrowseFilterControl.minFee: BrowseSessionFilters.defaultMinFee,
        BrowseFilterControl.maxFee: BrowseSessionFilters.defaultMaxFee,
        BrowseFilterControl.splitEvenly: false,
      },
    );
    setState(() {});
  }

  BrowseSessionFilters _filtersFromForm(String? preferredCity) {
    final city = _value<String>(BrowseFilterControl.city);
    return BrowseSessionFilters(
      search: widget.initial.search,
      date: _value<DateTime>(BrowseFilterControl.date),
      timeRanges:
          _value<Set<SessionTimeRange>>(BrowseFilterControl.timeRanges) ??
          const {},
      hasSlots: _value<bool>(BrowseFilterControl.hasSlots) ?? false,
      nearMe: _value<bool>(BrowseFilterControl.nearMe) ?? false,
      source:
          _value<SessionSource>(BrowseFilterControl.source) ??
          SessionSource.all,
      city: city,
      cityIsDefault: city == preferredCity,
      districts: _value<Set<String>>(BrowseFilterControl.districts) ?? const {},
      sports: _value<Set<SessionSport>>(BrowseFilterControl.sports) ?? const {},
      courtCount: _value<SessionCourtCountFilter>(
        BrowseFilterControl.courtCount,
      ),
      levels: _value<Set<int>>(BrowseFilterControl.levels) ?? const {},
      minFee:
          _value<int>(BrowseFilterControl.minFee) ??
          BrowseSessionFilters.defaultMinFee,
      maxFee:
          _value<int>(BrowseFilterControl.maxFee) ??
          BrowseSessionFilters.defaultMaxFee,
      splitEvenly: _value<bool>(BrowseFilterControl.splitEvenly) ?? false,
      latitude: _coordinates?.latitude,
      longitude: _coordinates?.longitude,
      venueId: widget.initial.venueId,
      venueName: widget.initial.venueName,
      sort: widget.initial.sort,
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

    final preferredCity = preference.preferredCity;
    return AppReactiveForm<void>(
      formGroup: _form,
      child: ReactiveFormConsumer(
        builder: (context, _, child) {
          final pending = _filtersFromForm(preferredCity);
          return AppFilterSheetScaffold(
            title: l10n.sessionFiltersTitle,
            activeCount: pending.activeCount,
            activeCountLabel: '${pending.activeCount}',
            resetLabel: l10n.sessionFiltersReset,
            applyLabel: l10n.sessionFiltersSearch,
            resetButtonKey: const Key('session-filter-reset'),
            applyButtonKey: const Key('session-filter-apply'),
            closeButtonKey: const Key('session-filter-close'),
            showActiveCount: false,
            actionsEnabled: !_isLocating,
            onReset: _reset,
            onApply: _apply,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFilterSection(
                  title: l10n.sessionFilterDate,
                  icon: AppIcons.calendar,
                  child: ReactiveValueListenableBuilder<DateTime>(
                    formControlName: BrowseFilterControl.date,
                    builder: (context, dateControl, _) {
                      final hasDate = dateControl.value != null;
                      final locale = Localizations.localeOf(context).toString();
                      final formattedDate = hasDate
                          ? DateFormat.yMMMMEEEEd(
                              locale,
                            ).format(dateControl.value!)
                          : null;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const Key('session-filter-date'),
                          onTap: () => _pickDate(context, dateControl),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm + 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: hasDate
                                    ? scheme.primary
                                    : palette.border,
                                width: hasDate ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: hasDate
                                      ? Text(
                                          formattedDate!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onSurface,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : Text(
                                          l10n.sessionFilterAllDates,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: palette.mutedForeground,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                                if (hasDate)
                                  IconButton(
                                    tooltip: l10n.commonDelete,
                                    icon: const Icon(
                                      AppIcons.close,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => dateControl.value = null,
                                  )
                                else
                                  Icon(
                                    AppIcons.chevronDown,
                                    size: 18,
                                    color: palette.mutedForeground,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                AppFilterSection(
                  title: l10n.sessionFilterTimeRange,
                  icon: AppIcons.clock,
                  selectedCount: pending.timeRanges.length,
                  child: ReactiveValueListenableBuilder<Set<SessionTimeRange>>(
                    formControlName: BrowseFilterControl.timeRanges,
                    builder: (context, control, _) =>
                        AppFilterOptionGroup<SessionTimeRange>(
                          values: SessionTimeRange.values,
                          selected: control.value ?? const {},
                          label: (range) => _timeRangeLabel(l10n, range),
                          icon: _timeRangeIcon,
                          itemKey: (range) => Key(
                            'session-filter-time-${range.name}',
                          ),
                          onSelected: (range) => _toggleSet(
                            BrowseFilterControl.timeRanges,
                            range,
                          ),
                        ),
                  ),
                ),
                AppFilterSection(
                  title: l10n.sessionFilterQuick,
                  icon: AppIcons.sparkles,
                  selectedCount:
                      (pending.hasSlots ? 1 : 0) +
                      (pending.nearMe ? 1 : 0) +
                      (pending.courtCount != null ? 1 : 0),
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      ReactiveValueListenableBuilder<bool>(
                        formControlName: BrowseFilterControl.hasSlots,
                        builder: (context, control, _) {
                          final isSelected = control.value ?? false;
                          return AppFilterChip(
                            key: const Key('session-filter-has-slots'),
                            label: l10n.sessionFilterAvailableSlots,
                            selected: isSelected,
                            avatar: Icon(
                              AppIcons.userCheck,
                              size: 16,
                              color: isSelected
                                  ? scheme.primary
                                  : palette.mutedForeground,
                            ),
                            onSelected: (value) => control.value = value,
                          );
                        },
                      ),
                      ReactiveValueListenableBuilder<bool>(
                        formControlName: BrowseFilterControl.nearMe,
                        builder: (context, control, _) {
                          final isSelected = control.value ?? false;
                          return AppFilterChip(
                            key: const Key('session-filter-near-me'),
                            label: l10n.sessionFilterNearMe,
                            selected: isSelected,
                            avatar: _isLocating
                                ? const SizedBox.square(
                                    dimension: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    AppIcons.myLocation,
                                    size: 16,
                                    color: isSelected
                                        ? scheme.primary
                                        : palette.mutedForeground,
                                  ),
                            onSelected: _isLocating
                                ? null
                                : (_) => _toggleNearMe(),
                          );
                        },
                      ),
                      for (final courtCount in SessionCourtCountFilter.values)
                        ReactiveValueListenableBuilder<SessionCourtCountFilter>(
                          formControlName: BrowseFilterControl.courtCount,
                          builder: (context, control, _) {
                            final isSelected = control.value == courtCount;
                            final isFourPlus =
                                courtCount == SessionCourtCountFilter.fourPlus;
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
                                  'session-filter-courts-${courtCount.name}',
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
                AppFilterSection(
                  title: l10n.sessionFilterSport,
                  icon: AppIcons.court,
                  selectedCount: pending.sports.length,
                  child: ReactiveValueListenableBuilder<Set<SessionSport>>(
                    formControlName: BrowseFilterControl.sports,
                    builder: (context, control, _) =>
                        AppFilterOptionGroup<SessionSport>(
                          values: SessionSport.values,
                          selected: control.value ?? const {},
                          label: (sport) => _sportLabel(l10n, sport),
                          avatarBuilder: (context, sport, isSelected) =>
                              switch (sport) {
                                SessionSport.badminton => Image.asset(
                                  'assets/icons/shuttlecock.png',
                                  width: 16,
                                  height: 16,
                                ),
                                SessionSport.pickleball => Icon(
                                  Icons.sports_tennis,
                                  size: 16,
                                  color: isSelected
                                      ? scheme.primary
                                      : palette.mutedForeground,
                                ),
                              },
                          itemKey: (sport) => Key(
                            'session-filter-sport-${sport.name}',
                          ),
                          onSelected: (sport) =>
                              _toggleSet(BrowseFilterControl.sports, sport),
                        ),
                  ),
                ),
                AppFilterSection(
                  key: const Key('session-filter-area-section'),
                  title: l10n.sessionFilterArea,
                  icon: AppIcons.mapPin,
                  selectedCount:
                      pending.districts.length +
                      (pending.city != null && !pending.cityIsDefault ? 1 : 0),
                  child: Column(
                    children: [
                      ReactiveValueListenableBuilder<String>(
                        formControlName: BrowseFilterControl.city,
                        builder: (context, cityControl, _) {
                          final selectedCity = cityControl.value;
                          final hasCityValue =
                              selectedCity != null &&
                              selectedCity.trim().isNotEmpty;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('session-filter-city'),
                              onTap: () => _pickCity(
                                context,
                                cities,
                                cityControl,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  border: Border.all(
                                    color: hasCityValue
                                        ? scheme.primary
                                        : palette.border,
                                    width: hasCityValue ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      AppIcons.location,
                                      size: 20,
                                      color: hasCityValue
                                          ? scheme.primary
                                          : palette.mutedForeground,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        hasCityValue
                                            ? selectedCity
                                            : l10n.citySelectorAllPlaces,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: hasCityValue
                                                  ? scheme.onSurface
                                                  : palette.mutedForeground,
                                              fontWeight: hasCityValue
                                                  ? FontWeight.w500
                                                  : FontWeight.normal,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasCityValue)
                                      IconButton(
                                        tooltip: l10n.commonDelete,
                                        icon: const Icon(
                                          AppIcons.close,
                                          size: 18,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          cityControl.value = null;
                                          _form
                                                  .control(
                                                    BrowseFilterControl
                                                        .districts,
                                                  )
                                                  .value =
                                              <String>{};
                                        },
                                      )
                                    else
                                      Icon(
                                        AppIcons.chevronDown,
                                        size: 18,
                                        color: palette.mutedForeground,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ReactiveValueListenableBuilder<String>(
                        formControlName: BrowseFilterControl.city,
                        builder: (context, cityControl, _) {
                          final selectedCity = cityControl.value;
                          final isCitySelected =
                              selectedCity != null &&
                              selectedCity.trim().isNotEmpty;

                          return ReactiveValueListenableBuilder<Set<String>>(
                            formControlName: BrowseFilterControl.districts,
                            builder: (context, districtControl, _) {
                              final selectedDistricts =
                                  districtControl.value ?? const <String>{};
                              final hasDistricts = selectedDistricts.isNotEmpty;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      key: const Key(
                                        'session-filter-districts',
                                      ),
                                      onTap: isCitySelected
                                          ? () => _pickDistricts(
                                              units,
                                              selectedCity,
                                              districtControl,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 48,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                          vertical: AppSpacing.sm,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCitySelected
                                              ? theme.colorScheme.surface
                                              : palette.muted.withValues(
                                                  alpha: 0.2,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.lg,
                                          ),
                                          border: Border.all(
                                            color: isCitySelected
                                                ? (hasDistricts
                                                      ? scheme.primary
                                                      : palette.border)
                                                : palette.border.withValues(
                                                    alpha: 0.4,
                                                  ),
                                            width: hasDistricts ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              AppIcons.mapPin,
                                              size: 20,
                                              color: isCitySelected
                                                  ? (hasDistricts
                                                        ? scheme.primary
                                                        : palette
                                                              .mutedForeground)
                                                  : palette.mutedForeground
                                                        .withValues(alpha: 0.4),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            Expanded(
                                              child: Text(
                                                !isCitySelected
                                                    ? l10n.citySelectorTitle
                                                    : (hasDistricts
                                                          ? l10n.sessionFilterSelectedCount(
                                                              selectedDistricts
                                                                  .length,
                                                            )
                                                          : l10n.sessionFilterDistricts),
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: !isCitySelected
                                                          ? palette
                                                                .mutedForeground
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                )
                                                          : (hasDistricts
                                                                ? scheme
                                                                      .onSurface
                                                                : palette
                                                                      .mutedForeground),
                                                      fontWeight: hasDistricts
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (hasDistricts) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: scheme.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppRadius.pill,
                                                      ),
                                                ),
                                                child: Text(
                                                  '${selectedDistricts.length}',
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: scheme.onPrimary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                            ],
                                            Icon(
                                              AppIcons.chevronDown,
                                              size: 18,
                                              color: isCitySelected
                                                  ? palette.mutedForeground
                                                  : palette.mutedForeground
                                                        .withValues(alpha: 0.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasDistricts) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: [
                                        for (final district
                                            in selectedDistricts)
                                          InputChip(
                                            label: Text(district),
                                            deleteIconColor: scheme.primary,
                                            onDeleted: () => _toggleSet(
                                              BrowseFilterControl.districts,
                                              district,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                AppFilterSection(
                  key: const Key('session-filter-level-section'),
                  title: l10n.sessionFilterLevel,
                  icon: AppIcons.award,
                  selectedCount: pending.levels.length,
                  child: ReactiveValueListenableBuilder<Set<int>>(
                    formControlName: BrowseFilterControl.levels,
                    builder: (context, control, _) => AppFilterOptionGroup<int>(
                      values: const [9, 1, 10, 2, 3, 4, 5, 6, 7, 8],
                      selected: control.value ?? const {},
                      label: l10n.levelName,
                      itemKey: (level) => Key('session-filter-level-$level'),
                      onSelected: (level) =>
                          _toggleSet(BrowseFilterControl.levels, level),
                    ),
                  ),
                ),
                AppFilterSection(
                  key: const Key('session-filter-cost-section'),
                  title: 'Phí',
                  icon: AppIcons.banknote,
                  selectedCount:
                      (pending.hasCustomFeeRange ? 1 : 0) +
                      (pending.splitEvenly ? 1 : 0),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final fields = <Widget>[
                            ReactiveTextField<int>(
                              key: const Key('session-filter-min-fee'),
                              formControlName: BrowseFilterControl.minFee,
                              valueAccessor: CurrencyValueAccessor(),
                              inputFormatters: [ThousandsSeparatorFormatter()],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.sessionFilterMinFee,
                                suffixText: 'VND',
                              ),
                            ),
                            ReactiveTextField<int>(
                              key: const Key('session-filter-max-fee'),
                              formControlName: BrowseFilterControl.maxFee,
                              valueAccessor: CurrencyValueAccessor(),
                              inputFormatters: [ThousandsSeparatorFormatter()],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.sessionFilterMaxFee,
                                suffixText: 'VND',
                              ),
                            ),
                          ];
                          if (constraints.maxWidth < 360) {
                            return Column(
                              children: [
                                fields.first,
                                const SizedBox(height: AppSpacing.sm),
                                fields.last,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: fields.first),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: fields.last),
                            ],
                          );
                        },
                      ),
                      ReactiveFormConsumer(
                        builder: (context, form, _) {
                          if (!form.touched || form.valid) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                form.hasError('feeRange')
                                    ? l10n.sessionFilterFeeRangeInvalid
                                    : l10n.sessionFilterFeeInvalid,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      ReactiveCheckboxListTile(
                        key: const Key('session-filter-split-evenly'),
                        formControlName: BrowseFilterControl.splitEvenly,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.sessionFilterSplitEvenly),
                      ),
                    ],
                  ),
                ),
                AppFilterSection(
                  key: const Key('session-filter-source-section'),
                  title: l10n.sessionFilterSource,
                  icon: AppIcons.link,
                  selectedCount: pending.source != SessionSource.all ? 1 : 0,
                  showDivider: false,
                  child: ReactiveValueListenableBuilder<SessionSource>(
                    formControlName: BrowseFilterControl.source,
                    builder: (context, control, _) =>
                        AppFilterOptionGroup<SessionSource>(
                          values: SessionSource.values,
                          selected: {control.value ?? SessionSource.all},
                          label: (source) => _sourceLabel(l10n, source),
                          icon: (source) => switch (source) {
                            SessionSource.all => AppIcons.grid,
                            SessionSource.regular => AppIcons.verified,
                            SessionSource.facebook => AppIcons.facebook,
                          },
                          itemKey: (source) => Key(
                            'session-filter-source-${source.name}',
                          ),
                          onSelected: (source) => control.value = source,
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

  Future<void> _pickDate(
    BuildContext context,
    AbstractControl<DateTime> control,
  ) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));

    // Track the selected date locally inside the sheet
    DateTime? sheetDate = control.value;

    final result = await showModalBottomSheet<Object>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isToday =
              sheetDate != null && DateUtils.isSameDay(sheetDate, today);
          final isTomorrow =
              sheetDate != null && DateUtils.isSameDay(sheetDate, tomorrow);
          final calendarDate = sheetDate ?? today;
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            // Material wraps SafeArea (not the other way around) so the
            // sheet's surface color still paints behind the bottom safe
            // area (e.g. the iOS home indicator strip) instead of leaving
            // it transparent — SafeArea only insets the content from it.
            child: Material(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSheetHeader(
                      title: l10n.sessionFilterDate,
                      showCloseButton: true,
                    ),
                    // Preset chips
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          _PresetChip(
                            label: l10n.sessionFilterAllDates,
                            isSelected: sheetDate == null,
                            onTap: () => setState(() => sheetDate = null),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _PresetChip(
                            label: 'Hôm nay',
                            isSelected: isToday,
                            onTap: () => setState(() => sheetDate = today),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _PresetChip(
                            label: 'Ngày mai',
                            isSelected: isTomorrow,
                            onTap: () => setState(() => sheetDate = tomorrow),
                          ),
                        ],
                      ),
                    ),
                    // Calendar — keyed by the active date so its internal
                    // selection resets when a preset chip changes the date.
                    // CalendarDatePicker only reads `initialDate` once
                    // (in initState), so without a key it ignores updates to
                    // that value on rebuild and keeps showing the old day.
                    CalendarDatePicker(
                      key: ValueKey(calendarDate),
                      initialDate: calendarDate,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 365)),
                      onDateChanged: (date) =>
                          setState(() => sheetDate = DateUtils.dateOnly(date)),
                    ),
                    // Action bar — same icon + fill layout as the "Bộ lọc"
                    // sheet's footer buttons.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: AppSheetFooterButtons(
                        secondaryLabel: l10n.commonCancel,
                        secondaryIcon: AppIcons.close,
                        onSecondary: () => Navigator.pop(context),
                        primaryLabel: l10n.commonDone,
                        primaryIcon: AppIcons.check,
                        onPrimary: () => Navigator.pop(
                          context,
                          sheetDate ?? _allDatesSelection,
                        ),
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
    // A null result means the sheet was cancelled or dismissed without a
    // choice — leave the current filter untouched rather than clearing it.
    if (!mounted || result == null) return;
    control.value = result is DateTime ? result : null;
  }

  Future<void> _pickCity(
    BuildContext context,
    List<String> cities,
    AbstractControl<String> cityControl,
  ) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = theme.extension<AppPalette>()!;
    String query = '';
    String? selected = cityControl.value;

    final result = await showModalBottomSheet<String?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filtered = query.isEmpty
              ? cities
              : cities
                    .where(
                      (city) =>
                          citySearchKey(city).contains(citySearchKey(query)),
                    )
                    .toList(growable: false);
          // Material wraps SafeArea (not the other way around) so the
          // sheet's surface color still paints behind the bottom safe area
          // instead of leaving it transparent there.
          return Material(
            color: scheme.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .75,
                child: Column(
                  children: [
                    AppSheetHeader(
                      title: l10n.sessionFilterCity,
                      showCloseButton: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: TextField(
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: 'Tìm tỉnh / thành phố...',
                          prefixIcon: const Icon(AppIcons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide(color: palette.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        onChanged: (v) => setState(() => query = v),
                      ),
                    ),
                    const Divider(height: 1),
                    // "All places" option
                    ListTile(
                      leading: Icon(
                        AppIcons.language,
                        size: 18,
                        color: selected == null
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(
                        l10n.citySelectorAllPlaces,
                        style: TextStyle(
                          color: selected == null ? scheme.primary : null,
                          fontWeight: selected == null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: selected == null
                          ? Icon(
                              AppIcons.checkCircle,
                              color: scheme.primary,
                              size: 20,
                            )
                          : null,
                      onTap: () => setState(() => selected = null),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(child: Text(l10n.citySelectorNoResults))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final city = filtered[index];
                                final isActive = city == selected;
                                return ListTile(
                                  leading: Icon(
                                    AppIcons.mapPin,
                                    size: 18,
                                    color: isActive
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                  title: Text(
                                    city,
                                    style: TextStyle(
                                      color: isActive ? scheme.primary : null,
                                      fontWeight: isActive
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: isActive
                                      ? Icon(
                                          AppIcons.checkCircle,
                                          color: scheme.primary,
                                          size: 20,
                                        )
                                      : null,
                                  selected: isActive,
                                  selectedTileColor: scheme.primary.withValues(
                                    alpha: .06,
                                  ),
                                  onTap: () => setState(() => selected = city),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: () => Navigator.pop(context, selected),
                        child: Text(l10n.commonDone),
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
    if (!mounted) return;
    if (result != cityControl.value) {
      cityControl.value = result;
      _form.control(BrowseFilterControl.districts).value = <String>{};
    }
  }

  Future<void> _pickDistricts(
    List<NewAdminUnit> units,
    String? city,
    AbstractControl<Set<String>> control,
  ) async {
    final normalizedCity = normalizeCityName(city ?? '');
    final wards = units
        .where(
          (unit) => normalizeCityName(unit.city) == normalizedCity,
        )
        .expand((unit) => unit.wards)
        .toList(growable: false);
    final selected = {...?control.value};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = AppLocalizations.of(context);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .75,
              child: Column(
                children: [
                  AppSheetHeader(
                    title: l10n.sessionFilterDistricts,
                    subtitle: city,
                    titleTrailing: selected.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              '${selected.length}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : null,
                    showCloseButton: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: wards.isEmpty
                              ? null
                              : () => setState(() {
                                  if (selected.length == wards.length) {
                                    selected.clear();
                                  } else {
                                    selected.addAll(wards);
                                  }
                                }),
                          child: Text(
                            selected.length == wards.length
                                ? l10n.homeSearchClearAll
                                : l10n.citySelectorAll,
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, selected),
                          child: Text(l10n.commonDone),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: wards.isEmpty
                        ? Center(
                            child: Text(
                              l10n.sessionFilterNoDistricts,
                            ),
                          )
                        : ListView.builder(
                            itemCount: wards.length,
                            itemBuilder: (context, index) {
                              final ward = wards[index];
                              return CheckboxListTile(
                                value: selected.contains(ward),
                                title: Text(ward),
                                onChanged: (checked) => setState(() {
                                  checked ?? false
                                      ? selected.add(ward)
                                      : selected.remove(ward);
                                }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result != null) control.value = result;
  }
}

String _timeRangeLabel(AppLocalizations l10n, SessionTimeRange value) =>
    switch (value) {
      SessionTimeRange.morning => l10n.sessionFilterMorning,
      SessionTimeRange.afternoon => l10n.sessionFilterAfternoon,
      SessionTimeRange.evening => l10n.sessionFilterEvening,
      SessionTimeRange.night => l10n.sessionFilterNight,
    };

IconData _timeRangeIcon(SessionTimeRange value) => switch (value) {
  SessionTimeRange.morning => AppIcons.light,
  SessionTimeRange.afternoon => AppIcons.light,
  SessionTimeRange.evening => AppIcons.clock,
  SessionTimeRange.night => AppIcons.dark,
};

String _sourceLabel(AppLocalizations l10n, SessionSource value) =>
    switch (value) {
      SessionSource.all => l10n.sessionSourceAll,
      SessionSource.regular => l10n.sessionSourceRegular,
      SessionSource.facebook => l10n.sessionSourceFacebook,
    };

String _sportLabel(AppLocalizations l10n, SessionSport value) =>
    switch (value) {
      SessionSport.badminton => l10n.sessionSportBadminton,
      SessionSport.pickleball => l10n.sessionSportPickleball,
    };

/// Sentinel returned by the date picker sheet when "Xong" is pressed with
/// the "Tất cả ngày" preset active, distinguishing that from a cancelled
/// sheet (which pops `null` and leaves the current filter untouched).
class _AllDatesSelection {
  const _AllDatesSelection();
}

const _allDatesSelection = _AllDatesSelection();

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppPalette>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 4,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: .12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? scheme.primary : palette.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
