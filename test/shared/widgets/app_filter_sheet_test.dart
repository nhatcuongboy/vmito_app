import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';

void main() {
  testWidgets('keeps actions visible on a narrow screen at 200% text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: AppFilterSheetScaffold(
              title: 'Bộ lọc',
              activeCount: 2,
              activeCountLabel: '2 bộ lọc',
              resetLabel: 'Đặt lại',
              applyLabel: 'Áp dụng',
              onReset: () {},
              onApply: () {},
              body: const SizedBox(height: 1000),
            ),
          ),
        ),
      ),
    );

    expect(find.text('2 bộ lọc'), findsOneWidget);
    expect(find.text('Đặt lại'), findsOneWidget);
    expect(find.text('Áp dụng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsible section exposes state and works in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: AppFilterSection(
            title: 'Chi phí',
            summary: '50.000–100.000',
            collapsible: true,
            child: Text('Nội dung'),
          ),
        ),
      ),
    );

    expect(find.text('Nội dung'), findsNothing);
    await tester.tap(find.text('Chi phí'));
    await tester.pump();
    expect(find.text('Nội dung'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the action bar available on a wide dark sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppFilterSheetScaffold(
            title: 'Bộ lọc',
            resetLabel: 'Đặt lại',
            applyLabel: 'Áp dụng',
            onReset: () {},
            onApply: () {},
            body: const SizedBox(height: 1600),
          ),
        ),
      ),
    );

    expect(find.text('Đặt lại'), findsOneWidget);
    expect(find.text('Áp dụng'), findsOneWidget);
    expect(tester.getSize(find.byType(AppFilterSheetScaffold)).width, 1024);
    expect(tester.takeException(), isNull);
  });
}
