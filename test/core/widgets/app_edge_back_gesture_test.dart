import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/widgets/app_edge_back_gesture.dart';

void main() {
  testWidgets('calls onBack for a rightward swipe from the left edge', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppEdgeBackGesture(
          onBack: () => backCount++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.dragFrom(const Offset(8, 300), const Offset(100, 0));

    expect(backCount, 1);
  });

  testWidgets('ignores swipes that do not start at the left edge', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppEdgeBackGesture(
          onBack: () => backCount++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.dragFrom(const Offset(80, 300), const Offset(100, 0));

    expect(backCount, 0);
  });
}
