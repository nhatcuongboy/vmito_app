import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/profile/presentation/widgets/delete_account_dialog.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAccountSecurity)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            ListTile(
              leading: Icon(AppIcons.userMinus, color: theme.colorScheme.error),
              title: Text(
                l10n.accountDeleteTitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(
                AppIcons.chevronRight,
                color: theme.colorScheme.error.withValues(alpha: 0.7),
              ),
              onTap: () => showDeleteAccountDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}
