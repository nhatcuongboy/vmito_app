import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/security/app_lock_controller.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_logo.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

final appLockNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  bool _promptScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfLocked());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final lock = ref.read(appLockControllerProvider);
    if (lock.isBusy) return;

    if (lifecycleState == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      if (backgroundedAt == null) return;
      ref
          .read(appLockControllerProvider.notifier)
          .resume(
            backgroundDuration: ref
                .read(appLockNowProvider)()
                .difference(
                  backgroundedAt,
                ),
          );
      _promptIfLocked();
      return;
    }

    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.paused) {
      _backgroundedAt ??= ref.read(appLockNowProvider)();
      ref.read(appLockControllerProvider.notifier).obscure();
    }
  }

  void _promptIfLocked() {
    if (!mounted ||
        _promptScheduled ||
        ref.read(appLockControllerProvider).status != AppLockStatus.locked) {
      return;
    }
    _promptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _promptScheduled = false;
      if (!mounted ||
          ref.read(appLockControllerProvider).status != AppLockStatus.locked) {
        return;
      }
      await ref
          .read(appLockControllerProvider.notifier)
          .unlock(reason: AppLocalizations.of(context).biometricUnlockReason);
    });
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    ref.read(appLockControllerProvider.notifier).resetAfterSignOut();
  }

  String? _errorMessage(
    AppLocalizations l10n,
    BiometricAuthFailure? failure,
  ) => switch (failure) {
    BiometricAuthFailure.canceled => l10n.biometricCanceledError,
    BiometricAuthFailure.unavailable => l10n.biometricUnavailableError,
    BiometricAuthFailure.lockedOut => l10n.biometricLockedOutError,
    BiometricAuthFailure.failed => l10n.biometricFailedError,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockControllerProvider);
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final lock = ref.read(appLockControllerProvider);
      if (next.status == AuthStatus.unauthenticated && lock.enabled) {
        ref.read(appLockControllerProvider.notifier).resetAfterSignOut();
        return;
      }
      // A sign-in that happens mid-run has to re-arm the resume lock;
      // bootstrap only saw the signed-out state at launch.
      if (next.status == AuthStatus.authenticated && !lock.enabled) {
        unawaited(
          ref
              .read(appLockControllerProvider.notifier)
              .syncWithStoredPreference(),
        );
      }
    });
    final isUnlocked = lock.status == AppLockStatus.unlocked;
    final l10n = AppLocalizations.of(context);
    final errorMessage = _errorMessage(l10n, lock.failure);
    final showActions = lock.status == AppLockStatus.locked;
    final isObscured = lock.status == AppLockStatus.obscured;

    return PopScope(
      canPop: isUnlocked,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: !isUnlocked,
            child: ExcludeFocus(
              excluding: !isUnlocked,
              child: widget.child,
            ),
          ),
          if (isObscured)
            const _AppPrivacyCover()
          else if (!isUnlocked)
            ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: AppLogo(height: 84)),
                          const SizedBox(height: AppSpacing.xl),
                          Icon(
                            AppIcons.lock,
                            size: 42,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.biometricLockScreenTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.biometricLockScreenDescription,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  decoration: TextDecoration.none,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              errorMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          if (showActions) ...[
                            FilledButton.icon(
                              key: const Key('app-lock-retry'),
                              onPressed: _promptIfLocked,
                              icon: const Icon(AppIcons.lock),
                              label: Text(l10n.biometricTryAgain),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton(
                              key: const Key('app-lock-sign-out'),
                              onPressed: _signOut,
                              child: Text(l10n.biometricSignOut),
                            ),
                          ] else
                            const Center(child: CircularProgressIndicator()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppPrivacyCover extends StatelessWidget {
  const _AppPrivacyCover();

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('app-privacy-cover'),
    color: Theme.of(context).colorScheme.surface,
    child: const SafeArea(
      child: Center(
        child: AppLogo(height: 84),
      ),
    ),
  );
}
