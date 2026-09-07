import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(AppIcons.language),
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
    // Keeps the native sheet aligned with the web language panel.
    final options = <(String, String, String)>[
      ('vi', l10n.languageVietnamese, '🇻🇳'),
      ('en', l10n.languageEnglish, '🇬🇧'),
      ('zh', l10n.languageChinese, '🇨🇳'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(
              title: l10n.languageTitle,
              showCloseButton: false,
            ),
            for (final (code, label, flag) in options)
              ListTile(
                leading: ExcludeSemantics(
                  child: Text(
                    flag,
                    style: const TextStyle(fontSize: 22, height: 1),
                  ),
                ),
                title: Text(label),
                trailing: selected == code ? const Icon(AppIcons.check) : null,
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
