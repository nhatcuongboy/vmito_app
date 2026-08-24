import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_fee_detail_dialog.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester, {
  required SessionFeeConfig feeConfig,
  Locale locale = const Locale('vi'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSessionFeeDetailDialog(
              context,
              feeConfig: feeConfig,
            ),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open Dialog'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeDateFormatting);

  group('SessionFeeDetailDialog', () {
    testWidgets('renders fixed fee modal matching mockup in Vietnamese', (
      tester,
    ) async {
      await _pump(
        tester,
        feeConfig: const SessionFeeConfig(
          maleFee: 80000,
          femaleFee: 70000,
          notes: 'hao cầu phụ thu 5k',
        ),
      );

      // Header
      expect(find.text('Phí tham gia'), findsOneWidget);
      expect(find.byIcon(AppIcons.close), findsOneWidget);

      // Badge
      expect(find.text('GIÁ VÃNG LAI'), findsOneWidget);
      expect(find.byIcon(AppIcons.dollarCircle), findsOneWidget);

      // Male fee card
      expect(find.text('PHÍ NAM'), findsOneWidget);
      expect(find.text('80.000 VND'), findsOneWidget);
      expect(find.byIcon(AppIcons.male), findsOneWidget);

      // Female fee card
      expect(find.text('PHÍ NỮ'), findsOneWidget);
      expect(find.text('70.000 VND'), findsOneWidget);
      expect(find.byIcon(AppIcons.female), findsOneWidget);

      // Notes card
      expect(find.text('GHI CHÚ'), findsOneWidget);
      expect(find.text('hao cầu phụ thu 5k'), findsOneWidget);
      expect(find.byIcon(AppIcons.notes), findsOneWidget);
    });

    testWidgets('renders fixed fee modal in English', (tester) async {
      await _pump(
        tester,
        feeConfig: const SessionFeeConfig(
          maleFee: 70000,
          femaleFee: 60000,
          notes: 'Bring shuttlecocks',
        ),
        locale: const Locale('en'),
      );

      expect(find.text('Fees'), findsOneWidget);
      expect(find.text('WALK-IN PRICE'), findsOneWidget);
      expect(find.text('MEN'), findsOneWidget);
      expect(find.text('70.000 VND'), findsOneWidget);
      expect(find.text('WOMEN'), findsOneWidget);
      expect(find.text('60.000 VND'), findsOneWidget);
      expect(find.text('NOTES'), findsOneWidget);
      expect(find.text('Bring shuttlecocks'), findsOneWidget);
    });

    testWidgets('renders split evenly fee modal', (tester) async {
      await _pump(
        tester,
        feeConfig: const SessionFeeConfig(
          feeType: FeeType.splitEvenly,
          splitPerPlayer: 50000,
          splitTotal: 400000,
        ),
      );

      expect(find.text('CHIA ĐỀU SAU BUỔI CHƠI'), findsOneWidget);
      expect(find.text('Mỗi người: 50.000 VND'), findsOneWidget);
      expect(find.text('Tổng chi phí: 400.000 VND'), findsOneWidget);
    });

    testWidgets('renders unpriced fixed fee empty state', (tester) async {
      await _pump(
        tester,
        feeConfig: const SessionFeeConfig(),
      );

      expect(find.text('Chủ kèo chưa cập nhật phí'), findsOneWidget);
    });

    testWidgets('tapping close button closes the dialog', (tester) async {
      await _pump(
        tester,
        feeConfig: const SessionFeeConfig(
          maleFee: 80000,
          femaleFee: 70000,
        ),
      );

      expect(find.text('Phí tham gia'), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.close));
      await tester.pumpAndSettle();

      expect(find.text('Phí tham gia'), findsNothing);
    });
  });
}
