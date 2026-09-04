import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/security/biometric_lock_storage.dart';

/// What the sign-in screen needs to render the Face ID / fingerprint shortcut.
class BiometricSignInOffer {
  const BiometricSignInOffer({required this.account, required this.kind});

  final BiometricAccount account;
  final BiometricKind kind;
}

/// Non-null only when all three conditions of the feature hold: the user
/// turned it on, a saved account is on file, and the device can still perform
/// the check. Enrolling a new face or wiping biometrics on the OS side
/// silently removes the offer instead of showing a button that cannot work.
final biometricSignInOfferProvider = FutureProvider<BiometricSignInOffer?>((
  ref,
) async {
  final storage = ref.watch(biometricLockStorageProvider);
  if (!await storage.readEnabled()) return null;

  final account = await storage.readAccount();
  if (account == null) return null;

  final capability = await ref
      .watch(biometricAuthenticatorProvider)
      .capability();
  if (!capability.isAvailable) return null;

  return BiometricSignInOffer(account: account, kind: capability.kind);
});
