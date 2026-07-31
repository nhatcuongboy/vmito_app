import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/language_selector.dart';
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
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
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
                    ? const Icon(Icons.person_outline_rounded)
                    : null,
              ),
              title: Text(user.displayName),
              subtitle: Text(user.email),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.notificationsTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.profileLanguage),
            subtitle: Text(languageName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLanguageSelector(context),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout_rounded,
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
              Icons.person_remove_outlined,
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
