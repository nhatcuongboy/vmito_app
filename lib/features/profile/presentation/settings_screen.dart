import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/theme_mode_controller.dart';
import 'package:vmito_app/core/widgets/language_selector.dart';
import 'package:vmito_app/core/widgets/theme_mode_selector.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final languageCode = ref.watch(localeControllerProvider).languageCode;
    final languageName = switch (languageCode) {
      'en' => l10n.languageEnglish,
      'zh' => l10n.languageChinese,
      _ => l10n.languageVietnamese,
    };
    final themeMode = ref.watch(themeModeControllerProvider);
    final themeModeName = switch (themeMode) {
      ThemeMode.light => l10n.themeModeLight,
      ThemeMode.dark => l10n.themeModeDark,
      ThemeMode.system => l10n.themeModeSystem,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            _SettingsSection(
              title: l10n.settingsAccount,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.shield),
                  title: Text(l10n.settingsAccountSecurity),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => context.pushNamed(AppRoutes.nameAccountSecurity),
                ),
                ListTile(
                  leading: const Icon(AppIcons.notifications),
                  title: Text(l10n.settingsNotificationPreferences),
                  enabled: false,
                ),
              ],
            ),
            _SettingsSection(
              title: l10n.settingsDisplay,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.language),
                  title: Text(l10n.profileLanguage),
                  subtitle: Text(languageName),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => showLanguageSelector(context),
                ),
                ListTile(
                  leading: const Icon(AppIcons.dark),
                  title: Text(l10n.profileTheme),
                  subtitle: Text(themeModeName),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => showThemeModeSelector(context),
                ),
              ],
            ),
            _SettingsSection(
              title: l10n.settingsOther,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.help),
                  title: Text(l10n.settingsHelpFeedback),
                  enabled: false,
                ),
                ListTile(
                  leading: const Icon(AppIcons.notes),
                  title: Text(l10n.settingsTermsPrivacy),
                  enabled: false,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  if (info == null) return const SizedBox.shrink();
                  return Text(
                    l10n.settingsVersion(
                      '${info.version} (${info.buildNumber})',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
                icon: const Icon(AppIcons.logout),
                label: Text(l10n.authSignOut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge),
      ),
      ...children,
    ],
  );
}
