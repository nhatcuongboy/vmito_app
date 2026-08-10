import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/theme_mode_controller.dart';
import 'package:vmito_app/core/widgets/language_selector.dart';
import 'package:vmito_app/core/widgets/theme_mode_selector.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/profile/presentation/widgets/delete_account_dialog.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.menuOpenTooltip,
          icon: const Icon(AppIcons.menu),
          onPressed: () =>
              ref.read(appShellScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: Text(l10n.profileTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          if (user != null) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user.image == null
                    ? null
                    : NetworkImage(user.image!),
                child: user.image == null
                    ? const Icon(AppIcons.profile)
                    : null,
              ),
              title: Text(user.displayName),
              subtitle: Text(user.email),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(AppIcons.notifications),
            title: Text(l10n.notificationsTitle),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => context.go(AppRoutes.notifications),
          ),
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
          const Divider(),
          ListTile(
            leading: Icon(
              AppIcons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.authSignOut,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          // App Store guideline 5.1.1(v): account deletion must be reachable
          // in-app. Two taps from here, not buried behind a web link.
          ListTile(
            leading: Icon(
              AppIcons.userMinus,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.accountDeleteTitle,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }
}
