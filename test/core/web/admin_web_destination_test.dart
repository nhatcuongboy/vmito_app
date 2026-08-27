import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/web/admin_web_destination.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

void main() {
  test('every admin destination opens an authenticated embedded web page', () {
    for (final destination in AdminWebDestination.values) {
      final page = destination.pageFor(const Locale('vi'));

      expect(page.path, '/vi${destination.relativePath}');
      expect(page.requiresAuth, isTrue);
      expect(page.embedded, isTrue);
      expect(page.title, isNotEmpty);
    }
  });

  test('Chinese admin paths use the web cn locale', () {
    expect(
      AdminWebDestination.users.pageFor(const Locale('zh')).path,
      '/cn/admin/users',
    );
  });

  test('only administrators can open an admin destination', () {
    const admin = User(
      id: 'admin',
      email: 'admin@example.com',
      role: UserRole.admin,
    );
    const host = User(
      id: 'host',
      email: 'host@example.com',
      role: UserRole.host,
    );

    expect(canOpenAdminWebDestination(admin), isTrue);
    expect(canOpenAdminWebDestination(host), isFalse);
    expect(canOpenAdminWebDestination(null), isFalse);
  });
}
