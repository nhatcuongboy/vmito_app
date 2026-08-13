import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/home/presentation/home_screen.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_discovery_tabs.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/presentation/player/public_sessions_content.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/presentation/browse_clubs_screen.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/presentation/browse_tournaments_content.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/browse_venues_screen.dart';
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
    expect(find.byType(FloatingActionButton), findsOneWidget);

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
  static BrowseSessionFilters? lastFilters;

  @override
  Future<void> load({String? search, BrowseSessionFilters? filters}) async {
    loads++;
    lastFilters = filters;
  }
}

class _FakeVenuesController extends VenueBrowseController {
  static int loads = 0;

  @override
  Future<void> load({VenueFilter? filter}) async {
    loads++;
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
  }) async {
    loads++;
  }
}
