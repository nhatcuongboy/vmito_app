import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/security/app_lock_controller.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/profile/presentation/widgets/delete_account_dialog.dart';
import 'package:vmito_app/features/profile/presentation/widgets/settings_group.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(appLockControllerProvider.notifier).refreshCapability(),
      ),
    );
  }

  String _title(AppLocalizations l10n, BiometricKind kind) => switch (kind) {
    BiometricKind.face => l10n.biometricSignInFaceTitle,
    BiometricKind.fingerprint => l10n.biometricSignInFingerprintTitle,
    BiometricKind.generic ||
    BiometricKind.unavailable => l10n.biometricSignInGenericTitle,
  };

  String _error(AppLocalizations l10n, BiometricAuthFailure? failure) =>
      switch (failure) {
        BiometricAuthFailure.canceled => l10n.biometricCanceledError,
        BiometricAuthFailure.unavailable => l10n.biometricUnavailableError,
        BiometricAuthFailure.lockedOut => l10n.biometricLockedOutError,
        BiometricAuthFailure.failed || null => l10n.biometricFailedError,
      };

  Future<void> _setBiometricLock(bool enabled) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(appLockControllerProvider.notifier);
    final result = enabled
        ? await controller.enable(reason: l10n.biometricEnableReason)
        : await controller.disable(reason: l10n.biometricDisableReason);
    if (!result.authenticated && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error(l10n, result.failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lock = ref.watch(appLockControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAccountSecurity)),
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
                  AppSpacing.xl,
                ),
                children: [
                  SettingsGroup(
                    children: [
                      SettingsSwitchTile(
                        key: const Key('biometric-lock-toggle'),
                        icon: AppIcons.biometric,
                        title: _title(l10n, lock.capability.kind),
                        subtitle: !lock.capability.isAvailable
                            ? l10n.biometricLockUnavailableDescription
                            : lock.enabled
                            ? l10n.biometricLockEnabledDescription
                            : l10n.biometricLockDisabledDescription,
                        value: lock.enabled,
                        onChanged:
                            (lock.enabled || lock.capability.isAvailable) &&
                                !lock.isBusy
                            ? _setBiometricLock
                            : null,
                      ),
                      SettingsActionTile(
                        icon: AppIcons.lock,
                        title: l10n.profileChangePassword,
                        onTap: () =>
                            context.pushNamed(AppRoutes.nameChangePassword),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SettingsGroup(
                    children: [
                      SettingsActionTile(
                        icon: AppIcons.userMinus,
                        title: l10n.accountDeleteTitle,
                        destructive: true,
                        onTap: () => showDeleteAccountDialog(context),
                      ),
                    ],
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
