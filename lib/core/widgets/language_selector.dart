import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.language_rounded),
      tooltip: l10n.languageChangeTooltip,
      onPressed: () => showLanguageSelector(context),
    );
  }
}

Future<void> showLanguageSelector(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _LanguageSelectorSheet(),
  );
}

class _LanguageSelectorSheet extends ConsumerWidget {
  const _LanguageSelectorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(localeControllerProvider).languageCode;
    final options = <(String, String)>[
      ('vi', l10n.languageVietnamese),
      ('en', l10n.languageEnglish),
      ('zh', l10n.languageChinese),
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
                l10n.languageTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final (code, label) in options)
              ListTile(
                title: Text(label),
                trailing: selected == code
                    ? const Icon(Icons.check_rounded)
                    : null,
                selected: selected == code,
                onTap: () async {
                  await ref
                      .read(localeControllerProvider.notifier)
                      .select(Locale(code));
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
