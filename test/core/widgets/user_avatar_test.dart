import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';

void main() {
  Future<void> pumpAvatar(WidgetTester tester, UserAvatar avatar) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: avatar)));

  testWidgets('uses first and last initials when no image is available', (
    tester,
  ) async {
    await pumpAvatar(tester, const UserAvatar(name: 'Nguyễn Văn An'));

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
