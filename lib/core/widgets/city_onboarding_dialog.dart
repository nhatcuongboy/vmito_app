import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/widgets/city_selector_sheet.dart';

class CityOnboardingDialog extends ConsumerWidget {
  const CityOnboardingDialog({super.key});

  static Future<CitySelection?> maybeShow(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final value = ref.read(locationPreferencesControllerProvider);
    if (!value.isRestored || value.onboardingCompleted) return null;
    final result = await showCitySelectorSheet(context, isOnboarding: true);
    if (result != null) {
      final notifier = ref.read(locationPreferencesControllerProvider.notifier);
      switch (result.type) {
        case LocationSelectionType.city:
          await notifier.selectCity(result.city);
        case LocationSelectionType.all:
          await notifier.selectAll();
        case LocationSelectionType.other:
          await notifier.selectOther();
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const CitySelectorSheet(isOnboarding: true);
}
