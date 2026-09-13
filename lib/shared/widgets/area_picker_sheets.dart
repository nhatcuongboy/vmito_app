import 'package:flutter/material.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_area_filter_section.dart'
    show AppAreaFilterSection;
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

/// Wraps a [showCityPickerSheet] result so a dismiss (tap outside, back
/// button) — which resolves the sheet's future to `null` — can be told apart
/// from an explicit tap on "all places" (`CityPick(null)`).
class CityPick {
  const CityPick(this.city);
  final String? city;
}

/// Bottom-sheet-in-sheet province/city picker: search field, an "all
/// places" option, and a single-select list. Tapping a row immediately
/// picks it and closes the sheet — there is exactly one option to choose,
/// so a separate "Done" step only adds a tap. Shared by
/// [AppAreaFilterSection] and the top-level location selector so both
/// render an identical picker.
Future<CityPick?> showCityPickerSheet(
  BuildContext context, {
  required List<String> cities,
  required String? selectedCity,
}) {
  var query = '';

  return showModalBottomSheet<CityPick>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final palette = theme.extension<AppPalette>()!;
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
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: l10n.citySelectorSearchHint,
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
                      color: selectedCity == null
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      l10n.citySelectorAllPlaces,
                      style: TextStyle(
                        color: selectedCity == null ? scheme.primary : null,
                        fontWeight: selectedCity == null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selectedCity == null
                        ? Icon(
                            AppIcons.checkCircle,
                            color: scheme.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, const CityPick(null)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text(l10n.citySelectorNoResults))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final city = filtered[index];
                              final isActive = city == selectedCity;
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
                                onTap: () =>
                                    Navigator.pop(context, CityPick(city)),
                              );
                            },
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

/// Bottom-sheet-in-sheet ward/commune picker: a tristate "select all" tile
/// plus a multi-select checkbox list. Shared by [AppAreaFilterSection] and
/// the top-level location selector so both render an identical picker.
Future<Set<String>?> showWardPickerSheet(
  BuildContext context, {
  required String? city,
  required List<String> wards,
  required Set<String> selected,
}) {
  final pending = {...selected};
  return showModalBottomSheet<Set<String>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        final allSelected = wards.isNotEmpty && pending.length == wards.length;
        final anySelected = pending.isNotEmpty;
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
                    titleTrailing: pending.isNotEmpty
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
                              '${pending.length}',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : null,
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
                              pending.clear();
                            } else {
                              pending
                                ..clear()
                                ..addAll(wards);
                            }
                          }),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: wards.isEmpty
                        ? Center(child: Text(l10n.sessionFilterNoDistricts))
                        : ListView.builder(
                            itemCount: wards.length,
                            itemBuilder: (context, index) {
                              final ward = wards[index];
                              return CheckboxListTile(
                                value: pending.contains(ward),
                                title: Text(ward),
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                                onChanged: (checked) => setState(() {
                                  checked ?? false
                                      ? pending.add(ward)
                                      : pending.remove(ward);
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
                      onPressed: () => Navigator.pop(context, pending),
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
}
