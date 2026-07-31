import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_player.dart';
import 'package:vmito_app/features/session/presentation/create_session_screen.dart';
import 'package:vmito_app/features/session/presentation/host_session_management_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  group('host management JSON', () {
    test('keeps pending players separate from the approved roster', () {
      final session = Session.fromJson({
        'id': 's1',
        'name': 'Friday games',
        'status': 'PREPARING',
        'players': [
          {'id': 'approved', 'registrationStatus': 'APPROVED'},
        ],
        'pendingPlayers': [
          {'id': 'pending', 'registrationStatus': 'PENDING'},
        ],
      });

      expect(
        session.players.single.registrationStatus,
        RegistrationStatus.approved,
      );
      expect(session.pendingPlayers.single.isPendingApproval, isTrue);
    });

    test('parses the payment list and server-calculated totals', () {
      final ledger = PaymentLedger.fromJson({
        'payments': [
          {
            'id': 'pay-1',
            'playerId': 'p1',
            'amount': 80000,
            'status': 'SUBMITTED',
            'paymentMethod': 'BANK_TRANSFER',
            'player': {'id': 'p1', 'name': 'Linh'},
          },
        ],
        'stats': {
          'total': 1,
          'submitted': 1,
          'totalAmount': 80000,
          'paidAmount': 0,
        },
      });

      expect(ledger.payments.single.status, PaymentStatus.submitted);
      expect(ledger.payments.single.paymentMethod, PaymentMethod.bankTransfer);
      expect(ledger.payments.single.player?.displayName, 'Linh');
      expect(ledger.stats.totalAmount, 80000);
    });

    test('parses expenses and host transaction summaries', () {
      final expense = SessionExpense.fromJson({
        'id': 'e1',
        'name': 'Court rental',
        'amount': 500000,
      });
      final summary = HostTransactionSummary.fromJson({
        'userId': 'u1',
        'userName': 'Linh',
        'totalSessions': 3,
        'totalAmount': 240000,
        'paidAmount': 160000,
        'pendingAmount': 80000,
      });

      expect(expense.amount, 500000);
      expect(summary.totalSessions, 3);
      expect(summary.pendingAmount, 80000);
    });
  });

  testWidgets('edit form is prefilled from the session', (tester) async {
    const session = Session(
      id: 's1',
      name: 'Friday games',
      status: SessionStatus.preparing,
      location: 'Court A',
      description: 'Weekly game',
      numberOfCourts: 3,
      maxPlayersPerCourt: 6,
      sessionDuration: 150,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CreateSessionScreen(
            initialSession: session,
            editingSessionId: 's1',
          ),
        ),
      ),
    );

    expect(find.text('Edit session'), findsOneWidget);
    expect(find.text('Friday games'), findsOneWidget);
    expect(find.text('Court A'), findsOneWidget);
    expect(find.text('Weekly game'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('court assignment requires exactly two or four players', (
    tester,
  ) async {
    final players = List.generate(
      4,
      (index) => SessionPlayer(
        id: 'p$index',
        name: 'Player $index',
        playerNumber: index + 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PlayerSelectionDialog(players: players)),
      ),
    );

    final confirm = find.byKey(const ValueKey('confirm-player-selection'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile).at(0));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.tap(find.byType(CheckboxListTile).at(2));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile).at(3));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });
}
