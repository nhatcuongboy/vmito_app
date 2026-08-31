import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';

void main() {
  Future<void> pumpAvatar(WidgetTester tester, UserAvatar avatar) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: avatar)));

  testWidgets('shows only the first letter for a single-word name', (
    tester,
  ) async {
    await pumpAvatar(tester, const UserAvatar(name: 'Minh'));

    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('shows the first letter of each word for multi-word names', (
    tester,
  ) async {
    await pumpAvatar(tester, const UserAvatar(name: 'Ngọc Anh'));

    expect(find.text('NA'), findsOneWidget);
  });

  testWidgets('shows a status dot when status is supplied', (tester) async {
    await pumpAvatar(
      tester,
      const UserAvatar(name: 'An', status: 'PLAYING'),
    );

    expect(find.byKey(const Key('user-avatar-status-dot')), findsOneWidget);
  });
}
