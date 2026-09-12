import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/city_selector_ward_field.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/area_picker_sheets.dart';

class AppAreaFilterSection extends ConsumerStatefulWidget {
  const AppAreaFilterSection({
    required this.form,
    required this.cityControlName,
    required this.districtsControlName,
    required this.cities,
    required this.units,
    required this.selectedCount,
    this.cityPickerKey,
    this.districtPickerKey,
    this.extraDistrictControlName,
    super.key,
  });

  final FormGroup form;
  final String cityControlName;
  final String districtsControlName;
  final List<String> cities;
  final List<NewAdminUnit> units;
  final int selectedCount;
  final Key? cityPickerKey;
  final Key? districtPickerKey;
  final String? extraDistrictControlName;

  @override
  ConsumerState<AppAreaFilterSection> createState() =>
      _AppAreaFilterSectionState();
}

class _AppAreaFilterSectionState extends ConsumerState<AppAreaFilterSection> {
  FormGroup get _form => widget.form;

  void _clearDistricts() {
    _form.control(widget.districtsControlName).value = <String>{};
    final extra = widget.extraDistrictControlName;
    if (extra != null && _form.contains(extra)) {
      _form.control(extra).value = null;
    }
  }

  void _toggleDistrict(String district) {
    final control =
        _form.control(widget.districtsControlName) as FormControl<Set<String>>;
    final next = {...?control.value};
    next.contains(district) ? next.remove(district) : next.add(district);
    control.value = next;
  }

  Future<void> _pickCity(
    BuildContext context,
    AbstractControl<String> cityControl,
  ) async {
    final result = await showCityPickerSheet(
      context,
      cities: widget.cities,
      selectedCity: cityControl.value,
    );
    if (!mounted || result == null) return;
    if (result.city != cityControl.value) {
      cityControl.value = result.city;
      _clearDistricts();
    }
  }

  Future<void> _pickDistricts(
    String? city,
    AbstractControl<Set<String>> control,
  ) async {
    final normalizedCity = normalizeCityName(city ?? '');
    final wards = widget.units
        .where(
          (unit) => normalizeCityName(unit.city) == normalizedCity,
        )
        .expand((unit) => unit.wards)
        .toList(growable: false);
    final result = await showWardPickerSheet(
      context,
      city: city,
      wards: wards,
      selected: {...?control.value},
    );
    if (result != null) control.value = result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final scheme = theme.colorScheme;

    return AppFilterSection(
      title: l10n.sessionFilterArea,
      icon: AppIcons.mapPin,
      selectedCount: widget.selectedCount,
      child: Column(
        children: [
          ReactiveValueListenableBuilder<String>(
            formControlName: widget.cityControlName,
            builder: (context, cityControl, _) {
              final selectedCity = cityControl.value;
              final hasCityValue =
                  selectedCity != null && selectedCity.trim().isNotEmpty;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  key: widget.cityPickerKey,
                  onTap: () => _pickCity(context, cityControl),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: hasCityValue ? scheme.primary : palette.border,
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
                            style: theme.textTheme.bodyMedium?.copyWith(
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
                          InkWell(
                            onTap: () {
                              cityControl.value = null;
                              _clearDistricts();
                            },
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(AppSpacing.xxs),
                              child: Icon(AppIcons.close, size: 18),
                            ),
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
            formControlName: widget.cityControlName,
            builder: (context, cityControl, _) {
              final selectedCity = cityControl.value;
              final isCitySelected =
                  selectedCity != null && selectedCity.trim().isNotEmpty;

              return ReactiveValueListenableBuilder<Set<String>>(
                formControlName: widget.districtsControlName,
                builder: (context, districtControl, _) => CitySelectorWardField(
                  key: widget.districtPickerKey,
                  wards: districtControl.value ?? const <String>{},
                  enabled: isCitySelected,
                  onTap: () => _pickDistricts(selectedCity, districtControl),
                  onClear: _clearDistricts,
                  onRemove: _toggleDistrict,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
