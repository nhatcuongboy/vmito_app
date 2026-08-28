import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/home/presentation/home_screen.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_discovery_tabs.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_discovery_toolbar.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/public_sessions_content.dart';
import 'package:vmito_app/features/session/presentation/player/session_filter_sheet.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/presentation/browse_clubs_screen.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/browse_tournaments_content.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/browse_venues_screen.dart';
import 'package:vmito_app/features/venue/presentation/venue_filter_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('shows all discovery tabs and updates the selected segment', (
    tester,
  ) async {
    var selected = HomeDiscoveryTab.sessions;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => HomeDiscoveryTabs(
              selected: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tìm kèo'), findsOneWidget);
    expect(find.text('Tìm sân'), findsOneWidget);
    expect(find.text('Tìm nhóm'), findsOneWidget);
    expect(find.text('Tìm giải'), findsOneWidget);
    expect(
      find.byKey(const Key('home-discovery-indicator-sessions')),
      findsOneWidget,
    );
    final selectedText = tester.widget<Text>(find.text('Tìm kèo'));
    final unselectedText = tester.widget<Text>(find.text('Tìm sân'));
    expect(selectedText.style?.fontSize, 15);
    expect(selectedText.style?.height, closeTo(20 / 15, 0.0001));
    expect(selectedText.style?.fontWeight, FontWeight.w600);
    expect(unselectedText.style?.fontWeight, FontWeight.w500);

    await tester.tap(find.byKey(const Key('home-discovery-tab-venues')));
    await tester.pumpAndSettle();

    expect(selected, HomeDiscoveryTab.venues);
    expect(
      find.byKey(const Key('home-discovery-indicator-venues')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-discovery-indicator-sessions')),
      findsNothing,
    );
  });

  testWidgets('Home fetches the newly selected discovery content', (
    tester,
  ) async {
    _FakeSessionsController.loads = 0;
    _FakeVenuesController.loads = 0;
    _FakeClubsController.loads = 0;
    _FakeTournamentsController.loads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browseSessionsControllerProvider.overrideWith(
            _FakeSessionsController.new,
          ),
          venueBrowseControllerProvider.overrideWith(
            _FakeVenuesController.new,
          ),
          clubsControllerProvider.overrideWith(_FakeClubsController.new),
          tournamentBrowseControllerProvider.overrideWith(
            _FakeTournamentsController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(_FakeSessionsController.loads, 1);
    expect(find.byIcon(AppIcons.login), findsOneWidget);
    expect(find.byKey(const Key('home-search-button')), findsOneWidget);
    expect(find.byType(SearchBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const Key('home-create-session-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-discovery-tab-venues')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(BrowseVenuesScreen), findsOneWidget);
    expect(_FakeVenuesController.loads, 1);

    await tester.tap(find.byKey(const Key('home-discovery-tab-clubs')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(BrowseClubsScreen), findsOneWidget);
    expect(_FakeClubsController.loads, 1);

    await tester.tap(find.byKey(const Key('home-discovery-tab-tournaments')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(BrowseTournamentsContent), findsOneWidget);
    expect(_FakeTournamentsController.loads, 1);

    // A re-tap recreates the selected content and revalidates its data.
    await tester.tap(find.byKey(const Key('home-discovery-tab-tournaments')));
    await tester.pump();
    await tester.pump();
    expect(_FakeTournamentsController.loads, 2);
  });

  testWidgets('discovery controls stay below tabs while results scroll', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _ScrollableSessionsController.lastFilters = null;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPreferencesControllerProvider.overrideWith(
            _HomeLocationPreferencesController.new,
          ),
          browseSessionsControllerProvider.overrideWith(
            _ScrollableSessionsController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final city = find.byKey(const Key('discovery-city-selector'));
    final sort = find.byKey(const Key('home-discovery-sort'));
    final filter = find.byKey(const Key('home-discovery-filter'));
    final tabs = find.byType(HomeDiscoveryTabs);
    expect(find.text('Hồ Chí Minh'), findsOneWidget);
    expect(tester.getCenter(city).dx, lessThan(tester.getCenter(sort).dx));
    expect(tester.getCenter(sort).dx, lessThan(tester.getCenter(filter).dx));
    expect(
      tester.getTopLeft(filter).dy,
      greaterThan(tester.getBottomLeft(tabs).dy),
    );

    final toolbarY = tester.getTopLeft(filter).dy;
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(filter).dy, toolbarY);

    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(find.byType(SessionFilterSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-filter-close')));
    await tester.pumpAndSettle();

    await tester.tap(sort);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giá thấp nhất'));
    await tester.pumpAndSettle();
    expect(
      _ScrollableSessionsController.lastFilters?.sort,
      SessionBrowseSort.priceAsc,
    );
  });

  testWidgets('discovery toolbar does not overflow at 320 pixels', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 160)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPreferencesControllerProvider.overrideWith(
            _HomeLocationPreferencesController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HomeDiscoveryToolbar(
              sortLabel: 'Ngày gần nhất',
              onSort: () {},
              onFilter: () {},
              onCityChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hồ Chí Minh'), findsOneWidget);
    expect(find.byKey(const Key('home-discovery-filter')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home applies an incoming venue filter to session discovery', (
    tester,
  ) async {
    _FakeSessionsController.lastFilters = null;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browseSessionsControllerProvider.overrideWith(
            _FakeSessionsController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(
            initialVenueId: 'venue-1',
            initialVenueName: 'Sân A',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_FakeSessionsController.lastFilters?.venueId, 'venue-1');
    expect(_FakeSessionsController.lastFilters?.venueName, 'Sân A');
  });

  testWidgets('session map toggle is hidden for guests', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browseSessionsControllerProvider.overrideWith(
            _FakeSessionsController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('session-map-view-toggle')), findsNothing);
  });

  testWidgets('session map toggle swaps the result view', (
    tester,
  ) async {
    _FakeSessionsController.mapLoads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_HostAuthController.new),
          notificationControllerProvider.overrideWith(
            _FakeNotificationController.new,
          ),
          browseSessionsControllerProvider.overrideWith(
            _FakeSessionsController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Bản đồ'), findsOneWidget);
    expect(find.text('Danh sách'), findsNothing);
    await tester.tap(find.byKey(const Key('session-map-view-toggle')));
    await tester.pump();

    expect(_FakeSessionsController.mapLoads, 1);
    expect(find.text('Bản đồ'), findsNothing);
    expect(find.text('Danh sách'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const Key('home-create-session-button')), findsOneWidget);
  });

  testWidgets('changing the default city keeps map mode and reloads markers', (
    tester,
  ) async {
    _FakeSessionsController.loads = 0;
    _FakeSessionsController.mapLoads = 0;
    _FakeSessionsController.lastFilters = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_HostAuthController.new),
          notificationControllerProvider.overrideWith(
            _FakeNotificationController.new,
          ),
          locationPreferencesControllerProvider.overrideWith(
            _HomeLocationPreferencesController.new,
          ),
          newAdminUnitsProvider.overrideWith(
            (ref) async => const [
              NewAdminUnit(city: 'Thành phố Hồ Chí Minh', wards: []),
              NewAdminUnit(city: 'Thành phố Hà Nội', wards: []),
            ],
          ),
          browseSessionsControllerProvider.overrideWith(
            _FakeSessionsController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('session-map-view-toggle')));
    await tester.pump();
    expect(_FakeSessionsController.mapLoads, 1);

    await tester.tap(find.byKey(const Key('discovery-city-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discovery-city-Hà Nội')));
    await tester.pumpAndSettle();

    expect(find.text('Danh sách'), findsOneWidget);
    expect(_FakeSessionsController.lastFilters?.city, 'Hà Nội');
    expect(_FakeSessionsController.lastFilters?.cityIsDefault, isTrue);
    expect(_FakeSessionsController.mapLoads, 2);
  });

  testWidgets(
    'map toggle shows only the destination view',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_HostAuthController.new),
            notificationControllerProvider.overrideWith(
              _FakeNotificationController.new,
            ),
            browseSessionsControllerProvider.overrideWith(
              _FakeSessionsController.new,
            ),
            clubsControllerProvider.overrideWith(_FakeClubsController.new),
            tournamentBrowseControllerProvider.overrideWith(
              _FakeTournamentsController.new,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('vi'),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Vmito'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Vmito')).style?.color,
        AppTheme.light.colorScheme.primary,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(
        find.byKey(const Key('home-create-session-button')),
        findsOneWidget,
      );
      expect(
        tester
            .getCenter(find.byKey(const Key('home-create-session-button')))
            .dx,
        lessThan(
          tester.getCenter(find.byKey(const Key('home-search-button'))).dx,
        ),
      );
      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Danh sách'), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('session-map-view-toggle'))).height,
        48,
      );
      expect(
        find.byKey(const Key('discovery-city-selector')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('home-discovery-tab-clubs')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('home-create-club-button')), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const Key('home-create-club-button'))).dx,
        lessThan(
          tester.getCenter(find.byKey(const Key('home-search-button'))).dx,
        ),
      );

      await tester.tap(find.byKey(const Key('home-discovery-tab-tournaments')));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('home-create-tournament-button')),
        findsOneWidget,
      );
      expect(
        tester
            .getCenter(find.byKey(const Key('home-create-tournament-button')))
            .dx,
        lessThan(
          tester.getCenter(find.byKey(const Key('home-search-button'))).dx,
        ),
      );
    },
  );

  testWidgets('submitted search shows result AppBar and back restores browse', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: AppRoutes.homeSearchPath,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const Key('fake-search-submit'),
                    onPressed: () => context.pop('quang hung'),
                    child: const Text('Submit'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browseSessionsControllerProvider.overrideWith(
            _FakeSessionsController.new,
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('home-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake-search-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-search-result-query')), findsOneWidget);
    expect(find.text('quang hung'), findsOneWidget);
    expect(find.byKey(const Key('home-discovery-filter')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-search-exit-results')));
    await tester.pump();

    expect(find.byKey(const Key('home-search-button')), findsOneWidget);
    expect(find.byKey(const Key('home-search-result-query')), findsNothing);
  });

  testWidgets('venue search results expose the combined filter sheet', (
    tester,
  ) async {
    final venueController = _SearchVenuesController();
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(
            initialDiscoveryTab: HomeDiscoveryTab.venues,
          ),
          routes: [
            GoRoute(
              path: AppRoutes.homeSearchPath,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const Key('fake-venue-search-submit'),
                    onPressed: () => context.pop('thpt'),
                    child: const Text('Submit venue search'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueBrowseControllerProvider.overrideWith(() => venueController),
        ],
        child: MaterialApp.router(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-discovery-filter')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake-venue-search-submit')));
    await tester.pumpAndSettle();

    expect(venueController.state.filter.keyword, 'thpt');
    expect(venueController.state.filter.sortBy, 'relevance');
    expect(find.byKey(const Key('home-discovery-filter')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-discovery-filter')));
    await tester.pumpAndSettle();

    expect(find.byType(VenueFilterSheet), findsOneWidget);
    expect(find.text('Lọc và sắp xếp'), findsOneWidget);
  });

  testWidgets('Home can open with venues selected from routing state', (
    tester,
  ) async {
    _FakeSessionsController.loads = 0;
    _FakeVenuesController.loads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browseSessionsControllerProvider.overrideWith(
            _FakeSessionsController.new,
          ),
          venueBrowseControllerProvider.overrideWith(
            _FakeVenuesController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(
            initialDiscoveryTab: HomeDiscoveryTab.venues,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BrowseVenuesScreen), findsOneWidget);
    expect(_FakeVenuesController.loads, 1);
    expect(_FakeSessionsController.loads, 0);
    expect(
      find.byKey(const Key('home-discovery-indicator-venues')),
      findsOneWidget,
    );
  });

  testWidgets('venue filter chip clears the venue and reloads sessions', (
    tester,
  ) async {
    _VenueFilterSessionsController.lastFilters = null;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browseSessionsControllerProvider.overrideWith(
            _VenueFilterSessionsController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: BrowseSessionsContent(
              initialFilters: BrowseSessionFilters(
                venueId: 'venue-1',
                venueName: 'Sân A',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('session-venue-filter-chip')),
      findsOneWidget,
    );
    tester
        .widget<InputChip>(find.byKey(const Key('session-venue-filter-chip')))
        .onDeleted!();
    await tester.pump();

    expect(_VenueFilterSessionsController.lastFilters?.venueId, isNull);
    expect(find.byKey(const Key('session-venue-filter-chip')), findsNothing);
  });
}

class _FakeSessionsController extends BrowseSessionsController {
  static int loads = 0;
  static int mapLoads = 0;
  static BrowseSessionFilters? lastFilters;

  @override
  Future<void> load({String? search, BrowseSessionFilters? filters}) async {
    loads++;
    final next = filters ?? state.filters;
    lastFilters = next;
    state = state.copyWith(filters: next);
  }

  @override
  Future<void> loadMap() async {
    mapLoads++;
    state = state.copyWith(mapSessions: const [], isMapLoading: false);
  }
}

class _ScrollableSessionsController extends BrowseSessionsController {
  static BrowseSessionFilters? lastFilters;

  @override
  BrowseSessionsState build() => BrowseSessionsState(
    sessions: List.generate(
      20,
      (index) => Session(
        id: 'session-$index',
        name: 'Kèo $index',
        status: SessionStatus.preparing,
        startTime: DateTime(2026, 9, 1, 18 + (index % 3)),
      ),
    ),
    page: 1,
    totalPages: 1,
  );

  @override
  Future<void> load({String? search, BrowseSessionFilters? filters}) async {
    final next = filters ?? state.filters;
    lastFilters = next;
    state = state.copyWith(filters: next);
  }
}

class _HomeLocationPreferencesController extends LocationPreferencesController {
  @override
  LocationPreferences build() => const LocationPreferences(
    preferredCity: 'Hồ Chí Minh',
    onboardingCompleted: true,
    isRestored: true,
  );

  @override
  Future<void> selectCity(String? city) async {
    state = state.copyWith(
      preferredCity: city,
      clearPreferredCity: city == null,
      onboardingCompleted: true,
    );
  }
}

class _FakeVenuesController extends VenueBrowseController {
  static int loads = 0;

  @override
  Future<void> load({VenueFilter? filter}) async {
    loads++;
  }
}

class _SearchVenuesController extends VenueBrowseController {
  @override
  Future<void> load({VenueFilter? filter}) async {
    state = VenueBrowseState(filter: filter ?? state.filter);
  }
}

class _VenueFilterSessionsController extends BrowseSessionsController {
  static BrowseSessionFilters? lastFilters;

  @override
  Future<void> load({String? search, BrowseSessionFilters? filters}) async {
    final next = filters ?? state.filters;
    lastFilters = next;
    state = state.copyWith(filters: next);
  }
}

class _FakeClubsController extends ClubsController {
  static int loads = 0;

  @override
  Future<void> load({
    String search = '',
    String? city,
    String? district,
    String? sortBy,
    bool? favoriteOnly,
    double? latitude,
    double? longitude,
    bool clearCity = false,
    bool clearDistrict = false,
  }) async {
    loads++;
  }
}

class _FakeTournamentsController extends TournamentBrowseController {
  static int loads = 0;

  @override
  Future<void> load({
    String? search,
    String? city,
    bool clearCity = false,
    Set<TournamentStatus>? statuses,
    Set<String>? sportTypes,
    bool? favoriteOnly,
    TournamentBrowseSort? sort,
  }) async {
    loads++;
  }
}

class _HostAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'host-1',
      email: 'host@example.com',
      role: UserRole.host,
    ),
  );
}

class _FakeNotificationController extends NotificationController {
  @override
  NotificationState build() => const NotificationState();

  @override
  Future<void> refreshUnreadCount() async {}
}
