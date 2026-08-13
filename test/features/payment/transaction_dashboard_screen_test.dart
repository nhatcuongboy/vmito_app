import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/payment/presentation/transaction_dashboard_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('renders overview and switches to player filters on a phone', (
    tester,
  ) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Bảng giao dịch'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Biểu đồ thu chi'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Biểu đồ thu chi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Theo người chơi'));
    await tester.pumpAndSettle();

    expect(find.text('An'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom range requires both dates', (tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tùy chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng'));
    await tester.pump();

    expect(
      find.text('Vui lòng chọn đủ ngày bắt đầu và kết thúc.'),
      findsOneWidget,
    );
  });

  testWidgets('adapts to tablet width without overflow', (tester) async {
    await _setSize(tester, const Size(800, 1024));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Theo người chơi'));
    await tester.pumpAndSettle();

    expect(find.text('An'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app() => ProviderScope(
  overrides: [
    hostFinanceReportProvider.overrideWith((ref, query) async => _report),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const TransactionDashboardScreen(),
  ),
);

final _report = HostFinanceReport(
  range: HostFinanceRange(
    from: DateTime.utc(2026, 8),
    to: DateTime.utc(2026, 8, 13),
    granularity: HostFinanceGranularity.day,
  ),
  totals: const HostFinanceTotals(
    income: 1000000,
    collected: 800000,
    outstanding: 200000,
    expenses: 100000,
    netActual: 700000,
    netExpected: 900000,
    sessionCount: 1,
    playerCount: 1,
    paymentCount: 1,
  ),
  previous: HostFinancePreviousTotals(
    income: 500000,
    collected: 400000,
    outstanding: 100000,
    expenses: 50000,
    netActual: 350000,
    netExpected: 450000,
    from: DateTime.utc(2026, 7),
    to: DateTime.utc(2026, 7, 31),
  ),
  series: [
    HostFinanceSeriesPoint(
      bucket: DateTime.utc(2026, 8),
      income: 1000000,
      collected: 800000,
      outstanding: 200000,
      expenses: 100000,
      netActual: 700000,
    ),
  ],
  bySession: [
    HostFinanceSessionRow(
      sessionId: 's1',
      name: 'Buổi tối',
      startTime: DateTime.utc(2026, 8, 1, 12),
      playerCount: 1,
      income: 1000000,
      collected: 800000,
      outstanding: 200000,
      expenses: 100000,
      netActual: 700000,
    ),
  ],
  byPlayer: const [
    HostTransactionSummary(
      userId: 'u1',
      userName: 'An',
      totalSessions: 1,
      totalAmount: 1000000,
      paidAmount: 800000,
      pendingAmount: 200000,
      averageRating: 4.5,
      totalRatings: 2,
    ),
  ],
);
