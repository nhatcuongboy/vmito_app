import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/data/favorite_repository.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/venue_detail_content.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _venue = Venue(
  id: 'venue-1',
  name: 'Sân Cầu Lông Vmito',
  address: '12 Nguyễn Trãi',
  district: 'Quận 1',
  city: 'Hồ Chí Minh',
  newAddress: '12 Nguyễn Trãi',
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
  hasCarParking: true,
  hasCanteen: false,
  wifiName: 'Vmito Guest',
  wifiPassword: '12345678',
  bookingPolicy: 'Đặt trước 30 phút.',
);

const _venueWithoutImages = Venue(
  id: 'venue-without-images',
  name: 'Sân chưa có ảnh',
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

class _TestLocationPreferencesController extends LocationPreferencesController {
  _TestLocationPreferencesController({required this.showNewAddress});

  final bool showNewAddress;

  @override
  LocationPreferences build() => LocationPreferences(
    showNewAddress: showNewAddress,
    isRestored: true,
  );
}

class _TestFavoriteRepository implements FavoriteRepository {
  @override
  Future<void> add(FavoriteType type, String targetId) async {}

  @override
  Future<void> remove(FavoriteType type, String targetId) async {}

  @override
  Future<FavoriteSummary> summary(FavoriteType type, String targetId) async =>
      const FavoriteSummary(favoriteCount: 12);
}

Future<void> _pump(
  WidgetTester tester, {
  double width = 390,
  Venue venue = _venue,
  AsyncValue<List<VenuePriceBook>>? priceBooks,
  VoidCallback? onDirections,
  VoidCallback? onCall,
  VoidCallback? onZalo,
  VoidCallback? onWebsite,
  VoidCallback? onRequestUpdate,
  bool showNewAddress = true,
  String? bottomPhone = '0901234567',
  int? minimumPrice = 80000,
  bool signedIn = false,
}) async {
  tester.view
    ..physicalSize = Size(width * 3, 844 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(showNewAddress),
      overrides: [
        isSignedInProvider.overrideWithValue(signedIn),
        favoriteRepositoryProvider.overrideWithValue(
          _TestFavoriteRepository(),
        ),
        locationPreferencesControllerProvider.overrideWith(
          () => _TestLocationPreferencesController(
            showNewAddress: showNewAddress,
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VenueDetailContent(
            venue: venue,
            priceBooks: priceBooks ?? AsyncData([_book]),
            onBack: () {},
            onShare: () {},
            onCall: onCall ?? () {},
            onZalo: onZalo ?? () {},
            onDirections: onDirections ?? () {},
            onFindSessions: () {},
            onRequestUpdate: onRequestUpdate ?? () {},
          ),
          bottomNavigationBar: VenueDetailBottomBar(
            phone: bottomPhone,
            website: venue.website,
            onCall: onCall ?? () {},
            onZalo: onZalo ?? () {},
            onWebsite: onWebsite ?? () {},
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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/icons/app-logo-96.png',
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('venue-verified-badge')), findsNothing);
    expect(find.byKey(const Key('venue-verified-icon')), findsOneWidget);
    expect(find.byKey(const Key('venue-info-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-about-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-pricing-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-amenities-heading')), findsOneWidget);
    expect(find.byKey(const Key('venue-photos-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-location-card')), findsNothing);
    expect(find.byKey(const Key('venue-contribution-card')), findsOneWidget);
    expect(find.byKey(const Key('venue-price-collapsed-rate')), findsOneWidget);
    expect(find.byKey(const Key('venue-call-button')), findsOneWidget);
    expect(find.byKey(const Key('venue-find-sessions-button')), findsOneWidget);
    expect(
      find.byKey(const Key('venue-address-directions-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('venue-directions-button')), findsNothing);
    expect(find.text('Bản đồ'), findsNothing);
    expect(find.text('Đề xuất chỉnh sửa'), findsOneWidget);
    expect(find.text('Gửi ảnh bảng giá'), findsNothing);
    expect(find.text('Gửi ảnh sân'), findsNothing);
    expect(find.textContaining('80.000'), findsOneWidget);
    expect(
      find.byKey(const Key('venue-website-bottom-button')),
      findsOneWidget,
    );

    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(appBar.expandedHeight, 220);

    final grid = tester.widget<GridView>(
      find.byKey(const Key('venue-photo-grid')),
    );
    expect(grid.padding, EdgeInsets.zero);
  });

  testWidgets('reveals sticky title after the hero scrolls away', (
    tester,
  ) async {
    await _pump(tester, signedIn: true);
    AnimatedOpacity sticky() => tester.widget<AnimatedOpacity>(
      find.byKey(const Key('venue-sticky-title')),
    );

    expect(sticky().opacity, 0);
    expect(find.byKey(const Key('venue-favorite-button')), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    final stickyText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('venue-sticky-title')),
        matching: find.byType(Text),
      ),
    );
    expect(stickyText.style?.fontSize, 16);
    expect(stickyText.style?.height, closeTo(20 / 16, 0.0001));
    expect(stickyText.style?.fontWeight, FontWeight.w700);
    expect(stickyText.maxLines, 1);
    expect(stickyText.overflow, TextOverflow.ellipsis);
    await tester.drag(
      find.byKey(const Key('venue-detail-scroll')),
      const Offset(0, -360),
    );
    await tester.pump();
    expect(sticky().opacity, 1);
    expect(find.byKey(const Key('venue-favorite-button')), findsNothing);
    expect(find.text('12'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('venue-share-button'))),
      const Size.square(FavoriteButton.detailControlSize),
    );
  });

  testWidgets('shows the favorite count only on the expanded cover', (
    tester,
  ) async {
    await _pump(tester, signedIn: true);

    expect(find.text('12'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('venue-favorite-button'))).width,
      greaterThan(
        tester.getSize(find.byKey(const Key('venue-share-button'))).width,
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('venue-share-button'))),
      const Size.square(FavoriteButton.detailControlSize),
    );
  });

  testWidgets('opens directions from the address row', (tester) async {
    var openedDirections = false;
    await _pump(
      tester,
      venue: const Venue(
        id: 'long-address',
        name: 'Sân địa chỉ dài',
        address: '5 Hoàng Minh Giám',
        district: 'Phường Đức Nhuận',
        city:
            'Thành Phố Hồ Chí Minh, Phường Đức Nhuận, '
            'Thành Phố Hồ Chí Minh',
        newAddress: '5 Hoàng Minh Giám',
        newDistrict: 'Phường Đức Nhuận',
        newCity:
            'Thành Phố Hồ Chí Minh, Phường Đức Nhuận, '
            'Thành Phố Hồ Chí Minh',
      ),
      onDirections: () => openedDirections = true,
    );

    final address = tester.getRect(find.byKey(const Key('venue-address')));
    final directions = tester.getRect(
      find.byKey(const Key('venue-address-directions-button')),
    );
    final leadingAddressLines = tester.getRect(
      find
          .descendant(
            of: find.byKey(const Key('venue-address')),
            matching: find.byType(Text),
          )
          .first,
    );
    final locationIcon = tester.getRect(
      find.byKey(const Key('venue-address-location-icon')),
    );
    expect(locationIcon.top, closeTo(leadingAddressLines.top, 3));
    expect(directions.bottom, closeTo(address.bottom, 0.1));
    expect(directions.left, greaterThanOrEqualTo(address.left));
    expect(directions.right, lessThanOrEqualTo(address.right));
    expect(directions.height, lessThanOrEqualTo(24));
    expect(leadingAddressLines.right, closeTo(address.right, 0.1));

    final directionsButton = tester.widget<IconButton>(
      find.byKey(const Key('venue-address-directions-button')),
    );
    final addressText = tester.widget<Text>(
      find
          .descendant(
            of: find.byKey(const Key('venue-address')),
            matching: find.byType(Text),
          )
          .first,
    );
    expect(
      addressText.textSpan?.toPlainText(includePlaceholders: false),
      contains(
        '5 Hoàng Minh Giám, Phường Đức Nhuận, '
        'Thành Phố Hồ Chí Minh',
      ),
    );
    final directionsIcon = directionsButton.icon as Icon;
    expect(directionsIcon.icon, AppIcons.navigation);
    expect(directionsButton.color, AppTheme.light.colorScheme.primary);
    expect(
      directionsButton.style?.backgroundColor?.resolve({}),
      isNull,
    );

    await tester.tap(find.byKey(const Key('venue-address-directions-button')));
    await tester.pump();

    expect(openedDirections, isTrue);
  });

  testWidgets('matches web typography and formats a missing venue prefix', (
    tester,
  ) async {
    await _pump(
      tester,
      venue: const Venue(
        id: 'venue-prefix',
        name: 'Phú Nhuận',
        sportTypes: ['BADMINTON', 'PICKLEBALL'],
      ),
    );

    final venueName = tester.widget<Text>(
      find.byKey(const Key('venue-display-name')),
    );
    final aboutHeading = tester.widget<Text>(find.text('Giới thiệu về sân'));
    final pricingHeading = tester.widget<Text>(find.text('Bảng giá'));

    expect(venueName.data, 'Sân Phú Nhuận');
    expect(venueName.style?.fontSize, 20);
    expect(aboutHeading.style?.fontSize, 16);
    expect(pricingHeading.style?.fontSize, 16);
  });

  testWidgets('shows the complete pricing row like the web venue detail', (
    tester,
  ) async {
    final book = VenuePriceBook(
      id: 'current-prices',
      isActive: true,
      effectiveFrom: DateTime(2026, 8),
      priority: 10,
      rules: const [
        VenuePriceRule(
          dayType: 'WEEKEND',
          customerType: 'FIXED',
          startMinute: 360,
          endMinute: 1440,
          pricePerHour: 150000,
        ),
        VenuePriceRule(
          dayType: 'WEEKEND',
          customerType: 'WALK_IN',
          startMinute: 360,
          endMinute: 1440,
          pricePerHour: 130000,
        ),
      ],
    );

    await _pump(tester, priceBooks: AsyncData([book]));

    expect(find.text('T7 - CN'), findsOneWidget);
    expect(find.text('6h - 24h'), findsOneWidget);
    expect(find.text('Cố định: 150.000 đ'), findsOneWidget);
    expect(find.text('Vãng lai: 130.000 đ'), findsOneWidget);
    expect(find.textContaining('.150.000'), findsNothing);
  });

  testWidgets('shows configured weekdays and specific dates', (tester) async {
    final book = VenuePriceBook(
      id: 'scheduled-prices',
      isActive: true,
      effectiveFrom: DateTime(2026, 8),
      rules: const [
        VenuePriceRule(
          dayType: 'SPECIFIC_DATE',
          specificDate: '2026-09-02',
          customerType: 'WALK_IN',
          startMinute: 480,
          endMinute: 600,
          pricePerHour: 120000,
        ),
        VenuePriceRule(
          dayType: 'WEEKDAY',
          daysOfWeek: [1, 3, 5],
          customerType: 'FIXED',
          startMinute: 360,
          endMinute: 480,
          pricePerHour: 100000,
        ),
      ],
    );

    await _pump(tester, priceBooks: AsyncData([book]));

    expect(find.text('T2, T4, T6'), findsOneWidget);
    expect(find.text('6h - 8h'), findsOneWidget);
    expect(find.text('2/9/2026'), findsOneWidget);
    expect(find.text('8h - 10h'), findsOneWidget);
  });

  testWidgets(
    'shows the new-address badge only for the preferred new address',
    (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Mới'), findsOneWidget);
      expect(find.textContaining('12 Nguyễn Trãi'), findsOneWidget);

      await _pump(tester, showNewAddress: false);
      expect(find.text('Mới'), findsNothing);
      expect(find.textContaining('Quận 1'), findsOneWidget);
    },
  );

  testWidgets('renders contact rows and dispatches their actions', (
    tester,
  ) async {
    var callCount = 0;
    var zaloCount = 0;
    var websiteCount = 0;
    await _pump(
      tester,
      onCall: () => callCount++,
      onZalo: () => zaloCount++,
      onWebsite: () => websiteCount++,
    );

    expect(find.text('Điện thoại'), findsNothing);
    expect(find.text('0901 234 567'), findsNothing);
    expect(find.text('https://vmito.com'), findsNothing);

    final zalo = tester.getTopRight(
      find.byKey(const Key('venue-zalo-bottom-button')),
    );
    final website = tester.getTopLeft(
      find.byKey(const Key('venue-website-bottom-button')),
    );
    expect(website.dx, greaterThan(zalo.dx));

    await tester.tap(find.byKey(const Key('venue-call-button')));
    await tester.tap(find.byKey(const Key('venue-zalo-bottom-button')));
    await tester.tap(find.byKey(const Key('venue-website-bottom-button')));
    await tester.pump();

    expect(callCount, 1);
    expect(zaloCount, 1);
    expect(websiteCount, 1);
  });

  testWidgets('renders web amenity states, wifi and booking policy', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Tiện ích & Quy định'), findsOneWidget);
    expect(find.byKey(const Key('venue-car-parking')), findsOneWidget);
    expect(find.byKey(const Key('venue-canteen')), findsOneWidget);
    expect(find.text('Vmito Guest'), findsOneWidget);
    expect(find.text('Mật khẩu: 12345678'), findsOneWidget);
    expect(find.text('Đặt trước 30 phút.'), findsOneWidget);
  });

  testWidgets('hides amenities and unavailable contact rows', (tester) async {
    await _pump(
      tester,
      venue: const Venue(
        id: 'minimal',
        name: 'Sân tối giản',
        phone: '0901234567',
      ),
    );

    expect(find.text('Tiện ích & Quy định'), findsNothing);
    expect(find.byKey(const Key('venue-phone-button')), findsNothing);
    expect(find.byKey(const Key('venue-zalo-button')), findsNothing);
    expect(find.byKey(const Key('venue-zalo-bottom-button')), findsOneWidget);
    expect(find.byKey(const Key('venue-website-bottom-button')), findsNothing);

    await _pump(
      tester,
      venue: const Venue(
        id: 'website-only',
        name: 'Sân có website',
        website: 'https://vmito.com',
      ),
    );
    expect(find.byKey(const Key('venue-phone-button')), findsNothing);
    expect(find.byKey(const Key('venue-zalo-button')), findsNothing);
    expect(
      find.byKey(const Key('venue-website-bottom-button')),
      findsOneWidget,
    );
  });

  testWidgets('dispatches the suggest-edit action from the ghost button', (
    tester,
  ) async {
    var requested = false;
    await _pump(tester, onRequestUpdate: () => requested = true);

    await tester.drag(
      find.byKey(const Key('venue-detail-scroll')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('venue-request-update-button')));
    await tester.pump();

    expect(requested, isTrue);
  });

  testWidgets('matches empty pricing copy style with the about copy', (
    tester,
  ) async {
    await _pump(
      tester,
      venue: _venueWithoutImages,
      priceBooks: const AsyncData([]),
    );

    final aboutText = tester.widget<Text>(find.text('Chưa có mô tả.'));
    final pricingText = tester.widget<Text>(find.text('Chưa có bảng giá.'));

    expect(pricingText.style?.fontSize, aboutText.style?.fontSize);
    expect(pricingText.style?.height, aboutText.style?.height);
  });

  testWidgets('uses the browse-venues default cover when no images exist', (
    tester,
  ) async {
    await _pump(tester, venue: _venueWithoutImages);

    expect(find.byKey(const Key('venue-default-cover')), findsOneWidget);
    expect(find.byKey(const Key('venue-hero-carousel')), findsNothing);
  });

  testWidgets('does not overflow at a narrow phone width', (tester) async {
    await _pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the compact find-sessions action aligned right', (
    tester,
  ) async {
    await _pump(tester);

    final button = tester.getRect(
      find.byKey(const Key('venue-find-sessions-button')),
    );
    final bottomBar = tester.getRect(find.byType(VenueDetailBottomBar));
    expect(button.width, lessThan(bottomBar.width / 2));
    expect(button.right, closeTo(bottomBar.right - 16, 0.1));
  });

  testWidgets('styles the call action green with and without a price', (
    tester,
  ) async {
    await _pump(tester);

    IconButton callButton() => tester.widget<IconButton>(
      find.byKey(const Key('venue-call-button')),
    );
    final primary = AppTheme.light.colorScheme.primary;
    expect(callButton().style?.foregroundColor?.resolve({}), primary);
    expect(callButton().style?.side?.resolve({})?.color, primary);

    await _pump(tester, minimumPrice: null);
    expect(find.byKey(const Key('venue-call-button')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(tester, bottomPhone: null, minimumPrice: null);
    expect(find.byKey(const Key('venue-call-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('selects the minimum price from the active price book', () {
    expect(minimumVenuePrice([_book]), 80000);
  });

  test('ignores non-public customer types in the minimum price', () {
    final book = VenuePriceBook(
      id: 'customer-specific-prices',
      isActive: true,
      effectiveFrom: DateTime(2026),
      rules: const [
        VenuePriceRule(
          dayType: 'EVERYDAY',
          customerType: 'STUDENT',
          startMinute: 360,
          endMinute: 1440,
          pricePerHour: 50000,
        ),
        VenuePriceRule(
          dayType: 'EVERYDAY',
          customerType: 'WALK_IN',
          startMinute: 360,
          endMinute: 1440,
          pricePerHour: 130000,
        ),
      ],
    );

    expect(minimumVenuePrice([book]), 130000);
  });

  test('selects the newest active price book when priorities are equal', () {
    final older = VenuePriceBook(
      id: 'older',
      isActive: true,
      effectiveFrom: DateTime(2026),
      priority: 10,
      rules: const [
        VenuePriceRule(
          dayType: 'EVERYDAY',
          customerType: 'FIXED',
          startMinute: 360,
          endMinute: 1440,
          pricePerHour: 150000,
        ),
      ],
    );
    final newer = VenuePriceBook(
      id: 'newer',
      isActive: true,
      effectiveFrom: DateTime(2026, 8),
      priority: 10,
      rules: const [
        VenuePriceRule(
          dayType: 'EVERYDAY',
          customerType: 'WALK_IN',
          startMinute: 360,
          endMinute: 1440,
          pricePerHour: 130000,
        ),
      ],
    );

    expect(activeVenuePriceBook([older, newer])?.id, 'newer');
    expect(minimumVenuePrice([older, newer]), 130000);
  });

  test('builds a Home route carrying the venue filter', () {
    final uri = Uri.parse(AppRoutes.homeForVenue('venue 1', 'Sân A'));

    expect(uri.path, AppRoutes.home);
    expect(uri.queryParameters['venueId'], 'venue 1');
    expect(uri.queryParameters['venueName'], 'Sân A');
  });
}
