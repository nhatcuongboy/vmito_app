import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient client;
  late PaymentRepositoryImpl repository;

  setUp(() {
    client = _MockApiClient();
    repository = PaymentRepositoryImpl(client);
  });

  test('financeReport sends ISO query and parses the envelope', () async {
    final query = HostFinanceQuery(
      from: DateTime.utc(2026, 8),
      to: DateTime.utc(2026, 8, 2),
      granularity: HostFinanceGranularity.day,
    );
    when(
      () => client.get<Map<String, dynamic>>(
        ApiEndpoints.hostFinanceReport,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {'success': true, 'data': _reportJson},
      ),
    );

    final result = await repository.financeReport(query);

    expect(result.totals.income, 100);
    verify(
      () => client.get<Map<String, dynamic>>(
        ApiEndpoints.hostFinanceReport,
        queryParameters: {
          'from': '2026-08-01T00:00:00.000Z',
          'to': '2026-08-02T00:00:00.000Z',
          'granularity': 'day',
        },
      ),
    ).called(1);
  });

  test('approve sends optional amount, method and trimmed notes', () async {
    when(
      () => client.post<void>(
        ApiEndpoints.paymentApprove('p1'),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => Response(requestOptions: RequestOptions()));

    await repository.approve(
      'p1',
      hostNotes: '  ok  ',
      amount: 150,
      paymentMethod: PaymentMethod.bankTransfer,
    );

    verify(
      () => client.post<void>(
        ApiEndpoints.paymentApprove('p1'),
        data: {
          'hostNotes': 'ok',
          'amount': 150,
          'paymentMethod': 'BANK_TRANSFER',
        },
        options: any(named: 'options'),
      ),
    ).called(1);
  });

  test('reminder methods use single and aggregate wire shapes', () async {
    when(
      () => client.post<void>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => Response(requestOptions: RequestOptions()));

    await repository.remindPayment('p1');
    await repository.remindUser('u1');

    verify(
      () => client.post<void>(
        ApiEndpoints.paymentReminders,
        data: {'paymentId': 'p1'},
        options: any(named: 'options'),
      ),
    ).called(1);
    verify(
      () => client.post<void>(
        ApiEndpoints.aggregatePaymentReminder,
        data: {'recipientUserId': 'u1'},
        options: any(named: 'options'),
      ),
    ).called(1);
  });

  test('loads creator reminders and parses linked payments', () async {
    when(
      () => client.get<Map<String, dynamic>>(
        ApiEndpoints.paymentReminders,
        queryParameters: const {'role': 'creator'},
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {
          'success': true,
          'data': [
            {
              'id': 'r1',
              'reminderCount': 3,
              'payments': [
                {
                  'payment': {'id': 'p1'},
                },
              ],
            },
          ],
        },
      ),
    );

    final reminders = await repository.remindersForCreator();

    expect(reminders.single.paymentIds, ['p1']);
    expect(reminders.single.reminderCount, 3);
  });

  test('updates fee config and recalculates session payments', () async {
    when(
      () => client.get<Map<String, dynamic>>(
        ApiEndpoints.sessionFeeConfig('s1'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {
          'success': true,
          'data': {'feeType': 'FIXED', 'maleFee': 80000},
        },
      ),
    );
    when(
      () => client.put<void>(
        ApiEndpoints.sessionFeeConfig('s1'),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => Response(requestOptions: RequestOptions()));
    when(
      () => client.post<Map<String, dynamic>>(
        ApiEndpoints.sessionFeeRecalculate('s1'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {
          'success': true,
          'data': {'updated': 4},
        },
      ),
    );

    await repository.saveFeeConfig(
      's1',
      const SessionFeeConfig(
        maleFee: 90000,
        femaleFee: 70000,
      ),
    );
    final result = await repository.recalculatePayments('s1');

    verify(
      () => client.put<void>(
        ApiEndpoints.sessionFeeConfig('s1'),
        data: {
          'feeType': 'FIXED',
          'maleFee': 90000,
          'femaleFee': 70000,
        },
        options: any(named: 'options'),
      ),
    ).called(1);
    expect(result.updated, 4);
  });

  test('payment settings include QR upload removal semantics', () async {
    when(
      () => client.put<void>(
        ApiEndpoints.paymentSetting('setting-1'),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => Response(requestOptions: RequestOptions()));

    await repository.saveSettings(
      id: 'setting-1',
      bankName: 'VCB',
      accountNumber: '123',
      clearQrCode: true,
    );

    verify(
      () => client.put<void>(
        ApiEndpoints.paymentSetting('setting-1'),
        data: {
          'bankName': 'VCB',
          'bankAccountNumber': '123',
          'accountHolderName': null,
          'qrCodeUrl': null,
          'isDefault': true,
        },
        options: any(named: 'options'),
      ),
    ).called(1);
  });
}

final Map<String, dynamic> _reportJson = {
  'range': {
    'from': '2026-08-01T00:00:00.000Z',
    'to': '2026-08-02T00:00:00.000Z',
    'granularity': 'day',
  },
  'totals': {
    'income': 100,
    'collected': 80,
    'outstanding': 20,
    'expenses': 10,
    'netActual': 70,
    'netExpected': 90,
    'sessionCount': 1,
    'playerCount': 1,
    'paymentCount': 1,
  },
  'previous': {
    'income': 0,
    'collected': 0,
    'outstanding': 0,
    'expenses': 0,
    'netActual': 0,
    'netExpected': 0,
    'from': '2026-07-30T00:00:00.000Z',
    'to': '2026-07-31T23:59:59.999Z',
  },
  'series': <Object>[],
  'bySession': <Object>[],
  'byPlayer': <Object>[],
};
