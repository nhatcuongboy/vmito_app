import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/court/presentation/player_live_payment_tab.dart';
import 'package:vmito_app/features/payment/application/player_session_payment_controller.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

Widget _app(Session session) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('vi'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: PlayerLivePaymentTab(session: session)),
);

void main() {
  testWidgets(
    'shows the empty state without fetching when no fee is configured',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _app(
            const Session(
              id: 's1',
              name: 'Tuesday badminton',
              status: SessionStatus.inProgress,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa cấu hình phí'), findsOneWidget);
      expect(find.text('Tóm tắt thanh toán của bạn'), findsNothing);
    },
  );

  testWidgets('renders the summary card and a slot-labelled payment card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerSessionPaymentsProvider.overrideWith(
            (ref, sessionId) async => PlayerSessionPayments(
              records: [
                PaymentRecord(
                  id: 'pay1',
                  playerId: 'p1',
                  amount: 50000,
                  status: PaymentStatus.approved,
                  createdAt: DateTime(2026),
                  player: const SessionPlayer(
                    id: 'p1',
                    userId: 'u1',
                    name: 'Nhật Cường',
                  ),
                ),
              ],
              hostSettings: null,
            ),
          ),
        ],
        child: _app(
          const Session(
            id: 's1',
            name: 'Tuesday badminton',
            status: SessionStatus.inProgress,
            feeConfig: SessionFeeConfig(maleFee: 50000, femaleFee: 50000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tóm tắt thanh toán của bạn'), findsOneWidget);
    expect(find.text('Chi tiết thanh toán'), findsOneWidget);
    expect(find.text('Slot của bạn (Nhật Cường)'), findsOneWidget);
  });
}
