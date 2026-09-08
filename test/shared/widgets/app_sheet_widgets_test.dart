import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_grabber.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

void main() {
  Widget buildSubject(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  group('AppSheetHeader', () {
    testWidgets('renders title and subtitle without a bottom border', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const AppSheetHeader(
            title: 'Bộ lọc',
            subtitle: 'Chọn tiêu chí tìm kiếm',
            showCloseButton: false,
          ),
        ),
      );

      expect(find.text('Bộ lọc'), findsOneWidget);
      expect(find.text('Chọn tiêu chí tìm kiếm'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('close button pops the route by default', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => const AppSheetHeader(title: 'Bộ lọc'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Bộ lọc'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('Bộ lọc'), findsNothing);
    });

    testWidgets('invokes onClose instead of popping when provided', (
      tester,
    ) async {
      var closed = false;
      await tester.pumpWidget(
        buildSubject(
          AppSheetHeader(title: 'Bộ lọc', onClose: () => closed = true),
        ),
      );

      await tester.tap(find.byType(IconButton));
      expect(closed, isTrue);
    });

    testWidgets('vertically centers the title with the close button', (
      tester,
    ) async {
      const closeButtonKey = Key('sheet-close');
      await tester.pumpWidget(
        buildSubject(
          const AppSheetHeader(
            title: 'Bộ lọc',
            closeButtonKey: closeButtonKey,
          ),
        ),
      );

      final titleCenter = tester.getCenter(find.text('Bộ lọc'));
      final closeButtonCenter = tester.getCenter(find.byKey(closeButtonKey));
      expect(titleCenter.dy, closeTo(closeButtonCenter.dy, 0.01));
    });
  });

  testWidgets('AppSheetGrabber renders a pill-shaped handle', (tester) async {
    await tester.pumpWidget(buildSubject(const AppSheetGrabber()));

    expect(find.byType(Container), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container));
    expect(
      container.constraints,
      const BoxConstraints.tightFor(width: 36, height: 4),
    );
  });

  group('AppSheetActionBar', () {
    testWidgets('renders its child with a top border', (tester) async {
      await tester.pumpWidget(
        buildSubject(const AppSheetActionBar(child: Text('actions'))),
      );

      expect(find.text('actions'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    });
  });
}
