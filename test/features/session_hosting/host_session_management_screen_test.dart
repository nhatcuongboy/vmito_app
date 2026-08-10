import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/host_session_management_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _session = Session(
  id: 's1',
  name: 'Kèo mẫu Sân Be Quang Trung',
  status: SessionStatus.preparing,
  numberOfCourts: 1,
  maxPlayersPerCourt: 8,
  location: 'Quang Trung',
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionDetailProvider('s1').overrideWith((ref) async => _session),
        liveSessionRealtimeProvider('s1').overrideWith((ref) {}),
        matchHistoryProvider('s1').overrideWith((ref) async => const []),
        paymentLedgerProvider('s1').overrideWith(
          (ref) async => const PaymentLedger(
            payments: [],
            stats: PaymentStats(),
          ),
        ),
        paymentSettingsProvider.overrideWith((ref) async => const []),
        sessionExpensesProvider('s1').overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HostSessionManagementScreen(sessionId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows session name, vertical More and all five fixed tabs', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const Key('host-session-title')), findsOneWidget);
    expect(find.byIcon(AppIcons.moreVert), findsOneWidget);
    const labels = ['Tổng quan', 'Người chơi', 'Sân', 'Kết quả', 'Thanh toán'];
    for (var index = 0; index < labels.length; index++) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('host-session-tab-$index')),
          matching: find.text(labels[index]),
        ),
        findsOneWidget,
      );
    }

    for (var index = 0; index < 5; index++) {
      final rect = tester.getRect(
        find.byKey(ValueKey('host-session-tab-$index')),
      );
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(400));
    }

    await tester.tap(find.byKey(const Key('host-session-more-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Sửa buổi chơi'), findsOneWidget);
    expect(find.text('Nhân bản buổi chơi'), findsOneWidget);
    expect(find.text('Hủy buổi chơi'), findsOneWidget);
  });

  testWidgets('each tab displays its implemented content', (tester) async {
    await _pump(tester);

    const contentKeys = [
      'host-tab-overview-content',
      'host-tab-roster-content',
      'host-tab-courts-content',
      'host-tab-results-content',
      'host-tab-payments-content',
    ];

    for (var index = 0; index < contentKeys.length; index++) {
      await tester.tap(find.byKey(ValueKey('host-session-tab-$index')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key(contentKeys[index])), findsOneWidget);
    }
  });
}
