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

  testWidgets('shows first and last letters for names with 3+ words', (
    tester,
  ) async {
    await pumpAvatar(tester, const UserAvatar(name: 'Nguyễn Hữu Trung'));

    expect(find.text('NT'), findsOneWidget);
  });

  testWidgets('shows only the first letter for small avatars (< 32px)', (
    tester,
  ) async {
    await pumpAvatar(tester, const UserAvatar(name: 'Ngọc Anh', size: 24));

    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('defaults to no shadow', (tester) async {
    await pumpAvatar(tester, const UserAvatar(name: 'Minh'));

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(UserAvatar),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isEmpty);
  });

  testWidgets('shows a status dot when status is supplied', (tester) async {
    await pumpAvatar(
      tester,
      const UserAvatar(name: 'An', status: 'PLAYING'),
    );

    expect(find.byKey(const Key('user-avatar-status-dot')), findsOneWidget);
  });

  testWidgets('clips avatar content with ClipOval to prevent edge cut-offs', (
    tester,
  ) async {
    await pumpAvatar(tester, const UserAvatar(name: 'Gavin'));

    expect(
      find.descendant(
        of: find.byType(UserAvatar),
        matching: find.byType(ClipOval),
      ),
      findsOneWidget,
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(UserAvatar),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.foregroundDecoration is BoxDecoration,
        ),
      ),
    );
    final foreground = container.foregroundDecoration! as BoxDecoration;
    expect(foreground.shape, BoxShape.circle);
    expect(foreground.border, isNotNull);
  });
}
