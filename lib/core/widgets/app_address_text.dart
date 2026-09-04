import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/address_display.dart';
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
    this.showNewAddressBadge = true,
    this.suffix,
    this.trailing,
    this.trailingWidth = 44,
    this.trailingSpacing = 4,
    super.key,
  });
  final String? address;
  final String? district;
  final String? city;
  final String? newAddress;
  final String? newDistrict;
  final String? newCity;
  final TextStyle? style;
  final int? maxLines;
  final bool showNewAddressBadge;
  final String? suffix;
  final Widget? trailing;
  final double trailingWidth;
  final double trailingSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showNew = ref
        .watch(locationPreferencesControllerProvider)
        .showNewAddress;
    final resolved = resolveAppAddress(
      showNewAddress: showNew,
      address: address,
      district: district,
      city: city,
      newAddress: newAddress,
      newDistrict: newDistrict,
      newCity: newCity,
    );
    final label = resolved.text;
    final l10n = AppLocalizations.of(context);
    final showNewBadge = showNewAddressBadge && resolved.isNew;

    InlineSpan contentSpan(
      String text, {
      required bool includeDetails,
      bool includeTrailing = false,
    }) => TextSpan(
      text: text,
      children: [
        if (includeDetails && showNewBadge)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _NewAddressBadge(label: l10n.addressNewBadge),
          ),
        if (includeDetails && suffix != null) TextSpan(text: suffix),
        if (includeTrailing && trailing != null)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(left: trailingSpacing),
              child: SizedBox(width: trailingWidth, child: trailing),
            ),
          ),
      ],
    );

    if (trailing == null) {
      return Text.rich(
        contentSpan(label, includeDetails: true),
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text.rich(
      contentSpan(
        label,
        includeDetails: true,
        includeTrailing: true,
      ),
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}

class _NewAddressBadge extends StatelessWidget {
  const _NewAddressBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
