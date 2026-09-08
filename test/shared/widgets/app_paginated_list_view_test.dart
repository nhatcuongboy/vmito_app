import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_paginated_list_view.dart';

void main() {
  const endLabel = 'Bạn đã xem hết kết quả.';

  Widget buildSubject({
    required int itemCount,
    bool hasMore = false,
    bool isLoading = false,
    bool isLoadingMore = false,
  }) => MaterialApp(
    locale: const Locale('vi'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: AppPaginatedListView.separated(
        itemCount: itemCount,
        hasMore: hasMore,
        isLoading: isLoading,
        isLoadingMore: isLoadingMore,
        padding: const EdgeInsets.all(16),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) => SizedBox(
          key: Key('result-$index'),
          height: 96,
          child: Text('Result $index'),
        ),
      ),
    ),
  );

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -2000),
    );
    await tester.pump();
  }

  testWidgets('shows the end label for an exhausted overflowing list', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 500)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject(itemCount: 8));
    await scrollToEnd(tester);

    expect(find.text(endLabel), findsOneWidget);
  });

  testWidgets('hides the end label when all results fit in the viewport', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject(itemCount: 2));

    expect(find.text(endLabel), findsNothing);
  });

  testWidgets('hides the end label while more pages are available', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 500)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject(itemCount: 8, hasMore: true));
    await scrollToEnd(tester);

    expect(find.text(endLabel), findsNothing);
  });

  testWidgets('suppresses the end label while loading', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 500)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject(itemCount: 8, isLoading: true));
    await scrollToEnd(tester);

    expect(find.text(endLabel), findsNothing);
  });

  testWidgets('shows a spinner instead of the label while loading more', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 500)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject(itemCount: 8, isLoadingMore: true));
    await scrollToEnd(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(endLabel), findsNothing);
  });

  testWidgets('reevaluates overflow when the viewport height changes', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 500)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject(itemCount: 6));
    await scrollToEnd(tester);
    expect(find.text(endLabel), findsOneWidget);

    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpAndSettle();

    expect(find.text(endLabel), findsNothing);
  });
}
