import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/widgets/city_selector_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

export 'package:vmito_app/core/widgets/city_onboarding_dialog.dart';

/// Compact entry point for the device-wide discovery city preference.
class CitySelector extends ConsumerWidget {
  const CitySelector({
    this.onChanged,
    this.showLabel = false,
    this.labelMaxWidth = 180,
    super.key,
  });

  final ValueChanged<String?>? onChanged;
  final bool showLabel;
  final double labelMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preference = ref.watch(locationPreferencesControllerProvider);
    final city = preference.preferredCity;
    final labelText = switch (preference.selectionType) {
      LocationSelectionType.other => l10n.citySelectorOther,
      LocationSelectionType.city =>
        (city?.trim().isNotEmpty ?? false) ? city! : l10n.citySelectorAll,
      _ => (city?.trim().isNotEmpty ?? false) ? city! : l10n.citySelectorAll,
    };
    void onPressed() => unawaited(_showSelector(context, ref));
    if (!showLabel) {
      return IconButton(
        key: const Key('discovery-city-selector'),
        tooltip: l10n.citySelectorTitle,
        onPressed: onPressed,
        icon: const Icon(AppIcons.location),
      );
    }
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final isActive = labelText != l10n.citySelectorAll;
    final foregroundColor = isActive
        ? theme.colorScheme.primary
        : palette.mutedForeground;
    return OutlinedButton(
      key: const Key('discovery-city-selector'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
        foregroundColor: foregroundColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.location, size: 18, color: foregroundColor),
          const SizedBox(width: 6),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: labelMaxWidth),
              child: Text(
                labelText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(AppIcons.chevronDown, size: 14),
        ],
      ),
    );
  }

  Future<void> _showSelector(BuildContext context, WidgetRef ref) async {
    final result = await showCitySelectorSheet(context);
    if (result == null || !context.mounted) return;
    final before = ref.read(locationPreferencesControllerProvider);
    final notifier = ref.read(locationPreferencesControllerProvider.notifier);
    switch (result.type) {
      case LocationSelectionType.city:
        await notifier.selectCity(result.city);
      case LocationSelectionType.all:
        await notifier.selectAll();
      case LocationSelectionType.other:
        await notifier.selectOther();
    }
    if (before.onboardingCompleted &&
        before.selectionType == result.type &&
        before.preferredCity == result.city) {
      return;
    }
    onChanged?.call(result.city);
  }
}
