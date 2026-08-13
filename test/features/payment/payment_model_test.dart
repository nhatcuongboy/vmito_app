import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';

void main() {
  test('HostFinanceReport parses the backend contract', () {
    final report = HostFinanceReport.fromJson({
      'range': {
        'from': '2026-08-01T00:00:00.000Z',
        'to': '2026-08-13T23:59:59.999Z',
        'granularity': 'day',
      },
      'totals': {
        'income': 1000,
        'collected': 800,
        'outstanding': 200,
        'expenses': 100,
        'netActual': 700,
        'netExpected': 900,
        'sessionCount': 2,
        'playerCount': 3,
        'paymentCount': 4,
      },
      'previous': {
        'income': 500,
        'collected': 400,
        'outstanding': 100,
        'expenses': 50,
        'netActual': 350,
        'netExpected': 450,
        'from': '2026-07-18T00:00:00.000Z',
        'to': '2026-07-31T23:59:59.999Z',
      },
      'series': [
        {
          'bucket': '2026-08-01T00:00:00.000Z',
          'income': 1000,
          'collected': 800,
          'outstanding': 200,
          'expenses': 100,
          'netActual': 700,
        },
      ],
      'bySession': [
        {
          'sessionId': 's1',
          'name': 'Friday night',
          'startTime': '2026-08-01T12:00:00.000Z',
          'playerCount': 3,
          'income': 1000,
          'collected': 800,
          'outstanding': 200,
          'expenses': 100,
          'netActual': 700,
        },
      ],
      'byPlayer': [
        {
          'userId': 'u1',
          'userName': 'An',
          'totalSessions': 2,
          'totalAmount': 1000,
          'paidAmount': 800,
          'pendingAmount': 200,
          'averageRating': 4.5,
          'totalRatings': 8,
        },
      ],
    });

    expect(report.range.granularity, HostFinanceGranularity.day);
    expect(report.totals.netActual, 700);
    expect(report.bySession.single.sessionId, 's1');
    expect(report.byPlayer.single.averageRating, 4.5);
  });

  test('PaymentRecord excludes cancelled and rejected registrations', () {
    final cancelled = PaymentRecord.fromJson({
      'id': 'p1',
      'playerId': 'pl1',
      'amount': 100,
      'status': 'PENDING',
      'createdAt': '2026-08-01T00:00:00.000Z',
      'session': {'id': 's1', 'status': 'CANCELLED'},
    });
    final rejected = PaymentRecord.fromJson({
      'id': 'p2',
      'playerId': 'pl2',
      'amount': 100,
      'status': 'PENDING',
      'createdAt': '2026-08-01T00:00:00.000Z',
      'player': {'id': 'pl2', 'registrationStatus': 'REJECTED'},
    });

    expect(cancelled.isBillable, isFalse);
    expect(rejected.isBillable, isFalse);
  });
}
