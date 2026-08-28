import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
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
        return Center(child: Text(l10n.citySelectorNoResults));
      }
      return ListView(
        key: const Key('city-selector-results'),
        children: [
          if (query.isEmpty)
            _CityRow(
              key: const Key('discovery-city-all'),
              label: l10n.citySelectorAll,
              isSelected: selectedCity == null,
              onTap: () => onSelected(null),
            ),
          for (final city in visible)
            _CityRow(
              key: Key('discovery-city-$city'),
              label: city,
              isSelected: selectedCity == city,
              onTap: () => onSelected(city),
            ),
        ],
      );
    },
  );
}

class _CityRow extends StatelessWidget {
  const _CityRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(
      label,
      style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : null),
    ),
    trailing: isSelected ? const Icon(AppIcons.check) : null,
    selected: isSelected,
    onTap: onTap,
  );
}
