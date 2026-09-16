import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_roster_tab.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockSocialService extends Mock implements SocialService {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Map<String, dynamic>>[]);
  });
  const session = Session(
    id: 'session-1',
    name: 'Kèo test',
    status: SessionStatus.preparing,
    numberOfCourts: 2,
    maxPlayersPerCourt: 4,
    players: [
      SessionPlayer(
        id: 'p-1',
        name: 'Sơn',
        playerNumber: 1,
        level: 4,
        matchesPlayed: 10,
      ),
      SessionPlayer(
        id: 'p-2',
        name: 'Minh',
        playerNumber: 2,
        level: 5,
        status: PlayerStatus.playing,
        matchesPlayed: 9,
      ),
    ],
  );

  Widget subject({
    SessionRepository? repository,
    Session value = session,
    SocialService? socialService,
    List<ClubSummary> clubs = const [],
  }) => ProviderScope(
    overrides: [
      if (repository != null)
        sessionRepositoryProvider.overrideWithValue(repository),
      managedClubsProvider.overrideWith((ref) async => clubs),
      if (socialService != null)
        socialServiceProvider.overrideWithValue(socialService),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: HostRosterTab(session: value)),
    ),
  );

  testWidgets('renders roster header and controls', (
    tester,
  ) async {
    await tester.pumpWidget(subject());

    expect(find.text('2/8 người'), findsOneWidget);
    expect(find.byKey(const Key('host-roster-add')), findsOneWidget);
    expect(find.byKey(const Key('host-roster-filter')), findsOneWidget);
    expect(find.text('Sơn'), findsOneWidget);
    expect(find.text('Minh'), findsOneWidget);
  });

  testWidgets('uses the single responsive two-column roster on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(subject());

    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.byKey(const Key('host-roster-grid')), findsNothing);
    final listGrid = tester.widget<GridView>(
      find.byKey(const Key('host-roster-list-grid')),
    );
    final listDelegate =
        listGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(listDelegate.crossAxisCount, 2);
    expect(listDelegate.mainAxisExtent, 114);

    expect(
      tester.getRect(find.byType(TextField)).height,
      42,
    );
    expect(
      tester.getRect(find.byKey(const Key('host-roster-filter'))).height,
      42,
    );
    expect(
      tester.getRect(find.byKey(const Key('host-roster-add'))).height,
      greaterThanOrEqualTo(36),
    );
    expect(find.byKey(const Key('host-roster-status-p-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expands the roster to three columns on a wide viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(subject());

    final grid = tester.widget<GridView>(
      find.byKey(const Key('host-roster-list-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(delegate.mainAxisExtent, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'list card gives the name two lines and shows level and gender badges',
    (
      tester,
    ) async {
      final longNameSession = session.copyWith(
        players: [
          session.players.first.copyWith(
            name: 'Ngọc Nhi Nguyễn Thị Minh Anh',
            gender: Gender.female,
          ),
        ],
      );

      await tester.pumpWidget(subject(value: longNameSession));

      final name = tester.widget<Text>(
        find.byKey(const Key('host-roster-name-p-1')),
      );
      expect(name.maxLines, 2);
      expect(name.style?.fontWeight, FontWeight.w700);
      expect(find.byKey(const Key('host-roster-level-p-1')), findsOneWidget);
      expect(find.text('TB'), findsOneWidget);
      expect(find.byKey(const Key('host-roster-gender-p-1')), findsOneWidget);
      expect(find.text('Nữ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows optional club badge without crowding the core badges', (
    tester,
  ) async {
    final clubSession = session.copyWith(
      players: [
        session.players.first.copyWith(
          isClubMember: true,
          club: const {'name': 'CLB Cầu Lông Vmito Rất Dài'},
        ),
      ],
    );

    await tester.pumpWidget(subject(value: clubSession));

    expect(find.byKey(const Key('host-roster-club-p-1')), findsOneWidget);
    expect(find.text('CLB Cầu Lông Vmito Rất Dài'), findsOneWidget);
    expect(find.byKey(const Key('host-roster-level-p-1')), findsOneWidget);
    expect(find.byKey(const Key('host-roster-gender-p-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters roster using the search field', (tester) async {
    await tester.pumpWidget(subject());

    await tester.enterText(find.byType(TextField), 'Minh');
    await tester.pump();

    expect(find.text('Minh'), findsNWidgets(2));
    expect(find.text('Sơn'), findsNothing);
  });

  testWidgets('exposes web-equivalent player actions and opens edit sheet', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    when(() => repository.searchUsers(any())).thenAnswer(
      (_) async => const <HostPlayerUserOption>[],
    );
    await tester.pumpWidget(subject(repository: repository));

    await tester.tap(find.byKey(const Key('host-roster-actions-p-1')));
    await tester.pumpAndSettle();

    expect(find.text('Xem người chơi'), findsOneWidget);
    expect(find.text('Sửa người chơi'), findsOneWidget);
    expect(find.text('Tạm dừng người chơi'), findsOneWidget);
    expect(find.text('Xóa người chơi'), findsOneWidget);

    await tester.tap(find.text('Sửa người chơi'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa người chơi #1'), findsOneWidget);
    expect(find.byKey(const Key('host-edit-player-submit')), findsOneWidget);
  });

  testWidgets('host add button opens the dedicated add-player sheet', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    when(() => repository.searchUsers(any())).thenAnswer(
      (_) async => const <HostPlayerUserOption>[],
    );

    await tester.pumpWidget(subject(repository: repository));
    await tester.tap(find.byKey(const Key('host-roster-add')));
    await tester.pumpAndSettle();

    final sheet = tester.getRect(find.byType(BottomSheet));
    final header = tester.getRect(
      find.byKey(const Key('host-add-players-header')),
    );
    expect(header.top - sheet.top, lessThanOrEqualTo(8));
    expect(find.text('Thêm khách'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('host-add-player-row')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('host-add-player-row')), findsOneWidget);

    await tester.tap(find.byKey(const Key('host-add-player-row')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('host-remove-player-1')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('host-remove-player-1')));
    await tester.pump();
  });

  testWidgets('existing-player picker opens modal sheet and can close', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    when(() => repository.searchUsers(any())).thenAnswer(
      (_) async => const <HostPlayerUserOption>[],
    );

    await tester.pumpWidget(subject(repository: repository));
    await tester.tap(find.byKey(const Key('host-roster-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('host-player-name-0')), 'Lan');

    await tester.tap(find.byKey(const Key('host-player-user-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-player-picker-header')), findsOneWidget);
    expect(find.byKey(const Key('host-picker-tab-roster')), findsOneWidget);
    expect(find.byKey(const Key('host-picker-tab-system')), findsOneWidget);

    await tester.tap(find.byKey(const Key('host-picker-tab-system')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-user-search-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('host-player-picker-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-player-name-0')), findsOneWidget);
    expect(find.text('Lan'), findsOneWidget);
  });

  testWidgets('valid host form submits through the bulk endpoint controller', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    when(() => repository.searchUsers(any())).thenAnswer(
      (_) async => const <HostPlayerUserOption>[],
    );
    late List<Map<String, dynamic>> submitted;
    when(() => repository.createPlayers(any(), any())).thenAnswer((call) async {
      submitted = call.positionalArguments[1] as List<Map<String, dynamic>>;
    });

    await tester.pumpWidget(subject(repository: repository));
    await tester.tap(find.byKey(const Key('host-roster-add')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('host-player-name-0')), 'Lan');
    await tester.tap(find.byKey(const Key('host-add-player-submit')));
    await tester.pumpAndSettle();

    // Sheet should close after successful submission
    expect(find.byKey(const Key('host-add-player-submit')), findsNothing);
    verify(() => repository.createPlayers('session-1', any())).called(1);
    expect(submitted, contains(containsPair('name', 'Lan')));
  });

  testWidgets('warns before adding beyond the recommended capacity', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    when(() => repository.searchUsers(any())).thenAnswer(
      (_) async => const <HostPlayerUserOption>[],
    );
    final full = session.copyWith(numberOfCourts: 1, maxPlayersPerCourt: 2);

    await tester.pumpWidget(subject(repository: repository, value: full));
    await tester.tap(find.byKey(const Key('host-roster-add')));
    await tester.pumpAndSettle();

    expect(find.text('Cảnh báo giới hạn người chơi'), findsOneWidget);
    expect(find.text('Vẫn thêm'), findsOneWidget);

    await tester.tap(find.text('Vẫn thêm'));
    await tester.pumpAndSettle();
    // Sheet should be open now
    expect(find.byKey(const Key('host-add-player-submit')), findsOneWidget);
  });

  testWidgets('selecting a monthly member auto-applies the session club fee', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    final socialService = _MockSocialService();
    const user = HostPlayerUserOption(
      id: 'u3',
      name: 'Linh',
      email: 'linh@vmito.com',
      gender: Gender.female,
      level: 5,
    );
    when(() => repository.searchUsers(any())).thenAnswer((_) async => [user]);
    when(
      () => socialService.clubFeeForMonth('c1', 2026, 8),
    ).thenAnswer(
      (_) async => const ClubFeeConfig(maleFeePerSession: 80000),
    );
    when(
      () => socialService.clubMonthlyMembers('c1', 2026, 8),
    ).thenAnswer(
      (_) async => const [ClubMonthlyMember(userId: 'u3')],
    );
    final clubSession = session.copyWith(
      clubId: 'c1',
      scheduledStartTime: DateTime(2026, 8, 25),
    );
    const club = ClubSummary(
      id: 'c1',
      name: 'CLB Vmito',
      memberCount: 1,
      joinPolicy: 'OPEN',
    );

    await tester.pumpWidget(
      subject(
        repository: repository,
        socialService: socialService,
        clubs: const [club],
        value: clubSession,
      ),
    );
    await tester.tap(find.byKey(const Key('host-roster-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-player-user-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-picker-tab-system')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Linh').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('80.000 VNĐ / buổi'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('80.000 VNĐ / buổi'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).last).value, isTrue);
  });

  testWidgets('existing session users are disabled in the user picker', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    const user = HostPlayerUserOption(
      id: 'u1',
      name: 'Sơn',
      email: 'son@vmito.com',
    );
    when(() => repository.searchUsers(any())).thenAnswer((_) async => [user]);
    final linkedSession = session.copyWith(
      players: [session.players.first.copyWith(userId: 'u1')],
    );

    await tester.pumpWidget(
      subject(repository: repository, value: linkedSession),
    );
    await tester.tap(find.byKey(const Key('host-roster-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-player-user-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-picker-tab-system')));
    await tester.pumpAndSettle();

    expect(find.text('Đã có trong kèo hoặc đã được chọn'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Sơn').last,
    );
    expect(tile.enabled, isFalse);
  });
}
