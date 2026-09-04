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
import 'package:vmito_app/features/profile/presentation/widgets/settings_group.dart';
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
        child: ColoredBox(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.xxl,
                ),
                children: [
                  SettingsGroup(
                    title: l10n.settingsAccount,
                    children: [
                      SettingsActionTile(
                        key: const ValueKey('settings-edit-profile'),
                        icon: AppIcons.edit,
                        title: l10n.profileEditTitle,
                        onTap: () =>
                            context.pushNamed(AppRoutes.nameEditProfile),
                      ),
                      SettingsActionTile(
                        icon: AppIcons.shield,
                        title: l10n.settingsAccountSecurity,
                        onTap: () =>
                            context.pushNamed(AppRoutes.nameAccountSecurity),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SettingsGroup(
                    title: l10n.settingsDisplay,
                    children: [
                      SettingsActionTile(
                        icon: AppIcons.language,
                        title: l10n.profileLanguage,
                        value: languageName,
                        onTap: () => showLanguageSelector(context),
                      ),
                      SettingsActionTile(
                        icon: AppIcons.dark,
                        title: l10n.profileTheme,
                        value: themeModeName,
                        onTap: () => showThemeModeSelector(context),
                      ),
                      SettingsSwitchTile(
                        icon: AppIcons.location,
                        title: l10n.settingsShowNewAddressTitle,
                        subtitle: locationPreferences.showNewAddress
                            ? l10n.settingsShowNewAddressOn
                            : l10n.settingsShowNewAddressOff,
                        value: locationPreferences.showNewAddress,
                        onChanged: (value) => ref
                            .read(
                              locationPreferencesControllerProvider.notifier,
                            )
                            .setShowNewAddress(value: value),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SettingsGroup(
                    title: l10n.settingsOther,
                    children: [
                      SettingsActionTile(
                        icon: AppIcons.help,
                        title: l10n.settingsHelpFeedback,
                        onTap: () => context.pushNamed(AppRoutes.nameFeedback),
                      ),
                      SettingsActionTile(
                        icon: AppIcons.notes,
                        title: l10n.settingsTermsPrivacy,
                        onTap: () => context.pushNamed(AppRoutes.nameTerms),
                      ),
                      SettingsActionTile(
                        icon: AppIcons.info,
                        title: l10n.settingsAbout,
                        onTap: () => showAboutVmitoDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.tonalIcon(
                    key: const Key('settings-sign-out-button'),
                    style: FilledButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.10),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                        width: 1.5,
                      ),
                    ),
                    onPressed: () => showSignOutConfirmation(context, ref),
                    icon: const Icon(AppIcons.logout),
                    label: Text(l10n.authSignOut),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
