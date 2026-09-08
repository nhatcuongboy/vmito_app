import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/payment_ledger_view.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  testWidgets('renders mobile summary and expands a multi-slot group', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(_ledger));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('payment-summary-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-group-u1')), findsOneWidget);
    expect(find.text('Bình'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('payment-group-u1')));
    await tester.pumpAndSettle();

    expect(find.text('Bình'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens native payment filters including member type', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(_ledger));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('payment-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('Loại thành viên'), findsOneWidget);
    await tester.tap(find.text('Tất cả').last);
    await tester.pumpAndSettle();
    expect(find.text('Thành viên cố định'), findsOneWidget);
    expect(find.text('Người chơi thường'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses compact, accessible actions in the payment section header',
    (
      tester,
    ) async {
      await tester.pumpWidget(_app(_ledger));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.text('Thống kê thanh toán')).style?.fontSize,
        16,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const Key('payment-filter-button')),
                matching: find.byIcon(AppIcons.filter),
              ),
            )
            .size,
        18,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const Key('payment-bulk-approve')),
                matching: find.byIcon(AppIcons.checkAll),
              ),
            )
            .size,
        18,
      );
      expect(
        tester.getSize(find.byKey(const Key('payment-filter-button'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(const Key('payment-bulk-approve'))).height,
        greaterThanOrEqualTo(48),
      );
    },
  );
}

Widget _app(PaymentLedger ledger) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: PaymentLedgerView(
          session: _session,
          ledger: ledger,
          totalExpenses: 100000,
          reminders: const {},
        ),
      ),
    ),
  ),
);

const _session = Session(
  id: 's1',
  name: 'Kèo tối',
  status: SessionStatus.preparing,
  numberOfCourts: 1,
  maxPlayersPerCourt: 8,
);

final _ledger = PaymentLedger(
  payments: [
    PaymentRecord(
      id: 'p1',
      playerId: 'player-1',
      registeredByUserId: 'u1',
      amount: 80000,
      status: PaymentStatus.submitted,
      createdAt: DateTime.utc(2026, 8, 25),
      player: const SessionPlayer(
        id: 'player-1',
        name: 'An',
        gender: Gender.male,
      ),
    ),
    PaymentRecord(
      id: 'p2',
      playerId: 'player-2',
      registeredByUserId: 'u1',
      amount: 70000,
      status: PaymentStatus.pending,
      createdAt: DateTime.utc(2026, 8, 25),
      player: const SessionPlayer(
        id: 'player-2',
        name: 'Bình',
        gender: Gender.female,
      ),
    ),
  ],
  stats: const PaymentStats(
    total: 2,
    submitted: 1,
    pending: 1,
    totalAmount: 150000,
  ),
);
