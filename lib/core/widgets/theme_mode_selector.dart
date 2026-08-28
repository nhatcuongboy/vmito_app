import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/theme_mode_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

Future<void> showThemeModeSelector(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _ThemeModeSelectorSheet(),
  );
}

class _ThemeModeSelectorSheet extends ConsumerWidget {
  const _ThemeModeSelectorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(themeModeControllerProvider);
    final options = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, l10n.themeModeSystem, AppIcons.themeSystem),
      (ThemeMode.light, l10n.themeModeLight, AppIcons.light),
      (ThemeMode.dark, l10n.themeModeDark, AppIcons.dark),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Text(
                l10n.themeTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final (mode, label, icon) in options)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                trailing: selected == mode ? const Icon(AppIcons.check) : null,
                selected: selected == mode,
                onTap: () async {
                  await ref
                      .read(themeModeControllerProvider.notifier)
                      .select(mode);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
