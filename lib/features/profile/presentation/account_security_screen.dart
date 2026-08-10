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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAccountSecurity)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            ListTile(
              leading: const Icon(AppIcons.userMinus),
              title: Text(
                l10n.accountDeleteTitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              onTap: () => showDeleteAccountDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}
