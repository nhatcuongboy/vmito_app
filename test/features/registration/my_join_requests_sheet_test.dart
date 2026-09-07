import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/registration/application/my_join_requests_controller.dart';
import 'package:vmito_app/features/registration/data/registration_repository.dart';
import 'package:vmito_app/features/registration/domain/my_join_request.dart';
import 'package:vmito_app/features/registration/presentation/my_join_requests_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _MockRegistrationRepository extends Mock
    implements RegistrationRepository {}

final _request = MyJoinRequest(
  requestedAt: DateTime.utc(2026, 8, 6),
  session: const MyJoinRequestSession(
    id: 's1',
    name: 'Kèo mẫu sân Be Quang Trung',
    location: 'Sân Cầu Lông',
    venueName: 'Be Badminton',
  ),
  players: const [
    MyJoinRequestPlayer(
      id: 'p1',
      name: 'Nhật Cường',
      playerNumber: 1,
      level: 4,
      registrationStatus: RegistrationStatus.approved,
    ),
    MyJoinRequestPlayer(
      id: 'p2',
      playerNumber: 2,
      level: 3,
      registrationStatus: RegistrationStatus.pending,
    ),
  ],
);

pagination.Page<MyJoinRequest> _page(List<MyJoinRequest> items) =>
    pagination.Page(
      items: items,
      total: items.length,
      page: 1,
      limit: 20,
      totalPages: 1,
    );

Future<void> _pump(
  WidgetTester tester,
  RegistrationRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        registrationRepositoryProvider.overrideWithValue(repository),
        myJoinRequestsRealtimeProvider.overrideWith((ref) {}),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: MyJoinRequestsSheet()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders statuses and withdraws pending request', (tester) async {
    final repository = _MockRegistrationRepository();
    var withdrawn = false;
    when(
      () => repository.myJoinRequests(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => _page(withdrawn ? [] : [_request]));
    when(
      () => repository.withdrawMyJoinRequest('s1'),
    ).thenAnswer((_) async => withdrawn = true);

    await _pump(tester, repository);

    expect(find.text('Yêu cầu đã gửi'), findsOneWidget);
    expect(find.text('1 kèo đã gửi yêu cầu tham gia'), findsOneWidget);
    expect(find.text('Kèo mẫu sân Be Quang Trung'), findsOneWidget);
    expect(find.text('Nhật Cường'), findsOneWidget);
    expect(find.text('TB'), findsOneWidget);
    expect(find.text('TB-'), findsOneWidget);
    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('withdraw-my-join-request-s1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('withdraw-my-join-request-s1')));
    await tester.pumpAndSettle();
    expect(
      find.text('Bạn có chắc muốn thu hồi yêu cầu tham gia kèo này không?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Thu hồi yêu cầu').last);
    await tester.pumpAndSettle();

    verify(() => repository.withdrawMyJoinRequest('s1')).called(1);
    expect(find.text('Đã thu hồi yêu cầu tham gia'), findsOneWidget);
    expect(find.text('Chưa có yêu cầu tham gia'), findsOneWidget);
  });

  testWidgets('uses the shared bottom sheet header style', (tester) async {
    final repository = _MockRegistrationRepository();
    when(
      () => repository.myJoinRequests(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => _page([_request]));

    await _pump(tester, repository);

    double fontSize(Key key) =>
        tester.widget<Text>(find.byKey(key)).style!.fontSize!;

    final context = tester.element(find.byKey(const Key('my-join-requests-close')));
    expect(
      find.text(AppLocalizations.of(context).myJoinRequestsTitle),
      findsOneWidget,
    );
    expect(fontSize(const ValueKey('my-join-request-title-s1')), 18);
    expect(fontSize(const ValueKey('my-join-request-date-s1')), 12);
    expect(fontSize(const ValueKey('my-join-request-player-p1')), 14);
    expect(fontSize(const ValueKey('my-join-request-level-p1')), 12);
    expect(fontSize(const ValueKey('my-join-request-status-p1')), 12);
  });

  testWidgets('does not withdraw when the confirmation is cancelled', (
    tester,
  ) async {
    final repository = _MockRegistrationRepository();
    when(
      () => repository.myJoinRequests(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => _page([_request]));

    await _pump(tester, repository);
    await tester.tap(
      find.byKey(const ValueKey('withdraw-my-join-request-s1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    verifyNever(() => repository.withdrawMyJoinRequest('s1'));
    expect(find.text('Kèo mẫu sân Be Quang Trung'), findsOneWidget);
  });

  testWidgets('renders empty state without a withdraw action', (tester) async {
    final repository = _MockRegistrationRepository();
    when(
      () => repository.myJoinRequests(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => _page([]));

    await _pump(tester, repository);

    expect(find.text('Chưa có yêu cầu tham gia'), findsOneWidget);
    expect(find.byKey(const Key('my-join-requests-close')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('withdraw-my-join-request-s1')),
      findsNothing,
    );
  });
}
