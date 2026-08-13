import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/payment/application/host_finance_export_service.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = HostFinanceExportService();
  const labels = HostFinanceExportLabels(
    title: 'Bảng giao dịch',
    period: 'Kỳ',
    income: 'Phải thu',
    collected: 'Đã thu',
    outstanding: 'Còn thiếu',
    expenses: 'Chi',
    netActual: 'Tổng kết',
    netExpected: 'Dự kiến',
    bySession: 'Theo buổi',
    byPlayer: 'Theo người chơi',
    trend: 'Xu hướng',
    sessionName: 'Tên buổi',
    startTime: 'Bắt đầu',
    playerCount: 'Số người',
    playerName: 'Người chơi',
    sessionCount: 'Số buổi',
    bucket: 'Ngày',
  );

  test('CSV is UTF-8 BOM encoded and contains report sections', () {
    final bytes = service.csvBytes(_report, labels);
    final text = utf8.decode(bytes);

    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(text, contains('"Theo buổi"'));
    expect(text, contains('"Theo người chơi"'));
    expect(text, contains('"Buổi, tối"'));
  });

  test('PDF uses bundled fonts and produces a document', () async {
    final bytes = await service.pdfBytes(_report, labels);

    expect(bytes.take(4), [0x25, 0x50, 0x44, 0x46]);
    expect(bytes.length, greaterThan(1000));
  });
}

final _report = HostFinanceReport(
  range: HostFinanceRange(
    from: DateTime.utc(2026, 8),
    to: DateTime.utc(2026, 8, 13),
    granularity: HostFinanceGranularity.day,
  ),
  totals: const HostFinanceTotals(
    income: 1000,
    collected: 800,
    outstanding: 200,
    expenses: 100,
    netActual: 700,
    netExpected: 900,
    sessionCount: 1,
    playerCount: 1,
    paymentCount: 1,
  ),
  previous: HostFinancePreviousTotals(
    income: 500,
    collected: 400,
    outstanding: 100,
    expenses: 50,
    netActual: 350,
    netExpected: 450,
    from: DateTime.utc(2026, 7),
    to: DateTime.utc(2026, 7, 31),
  ),
  series: [
    HostFinanceSeriesPoint(
      bucket: DateTime.utc(2026, 8),
      income: 1000,
      collected: 800,
      outstanding: 200,
      expenses: 100,
      netActual: 700,
    ),
  ],
  bySession: [
    HostFinanceSessionRow(
      sessionId: 's1',
      name: 'Buổi, tối',
      startTime: DateTime.utc(2026, 8),
      playerCount: 1,
      income: 1000,
      collected: 800,
      outstanding: 200,
      expenses: 100,
      netActual: 700,
    ),
  ],
  byPlayer: const [
    HostTransactionSummary(
      userId: 'u1',
      userName: 'An',
      totalSessions: 1,
      totalAmount: 1000,
      paidAmount: 800,
      pendingAmount: 200,
    ),
  ],
);
