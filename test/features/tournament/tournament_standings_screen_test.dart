import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_standings_preferences.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_standings_screen.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_standings_bracket.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TournamentService extends Mock implements TournamentService {}

class _AuthController extends AuthController {
  _AuthController(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;
}

class _Preferences implements TournamentStandingsPreferences {
  @override
  Future<bool> readShowPlayerNames() async => false;

  @override
  Future<void> writeShowPlayerNames({required bool value}) async {}
}

void main() {
  testWidgets('renders adaptive cards and complete mobile interactions', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _service();
    String? openedRegistration;
    await tester.pumpWidget(
      _app(
        service,
        onOpenRegistration: (_, registrationId) {
          openedRegistration = registrationId;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tournament-standings-cards')), findsOneWidget);
    expect(find.text('Team One'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Team One'));
    await tester.pump();
    expect(openedRegistration, 'r1');

    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();
    expect(find.text('Set thắng: 2'), findsOneWidget);
    expect(find.text('5 trận gần nhất'), findsOneWidget);

    final rankingInfo = find.byKey(
      const Key('tournament-standings-ranking-info'),
    );
    await tester.scrollUntilVisible(
      rankingInfo,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(rankingInfo);
    await tester.pumpAndSettle();
    expect(find.text('Cách tính bảng xếp hạng'), findsWidgets);
    expect(find.text('Điểm xếp hạng'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vòng loại trực tiếp'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('tournament-standings-single-bracket')),
      findsOneWidget,
    );
    expect(find.text('TỨ KẾT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the full table on a wide constraint', (tester) async {
    _setSize(tester, const Size(900, 1000));
    await tester.pumpWidget(_app(_service()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tournament-standings-table')), findsOneWidget);
    expect(find.text('Thua điểm'), findsOneWidget);
    expect(find.text('5 trận gần nhất'), findsOneWidget);
    expect(find.byKey(const Key('tournament-standings-cards')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('host can recalculate while spectators cannot', (tester) async {
    _setSize(tester, const Size(390, 844));
    final hostService = _service();
    when(
      () => hostService.calculateStandings('c1', 'g1'),
    ).thenAnswer((_) async {});
    const host = User(
      id: 'host-1',
      email: 'host@example.com',
      role: UserRole.host,
    );
    await tester.pumpWidget(
      _app(
        hostService,
        auth: const AuthState(status: AuthStatus.authenticated, user: host),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tính lại'));
    await tester.pumpAndSettle();
    verify(() => hostService.calculateStandings('c1', 'g1')).called(1);
    expect(find.text('Đã tính lại bảng xếp hạng'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(_app(_service()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tính lại'), findsNothing);
  });

  testWidgets('shows a retryable required-data error', (tester) async {
    _setSize(tester, const Size(390, 844));
    final service = _TournamentService();
    when(() => service.detail('open')).thenThrow(Exception('offline'));
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể tải bảng xếp hạng. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets(
    'renders upper, lower and grand-final double elimination sections',
    (
      tester,
    ) async {
      _setSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TournamentPlayoffsView(
                categories: [
                  TournamentCategory(
                    id: 'c1',
                    name: 'Đôi nam',
                    type: 'MEN_DOUBLES',
                    registrationMode: TournamentRegistrationMode.team,
                    format: TournamentCategoryFormat.doubleElimination,
                    registrationCount: 4,
                  ),
                ],
                matches: [
                  TournamentMatch(
                    id: 'u1',
                    categoryId: 'c1',
                    round: 'UB-QF',
                    matchNumber: 1,
                    status: TournamentMatchStatus.finished,
                    participants: [],
                    bracketType: 'UPPER',
                    winnerNextMatchId: 'gf',
                    winnerNextSlot: 1,
                  ),
                  TournamentMatch(
                    id: 'l1',
                    categoryId: 'c1',
                    round: 'LB-F',
                    matchNumber: 2,
                    status: TournamentMatchStatus.finished,
                    participants: [],
                    bracketType: 'LOWER',
                    winnerNextMatchId: 'gf',
                    winnerNextSlot: 2,
                  ),
                  TournamentMatch(
                    id: 'gf',
                    categoryId: 'c1',
                    round: 'GF',
                    matchNumber: 3,
                    status: TournamentMatchStatus.scheduled,
                    participants: [],
                    bracketType: 'GF',
                  ),
                ],
                showPlayerNames: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tournament-standings-double-bracket')),
        findsOneWidget,
      );
      expect(find.text('Nhánh thắng'), findsOneWidget);
      expect(find.text('Nhánh thua'), findsOneWidget);
      expect(find.text('CHUNG KẾT TỔNG'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  TournamentService service, {
  AuthState auth = const AuthState(status: AuthStatus.unauthenticated),
  TournamentRegistrationOpener? onOpenRegistration,
}) => ProviderScope(
  overrides: [
    tournamentServiceProvider.overrideWithValue(service),
    tournamentStandingsPreferencesProvider.overrideWithValue(_Preferences()),
    authControllerProvider.overrideWith(() => _AuthController(auth)),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TournamentStandingsScreen(
      idOrSlug: 'open',
      onOpenRegistration: onOpenRegistration,
    ),
  ),
);

_TournamentService _service() {
  final service = _TournamentService();
  when(() => service.detail('open')).thenAnswer((_) async => _tournament());
  when(() => service.matches('t1')).thenAnswer((_) async => _matches());
  when(() => service.standings('c1')).thenAnswer((_) async => _groups());
  return service;
}

TournamentDetail _tournament() => TournamentDetail(
  id: 't1',
  slug: 'open',
  name: 'Vmito Open',
  startDate: DateTime(2026, 8),
  endDate: DateTime(2026, 8, 2),
  hostId: 'host-1',
  status: TournamentStatus.finished,
  isPublished: true,
  categories: const [
    TournamentCategory(
      id: 'c1',
      name: 'Đôi nam',
      type: 'MEN_DOUBLES',
      registrationMode: TournamentRegistrationMode.team,
      format: TournamentCategoryFormat.roundRobinToSingleElimination,
      registrationCount: 4,
      groupCount: 1,
      winnersPerGroup: 4,
    ),
  ],
  venues: const [],
  playerCount: 8,
  pairCount: 4,
);

List<TournamentStandingGroup> _groups() => const [
  TournamentStandingGroup(
    group: TournamentCategoryGroup(
      id: 'g1',
      categoryId: 'c1',
      number: 1,
      name: 'A',
    ),
    rows: [
      TournamentStanding(
        registration: TournamentRegistration(
          id: 'r1',
          pairName: 'Team One',
          pairMembers: ['Player One', 'Player Two'],
        ),
        categoryRegistrationId: 'r1',
        matchesPlayed: 2,
        matchesWon: 2,
        matchesLost: 0,
        matchesDrawn: 0,
        matchesForfeited: 0,
        matchesCancelled: 0,
        points: 4,
        pointsFor: 42,
        pointsAgainst: 22,
        pointDifference: 20,
        gamesWon: 2,
        gameDifference: 2,
        recentForm: [TournamentStandingResult.win],
        rank: 1,
      ),
    ],
  ),
];

List<TournamentMatch> _matches() => const [
  TournamentMatch(
    id: 'g-match',
    categoryId: 'c1',
    groupId: 'g1',
    round: 'GROUP',
    matchNumber: 1,
    status: TournamentMatchStatus.finished,
    participants: [],
  ),
  TournamentMatch(
    id: 'qf',
    categoryId: 'c1',
    round: 'QF',
    matchNumber: 2,
    status: TournamentMatchStatus.scheduled,
    participants: [],
  ),
];
