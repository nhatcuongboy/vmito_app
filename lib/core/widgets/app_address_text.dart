import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// One consistent address line for every discovery surface.
class AppAddressText extends ConsumerWidget {
  const AppAddressText({
    required this.address,
    required this.district,
    required this.city,
    this.newAddress,
    this.newDistrict,
    this.newCity,
    this.style,
    this.maxLines = 1,
    this.suffix,
    super.key,
  });
  final String? address;
  final String? district;
  final String? city;
  final String? newAddress;
  final String? newDistrict;
  final String? newCity;
  final TextStyle? style;
  final int maxLines;
  final String? suffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showNew = ref
        .watch(locationPreferencesControllerProvider)
        .showNewAddress;
    final hasNew = newAddress?.trim().isNotEmpty ?? false;
    final values = showNew && hasNew
        ? [newAddress, newDistrict, newCity]
        : [address, district, city];
    final label = values
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    return Text.rich(
      TextSpan(
        text: label,
        children: [
          if (showNew && hasNew)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      AppLocalizations.of(context).addressNewBadge,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (suffix != null) TextSpan(text: suffix),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
