import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/theme_mode_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// An [IconButton] that reflects the active [ThemeMode] and opens the
/// theme-mode selector sheet on tap.
class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({super.key});

  static IconData _iconFor(ThemeMode mode) => switch (mode) {
    ThemeMode.light => AppIcons.light,
    ThemeMode.dark => AppIcons.dark,
    ThemeMode.system => AppIcons.themeSystem,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: Icon(_iconFor(mode)),
      tooltip: l10n.themeTitle,
      onPressed: () => showThemeModeSelector(context),
    );
  }
}

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
