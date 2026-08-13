import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/create_session_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

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
    // The web-parity form shows the selected custom location in both the
    // location trigger and its editable custom-location field.
    expect(find.text('Court A'), findsAtLeastNWidgets(1));
    expect(find.text('Weekly game'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save changes'), findsOneWidget);
  });
}
