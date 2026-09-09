import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/browse_venues_screen.dart';
import 'package:vmito_app/features/venue/presentation/venue_card_skeleton.dart';
import 'package:vmito_app/features/venue/presentation/venue_filter_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_paginated_list_view.dart';

void main() {
  Widget buildApp(
    Widget child, {
    List<Object> overrides = const [],
  }) => ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  group('BrowseVenuesScreen', () {
    testWidgets('shows venue card skeletons during the first load', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          const BrowseVenuesScreen(embedded: true, showMapToggle: true),
          overrides: [
            venueBrowseControllerProvider.overrideWith(
              () => _FakeVenueBrowseController(
                const VenueBrowseState(isLoading: true),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('venue-skeleton-list')), findsOneWidget);
      expect(find.byType(VenueCardSkeleton), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('venue-map-view-toggle')), findsOneWidget);
    });

    testWidgets('refresh indicator starts below discovery controls', (
      tester,
    ) async {
      const discoveryHeaderKey = Key('test-discovery-header');
      await tester.pumpWidget(
        buildApp(
          const BrowseVenuesScreen(
            embedded: true,
            showFilterSummary: true,
            discoveryHeader: SizedBox(
              key: discoveryHeaderKey,
              height: 96,
            ),
          ),
          overrides: [
            venueBrowseControllerProvider.overrideWith(
              () => _FakeVenueBrowseController(
                const VenueBrowseState(
                  filter: VenueFilter(sortBy: 'createdAt'),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final refreshIndicator = find.byKey(
        const Key('venue-refresh-indicator'),
      );
      expect(refreshIndicator, findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(discoveryHeaderKey),
          matching: refreshIndicator,
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('venue-filter-summary')),
          matching: refreshIndicator,
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(refreshIndicator).dy,
        greaterThanOrEqualTo(
          tester
              .getBottomLeft(
                find.byKey(const Key('venue-filter-summary')),
              )
              .dy,
        ),
      );
    });

    testWidgets('renders active filter and sort summary without old dropdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          const BrowseVenuesScreen(
            embedded: true,
            showFilterSummary: true,
            initialFilter: VenueFilter(
              keyword: 'phu nhuan',
              city: 'Hà Nội',
              sortBy: 'createdAt',
              favoriteOnly: true,
            ),
          ),
          overrides: [
            venueBrowseControllerProvider.overrideWith(
              () => _FakeVenueBrowseController(
                const VenueBrowseState(
                  filter: VenueFilter(
                    keyword: 'phu nhuan',
                    city: 'Hà Nội',
                    sortBy: 'createdAt',
                    favoriteOnly: true,
                  ),
                  venues: [
                    Venue(
                      id: 'v1',
                      name: 'Sân Cầu Lông A',
                      coverPhoto: 'https://example.com/cover.jpg',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('venue-sort-button')), findsNothing);
      expect(find.byType(AppPaginatedListView), findsOneWidget);
      final paginatedList = tester.widget<AppPaginatedListView>(
        find.byType(AppPaginatedListView),
      );
      expect(paginatedList.itemCount, 1);
      expect(paginatedList.hasMore, isFalse);
      expect(paginatedList.isLoadingMore, isFalse);
      expect(find.byKey(const Key('venue-filter-summary')), findsOneWidget);
      expect(find.text('Mới đăng'), findsOneWidget);
      expect(find.text('Hà Nội'), findsOneWidget);
      expect(find.text('Chỉ sân yêu thích'), findsOneWidget);
    });

    testWidgets('filter sheet applies area, favorite, and sort together', (
      tester,
    ) async {
      final controller = _FakeVenueBrowseController(
        const VenueBrowseState(
          filter: VenueFilter(keyword: 'thpt', sortBy: 'relevance'),
        ),
      );
      await tester.pumpWidget(
        buildApp(
          const BrowseVenuesScreen(
            initialFilter: VenueFilter(keyword: 'thpt', sortBy: 'relevance'),
          ),
          overrides: [
            venueBrowseControllerProvider.overrideWith(() => controller),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('venue-filter-button')));
      await tester.pumpAndSettle();

      expect(find.byType(VenueFilterSheet), findsOneWidget);
      for (final option in VenueSortOption.values) {
        expect(
          find.byKey(Key('venue-filter-sort-${option.value}')),
          findsOneWidget,
        );
      }

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('venue-filter-city')),
          matching: find.byType(TextField),
        ),
        'Hồ Chí Minh',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('venue-filter-district')),
          matching: find.byType(TextField),
        ),
        'Phú Nhuận',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final courtsSort = find.byKey(
        const Key('venue-filter-sort-numberOfCourts'),
      );
      await tester.ensureVisible(courtsSort);
      await tester.tap(courtsSort);
      final favorite = find.byKey(const Key('venue-filter-favorite'));
      await tester.ensureVisible(favorite);
      await tester.tap(favorite);
      final apply = find.byKey(const Key('venue-filter-apply'));
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();

      expect(controller.state.filter.keyword, 'thpt');
      expect(controller.state.filter.city, 'Hồ Chí Minh');
      expect(controller.state.filter.district, 'Phú Nhuận');
      expect(controller.state.filter.sortBy, 'numberOfCourts');
      expect(controller.state.filter.favoriteOnly, isTrue);
    });

    testWidgets('filter reset preserves the search keyword', (tester) async {
      final controller = _FakeVenueBrowseController(
        const VenueBrowseState(
          filter: VenueFilter(
            keyword: 'thpt',
            city: 'Hà Nội',
            district: 'Ba Đình',
            sortBy: 'createdAt',
            favoriteOnly: true,
          ),
        ),
      );
      await tester.pumpWidget(
        buildApp(
          const BrowseVenuesScreen(
            initialFilter: VenueFilter(
              keyword: 'thpt',
              city: 'Hà Nội',
              district: 'Ba Đình',
              sortBy: 'createdAt',
              favoriteOnly: true,
            ),
          ),
          overrides: [
            venueBrowseControllerProvider.overrideWith(() => controller),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('venue-filter-button')));
      await tester.pumpAndSettle();
      final reset = find.byKey(const Key('venue-filter-reset'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      final apply = find.byKey(const Key('venue-filter-apply'));
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();

      expect(controller.state.filter.keyword, 'thpt');
      expect(controller.state.filter.city, isNull);
      expect(controller.state.filter.district, isNull);
      expect(controller.state.filter.sortBy, 'relevance');
      expect(controller.state.filter.favoriteOnly, isFalse);
    });

    testWidgets('VenueCard shows the default logo when logo is absent', (
      tester,
    ) async {
      const venueWithoutLogo = Venue(
        id: 'v1',
        name: 'Sân Trường THPT Phú Nhuận',
        coverPhoto: 'https://example.com/cover_photo.jpg',
      );

      await tester.pumpWidget(
        buildApp(const VenueCard(venue: venueWithoutLogo)),
      );
      await tester.pump();

      expect(find.text('Sân Trường THPT Phú Nhuận'), findsOneWidget);
      expect(find.byType(ClipOval), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ClipOval),
          matching: find.byWidgetPredicate(
            (widget) => widget is Icon && widget.icon == AppIcons.location,
          ),
        ),
        findsOneWidget,
      );
      final favorite = tester.widget<FavoriteButton>(
        find.byType(FavoriteButton),
      );
      expect(favorite.type, FavoriteType.venue);
      expect(favorite.targetId, 'v1');
      expect(favorite.variant, FavoriteButtonVariant.card);
      expect(favorite.showCount, isFalse);
    });

    testWidgets(
      'VenueCard shows address, hours before courts, without badges',
      (
        tester,
      ) async {
        const venue = Venue(
          id: 'v1',
          name: '18E Cộng Hòa',
          address: '18E Cộng Hòa',
          newAddress: '18E Cộng Hòa mới',
          district: 'Tân Sơn Nhất',
          city: 'Hồ Chí Minh',
          numberOfCourts: 10,
          openingHours: '06:00 – 22:00',
          hourlyRateFixed: 120000,
          isVerified: true,
        );

        await tester.pumpWidget(buildApp(const VenueCard(venue: venue)));
        await tester.pump();

        expect(find.byKey(const Key('venue-verified-badge')), findsNothing);
        expect(
          find.byKey(const Key('venue-address-location-icon')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('venue-courts-meta')), findsOneWidget);
        expect(find.byKey(const Key('venue-hours-meta')), findsOneWidget);
        expect(find.byKey(const Key('venue-meta-divider')), findsNothing);
        expect(find.text('10 sân'), findsOneWidget);
        expect(find.text('06:00 – 22:00'), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('10 sân')).style?.fontWeight,
          FontWeight.normal,
        );
        expect(
          tester.widget<Text>(find.text('06:00 – 22:00')).style?.fontWeight,
          FontWeight.normal,
        );
        expect(find.text('Mới'), findsNothing);
        expect(find.text('120.000đ/giờ'), findsNothing);
        expect(
          tester.getCenter(find.byKey(const Key('venue-hours-meta'))).dx,
          lessThan(
            tester.getCenter(find.byKey(const Key('venue-courts-meta'))).dx,
          ),
        );
      },
    );
  });
}

class _FakeVenueBrowseController extends VenueBrowseController {
  _FakeVenueBrowseController(this._initialState);
  final VenueBrowseState _initialState;

  @override
  VenueBrowseState build() => _initialState;

  @override
  Future<void> load({VenueFilter? filter}) async {
    state = state.copyWithFilter(filter ?? state.filter);
  }
}

extension on VenueBrowseState {
  VenueBrowseState copyWithFilter(VenueFilter newFilter) => VenueBrowseState(
    venues: venues,
    filter: newFilter,
    page: page,
    totalPages: totalPages,
    isLoading: isLoading,
    isLoadingMore: isLoadingMore,
    error: error,
  );
}
