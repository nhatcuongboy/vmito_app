import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricKind { face, fingerprint, generic, unavailable }

class BiometricCapability {
  const BiometricCapability({
    required this.isAvailable,
    required this.kind,
  });

  const BiometricCapability.unavailable()
    : isAvailable = false,
      kind = BiometricKind.unavailable;

  final bool isAvailable;
  final BiometricKind kind;
}

enum BiometricAuthFailure { canceled, unavailable, lockedOut, failed }

class BiometricAuthResult {
  const BiometricAuthResult.success() : authenticated = true, failure = null;

  const BiometricAuthResult.failure(this.failure) : authenticated = false;

  final bool authenticated;
  final BiometricAuthFailure? failure;
}

abstract interface class BiometricAuthenticator {
  Future<BiometricCapability> capability();

  Future<BiometricAuthResult> authenticate({required String reason});
}

class LocalBiometricAuthenticator implements BiometricAuthenticator {
  LocalBiometricAuthenticator([LocalAuthentication? authentication])
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<BiometricCapability> capability() async {
    if (!_isSupportedPlatform) {
      return const BiometricCapability.unavailable();
    }

    try {
      if (!await _authentication.isDeviceSupported()) {
        return const BiometricCapability.unavailable();
      }
      final biometrics = await _authentication.getAvailableBiometrics();
      if (biometrics.isEmpty) {
        return const BiometricCapability.unavailable();
      }
      final kind = biometrics.contains(BiometricType.face)
          ? BiometricKind.face
          : biometrics.contains(BiometricType.fingerprint)
          ? BiometricKind.fingerprint
          : BiometricKind.generic;
      return BiometricCapability(isAvailable: true, kind: kind);
    } on LocalAuthException {
      return const BiometricCapability.unavailable();
    } on PlatformException {
      return const BiometricCapability.unavailable();
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({required String reason}) async {
    if (!_isSupportedPlatform) {
      return const BiometricAuthResult.failure(
        BiometricAuthFailure.unavailable,
      );
    }

    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? const BiometricAuthResult.success()
          : const BiometricAuthResult.failure(BiometricAuthFailure.canceled);
    } on LocalAuthException catch (error) {
      return BiometricAuthResult.failure(_mapFailure(error.code));
    } on PlatformException {
      return const BiometricAuthResult.failure(BiometricAuthFailure.failed);
    }
  }

  BiometricAuthFailure _mapFailure(LocalAuthExceptionCode code) {
    if (code == LocalAuthExceptionCode.userCanceled ||
        code == LocalAuthExceptionCode.systemCanceled) {
      return BiometricAuthFailure.canceled;
    }
    if (code == LocalAuthExceptionCode.temporaryLockout ||
        code == LocalAuthExceptionCode.biometricLockout) {
      return BiometricAuthFailure.lockedOut;
    }
    if (code == LocalAuthExceptionCode.noCredentialsSet ||
        code == LocalAuthExceptionCode.noBiometricsEnrolled ||
        code == LocalAuthExceptionCode.noBiometricHardware ||
        code ==
            LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        code == LocalAuthExceptionCode.uiUnavailable) {
      return BiometricAuthFailure.unavailable;
    }
    return BiometricAuthFailure.failed;
  }
}

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalBiometricAuthenticator(),
);
