import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/location/vietnam_locations.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/browse_session_filters.dart';
import 'package:vmito_app/features/session/domain/form/browse_session_filter_form.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
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
        BrowseFilterControl.levels: FormControl<Set<int>>(
          value: {...initial.levels},
        ),
        BrowseFilterControl.minFee: FormControl<String>(
          value: '${initial.minFee}',
          validators: [Validators.required, Validators.number()],
        ),
        BrowseFilterControl.maxFee: FormControl<String>(
          value: '${initial.maxFee}',
          validators: [Validators.required, Validators.number()],
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
    final preferredCity = ref
        .read(locationPreferencesControllerProvider)
        .preferredCity;
    final city = _value<String>(BrowseFilterControl.city);
    Navigator.of(context).pop(
      BrowseSessionFilters(
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
        districts:
            _value<Set<String>>(BrowseFilterControl.districts) ?? const {},
        sports:
            _value<Set<SessionSport>>(BrowseFilterControl.sports) ?? const {},
        levels: _value<Set<int>>(BrowseFilterControl.levels) ?? const {},
        minFee: int.parse(_value<String>(BrowseFilterControl.minFee)!),
        maxFee: int.parse(_value<String>(BrowseFilterControl.maxFee)!),
        splitEvenly: _value<bool>(BrowseFilterControl.splitEvenly) ?? false,
        latitude: _coordinates?.latitude,
        longitude: _coordinates?.longitude,
      ),
    );
  }

  void _reset() {
    final city = ref.read(locationPreferencesControllerProvider).preferredCity;
    Navigator.of(context).pop(widget.initial.reset(preferredCity: city));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final unitsState = ref.watch(newAdminUnitsProvider);
    final units = unitsState.value ?? const <NewAdminUnit>[];
    final cities = units.isEmpty
        ? vietnamCities
        : units.map((unit) => unit.city).toList(growable: false);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: AppReactiveForm<void>(
          formGroup: _form,
          child: Column(
            children: [
              AppSheetHeader(
                title: l10n.sessionFiltersTitle,
                closeButtonKey: const Key('session-filter-close'),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(l10n.sessionFilterDate),
                      ReactiveDatePicker<DateTime>(
                        formControlName: BrowseFilterControl.date,
                        firstDate: today,
                        lastDate: today.add(
                          const Duration(days: 365),
                        ),
                        builder: (context, picker, _) => OutlinedButton.icon(
                          key: const Key('session-filter-date'),
                          onPressed: picker.showPicker,
                          icon: const Icon(AppIcons.calendar),
                          label: Text(
                            picker.value == null
                                ? l10n.sessionFilterAllDates
                                : DateFormat.yMd(
                                    Localizations.localeOf(context).toString(),
                                  ).format(picker.value!),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SectionTitle(l10n.sessionFilterTimeRange),
                      ReactiveValueListenableBuilder<Set<SessionTimeRange>>(
                        formControlName: BrowseFilterControl.timeRanges,
                        builder: (context, control, _) => Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final range in SessionTimeRange.values)
                              FilterChip(
                                key: Key('session-filter-time-${range.name}'),
                                label: Text(_timeRangeLabel(l10n, range)),
                                selected:
                                    control.value?.contains(range) ?? false,
                                onSelected: (_) => _toggleSet(
                                  BrowseFilterControl.timeRanges,
                                  range,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SectionTitle(l10n.sessionFilterQuick),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          ReactiveValueListenableBuilder<bool>(
                            formControlName: BrowseFilterControl.hasSlots,
                            builder: (context, control, _) => FilterChip(
                              key: const Key('session-filter-has-slots'),
                              label: Text(l10n.sessionFilterAvailableSlots),
                              selected: control.value ?? false,
                              onSelected: (value) => control.value = value,
                            ),
                          ),
                          ReactiveValueListenableBuilder<bool>(
                            formControlName: BrowseFilterControl.nearMe,
                            builder: (context, control, _) => FilterChip(
                              key: const Key('session-filter-near-me'),
                              avatar: _isLocating
                                  ? const SizedBox.square(
                                      dimension: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(AppIcons.myLocation, size: 16),
                              label: Text(l10n.sessionFilterNearMe),
                              selected: control.value ?? false,
                              onSelected: _isLocating
                                  ? null
                                  : (_) => _toggleNearMe(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SectionTitle(l10n.sessionFilterSource),
                      ReactiveValueListenableBuilder<SessionSource>(
                        formControlName: BrowseFilterControl.source,
                        builder: (context, control, _) => Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final source in SessionSource.values)
                              ChoiceChip(
                                key: Key(
                                  'session-filter-source-${source.name}',
                                ),
                                label: Text(_sourceLabel(l10n, source)),
                                selected: control.value == source,
                                onSelected: (_) => control.value = source,
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: AppSpacing.xl),
                      _SectionTitle(l10n.sessionFilterArea),
                      ReactiveDropdownField<String>(
                        key: const Key('session-filter-city'),
                        formControlName: BrowseFilterControl.city,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.sessionFilterCity,
                        ),
                        items: [
                          for (final city in cities)
                            DropdownMenuItem(value: city, child: Text(city)),
                        ],
                        onChanged: (_) =>
                            _form.control(BrowseFilterControl.districts).value =
                                <String>{},
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ReactiveValueListenableBuilder<String>(
                        formControlName: BrowseFilterControl.city,
                        builder: (context, cityControl, _) =>
                            ReactiveValueListenableBuilder<Set<String>>(
                              formControlName: BrowseFilterControl.districts,
                              builder: (context, districtControl, _) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  OutlinedButton.icon(
                                    key: const Key('session-filter-districts'),
                                    onPressed: () => _pickDistricts(
                                      units,
                                      cityControl.value,
                                      districtControl,
                                    ),
                                    icon: const Icon(AppIcons.mapPin),
                                    label: Text(
                                      districtControl.value?.isEmpty ?? true
                                          ? l10n.sessionFilterDistricts
                                          : l10n.sessionFilterSelectedCount(
                                              districtControl.value!.length,
                                            ),
                                    ),
                                  ),
                                  if (districtControl.value?.isNotEmpty ??
                                      false)
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      children: [
                                        for (final district
                                            in districtControl.value!)
                                          InputChip(
                                            label: Text(district),
                                            onDeleted: () => _toggleSet(
                                              BrowseFilterControl.districts,
                                              district,
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                      ),
                      const Divider(height: AppSpacing.xl),
                      _SectionTitle(l10n.sessionFilterSport),
                      ReactiveValueListenableBuilder<Set<SessionSport>>(
                        formControlName: BrowseFilterControl.sports,
                        builder: (context, control, _) => Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final sport in SessionSport.values)
                              FilterChip(
                                key: Key('session-filter-sport-${sport.name}'),
                                label: Text(_sportLabel(l10n, sport)),
                                selected:
                                    control.value?.contains(sport) ?? false,
                                onSelected: (_) => _toggleSet(
                                  BrowseFilterControl.sports,
                                  sport,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: AppSpacing.xl),
                      _SectionTitle(l10n.sessionFilterLevel),
                      ReactiveValueListenableBuilder<Set<int>>(
                        formControlName: BrowseFilterControl.levels,
                        builder: (context, control, _) => Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final level in [9, 1, 10, 2, 3, 4, 5, 6, 7, 8])
                              FilterChip(
                                key: Key('session-filter-level-$level'),
                                label: Text(l10n.levelName(level)),
                                selected:
                                    control.value?.contains(level) ?? false,
                                onSelected: (_) => _toggleSet(
                                  BrowseFilterControl.levels,
                                  level,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: AppSpacing.xl),
                      _SectionTitle(l10n.sessionFilterCost),
                      Row(
                        children: [
                          Expanded(
                            child: ReactiveTextField<String>(
                              key: const Key('session-filter-min-fee'),
                              formControlName: BrowseFilterControl.minFee,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.sessionFilterMinFee,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: Text('→'),
                          ),
                          Expanded(
                            child: ReactiveTextField<String>(
                              key: const Key('session-filter-max-fee'),
                              formControlName: BrowseFilterControl.maxFee,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.sessionFilterMaxFee,
                                suffixText: 'VND',
                              ),
                            ),
                          ),
                        ],
                      ),
                      ReactiveFormConsumer(
                        builder: (context, form, _) {
                          if (!form.touched || form.valid) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              form.hasError('feeRange')
                                  ? l10n.sessionFilterFeeRangeInvalid
                                  : l10n.sessionFilterFeeInvalid,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
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
              ),
              AppSheetActionBar(
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('session-filter-reset'),
                        onPressed: _reset,
                        icon: const Icon(AppIcons.close),
                        label: Text(l10n.sessionFiltersReset),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('session-filter-apply'),
                        onPressed: _apply,
                        icon: const Icon(AppIcons.check),
                        label: Text(l10n.sessionFiltersSearch),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDistricts(
    List<NewAdminUnit> units,
    String? city,
    AbstractControl<Set<String>> control,
  ) async {
    final wards = units
        .where((unit) => unit.city == city)
        .expand((unit) => unit.wards)
        .toList(growable: false);
    final selected = {...?control.value};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    AppLocalizations.of(context).sessionFilterDistricts,
                  ),
                  trailing: TextButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: Text(AppLocalizations.of(context).commonDone),
                  ),
                ),
                Expanded(
                  child: wards.isEmpty
                      ? Center(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).sessionFilterNoDistricts,
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
        ),
      ),
    );
    if (result != null) control.value = result;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

String _timeRangeLabel(AppLocalizations l10n, SessionTimeRange value) =>
    switch (value) {
      SessionTimeRange.morning => l10n.sessionFilterMorning,
      SessionTimeRange.afternoon => l10n.sessionFilterAfternoon,
      SessionTimeRange.evening => l10n.sessionFilterEvening,
      SessionTimeRange.night => l10n.sessionFilterNight,
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
