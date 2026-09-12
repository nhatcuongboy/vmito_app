import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/celebration/confetti_burst.dart';

void main() {
  testWidgets('paints particles by default', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: false));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paints nothing under reduced motion', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.descendant(
        of: find.byType(ConfettiBurst),
        matching: find.byType(IgnorePointer),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app({required bool disableAnimations}) => MediaQuery(
  data: MediaQueryData(disableAnimations: disableAnimations),
  child: const Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 400,
      height: 800,
      child: ConfettiBurst(colors: [Colors.amber, Colors.green]),
    ),
  ),
);
