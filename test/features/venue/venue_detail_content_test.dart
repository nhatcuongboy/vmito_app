import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/venue_detail_content.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _venue = Venue(
  id: 'venue-1',
  name: 'Sân Cầu Lông Vmito',
  address: '12 Nguyễn Trãi',
  newDistrict: 'Phường Bến Thành',
  newCity: 'Hồ Chí Minh',
  description:
      'Sân rộng, thoáng và có đầy đủ tiện nghi cho người chơi. '
      'Đây là phần mô tả dài dùng để kiểm tra bố cục cuộn liên tục. '
      'Khách có thể đặt lịch theo giờ và sử dụng khu vực thay đồ riêng. '
      'Sân rộng, thoáng và có đầy đủ tiện nghi cho người chơi. '
      'Đây là phần mô tả dài dùng để kiểm tra bố cục cuộn liên tục. '
      'Khách có thể đặt lịch theo giờ và sử dụng khu vực thay đồ riêng.',
  coverPhoto: 'https://example.invalid/cover.jpg',
  images: [
    'https://example.invalid/one.jpg',
    'https://example.invalid/two.jpg',
  ],
  openingHours: '06:00 – 22:00',
  numberOfCourts: 6,
  phone: '0901234567',
  website: 'https://vmito.com',
  distance: 3.2,
  isVerified: true,
  amenities: ['Bãi xe', 'Căn tin'],
);

final _book = VenuePriceBook(
  id: 'price-1',
  isActive: true,
  effectiveFrom: DateTime(2026),
  priority: 10,
  rules: const [
    VenuePriceRule(
      dayType: 'WEEKDAY',
      customerType: 'FIXED',
      startMinute: 360,
      endMinute: 600,
      pricePerHour: 80000,
    ),
    VenuePriceRule(
      dayType: 'WEEKDAY',
      customerType: 'WALK_IN',
      startMinute: 360,
      endMinute: 600,
      pricePerHour: 80000,
    ),
  ],
);

Future<void> _pump(WidgetTester tester, {double width = 390}) async {
  tester.view
    ..physicalSize = Size(width * 3, 844 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [isSignedInProvider.overrideWithValue(false)],
      child: MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VenueDetailContent(
            venue: _venue,
            priceBooks: AsyncData([_book]),
            onBack: () {},
            onShare: () {},
            onCall: () {},
            onWebsite: () {},
            onZalo: () {},
            onDirections: () {},
            onFindSessions: () {},
            onRequestUpdate: () {},
            onPriceCorrection: () {},
            onImageCorrection: () {},
          ),
          bottomNavigationBar: VenueDetailBottomBar(
            phone: _venue.phone,
            minimumPrice: minimumVenuePrice([_book]),
            onCall: () {},
            onFindSessions: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders venue detail as one continuous mobile scroll', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(TabBarView), findsNothing);
    expect(find.byKey(const Key('venue-hero-carousel')), findsOneWidget);
    expect(find.byKey(const ValueKey('venue-hero-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('venue-logo')), findsNothing);
    expect(find.byKey(const Key('venue-verified-badge')), findsOneWidget);
    expect(find.byKey(const Key('venue-info-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-about-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-pricing-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-photos-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-location-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-contribution-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-price-collapsed-rate')), findsOneWidget);
    expect(find.byKey(const Key('venue-call-button')), findsOneWidget);
    expect(find.byKey(const Key('venue-find-sessions-button')), findsOneWidget);
    expect(find.textContaining('80.000'), findsNWidgets(2));
  });

  testWidgets('reveals sticky title after the hero scrolls away', (
    tester,
  ) async {
    await _pump(tester);
    AnimatedOpacity sticky() => tester.widget<AnimatedOpacity>(
      find.byKey(const Key('venue-sticky-title')),
    );

    expect(sticky().opacity, 0);
    await tester.drag(
      find.byKey(const Key('venue-detail-scroll')),
      const Offset(0, -360),
    );
    await tester.pump();
    expect(sticky().opacity, 1);
  });

  testWidgets('does not overflow at a narrow phone width', (tester) async {
    await _pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });

  test('selects the minimum price from the active price book', () {
    expect(minimumVenuePrice([_book]), 80000);
  });

  test('builds a Home route carrying the venue filter', () {
    final uri = Uri.parse(AppRoutes.homeForVenue('venue 1', 'Sân A'));

    expect(uri.path, AppRoutes.home);
    expect(uri.queryParameters['venueId'], 'venue 1');
    expect(uri.queryParameters['venueName'], 'Sân A');
  });
}
