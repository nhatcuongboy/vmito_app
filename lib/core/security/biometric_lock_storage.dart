import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vmito_app/core/utils/logger.dart';

/// The account a biometric sign-in resumes.
///
/// Deliberately holds no secret: the refresh token stays in `TokenStorage`,
/// the single owner of tokens. This record only lets the sign-in screen name
/// whose session the Face ID button is about to restore.
class BiometricAccount {
  const BiometricAccount({
    required this.userId,
    required this.displayName,
    required this.email,
  });

  /// Local persistence, not an API contract — hand-mapped so `core/` stays
  /// free of a codegen step.
  static BiometricAccount? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final userId = json['userId'] as String?;
      if (userId == null || userId.isEmpty) return null;
      return BiometricAccount(
        userId: userId,
        displayName: json['displayName'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
    } on Object catch (error) {
      AppLogger.warn('biometric account record is unreadable', error: error);
      return null;
    }
  }

  final String userId;
  final String displayName;
  final String email;

  String encode() => jsonEncode({
    'userId': userId,
    'displayName': displayName,
    'email': email,
  });
}

class BiometricLockStorage {
  BiometricLockStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const _enabledKey = 'vmito.biometric_lock_enabled';
  static const _accountKey = 'vmito.biometric_account';

  final FlutterSecureStorage _storage;

  Future<bool> readEnabled() async =>
      await _storage.read(key: _enabledKey) == 'true';

  Future<void> setEnabled({required bool enabled}) async {
    if (!enabled) {
      await clear();
      return;
    }
    await _storage.write(key: _enabledKey, value: 'true');
  }

  Future<BiometricAccount?> readAccount() async =>
      BiometricAccount.tryParse(await _storage.read(key: _accountKey));

  Future<void> saveAccount(BiometricAccount account) =>
      _storage.write(key: _accountKey, value: account.encode());

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _enabledKey),
      _storage.delete(key: _accountKey),
    ]);
  }
}

final biometricLockStorageProvider = Provider<BiometricLockStorage>(
  (ref) => BiometricLockStorage(),
);
