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
  final int maxLines;
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
    );
    final label = resolved.text;
    final l10n = AppLocalizations.of(context);
    final showNewBadge = showNewAddressBadge && resolved.isNew;

    InlineSpan contentSpan(String text, {required bool includeDetails}) =>
        TextSpan(
          text: text,
          children: [
            if (includeDetails && showNewBadge)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _NewAddressBadge(label: l10n.addressNewBadge),
              ),
            if (includeDetails && suffix != null) TextSpan(text: suffix),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final finalLineWidth =
            constraints.maxWidth - trailingWidth - trailingSpacing;
        if (maxLines <= 1 || finalLineWidth <= 0) {
          return Row(
            children: [
              Expanded(
                child: Text.rich(
                  contentSpan(label, includeDetails: true),
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: trailingSpacing),
              SizedBox(width: trailingWidth, child: trailing),
            ],
          );
        }

        final splitIndex = _trailingLineSplit(
          context: context,
          label: label,
          availableWidth: finalLineWidth,
          style: style,
          includeNewBadge: showNewBadge,
          newBadgeLabel: l10n.addressNewBadge,
          suffix: suffix,
        );
        final leadingText = label.substring(0, splitIndex).trimRight();
        final trailingText = label.substring(splitIndex).trimLeft();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leadingText.isNotEmpty)
              Text(
                leadingText,
                style: style,
                maxLines: maxLines - 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    contentSpan(trailingText, includeDetails: true),
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: trailingSpacing),
                SizedBox(width: trailingWidth, child: trailing),
              ],
            ),
          ],
        );
      },
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

int _trailingLineSplit({
  required BuildContext context,
  required String label,
  required double availableWidth,
  required TextStyle? style,
  required bool includeNewBadge,
  required String newBadgeLabel,
  required String? suffix,
}) {
  final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
  final badgeStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
    color: Colors.blue.shade700,
    fontWeight: FontWeight.w600,
  );
  final textScaler = MediaQuery.textScalerOf(context);
  final badgePainter = TextPainter(
    text: TextSpan(text: newBadgeLabel, style: badgeStyle),
    textDirection: Directionality.of(context),
    textScaler: textScaler,
  )..layout();
  final badgeSize = Size(badgePainter.width + 12, badgePainter.height + 2);

  bool fits(String candidate) {
    final span = TextSpan(
      text: candidate,
      style: effectiveStyle,
      children: [
        if (includeNewBadge)
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox.shrink(),
          ),
        if (suffix != null) TextSpan(text: suffix),
      ],
    );
    final painter = TextPainter(
      text: span,
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 1,
    );
    if (includeNewBadge) {
      painter.setPlaceholderDimensions([
        PlaceholderDimensions(
          size: badgeSize,
          alignment: PlaceholderAlignment.middle,
        ),
      ]);
    }
    painter.layout(maxWidth: availableWidth);
    return !painter.didExceedMaxLines;
  }

  if (fits(label)) return 0;
  for (final whitespace in RegExp(r'\s+').allMatches(label)) {
    if (fits(label.substring(whitespace.end))) return whitespace.end;
  }
  return 0;
}
