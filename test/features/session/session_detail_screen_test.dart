import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/favorite/data/favorite_repository.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/registration/data/registration_repository.dart';
import 'package:vmito_app/features/registration/domain/my_join_request.dart';
import 'package:vmito_app/features/session/application/player/host_detail_controller.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/application/player/session_recommendations_controller.dart';
import 'package:vmito_app/features/session/domain/player_detail.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/domain/session_recommendation.dart';
import 'package:vmito_app/features/session/presentation/player/session_detail_screen.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/session_player.dart';

const _host = SessionHost(id: 'h1', name: 'Admin', email: 'admin@vmito.com');

/// Today at 20:00-22:00.
///
/// Relative, not a fixed calendar date: the screen renders "Today"/"Tomorrow"
/// against the wall clock, so a hardcoded date silently starts asserting
/// "Yesterday" once that day passes.
final _today = DateTime(
  DateTime.now().year,
  DateTime.now().month,
  DateTime.now().day,
);

Session _session({
  SessionStatus status = SessionStatus.preparing,
  List<SessionPlayer> players = const [],
  List<int> requiredLevels = const [9, 1, 10, 2],
  bool isCrawled = false,
  SessionVenue? venue,
}) => Session(
  id: 's1',
  name: 'Kèo test chuẩn',
  status: status,
  host: _host,
  isCrawled: isCrawled,
  numberOfCourts: 2,
  maxPlayersPerCourt: 8,
  startTime: _today.add(const Duration(hours: 20)),
  scheduledEndTime: _today.add(const Duration(hours: 22)),
  courts: const [
    Court(id: 'c1', courtNumber: 1),
    Court(id: 'c2', courtNumber: 2),
  ],
  players: players,
  requiredLevels: requiredLevels,
  shuttlecock: 'Vina',
  venue:
      venue ??
      const SessionVenue(
        id: 'v1',
        name: 'Sân The B Hòa Bình',
        address: '259 Hòa Bình, Phú Thạnh',
      ),
);

/// Keeps the screen off the network: the hero and the rail both fetch, and
/// neither is what these tests are about.
class _StubFavoriteRepository implements FavoriteRepository {
  const _StubFavoriteRepository();

  @override
  Future<FavoriteSummary> summary(FavoriteType type, String targetId) async =>
      const FavoriteSummary(favoriteCount: 3);

  @override
  Future<void> add(FavoriteType type, String targetId) async {}

  @override
  Future<void> remove(FavoriteType type, String targetId) async {}
}

class _StubRegistrationRepository implements RegistrationRepository {
  const _StubRegistrationRepository(this.players);

  final List<SessionPlayer> players;

  @override
  Future<List<SessionPlayer>> myPlayers(String sessionId) async => players;

  @override
  Future<void> register(String s, List<Map<String, dynamic>> p) async {}

  @override
  Future<void> withdraw(String playerId) async {}

  @override
  Future<pagination.Page<MyJoinRequest>> myJoinRequests({
    required int page,
    required int limit,
  }) async => const pagination.Page<MyJoinRequest>(
    items: <MyJoinRequest>[],
    total: 0,
    page: 1,
    limit: 20,
    totalPages: 0,
  );

  @override
  Future<void> withdrawMyJoinRequest(String sessionId) async {}
}

Future<void> _pump(
  WidgetTester tester,
  Session session, {
  User? currentUser,
  List<Session> recommendations = const [],
  bool recommendationsFallback = false,
  List<SessionPlayer> myPlayers = const [],
  PlayerDetail? playerDetail,
  ClubSummary? club,
  double width = 390,
}) async {
  final playerDetailOverride = playerDetail;
  final clubOverride = club;
  // A phone-width but very tall viewport: the page is one long scroll, and
  // asserting on content below the fold is what these tests are for. Height
  // only — the width is what drives the two-column fact grid, so widen it only
  // for the tests that are about a wide layout.
  tester.view
    ..physicalSize = Size(width * 3, 9000)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionDetailProvider.overrideWith((ref, id) async => session),
        currentUserProvider.overrideWithValue(currentUser),
        isSignedInProvider.overrideWithValue(currentUser != null),
        favoriteRepositoryProvider.overrideWithValue(
          const _StubFavoriteRepository(),
        ),
        sessionRecommendationsProvider.overrideWith(
          (ref, id) async => SessionRecommendationsPage(
            items: recommendations
                .map((session) => SessionRecommendation(session: session))
                .toList(growable: false),
            page: 1,
            limit: 12,
            total: recommendations.length,
            totalPages: 1,
            isFallback: recommendationsFallback,
          ),
        ),
        registrationRepositoryProvider.overrideWithValue(
          _StubRegistrationRepository(myPlayers),
        ),
        hostDetailStatsProvider.overrideWith(
          (ref, id) async => const HostDetailStats(
            averageRating: 4.6,
            totalRatings: 23,
            hostedSessions: 42,
            openSessions: 3,
          ),
        ),
        if (playerDetailOverride != null)
          playerDetailProvider.overrideWith(
            (ref, id) async => playerDetailOverride,
          ),
        if (clubOverride != null)
          clubDetailProvider.overrideWith((ref, id) async => clubOverride),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SessionDetailScreen(sessionId: session.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the session as one scroll, not tabs', (tester) async {
    await _pump(
      tester,
      _session(
        players: const [SessionPlayer(id: 'p1', name: 'Linh', level: 4)],
      ),
    );

    // The tabbed layout this screen replaced.
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Courts'), findsNothing);

    expect(find.text('Kèo test chuẩn'), findsNWidgets(2));
    // Clock range and day share one rich Text, so match the plain-text run.
    expect(find.textContaining('20:00 - 22:00'), findsOneWidget);
    expect(find.textContaining('Today'), findsOneWidget);
    expect(find.text('Badminton  ·  Doubles'), findsOneWidget);
    expect(find.byKey(const Key('session-detail-sport-icon')), findsOneWidget);
    expect(find.text('Sân The B Hòa Bình'), findsOneWidget);
    expect(find.text('259 Hòa Bình, Phú Thạnh'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Linh'), findsOneWidget);

    final title = find.byKey(const Key('session-detail-title'));
    final schedule = find.textContaining('20:00 - 22:00');
    final content = find.byKey(const Key('session-detail-content'));
    expect(tester.getTopLeft(title).dy - tester.getTopLeft(content).dy, 16);
    expect(tester.widget<Text>(title).style?.fontSize, 19);
    expect(
      tester.getTopLeft(schedule).dy - tester.getBottomRight(title).dy,
      12,
    );

    final scheduleText = tester.widget<Text>(schedule);
    final sportText = tester.widget<Text>(
      find.text('Badminton  ·  Doubles'),
    );
    final sportSpan = sportText.textSpan! as TextSpan;
    final sportLabel = sportSpan.children!.first as TextSpan;
    expect(sportText.style?.fontSize, scheduleText.style?.fontSize);
    expect(sportText.style?.color, scheduleText.style?.color);
    expect(sportLabel.style?.fontWeight, FontWeight.w600);
    expect(find.text('TB'), findsOneWidget);

    // Court numbers ride along with the count as a muted suffix.
    expect(find.textContaining('(1, 2)'), findsOneWidget);
    expect(find.text('Up to 16 players'), findsOneWidget);
    expect(find.text('Vina shuttlecock'), findsOneWidget);

    // One badge per accepted level, in display-rank order.
    expect(find.text('Yếu-'), findsOneWidget);
    expect(find.text('Yếu+'), findsOneWidget);
    expect(find.text('TBY'), findsOneWidget);
  });

  testWidgets('shows the configured new address with its badge', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(
        venue: const SessionVenue(
          id: 'v1',
          name: 'Sân The B Hòa Bình',
          address: '259 Hòa Bình, Phú Thạnh',
          district: 'Phú Thạnh',
          city: 'Hồ Chí Minh',
          newAddress: '259 Hòa Bình',
          newDistrict: 'Phường Phú Thạnh',
          newCity: 'Thành phố Hồ Chí Minh',
        ),
      ),
    );

    expect(find.textContaining('259 Hòa Bình'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('session-get-directions'))).height,
      24,
    );
  });

  testWidgets('reveals the pinned white header after scrolling past the hero', (
    tester,
  ) async {
    await _pump(tester, _session());

    final appBar = tester.widget<SliverAppBar>(
      find.byKey(const Key('session-detail-app-bar')),
    );
    final scrollView = tester.widget<CustomScrollView>(
      find.byKey(const Key('session-detail-scroll')),
    );
    final stickyTitle = tester.widget<AnimatedOpacity>(
      find.byKey(const Key('session-sticky-title')),
    );
    final stickyText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('session-sticky-title')),
        matching: find.byType(Text),
      ),
    );
    final favorite = tester.widget<FavoriteButton>(
      find.byKey(const Key('session-favorite-button')),
    );

    expect(appBar.pinned, isTrue);
    expect(appBar.expandedHeight, 220);
    expect(appBar.leadingWidth, 64);
    expect(
      appBar.actionsPadding,
      const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
    );
    expect(scrollView.paintOrder, SliverPaintOrder.lastIsTop);
    expect(stickyTitle.opacity, 0);
    expect(stickyText.style?.fontSize, 16);
    expect(stickyText.style?.height, closeTo(20 / 16, 0.0001));
    expect(stickyText.style?.fontWeight, FontWeight.w700);
    expect(stickyText.maxLines, 1);
    expect(stickyText.overflow, TextOverflow.ellipsis);
    expect(favorite.overlay, isTrue);
    expect(favorite.overlayColor, const Color(0xB8000000));
    final backVisual = tester.widget<DecoratedBox>(
      find.byKey(const Key('session-back-button-visual')),
    );
    expect(
      (backVisual.decoration as BoxDecoration).color,
      const Color(0xB8000000),
    );
    expect(
      tester.getSize(find.byKey(const Key('session-back-button'))),
      const Size.square(AppSizes.minTapTarget),
    );
    expect(
      tester.getSize(find.byKey(const Key('session-back-button-visual'))),
      const Size.square(40),
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('session-back-button')),
              matching: find.byIcon(AppIcons.chevronLeft),
            ),
          )
          .size,
      24,
    );
    expect(
      tester.getSize(find.byKey(const Key('session-share-button'))).height,
      FavoriteButton.detailControlSize,
    );
    expect(
      tester.getSize(find.byKey(const Key('session-share-button'))),
      const Size.square(FavoriteButton.detailControlSize),
    );
    expect(
      tester.getSize(find.byKey(const Key('session-favorite-button'))),
      const Size.square(FavoriteButton.detailControlSize),
    );

    // This test needs enough content below the fold for the scroll controller
    // to move; the shared fixture intentionally uses a very tall viewport for
    // content assertions.
    tester.view.physicalSize = const Size(390 * 3, 600 * 3);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('session-detail-scroll')),
      const Offset(0, -360),
    );
    await tester.pump();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('session-sticky-title')),
          )
          .opacity,
      1,
    );
    expect(
      tester
          .widget<FavoriteButton>(
            find.byKey(const Key('session-favorite-button')),
          )
          .overlay,
      isFalse,
    );
    expect(
      tester
          .widget<CustomScrollView>(
            find.byKey(const Key('session-detail-scroll')),
          )
          .paintOrder,
      SliverPaintOrder.firstIsTop,
    );
  });

  testWidgets('tapping a cover opens the session image preview', (
    tester,
  ) async {
    await _pump(
      tester,
      _session().copyWith(
        images: const ['https://image/1.jpg', 'https://image/2.jpg'],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('session-detail-cover-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1/2'), findsOneWidget);
    expect(find.byKey(const Key('lightbox-next-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('lightbox-next-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2/2'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();
  });

  testWidgets('avatar roster opens a read-only player detail sheet', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(
        players: const [SessionPlayer(id: 'p1', name: 'Linh', level: 4)],
      ),
      playerDetail: const PlayerDetail(
        id: 'p1',
        playerNumber: 1,
        status: PlayerStatus.waiting,
        currentWaitTime: 0,
        totalWaitTime: 0,
        matchesPlayed: 0,
        name: 'Linh',
        level: 4,
      ),
    );

    await tester.tap(find.text('Linh'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('session-player-detail-sheet')),
      findsOneWidget,
    );
    expect(find.text('Player details'), findsOneWidget);
  });

  testWidgets('host name and avatar link to the public profile', (
    tester,
  ) async {
    await _pump(tester, _session());

    final row = tester.widget<InkWell>(
      find.byKey(const Key('session-detail-host-row')),
    );
    expect(row.onTap, isNotNull);
  });

  testWidgets('crawled session links its author row to the original post', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(isCrawled: true).copyWith(
        externalUrl: 'https://facebook.com/post/1',
        externalSource: 'Badminton group',
      ),
    );

    final row = tester.widget<InkWell>(
      find.byKey(const Key('session-detail-host-row')),
    );
    expect(row.onTap, isNotNull);
    expect(find.text('Badminton group'), findsOneWidget);
  });

  testWidgets('empty roster shows placeholder text and no circles', (
    tester,
  ) async {
    await _pump(tester, _session());

    expect(find.text('No players yet'), findsOneWidget);
    expect(find.text('Empty'), findsNothing);
    expect(find.text("Who's playing with you?"), findsOneWidget);
    expect(find.text('0/16'), findsOneWidget);
  });

  testWidgets(
    'roster with players shows player initials, empty slots, and view all button when > 10',
    (tester) async {
      await _pump(
        tester,
        _session(
          players: const [
            SessionPlayer(id: 'p1', name: 'An', level: 1),
            SessionPlayer(id: 'p2', name: 'Binh', level: 2),
          ],
        ),
      );

      // The shared avatar follows the web convention: up to two initials for
      // a one-word name.
      expect(find.text('AN'), findsOneWidget);
      expect(find.text('BI'), findsOneWidget);
      // Empty slots limited to 2 rows (10 total items: 2 players + 8 empty slots)
      expect(find.text('Empty'), findsNWidgets(8));
      // View all button when total slots = 16 > 10
      expect(find.text('View all players'), findsOneWidget);

      await tester.tap(find.text('View all players'));
      await tester.pumpAndSettle();

      // Expanded to all 14 empty slots
      expect(find.text('Empty'), findsNWidgets(14));
      expect(find.text('Show less'), findsOneWidget);
    },
  );

  testWidgets('all-levels session states no restriction', (tester) async {
    await _pump(tester, _session(requiredLevels: const []));

    expect(find.text('All levels'), findsOneWidget);
    expect(find.text('Yếu-'), findsNothing);
  });

  group('bottom bar branches, in web precedence order', () {
    const visitor = User(
      id: 'someone-else',
      email: 'player@vmito.com',
      role: UserRole.player,
    );

    testWidgets('1. a crawled session only offers the original post', (
      tester,
    ) async {
      await _pump(
        tester,
        _session().copyWith(
          isCrawled: true,
          externalUrl: 'https://facebook.com/post/1',
        ),
        currentUser: visitor,
      );

      expect(find.text('View original'), findsOneWidget);
      expect(find.byIcon(AppIcons.facebook), findsOneWidget);
      expect(find.text('Register now'), findsNothing);
    });

    testWidgets('2. the host gets manage, even on a finished session', (
      tester,
    ) async {
      // Branch order matters: "Host" must beat the disabled "Session ended".
      await _pump(
        tester,
        _session(status: SessionStatus.finished),
        currentUser: const User(
          id: 'h1',
          email: 'admin@vmito.com',
          role: UserRole.host,
        ),
      );

      expect(find.widgetWithText(FilledButton, 'Host'), findsOneWidget);
      expect(find.text('Session ended'), findsNothing);
    });

    testWidgets("2b. an admin gets manage on someone else's session", (
      tester,
    ) async {
      await _pump(
        tester,
        _session(),
        currentUser: const User(
          id: 'not-the-host',
          email: 'admin@vmito.com',
          role: UserRole.admin,
        ),
      );

      expect(find.widgetWithText(FilledButton, 'Host'), findsOneWidget);
    });

    testWidgets('3. a finished session is closed to a visitor', (tester) async {
      await _pump(
        tester,
        _session(status: SessionStatus.finished),
        currentUser: visitor,
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Session ended'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('4. approved gets board + ticket + add guest', (tester) async {
      await _pump(
        tester,
        _session(),
        currentUser: visitor,
        myPlayers: const [SessionPlayer(id: 'p1', name: 'Linh')],
      );

      expect(find.text('Board'), findsOneWidget);
      expect(find.byIcon(AppIcons.ticket), findsOneWidget);
      expect(find.byIcon(AppIcons.userPlus), findsOneWidget);
    });

    testWidgets('5. pending shows the ticket, not the board', (tester) async {
      await _pump(
        tester,
        _session(),
        currentUser: visitor,
        myPlayers: const [
          SessionPlayer(
            id: 'p1',
            name: 'Linh',
            registrationStatus: RegistrationStatus.pending,
          ),
        ],
      );

      expect(find.text('View registration'), findsOneWidget);
      expect(find.text('Board'), findsNothing);
      expect(find.text('Register now'), findsNothing);
    });

    testWidgets('5b. rejected shares the pending branch', (tester) async {
      await _pump(
        tester,
        _session(),
        currentUser: visitor,
        myPlayers: const [
          SessionPlayer(
            id: 'p1',
            name: 'Linh',
            registrationStatus: RegistrationStatus.rejected,
          ),
        ],
      );

      expect(find.text('View registration'), findsOneWidget);
    });

    testWidgets('6. a visitor who has not registered gets Register', (
      tester,
    ) async {
      await _pump(tester, _session(), currentUser: visitor);

      expect(find.text('Register now'), findsOneWidget);
    });

    testWidgets('6b. a full session disables Register', (tester) async {
      await _pump(
        tester,
        _session().copyWith(counts: const SessionCounts(players: 16)),
        currentUser: visitor,
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Full'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('6c. signed out still sees Register (auth gate is on tap)', (
      tester,
    ) async {
      await _pump(tester, _session());

      expect(find.text('Register now'), findsOneWidget);
    });

    testWidgets('the actions hug the right edge next to a short price', (
      tester,
    ) async {
      // Wide on purpose: the price and the actions split the row's free space
      // evenly, so at phone width the buttons overflow their half and land on
      // the edge by accident. Only a tablet-width bar leaves the half unfilled
      // and exposes whether the slack sits before or after the buttons.
      await _pump(
        tester,
        _session().copyWith(
          feeConfig: const SessionFeeConfig(maleFee: 70000, femaleFee: 80000),
        ),
        currentUser: visitor,
        width: 900,
        myPlayers: const [
          SessionPlayer(
            id: 'p1',
            name: 'Linh',
            registrationStatus: RegistrationStatus.pending,
          ),
        ],
      );

      final addGuest = tester.getRect(
        find.byIcon(AppIcons.userPlus),
      );

      // The icon draws inside a 48pt tap target, so its glyph stops a little
      // short of the button's own edge; the bar's padding is AppSpacing.md.
      expect(addGuest.right, greaterThan(900 - AppSpacing.md - 24));
      expect(addGuest.right, lessThan(900 - AppSpacing.md));
    });
  });

  testWidgets('hero shows the favorite count from the summary', (tester) async {
    await _pump(
      tester,
      _session(),
      currentUser: const User(
        id: 'someone-else',
        email: 'player@vmito.com',
        role: UserRole.player,
      ),
    );

    expect(find.byIcon(AppIcons.favorite), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('signed out: the heart hides zero without calling the API', (
    tester,
  ) async {
    await _pump(tester, _session());

    expect(find.byIcon(AppIcons.favorite), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('signed-out heart asks for sign-in instead of writing', (
    tester,
  ) async {
    await _pump(tester, _session());

    await tester.tap(find.byIcon(AppIcons.favorite));
    await tester.pumpAndSettle();

    // Still empty (not favorited), so the icon color remains white rather than error color.
    expect(
      (tester.widget(find.byIcon(AppIcons.favorite)) as Icon).color,
      Colors.white,
    );
  });

  testWidgets('no reference video means no video section', (tester) async {
    await _pump(tester, _session());

    expect(find.text('Reference video'), findsNothing);
  });

  testWidgets('a YouTube link renders the reference video card', (
    tester,
  ) async {
    await _pump(
      tester,
      _session().copyWith(
        referenceVideoUrl: 'https://youtu.be/abc123',
      ),
    );
    expect(find.text('Reference video'), findsOneWidget);
    expect(find.byIcon(AppIcons.playCircle), findsOneWidget);
  });

  testWidgets('no recommendations means no rail at all', (tester) async {
    await _pump(tester, _session());

    // Not a spinner and not an empty-state card: this is a tail-end upsell,
    // and either would look like the page itself failed.
    expect(find.text('Suggested for you'), findsNothing);
  });

  testWidgets('recommendations render as a rail of cards', (tester) async {
    await _pump(
      tester,
      _session(),
      recommendations: [
        _session().copyWith(id: 's2', name: 'Kèo tối thứ 5'),
      ],
    );

    expect(find.text('Suggested for you'), findsOneWidget);
    expect(find.text('Kèo tối thứ 5'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('16/16'), findsOneWidget);
    expect(find.text('View all sessions'), findsOneWidget);
  });

  testWidgets('split-evenly recommendation uses its web fee label', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(),
      recommendations: [
        _session().copyWith(
          id: 's2',
          feeConfig: const SessionFeeConfig(feeType: FeeType.splitEvenly),
        ),
      ],
    );

    expect(find.text('Split evenly'), findsOneWidget);
  });

  testWidgets('fallback recommendations use popular title and no AI badge', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(),
      recommendations: [_session().copyWith(id: 's2', name: 'Popular session')],
      recommendationsFallback: true,
    );

    expect(find.text('Popular sessions'), findsOneWidget);
    expect(find.text('Suggested'), findsNothing);
  });

  testWidgets('fee details open from the sticky bar, not the scroll body', (
    tester,
  ) async {
    await _pump(
      tester,
      _session().copyWith(
        feeConfig: const SessionFeeConfig(
          maleFee: 70000,
          femaleFee: 60000,
          notes: 'Bring a shuttlecock tube',
        ),
      ),
    );

    expect(find.text('Fees'), findsNothing);
    await tester.tap(find.byKey(const Key('session-fee-details')));
    await tester.pumpAndSettle();

    expect(find.text('Fees'), findsOneWidget);
    expect(find.text('MEN'), findsOneWidget);
    expect(find.text('WOMEN'), findsOneWidget);
    expect(find.text('Bring a shuttlecock tube'), findsOneWidget);
  });

  testWidgets('split-evenly fee is labelled beside its details button', (
    tester,
  ) async {
    await _pump(
      tester,
      _session().copyWith(
        feeConfig: const SessionFeeConfig(feeType: FeeType.splitEvenly),
      ),
    );

    expect(find.text('Split evenly'), findsOneWidget);
    expect(find.byKey(const Key('session-fee-details')), findsOneWidget);
  });

  testWidgets('managed club is included in the session facts', (tester) async {
    await _pump(
      tester,
      _session().copyWith(clubId: 'club-1'),
      club: const ClubSummary(
        id: 'club-1',
        name: 'Badminton Center',
        memberCount: 16,
        joinPolicy: 'OPEN',
      ),
    );

    expect(find.text('Managed club'), findsNothing);
    expect(find.text('Badminton Center'), findsOneWidget);
  });

  testWidgets('detail stays usable at a narrow phone width', (tester) async {
    await _pump(
      tester,
      _session(
        players: const [
          SessionPlayer(id: 'p1', name: 'Linh', level: 4),
          SessionPlayer(id: 'p2', name: 'Minh', level: 5),
        ],
      ),
      width: 320,
    );

    expect(find.text('Kèo test chuẩn'), findsNWidgets(2));
    expect(find.text("Who's playing with you?"), findsOneWidget);
  });

  testWidgets('a recommendation card truncates a long title without overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(),
      recommendations: [
        _session().copyWith(
          id: 's2',
          name: 'Kèo sáng chủ nhật ở sân The B Hòa Bình',
        ),
      ],
    );

    expect(
      find.text('Kèo sáng chủ nhật ở sân The B Hòa Bình'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty slots do not show in collapsed mode and show when expanded',
    (tester) async {
      final players = List.generate(
        8,
        (i) => SessionPlayer(id: 'p$i', name: 'Player $i', level: 3),
      );

      // Session capacity is 16 (2 courts * 8 maxPlayersPerCourt).
      await _pump(tester, _session(players: players));

      // 8 players shown, but 0 empty slot tiles when collapsed.
      for (final player in players) {
        expect(find.text(player.name), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('empty-slot-0')), findsNothing);
      expect(find.text('View all players'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('View all players'));
      await tester.pumpAndSettle();

      // Now empty slots are visible (8 empty slots for capacity 16 - 8 players)
      for (var i = 0; i < 8; i++) {
        expect(find.byKey(ValueKey('empty-slot-$i')), findsOneWidget);
      }
      expect(find.text('Show less'), findsOneWidget);

      // Tap to collapse
      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('empty-slot-0')), findsNothing);
      expect(find.text('View all players'), findsOneWidget);
    },
  );
}
