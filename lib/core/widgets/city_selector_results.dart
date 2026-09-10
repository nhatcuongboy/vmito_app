import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/city_selector_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class CitySelectorResults extends StatelessWidget {
  const CitySelectorResults({
    required this.searchControlName,
    required this.cities,
    required this.selectedCity,
    required this.onSelected,
    this.selectionType,
    super.key,
  });

  final String searchControlName;
  final List<String> cities;
  final String? selectedCity;
  final LocationSelectionType? selectionType;
  final ValueChanged<CitySelection> onSelected;

  @override
  Widget build(BuildContext context) => ReactiveValueListenableBuilder<String>(
    formControlName: searchControlName,
    builder: (context, control, _) {
      final l10n = AppLocalizations.of(context);
      final query = citySearchKey(control.value ?? '');
      final visible = query.isEmpty
          ? cities
          : cities
                .where((city) => citySearchKey(city).contains(query))
                .toList(growable: false);
      final matchesOther =
          query.isNotEmpty &&
          citySearchKey(l10n.citySelectorOther).contains(query);

      if (visible.isEmpty && !matchesOther) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.searchOff,
                  size: 36,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.citySelectorNoResults,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  key: const Key('discovery-city-empty-other'),
                  onPressed: () => onSelected(const CitySelection.other()),
                  icon: const Icon(AppIcons.location, size: 18),
                  label: Text(l10n.citySelectorOther),
                ),
              ],
            ),
          ),
        );
      }
      final entries = query.isEmpty
          ? _groupedEntries(visible, l10n)
          : [
              ...visible.map<_ResultEntry>(_CityEntry.new),
              if (matchesOther) const _OtherEntry(),
            ];
      final isCitySelected =
          (selectionType == LocationSelectionType.city ||
              (selectionType == null && selectedCity != null)) &&
          selectedCity != null;
      return ListView.builder(
        key: const Key('city-selector-results'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return switch (entry) {
            _HeadingEntry(:final label) => _SectionHeading(label: label),
            _DividerEntry() => const _SectionDivider(),
            _BottomSpacingEntry() => const SizedBox(height: AppSpacing.xl),
            _AllEntry() => _CityRow(
              key: const Key('discovery-city-all'),
              label: l10n.citySelectorAll,
              isSelected: selectionType == LocationSelectionType.all,
              icon: AppIcons.language,
              onTap: () => onSelected(const CitySelection.all()),
            ),
            _OtherEntry() => _CityRow(
              key: const Key('discovery-city-other'),
              label: l10n.citySelectorOther,
              isSelected: selectionType == LocationSelectionType.other,
              icon: AppIcons.location,
              onTap: () => onSelected(const CitySelection.other()),
            ),
            _CityEntry(:final city) => _CityRow(
              key: Key('discovery-city-$city'),
              label: city,
              isSelected: isCitySelected && selectedCity == city,
              icon: AppIcons.mapPin,
              onTap: () => onSelected(CitySelection.city(city)),
            ),
          };
        },
      );
    },
  );

  List<_ResultEntry> _groupedEntries(
    List<String> visible,
    AppLocalizations l10n,
  ) {
    final popular = visible.where(isPopularCity).toList(growable: false);
    final remaining = visible
        .where((city) => !isPopularCity(city))
        .toList(growable: false);
    return [
      const _AllEntry(),
      if (popular.isNotEmpty) ...[
        _HeadingEntry(l10n.citySelectorPopular),
        ...popular.map(_CityEntry.new),
      ],
      if (remaining.isNotEmpty) ...[
        _HeadingEntry(l10n.citySelectorAllPlaces),
        ...remaining.map(_CityEntry.new),
      ],
      const _DividerEntry(),
      const _OtherEntry(),
      const _BottomSpacingEntry(),
    ];
  }
}

sealed class _ResultEntry {
  const _ResultEntry();
}

class _AllEntry extends _ResultEntry {
  const _AllEntry();
}

class _OtherEntry extends _ResultEntry {
  const _OtherEntry();
}

class _DividerEntry extends _ResultEntry {
  const _DividerEntry();
}

class _BottomSpacingEntry extends _ResultEntry {
  const _BottomSpacingEntry();
}

class _HeadingEntry extends _ResultEntry {
  const _HeadingEntry(this.label);

  final String label;
}

class _CityEntry extends _ResultEntry {
  const _CityEntry(this.city);

  final String city;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.xs,
    ),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.md,
    ),
    child: Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .3),
    ),
  );
}

class _CityRow extends StatelessWidget {
  const _CityRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool isSelected;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected
          ? colorScheme.primary.withValues(alpha: .09)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: 48,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        leading: icon == null
            ? null
            : Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.primary : null,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        trailing: isSelected
            ? Icon(AppIcons.checkCircle, color: colorScheme.primary, size: 20)
            : null,
        selected: isSelected,
        onTap: onTap,
      ),
    );
  }
}
