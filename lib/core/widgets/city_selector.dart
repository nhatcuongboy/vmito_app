import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/location/vietnam_locations.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Compact global discovery-area picker. It owns only presentation; the
/// selected value is a device preference shared by every discovery tab.
class CitySelector extends ConsumerWidget {
  const CitySelector({this.onChanged, super.key});
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(locationPreferencesControllerProvider);
    final unitsState = ref.watch(newAdminUnitsProvider);
    final units = switch (unitsState) {
      AsyncData<List<NewAdminUnit>>(:final value) => value,
      _ => const <NewAdminUnit>[],
    };
    final cities = preference.showNewAddress && units.isNotEmpty
        ? units.map((unit) => unit.city).toList(growable: false)
        : vietnamCities;
    final selected = preference.preferredCity;
    return MenuAnchor(
      builder: (context, controller, _) => OutlinedButton.icon(
        key: const Key('discovery-city-selector'),
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: const Icon(AppIcons.location, size: 17),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(
            selected ?? 'Tất cả',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          key: const Key('discovery-city-all'),
          leadingIcon: selected == null ? const Icon(Icons.check) : null,
          onPressed: () async {
            await ref
                .read(locationPreferencesControllerProvider.notifier)
                .selectCity(null);
            onChanged?.call();
          },
          child: const Text('Tất cả'),
        ),
        const Divider(height: 1),
        ...cities.map(
          (city) => MenuItemButton(
            key: Key('discovery-city-$city'),
            leadingIcon: selected == city ? const Icon(Icons.check) : null,
            onPressed: () async {
              await ref
                  .read(locationPreferencesControllerProvider.notifier)
                  .selectCity(city);
              onChanged?.call();
            },
            child: Text(city),
          ),
        ),
      ],
    );
  }
}

class CityOnboardingDialog extends ConsumerWidget {
  const CityOnboardingDialog({super.key});

  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    final value = ref.read(locationPreferencesControllerProvider);
    if (!value.isRestored || value.onboardingCompleted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CityOnboardingDialog(),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    String? city,
  ) async {
    await ref
        .read(locationPreferencesControllerProvider.notifier)
        .selectCity(city);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AlertDialog measures its content intrinsically. A shrink-wrapped
    // GridView has no intrinsic size, which can leave the dialog unlaid out
    // while its route is being animated and then receives a pointer event.
    final gridHeight = (MediaQuery.sizeOf(context).height * .3).clamp(
      120.0,
      300.0,
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      title: const Text('Bạn đang ở đâu?', textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chọn thành phố để xem các kèo và sân gần bạn nhất.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.maxFinite,
              height: gridHeight,
              child: GridView.count(
                primary: false,
                crossAxisCount: 2,
                childAspectRatio: 2.7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final city in vietnamCities)
                    OutlinedButton.icon(
                      onPressed: () => _select(context, ref, city),
                      icon: const Icon(AppIcons.location, size: 17),
                      label: Text(city, overflow: TextOverflow.ellipsis),
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
          child: const Text('Bỏ qua, dùng TP. Hồ Chí Minh'),
        ),
      ],
    );
  }
}
