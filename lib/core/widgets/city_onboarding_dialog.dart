import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/city_selector_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class CityOnboardingDialog extends ConsumerWidget {
  const CityOnboardingDialog({super.key});

  static Future<CitySelection?> maybeShow(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final value = ref.read(locationPreferencesControllerProvider);
    if (!value.isRestored || value.onboardingCompleted) return null;
    return showDialog<CitySelection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CityOnboardingDialog(),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    String city,
  ) async {
    await ref
        .read(locationPreferencesControllerProvider.notifier)
        .selectCity(city);
    if (context.mounted) Navigator.of(context).pop(CitySelection(city));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // A two-column grid leaves too little room for a location icon and longer
    // city names on narrow windows. Use one column there so labels remain
    // readable instead of being truncated.
    final isCompact = MediaQuery.sizeOf(context).width < 400;
    final gridHeight = (MediaQuery.sizeOf(context).height * .3).clamp(
      120.0,
      300.0,
    );
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      title: Text(l10n.cityOnboardingTitle, textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.cityOnboardingDescription, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.maxFinite,
              height: gridHeight,
              child: GridView.count(
                primary: false,
                crossAxisCount: isCompact ? 1 : 2,
                mainAxisExtent: AppSizes.minTapTarget,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                children: [
                  for (final city in legacyCities())
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                      onPressed: () => _select(context, ref, city),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(AppIcons.location, size: 17),
                          const SizedBox(width: AppSpacing.sm),
                          Text(city, maxLines: 1),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => _select(context, ref, 'Hồ Chí Minh'),
          child: Text(l10n.cityOnboardingSkip),
        ),
      ],
    );
  }
}
