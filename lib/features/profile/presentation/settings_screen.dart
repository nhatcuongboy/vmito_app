import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/theme_mode_controller.dart';
import 'package:vmito_app/core/widgets/language_selector.dart';
import 'package:vmito_app/core/widgets/sign_out_confirmation.dart';
import 'package:vmito_app/core/widgets/theme_mode_selector.dart';
import 'package:vmito_app/features/profile/presentation/widgets/about_vmito_dialog.dart';
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
    final locationPreferences = ref.watch(
      locationPreferencesControllerProvider,
    );
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
                  key: const ValueKey('settings-edit-profile'),
                  leading: const Icon(AppIcons.edit),
                  title: Text(l10n.profileEditTitle),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => context.pushNamed(AppRoutes.nameEditProfile),
                ),
                ListTile(
                  leading: const Icon(AppIcons.shield),
                  title: Text(l10n.settingsAccountSecurity),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => context.pushNamed(AppRoutes.nameAccountSecurity),
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
                SwitchListTile(
                  secondary: const Icon(AppIcons.location),
                  title: Text(l10n.settingsShowNewAddressTitle),
                  subtitle: Text(
                    locationPreferences.showNewAddress
                        ? l10n.settingsShowNewAddressOn
                        : l10n.settingsShowNewAddressOff,
                  ),
                  value: locationPreferences.showNewAddress,
                  onChanged: (value) => ref
                      .read(locationPreferencesControllerProvider.notifier)
                      .setShowNewAddress(value: value),
                ),
              ],
            ),
            _SettingsSection(
              title: l10n.settingsOther,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.help),
                  title: Text(l10n.settingsHelpFeedback),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => context.pushNamed(AppRoutes.nameFeedback),
                ),
                ListTile(
                  leading: const Icon(AppIcons.notes),
                  title: Text(l10n.settingsTermsPrivacy),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => context.pushNamed(AppRoutes.nameTerms),
                ),
                ListTile(
                  leading: const Icon(AppIcons.info),
                  title: Text(l10n.settingsAbout),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => showAboutVmitoDialog(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: OutlinedButton.icon(
                key: const Key('settings-sign-out-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                onPressed: () => showSignOutConfirmation(context, ref),
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
