import 'package:flutter/material.dart';
import 'package:vmito_app/core/location/vietnam_locations.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/city_selector_compact_chip.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Quick-pick chips for the three cities the product wants surfaced above
/// the full province list: [vietnamCities] indices 0, 1, 3 (Hồ Chí Minh, Hà
/// Nội, Đà Nẵng) — the shared "popular" catalogue used elsewhere also keeps
/// index 2 (Huế); this curated set deliberately doesn't.
final List<String> kCitySelectorPopularCities = [
  vietnamCities[0],
  vietnamCities[1],
  vietnamCities[3],
];

/// Label on the left, compact chips scrolling horizontally on the right — a
/// single row rather than the full-size [AppFilterChip] wrapped below a
/// label, since there are only ever three quick picks here.
class CitySelectorPopularChips extends StatelessWidget {
  const CitySelectorPopularChips({
    required this.selectedCity,
    required this.onSelected,
    super.key,
  });

  final String? selectedCity;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Text(
          l10n.citySelectorPopular,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final city in kCitySelectorPopularCities) ...[
                  CitySelectorCompactChip(
                    label: city,
                    selected: selectedCity == city,
                    onTap: () => onSelected(city),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
