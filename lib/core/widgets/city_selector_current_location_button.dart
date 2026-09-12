import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The "use my current location" action row: fills in the province field via
/// geolocation without closing the sheet. Presentational only — the caller
/// owns the async geolocate/reverse-geocode flow and loading/error state.
class CitySelectorCurrentLocationButton extends StatelessWidget {
  const CitySelectorCurrentLocationButton({
    required this.isLocating,
    required this.onPressed,
    this.hasError = false,
    super.key,
  });

  final bool isLocating;
  final VoidCallback? onPressed;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('city-selector-current-location'),
          onPressed: isLocating ? null : onPressed,
          icon: isLocating
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                )
              : const Icon(AppIcons.myLocation, size: 18),
          label: Text(
            isLocating
                ? l10n.citySelectorLocating
                : l10n.citySelectorUseCurrentLocation,
          ),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Container(
              key: const Key('city-selector-location-error'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.warning,
                    color: scheme.onErrorContainer,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.citySelectorLocationError,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
