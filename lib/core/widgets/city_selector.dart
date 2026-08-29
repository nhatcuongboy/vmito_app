import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
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
    final city = ref.watch(locationPreferencesControllerProvider).preferredCity;
    void onPressed() => unawaited(_showSelector(context, ref));
    if (!showLabel) {
      return IconButton(
        key: const Key('discovery-city-selector'),
        tooltip: l10n.citySelectorTitle,
        onPressed: onPressed,
        icon: const Icon(AppIcons.location),
      );
    }
    return OutlinedButton.icon(
      key: const Key('discovery-city-selector'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(AppIcons.location, size: 18),
      label: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: labelMaxWidth),
        child: Text(
          city?.trim().isNotEmpty ?? false ? city! : l10n.citySelectorAll,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _showSelector(BuildContext context, WidgetRef ref) async {
    final result = await showCitySelectorSheet(context);
    if (result == null || !context.mounted) return;
    final before = ref.read(locationPreferencesControllerProvider);
    await ref
        .read(locationPreferencesControllerProvider.notifier)
        .selectCity(result.city);
    if (before.onboardingCompleted && before.preferredCity == result.city) {
      return;
    }
    onChanged?.call(result.city);
  }
}
