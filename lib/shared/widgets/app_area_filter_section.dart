import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

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
          final cities = widget.cities;
          final filtered = query.isEmpty
              ? cities
              : cities
                    .where(
                      (city) =>
                          citySearchKey(city).contains(citySearchKey(query)),
                    )
                    .toList(growable: false);
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
    final selected = {...?control.value};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = AppLocalizations.of(context);
          final scheme = Theme.of(context).colorScheme;
          final allSelected =
              wards.isNotEmpty && selected.length == wards.length;
          final anySelected = selected.isNotEmpty;
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
                      title: l10n.sessionFilterDistricts,
                      subtitle: city,
                      titleTrailing: selected.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                '${selected.length}',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : null,
                      showCloseButton: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: Text(
                        l10n.citySelectorAll,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: allSelected ? true : (anySelected ? null : false),
                      tristate: true,
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: wards.isEmpty
                          ? null
                          : (_) => setState(() {
                              if (allSelected) {
                                selected.clear();
                              } else {
                                selected.addAll(wards);
                              }
                            }),
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
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                  onChanged: (checked) => setState(() {
                                    checked ?? false
                                        ? selected.add(ward)
                                        : selected.remove(ward);
                                  }),
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
                          IconButton(
                            tooltip: l10n.commonDelete,
                            icon: const Icon(AppIcons.close, size: 18),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              cityControl.value = null;
                              _clearDistricts();
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
            formControlName: widget.cityControlName,
            builder: (context, cityControl, _) {
              final selectedCity = cityControl.value;
              final isCitySelected =
                  selectedCity != null && selectedCity.trim().isNotEmpty;

              return ReactiveValueListenableBuilder<Set<String>>(
                formControlName: widget.districtsControlName,
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
                          key: widget.districtPickerKey,
                          onTap: isCitySelected
                              ? () => _pickDistricts(
                                  selectedCity,
                                  districtControl,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isCitySelected
                                  ? theme.colorScheme.surface
                                  : palette.muted.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: isCitySelected
                                    ? (hasDistricts
                                          ? scheme.primary
                                          : palette.border)
                                    : palette.border.withValues(alpha: 0.4),
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
                                            : palette.mutedForeground)
                                      : palette.mutedForeground.withValues(
                                          alpha: 0.4,
                                        ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    !isCitySelected
                                        ? l10n.citySelectorTitle
                                        : (hasDistricts
                                              ? l10n.sessionFilterSelectedCount(
                                                  selectedDistricts.length,
                                                )
                                              : l10n.sessionFilterDistricts),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: !isCitySelected
                                          ? palette.mutedForeground.withValues(
                                              alpha: 0.5,
                                            )
                                          : (hasDistricts
                                                ? scheme.onSurface
                                                : palette.mutedForeground),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: Text(
                                      '${selectedDistricts.length}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: scheme.onPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                ],
                                Icon(
                                  AppIcons.chevronDown,
                                  size: 18,
                                  color: isCitySelected
                                      ? palette.mutedForeground
                                      : palette.mutedForeground.withValues(
                                          alpha: 0.3,
                                        ),
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
                            for (final district in selectedDistricts)
                              InputChip(
                                label: Text(district),
                                deleteIconColor: scheme.primary,
                                onDeleted: () => _toggleDistrict(district),
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
    );
  }
}
