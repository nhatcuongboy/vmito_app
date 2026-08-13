import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/payment/domain/repositories/payment_repository.dart';
import 'package:vmito_app/features/payment/presentation/widgets/player_payment_detail_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _MockPaymentRepository extends Mock implements PaymentRepository {}

void main() {
  testWidgets('review sheet approves the validated reactive form', (
    tester,
  ) async {
    final repository = _MockPaymentRepository();
    when(
      () => repository.approve(
        'p1',
        hostNotes: '',
        amount: 120000,
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PaymentReviewSheet(
              payment: _payment,
              summary: _summary,
              query: _query,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();

    verify(
      () => repository.approve(
        'p1',
        hostNotes: '',
        amount: 120000,
      ),
    ).called(1);
  });
}

final _query = HostFinanceQuery(
  from: DateTime.utc(2026, 8),
  to: DateTime.utc(2026, 8, 13),
  granularity: HostFinanceGranularity.day,
);

final _payment = PaymentRecord(
  id: 'p1',
  playerId: 'player-1',
  amount: 120000,
  status: PaymentStatus.submitted,
  createdAt: DateTime.utc(2026, 8),
  session: PaymentSessionSummary(
    id: 's1',
    name: 'Buổi tối',
    startTime: DateTime.utc(2026, 8),
  ),
);

const _summary = HostTransactionSummary(
  userId: 'u1',
  userName: 'An',
  totalSessions: 1,
  totalAmount: 120000,
  paidAmount: 0,
  pendingAmount: 120000,
);
