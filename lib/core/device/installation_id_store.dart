import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A random identifier for this installation, used only to reconcile push
/// registrations. It deliberately does not use a hardware identifier.
class InstallationIdStore {
  InstallationIdStore(this._preferences);

  static const _key = 'push.installation_id';

  final SharedPreferences _preferences;

  Future<String> getOrCreate() async {
    final existing = _preferences.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
    await _preferences.setString(_key, id);
    return id;
  }
}

final installationIdStoreProvider = Provider<InstallationIdStore>((ref) {
  throw UnimplementedError(
    'installationIdStoreProvider must be overridden in bootstrap',
  );
});
