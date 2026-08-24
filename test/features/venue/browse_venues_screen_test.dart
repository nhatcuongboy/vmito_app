import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/browse_venues_screen.dart';
import 'package:vmito_app/features/venue/presentation/venue_filter_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

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
      expect(find.byKey(const Key('venue-filter-summary')), findsOneWidget);
      expect(find.text('Mới nhất'), findsOneWidget);
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

    testWidgets('VenueCard uses coverPhoto as avatar when logo is absent', (
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
    });
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
