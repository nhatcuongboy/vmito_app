import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vmito_app/features/payment/domain/payment.dart';

class HostFinanceExportLabels {
  const HostFinanceExportLabels({
    required this.title,
    required this.period,
    required this.income,
    required this.collected,
    required this.outstanding,
    required this.expenses,
    required this.netActual,
    required this.netExpected,
    required this.bySession,
    required this.byPlayer,
    required this.trend,
    required this.sessionName,
    required this.startTime,
    required this.playerCount,
    required this.playerName,
    required this.sessionCount,
    required this.bucket,
  });

  final String title;
  final String period;
  final String income;
  final String collected;
  final String outstanding;
  final String expenses;
  final String netActual;
  final String netExpected;
  final String bySession;
  final String byPlayer;
  final String trend;
  final String sessionName;
  final String startTime;
  final String playerCount;
  final String playerName;
  final String sessionCount;
  final String bucket;
}

class HostFinanceExportService {
  const HostFinanceExportService();

  String fileStem(HostFinanceReport report) {
    final date = DateFormat('yyyy-MM-dd');
    return 'vmito-thu-chi_${date.format(report.range.from.toUtc())}_'
        '${date.format(report.range.to.toUtc())}';
  }

  Uint8List csvBytes(
    HostFinanceReport report,
    HostFinanceExportLabels labels,
  ) {
    final rows = _rows(report, labels);
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return Uint8List.fromList(utf8.encode('\uFEFF$csv'));
  }

  Future<Uint8List> pdfBytes(
    HostFinanceReport report,
    HostFinanceExportLabels labels,
  ) async {
    final regularData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final date = DateFormat('dd/MM/yyyy');
    String formatSessionDate(DateTime? value) =>
        value == null ? '' : date.format(value.toLocal());
    final money = NumberFormat.decimalPattern('vi_VN');
    final range =
        '${date.format(report.range.from.toLocal())} – '
        '${date.format(report.range.to.toLocal())}';

    pw.Table table(List<List<Object?>> rows) => pw.TableHelper.fromTextArray(
      headers: rows.first.map((value) => '$value').toList(),
      data: rows
          .skip(1)
          .map((row) => row.map((value) => '$value').toList())
          .toList(),
      headerStyle: pw.TextStyle(font: bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 7),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellPadding: const pw.EdgeInsets.all(4),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
    );

    final totals = <List<Object?>>[
      [labels.income, money.format(report.totals.income)],
      [labels.collected, money.format(report.totals.collected)],
      [labels.outstanding, money.format(report.totals.outstanding)],
      [labels.expenses, money.format(report.totals.expenses)],
      [labels.netActual, money.format(report.totals.netActual)],
      [labels.netExpected, money.format(report.totals.netExpected)],
    ];
    final series = <List<Object?>>[
      [labels.bucket, labels.income, labels.expenses, labels.netActual],
      for (final point in report.series)
        [
          date.format(point.bucket.toLocal()),
          money.format(point.income),
          money.format(point.expenses),
          money.format(point.netActual),
        ],
    ];
    final sessions = <List<Object?>>[
      [
        labels.sessionName,
        labels.startTime,
        labels.playerCount,
        labels.income,
        labels.collected,
        labels.outstanding,
        labels.expenses,
        labels.netActual,
      ],
      for (final row in report.bySession)
        [
          row.name,
          formatSessionDate(row.startTime),
          row.playerCount,
          money.format(row.income),
          money.format(row.collected),
          money.format(row.outstanding),
          money.format(row.expenses),
          money.format(row.netActual),
        ],
    ];
    final players = <List<Object?>>[
      [
        labels.playerName,
        labels.sessionCount,
        labels.income,
        labels.collected,
        labels.outstanding,
      ],
      for (final row in report.byPlayer)
        [
          row.userName,
          row.totalSessions,
          money.format(row.totalAmount),
          money.format(row.paidAmount),
          money.format(row.pendingAmount),
        ],
    ];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              labels.title,
              style: pw.TextStyle(font: bold, fontSize: 18),
            ),
            pw.Text(
              '${labels.period}: $range',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          table(totals),
          pw.SizedBox(height: 16),
          _heading(labels.trend, bold),
          table(series),
          pw.SizedBox(height: 16),
          _heading(labels.bySession, bold),
          table(sessions),
          pw.SizedBox(height: 16),
          _heading(labels.byPlayer, bold),
          table(players),
        ],
      ),
    );
    return document.save();
  }

  List<List<Object?>> _rows(
    HostFinanceReport report,
    HostFinanceExportLabels labels,
  ) => [
    [
      labels.period,
      '${report.range.from.toIso8601String()} - ${report.range.to.toIso8601String()}',
    ],
    [labels.income, report.totals.income],
    [labels.collected, report.totals.collected],
    [labels.outstanding, report.totals.outstanding],
    [labels.expenses, report.totals.expenses],
    [labels.netActual, report.totals.netActual],
    [labels.netExpected, report.totals.netExpected],
    const [],
    [labels.bySession],
    [
      labels.sessionName,
      labels.startTime,
      labels.playerCount,
      labels.income,
      labels.collected,
      labels.outstanding,
      labels.expenses,
      labels.netActual,
    ],
    for (final row in report.bySession)
      [
        row.name,
        row.startTime?.toIso8601String() ?? '',
        row.playerCount,
        row.income,
        row.collected,
        row.outstanding,
        row.expenses,
        row.netActual,
      ],
    const [],
    [labels.byPlayer],
    [
      labels.playerName,
      labels.sessionCount,
      labels.income,
      labels.collected,
      labels.outstanding,
    ],
    for (final row in report.byPlayer)
      [
        row.userName,
        row.totalSessions,
        row.totalAmount,
        row.paidAmount,
        row.pendingAmount,
      ],
  ];

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  pw.Widget _heading(String value, pw.Font bold) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 12)),
  );
}
