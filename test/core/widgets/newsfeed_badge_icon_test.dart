import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/widgets/newsfeed_badge_icon.dart';
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';

class _FakeNewsfeedBadgeController extends NewsfeedBadgeController {
  _FakeNewsfeedBadgeController(this.count);

  final int count;

  @override
  NewsfeedBadgeState build() => NewsfeedBadgeState(count: count);
}

Widget _harness(int count) => ProviderScope(
  overrides: [
    newsfeedBadgeControllerProvider.overrideWith(
      () => _FakeNewsfeedBadgeController(count),
    ),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: NewsfeedBadgeIcon(
        icon: AppIcons.feed,
        semanticLabel: 'Bảng tin',
      ),
    ),
  ),
);

void main() {
  testWidgets('shows the unread count with accessible semantics', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(8));

    expect(find.text('8'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(NewsfeedBadgeIcon)).label,
      'Bảng tin: 8',
    );
  });

  testWidgets('caps the visible count at 99+', (tester) async {
    await tester.pumpWidget(_harness(120));
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('hides the label when there are no unread posts', (tester) async {
    await tester.pumpWidget(_harness(0));
    expect(find.text('0'), findsNothing);
    expect(
      tester.getSemantics(find.byType(NewsfeedBadgeIcon)).label,
      'Bảng tin',
    );
  });
}
