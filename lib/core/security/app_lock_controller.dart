import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/security/biometric_lock_storage.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';

enum AppLockStatus { initializing, unlocked, obscured, locked, authenticating }

class AppLockState {
  const AppLockState({
    this.status = AppLockStatus.unlocked,
    this.enabled = false,
    this.capability = const BiometricCapability.unavailable(),
    this.failure,
  });

  final AppLockStatus status;
  final bool enabled;
  final BiometricCapability capability;
  final BiometricAuthFailure? failure;

  bool get isBusy => status == AppLockStatus.authenticating;

  AppLockState copyWith({
    AppLockStatus? status,
    bool? enabled,
    BiometricCapability? capability,
    BiometricAuthFailure? failure,
    bool clearFailure = false,
  }) => AppLockState(
    status: status ?? this.status,
    enabled: enabled ?? this.enabled,
    capability: capability ?? this.capability,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

class AppLockController extends Notifier<AppLockState> {
  @override
  AppLockState build() => const AppLockState();

  BiometricAuthenticator get _authenticator =>
      ref.read(biometricAuthenticatorProvider);
  BiometricLockStorage get _storage => ref.read(biometricLockStorageProvider);

  void bootstrap({required bool enabled, required bool hasSession}) {
    state = AppLockState(
      status: enabled && hasSession
          ? AppLockStatus.locked
          : AppLockStatus.unlocked,
      enabled: enabled && hasSession,
    );
  }

  Future<void> refreshCapability() async {
    final capability = await _authenticator.capability();
    state = state.copyWith(capability: capability);
  }

  Future<BiometricAuthResult> enable({required String reason}) async {
    if (state.isBusy) {
      return const BiometricAuthResult.failure(BiometricAuthFailure.failed);
    }
    final capability = await _authenticator.capability();
    if (!capability.isAvailable) {
      state = state.copyWith(
        capability: capability,
        failure: BiometricAuthFailure.unavailable,
      );
      return const BiometricAuthResult.failure(
        BiometricAuthFailure.unavailable,
      );
    }

    state = state.copyWith(
      status: AppLockStatus.authenticating,
      capability: capability,
      clearFailure: true,
    );
    final result = await _authenticator.authenticate(reason: reason);
    if (result.authenticated) {
      try {
        await _storage.setEnabled(enabled: true);
        // Arming the feature is also what tells the sign-in screen whose
        // session the Face ID button may resume.
        final user = ref.read(authControllerProvider).user;
        if (user != null) {
          await ref
              .read(authControllerProvider.notifier)
              .rememberBiometricAccount(user);
        }
      } on Object {
        state = state.copyWith(
          status: AppLockStatus.unlocked,
          enabled: false,
          failure: BiometricAuthFailure.failed,
        );
        return const BiometricAuthResult.failure(
          BiometricAuthFailure.failed,
        );
      }
      state = state.copyWith(
        status: AppLockStatus.unlocked,
        enabled: true,
        clearFailure: true,
      );
    } else {
      state = state.copyWith(
        status: AppLockStatus.unlocked,
        failure: result.failure,
      );
    }
    return result;
  }

  Future<BiometricAuthResult> disable({required String reason}) async {
    if (!state.enabled || state.isBusy) {
      return const BiometricAuthResult.failure(BiometricAuthFailure.failed);
    }
    state = state.copyWith(
      status: AppLockStatus.authenticating,
      clearFailure: true,
    );
    final result = await _authenticator.authenticate(reason: reason);
    if (result.authenticated) {
      try {
        await _storage.clear();
      } on Object {
        state = state.copyWith(
          status: AppLockStatus.unlocked,
          failure: BiometricAuthFailure.failed,
        );
        return const BiometricAuthResult.failure(
          BiometricAuthFailure.failed,
        );
      }
      state = state.copyWith(
        status: AppLockStatus.unlocked,
        enabled: false,
        clearFailure: true,
      );
    } else {
      state = state.copyWith(
        status: AppLockStatus.unlocked,
        failure: result.failure,
      );
    }
    return result;
  }

  void obscure() {
    if (!state.enabled || state.status != AppLockStatus.unlocked) return;
    state = state.copyWith(status: AppLockStatus.obscured);
  }

  void resume({required Duration backgroundDuration}) {
    if (!state.enabled || state.status != AppLockStatus.obscured) return;
    state = state.copyWith(
      status: backgroundDuration >= const Duration(seconds: 30)
          ? AppLockStatus.locked
          : AppLockStatus.unlocked,
      clearFailure: true,
    );
  }

  Future<BiometricAuthResult> unlock({required String reason}) async {
    if (!state.enabled || state.status != AppLockStatus.locked) {
      return const BiometricAuthResult.failure(BiometricAuthFailure.failed);
    }
    state = state.copyWith(
      status: AppLockStatus.authenticating,
      clearFailure: true,
    );
    final result = await _authenticator.authenticate(reason: reason);
    if (!result.authenticated) {
      state = state.copyWith(
        status: AppLockStatus.locked,
        failure: result.failure,
      );
      return result;
    }

    final auth = ref.read(authControllerProvider);
    if (!auth.isResolved) {
      await ref.read(authControllerProvider.notifier).restoreSession();
    }
    state = state.copyWith(
      status: AppLockStatus.unlocked,
      enabled:
          ref.read(authControllerProvider).status == AuthStatus.authenticated,
      clearFailure: true,
    );
    return result;
  }

  void resetAfterSignOut() {
    state = state.copyWith(
      status: AppLockStatus.unlocked,
      enabled: false,
      clearFailure: true,
    );
  }

  /// Re-arms the resume lock after a sign-in that happened mid-run.
  ///
  /// [bootstrap] only sees the state at launch, and a biometric sign-in from
  /// the sign-in screen happens well after that.
  Future<void> syncWithStoredPreference() async {
    state = state.copyWith(enabled: await _storage.readEnabled());
  }
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
