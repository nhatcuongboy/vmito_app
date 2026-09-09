import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_location_payload.dart';
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

class _SessionRepository extends Mock implements SessionRepository {}

Future<void> _pump(
  WidgetTester tester, {
  Session session = _session,
  SessionRepository? repository,
  Locale locale = const Locale('vi'),
  VoidCallback? onSessionLoad,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionDetailProvider('s1').overrideWith((ref) async {
          onSessionLoad?.call();
          return session;
        }),
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
        sessionFeeConfigProvider('s1').overrideWith((ref) async => null),
        paymentRemindersProvider.overrideWith((ref) async => const {}),
        vietnamBanksProvider.overrideWith((ref) async => const []),
        if (repository != null)
          sessionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HostSessionManagementScreen(sessionId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateSessionRequest(
        name: 'Fallback',
        location: CustomLocation(name: 'Fallback court'),
        hostName: 'Host',
        maxPlayersPerCourt: 8,
      ),
    );
  });

  testWidgets('shows status badge, More actions and all five fixed tabs', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const Key('host-session-title')), findsOneWidget);
    expect(find.byKey(const Key('host-session-status-badge')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('host-session-status-badge')),
        matching: find.text('Sắp diễn ra'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.moreVert), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNotNull);
    expect(find.byKey(const Key('host-session-bottom-nav')), findsOneWidget);
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
    expect(find.text('Bắt đầu kèo'), findsNWidgets(2));
    expect(find.text('Chỉnh sửa kèo'), findsOneWidget);
    expect(find.text('Nhân bản buổi chơi'), findsOneWidget);
    expect(find.text('Hủy buổi chơi'), findsOneWidget);
  });

  testWidgets('separates the header and content surfaces', (tester) async {
    await _pump(tester);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final content = tester.widget<ColoredBox>(
      find.byKey(const Key('host-session-content-background')),
    );

    expect(appBar.backgroundColor, AppColors.card);
    expect(appBar.shape, isA<Border>());
    expect(content.color.r, closeTo(247 / 255, 0.002));
    expect(content.color.g, closeTo(247 / 255, 0.002));
    expect(content.color.b, closeTo(248 / 255, 0.002));
    expect(content.color, isNot(appBar.backgroundColor));
  });

  testWidgets('More shows end action while a session is in progress', (
    tester,
  ) async {
    await _pump(
      tester,
      session: _session.copyWith(status: SessionStatus.inProgress),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('host-session-status-badge')),
        matching: find.text('Đang diễn ra'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('host-session-more-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Kết thúc kèo'), findsNWidgets(2));
    expect(find.text('Sửa buổi chơi'), findsNothing);
  });

  testWidgets('header keeps a long name on one line beside the status', (
    tester,
  ) async {
    const longName =
        'Kèo Cường test chạy vị trí header với một tên buổi chơi thật dài';
    await _pump(tester, session: _session.copyWith(name: longName));

    final title = tester.widget<Text>(
      find.byKey(const Key('host-session-title')),
    );
    final titleRect = tester.getRect(
      find.byKey(const Key('host-session-title')),
    );
    final badgeRect = tester.getRect(
      find.byKey(const Key('host-session-status-badge')),
    );
    final moreRect = tester.getRect(
      find.byKey(const Key('host-session-more-menu')),
    );

    expect(title.data, longName);
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.style?.fontSize, 16);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(titleRect.right, lessThanOrEqualTo(badgeRect.left));
    expect(badgeRect.right, lessThanOrEqualTo(moreRect.left));
    expect(
      (titleRect.center.dy - badgeRect.center.dy).abs(),
      lessThanOrEqualTo(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'overview edit refreshes session detail after a successful save',
    (
      tester,
    ) async {
      final repository = _SessionRepository();
      final start = DateTime(2030, 8, 26, 18);
      final editable = _session.copyWith(
        hostName: 'Chủ kèo',
        hostPhone: '0901234567',
        customLocationName: 'Sân Quang Trung',
        startTime: start,
        endTime: start.add(const Duration(hours: 2)),
      );
      when(() => repository.update('s1', any())).thenAnswer(
        (_) async => editable.copyWith(name: 'Kèo đã cập nhật'),
      );
      var loads = 0;
      await _pump(
        tester,
        session: editable,
        repository: repository,
        onSessionLoad: () => loads++,
      );
      expect(loads, 1);

      await tester.tap(find.byKey(const Key('host-overview-edit-session')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('create-session-submit')));
      await tester.pumpAndSettle();

      expect(loads, 2);
      verify(() => repository.update('s1', any())).called(1);
    },
  );

  testWidgets('shows the API reason when starting without players fails', (
    tester,
  ) async {
    final repository = _SessionRepository();
    when(() => repository.startSession('s1')).thenThrow(
      const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Cannot start a session with no players',
        statusCode: 400,
        hasServerMessage: true,
      ),
    );
    await _pump(tester, repository: repository);

    await tester.tap(find.byKey(const Key('host-session-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu kèo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-start-session')));
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể bắt đầu buổi chơi vì chưa có người chơi nào.'),
      findsOneWidget,
    );
  });

  testWidgets('translates the no-player start failure in English', (
    tester,
  ) async {
    final repository = _SessionRepository();
    when(() => repository.startSession('s1')).thenThrow(
      const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Cannot start a session with no players',
        statusCode: 400,
        hasServerMessage: true,
      ),
    );
    await _pump(
      tester,
      repository: repository,
      locale: const Locale('en'),
    );

    await tester.tap(find.byKey(const Key('host-session-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start session').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-start-session')));
    await tester.pumpAndSettle();

    expect(
      find.text('Cannot start the session because it has no players.'),
      findsOneWidget,
    );
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
