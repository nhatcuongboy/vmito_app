import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/club_browse_filters.dart';
import 'package:vmito_app/features/social/presentation/browse_clubs_screen.dart';
import 'package:vmito_app/features/social/presentation/club_browse_card_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_paginated_list_view.dart';

class _TestClubsController extends ClubsController {
  _TestClubsController(this.initialState);

  final ClubsState initialState;

  @override
  ClubsState build() => initialState;

  @override
  Future<void> load({
    String? search,
    ClubBrowseFilters? filters,
    String? sortBy,
    double? latitude,
    double? longitude,
    bool isPullToRefresh = false,
  }) async {}
}

class _TestLocationPreferencesController extends LocationPreferencesController {
  @override
  LocationPreferences build() => const LocationPreferences(isRestored: true);
}

void main() {
  testWidgets('shows club card skeletons during the first load', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPreferencesControllerProvider.overrideWith(
            _TestLocationPreferencesController.new,
          ),
          clubsControllerProvider.overrideWith(
            () => _TestClubsController(const ClubsState(isLoading: true)),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BrowseClubsScreen(embedded: true, showMapToggle: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('club-skeleton-list')), findsOneWidget);
    expect(find.byType(ClubBrowseCardSkeleton), findsAtLeastNWidgets(3));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('club-map-view-toggle')), findsOneWidget);
  });

  testWidgets('club card shows schedule and location metadata with icons', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const club = ClubSummary(
      id: 'club-1',
      name: 'Nhóm Cầu Lông Vmito',
      memberCount: 24,
      joinPolicy: 'OPEN',
      logo: 'https://example.invalid/logo.jpg',
      defaultVenue: ClubVenue(
        name: 'Sân Trung tâm',
        address: '12 Nguyễn Trãi',
      ),
      schedules: [
        ClubSchedule(dayOfWeek: 1, startTime: '19:00', endTime: '21:00'),
        ClubSchedule(dayOfWeek: 2, startTime: '19:00', endTime: '21:00'),
        ClubSchedule(dayOfWeek: 3, startTime: '19:00', endTime: '21:00'),
        ClubSchedule(dayOfWeek: 4, startTime: '19:00', endTime: '21:00'),
        ClubSchedule(dayOfWeek: 5, startTime: '19:00', endTime: '21:00'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSignedInProvider.overrideWithValue(false),
          locationPreferencesControllerProvider.overrideWith(
            _TestLocationPreferencesController.new,
          ),
          clubsControllerProvider.overrideWith(
            () => _TestClubsController(
              const ClubsState(
                clubs: [club],
                page: 1,
                totalPages: 1,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BrowseClubsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('thành viên'), findsNothing);
    expect(find.text('Thứ 2 – Thứ 6 · 19:00–21:00'), findsOneWidget);
    expect(find.text('Sân Trung tâm'), findsOneWidget);
    expect(find.byType(AppPaginatedListView), findsOneWidget);
    final paginatedList = tester.widget<AppPaginatedListView>(
      find.byType(AppPaginatedListView),
    );
    expect(paginatedList.itemCount, 1);
    expect(paginatedList.hasMore, isFalse);
    expect(paginatedList.isLoadingMore, isFalse);
    expect(find.byIcon(AppIcons.clock), findsOneWidget);
    expect(find.byIcon(AppIcons.location), findsOneWidget);

    final logo = tester.widget<Container>(
      find.byKey(const Key('club-card-logo')),
    );
    final decoration = logo.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.border, isNotNull);
    expect(decoration.border!.top.color, Colors.white);

    final favorite = tester.widget<FavoriteButton>(
      find.byType(FavoriteButton),
    );
    expect(favorite.type, FavoriteType.club);
    expect(favorite.targetId, 'club-1');
    expect(favorite.variant, FavoriteButtonVariant.card);
    expect(favorite.showCount, isFalse);
    expect(find.byIcon(AppIcons.favorite), findsNothing);
  });
}
