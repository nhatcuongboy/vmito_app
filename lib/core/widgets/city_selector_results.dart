import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class CitySelectorResults extends StatelessWidget {
  const CitySelectorResults({
    required this.searchControlName,
    required this.cities,
    required this.selectedCity,
    required this.onSelected,
    super.key,
  });

  final String searchControlName;
  final List<String> cities;
  final String? selectedCity;
  final ValueChanged<String?> onSelected;

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
      if (visible.isEmpty) {
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
              ],
            ),
          ),
        );
      }
      final entries = query.isEmpty
          ? _groupedEntries(visible, l10n)
          : visible.map<_ResultEntry>(_CityEntry.new).toList(growable: false);
      return ListView.separated(
        key: const Key('city-selector-results'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xxs),
        itemBuilder: (context, index) {
          return switch (entries[index]) {
            _HeadingEntry(:final label) => _SectionHeading(label: label),
            _AllEntry() => _CityRow(
              key: const Key('discovery-city-all'),
              label: l10n.citySelectorAll,
              isSelected: selectedCity == null,
              icon: AppIcons.language,
              onTap: () => onSelected(null),
            ),
            _CityEntry(:final city) => _CityRow(
              key: Key('discovery-city-$city'),
              label: city,
              isSelected: selectedCity == city,
              onTap: () => onSelected(city),
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
    ];
  }
}

sealed class _ResultEntry {
  const _ResultEntry();
}

class _AllEntry extends _ResultEntry {
  const _AllEntry();
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
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.xs,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
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
