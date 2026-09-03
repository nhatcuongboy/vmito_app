import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/data/favorite_repository.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

Session _session({
  List<int> requiredLevels = const [],
  SessionFeeConfig? feeConfig,
  DateTime? startTime,
  DateTime? scheduledEndTime,
  DateTime? endTime,
  int sessionDuration = 0,
  bool isCrawled = false,
  SessionVenue? venue,
  String? location,
  String? hostName,
  bool isFavorite = false,
}) => Session(
  id: 's1',
  name: 'Kèo tối thứ 6',
  status: SessionStatus.preparing,
  requiredLevels: requiredLevels,
  feeConfig: feeConfig,
  startTime: startTime,
  scheduledEndTime: scheduledEndTime,
  endTime: endTime,
  sessionDuration: sessionDuration,
  isCrawled: isCrawled,
  venue: venue,
  location: location,
  hostName: hostName,
  isFavorite: isFavorite,
);

Future<void> _pump(
  WidgetTester tester,
  Session session, {
  bool showNewAddress = true,
  bool showFavorite = false,
  bool signedIn = false,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(showNewAddress),
      overrides: [
        locationPreferencesControllerProvider.overrideWith(
          () => _TestLocationPreferencesController(value: showNewAddress),
        ),
        isSignedInProvider.overrideWithValue(signedIn),
        favoriteRepositoryProvider.overrideWithValue(
          const _TestFavoriteRepository(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        theme: theme ?? AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SessionCard(
            session: session,
            showFavorite: showFavorite,
          ),
        ),
      ),
    ),
  );
}

class _TestFavoriteRepository implements FavoriteRepository {
  const _TestFavoriteRepository();

  @override
  Future<void> add(FavoriteType type, String targetId) async {}

  @override
  Future<void> remove(FavoriteType type, String targetId) async {}

  @override
  Future<FavoriteSummary> summary(FavoriteType type, String targetId) async =>
      const FavoriteSummary();
}

class _TestLocationPreferencesController extends LocationPreferencesController {
  _TestLocationPreferencesController({required this.value});

  final bool value;

  @override
  LocationPreferences build() => LocationPreferences(
    showNewAddress: value,
    isRestored: true,
  );
}

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('favorite is opt-in and uses the session API type', (
    tester,
  ) async {
    await _pump(tester, _session());
    expect(find.byType(FavoriteButton), findsNothing);

    await _pump(
      tester,
      _session(isFavorite: true),
      showFavorite: true,
      signedIn: true,
    );
    await tester.pumpAndSettle();

    final favorite = tester.widget<FavoriteButton>(
      find.byType(FavoriteButton),
    );
    expect(favorite.type, FavoriteType.session);
    expect(favorite.targetId, 's1');
    expect(favorite.initialIsFavorite, isTrue);
    expect(favorite.showCount, isFalse);
    expect(favorite.variant, FavoriteButtonVariant.surface);

    final headerRow = find.ancestor(
      of: find.byType(FavoriteButton),
      matching: find.byType(Row),
    );
    expect(headerRow, findsWidgets);
    expect(
      find.descendant(of: headerRow, matching: find.text('Kèo tối thứ 6')),
      findsOneWidget,
    );
  });

  testWidgets('favorite icon is hidden for guests', (tester) async {
    await _pump(tester, _session(), showFavorite: true);

    expect(find.byIcon(AppIcons.favorite), findsNothing);
  });

  group('skill band', () {
    testWidgets('shows the range in display order, not numeric order', (
      tester,
    ) async {
      // The trap: 9 is Yếu- and 10 is Yếu+, and both bracket 1 (Yếu). A
      // numeric range over [1, 9, 10] would read "Yếu → Yếu+" and hide that
      // weaker players are welcome.
      await _pump(tester, _session(requiredLevels: [1, 9, 10]));

      expect(find.text('Yếu-'), findsOneWidget);
      expect(find.text('Yếu+'), findsOneWidget);
      expect(find.text('Yếu'), findsNothing);
    });

    testWidgets('shows a single chip when the band is one level', (
      tester,
    ) async {
      await _pump(tester, _session(requiredLevels: [3]));

      expect(find.text('TB-'), findsOneWidget);
    });

    testWidgets('shows an explicit badge when all levels are welcome', (
      tester,
    ) async {
      await _pump(tester, _session());

      expect(find.text('Mọi trình độ'), findsOneWidget);
      expect(
        find.byKey(const Key('session-all-levels-badge')),
        findsOneWidget,
      );
      final badge = find.byKey(const Key('session-all-levels-badge'));
      final slot = find.ancestor(of: badge, matching: find.byType(Align));
      expect(tester.getSize(badge).width, lessThan(tester.getSize(slot).width));
      expect(find.text('Yếu'), findsNothing);
      expect(find.text('CN'), findsNothing);
    });
  });

  group('price', () {
    testWidgets('shows a compact range for gendered fixed fees', (
      tester,
    ) async {
      await _pump(
        tester,
        _session(
          feeConfig: const SessionFeeConfig(maleFee: 60000, femaleFee: 50000),
        ),
      );

      expect(find.text('50k-60k'), findsOneWidget);
    });

    testWidgets('collapses equal fees to one number', (tester) async {
      await _pump(
        tester,
        _session(
          feeConfig: const SessionFeeConfig(maleFee: 50000, femaleFee: 50000),
        ),
      );

      expect(find.text('50k'), findsOneWidget);
    });

    testWidgets('shows nothing when the session is unpriced', (tester) async {
      await _pump(
        tester,
        _session(feeConfig: const SessionFeeConfig()),
      );

      expect(find.textContaining('k'), findsNothing);
    });

    testWidgets('shows dong on a small fixed-fee range', (tester) async {
      await _pump(
        tester,
        _session(
          feeConfig: const SessionFeeConfig(maleFee: 65, femaleFee: 50),
        ),
      );

      expect(find.text('50đ-65đ'), findsOneWidget);
    });
  });

  group('time', () {
    testWidgets('styles host and date/time values for scanability', (
      tester,
    ) async {
      await _pump(
        tester,
        _session(
          hostName: 'Nguyễn Cường',
          startTime: DateTime.now(),
          scheduledEndTime: DateTime.now().add(const Duration(hours: 2)),
        ),
      );

      final host = tester.widget<Text>(
        find.byKey(const Key('session-host-name')),
      );
      final date = tester.widget<Text>(
        find.byKey(const Key('session-date-value')),
      );
      final time = tester.widget<Text>(
        find.byKey(const Key('session-time-value')),
      );
      expect(host.style?.fontWeight, FontWeight.w500);
      expect(date.style?.color, const Color(0xFFF97316));
      expect(time.style?.color, const Color(0xFF3F3F46));
      expect(date.style?.fontWeight, FontWeight.w600);
      expect(time.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('uses high-contrast time color in dark mode', (tester) async {
      await _pump(
        tester,
        _session(
          startTime: DateTime.now(),
          scheduledEndTime: DateTime.now().add(const Duration(hours: 2)),
        ),
        theme: AppTheme.dark,
      );

      final time = tester.widget<Text>(
        find.byKey(const Key('session-time-value')),
      );
      expect(
        time.style?.color,
        AppTheme.dark.colorScheme.onSurface.withValues(alpha: 0.85),
      );
    });

    testWidgets('uses the planned end, not the actual one', (tester) async {
      // endTime is when the session really stopped — the backend auto-ends on
      // ragged minutes, and "21:00-23:38" on a card reads as broken data.
      await _pump(
        tester,
        _session(
          startTime: DateTime(2026, 7, 10, 21),
          scheduledEndTime: DateTime(2026, 7, 10, 23),
          endTime: DateTime(2026, 7, 10, 23, 38),
        ),
      );

      expect(find.textContaining('21:00-23:00'), findsOneWidget);
      expect(find.textContaining('23:38'), findsNothing);
    });

    testWidgets('derives the end from the duration when none is scheduled', (
      tester,
    ) async {
      await _pump(
        tester,
        _session(
          startTime: DateTime(2026, 7, 10, 18),
          sessionDuration: 90,
        ),
      );

      expect(find.textContaining('18:00-19:30'), findsOneWidget);
    });

    testWidgets('does not overflow at narrow width and large text scale', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(280, 700)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(
        tester.platformDispatcher.clearTextScaleFactorTestValue,
      );

      await _pump(
        tester,
        _session(
          hostName: 'Người tổ chức có tên rất dài',
          startTime: DateTime(2026, 7, 10, 18),
          scheduledEndTime: DateTime(2026, 7, 10, 22, 30),
          location: 'Một địa điểm có tên rất dài',
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('shows split-evenly fee when no per-player amount exists', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(
        feeConfig: const SessionFeeConfig(feeType: FeeType.splitEvenly),
      ),
    );

    expect(find.text('Chia đều'), findsOneWidget);
  });

  group('place', () {
    testWidgets('prefers venue and district over the street address', (
      tester,
    ) async {
      await _pump(
        tester,
        _session(
          venue: const SessionVenue(
            id: 'v1',
            name: 'Sân Be Badminton',
            district: 'Gò Vấp',
          ),
          location: '163 Đ. số 11, Phường 11, Gò Vấp, Hồ Chí Minh',
        ),
      );

      expect(find.text('Sân Be Badminton • Gò Vấp'), findsOneWidget);
    });

    testWidgets('falls back to the free-text location', (tester) async {
      await _pump(tester, _session(location: '18B Cộng Hòa'));

      expect(find.text('18B Cộng Hòa'), findsOneWidget);
    });

    testWidgets('prefers the current ward and removes its prefix', (
      tester,
    ) async {
      await _pump(
        tester,
        _session(
          venue: const SessionVenue(
            id: 'v1',
            name: 'Sân ABC',
            district: 'Quận cũ',
            newDistrict: 'Phường Tân Phú',
          ),
        ),
      );

      expect(find.text('Sân ABC • Tân Phú'), findsOneWidget);
    });

    testWidgets('switches compact area with the address setting', (
      tester,
    ) async {
      final session = _session(
        venue: const SessionVenue(
          id: 'v1',
          name: 'Sân ABC',
          district: 'Quận Cũ',
          newDistrict: 'Phường Tân Phú',
        ),
      );

      await _pump(tester, session, showNewAddress: false);
      expect(find.text('Sân ABC • Quận Cũ'), findsOneWidget);

      await _pump(tester, session);
      expect(find.text('Sân ABC • Tân Phú'), findsOneWidget);
    });
  });

  testWidgets('uses the web default cover when cover photo is missing', (
    tester,
  ) async {
    await _pump(tester, _session());

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, contains('badminton/session-covers'));
  });

  testWidgets('marks a crawled session', (tester) async {
    await _pump(tester, _session(isCrawled: true));

    expect(find.text('Bài Facebook'), findsOneWidget);
    expect(find.byKey(const Key('session-slots-badge')), findsNothing);
  });

  testWidgets('uses the web host-avatar size', (tester) async {
    await _pump(tester, _session(hostName: 'Trần Minh Quân'));

    final avatar = find.byType(UserAvatar);
    expect(tester.getSize(avatar), const Size.square(24));
  });

  testWidgets('positions the cover so its aspect ratio cannot stretch cards', (
    tester,
  ) async {
    await _pump(tester, _session(isCrawled: true));

    final image = find.byType(CachedNetworkImage);
    final positioned = tester.widget<Positioned>(
      find.ancestor(of: image, matching: find.byType(Positioned)).first,
    );
    expect(positioned.left, 0);
    expect(positioned.top, 0);
    expect(positioned.right, 0);
    expect(positioned.bottom, 0);
  });

  group('availability badge', () {
    testWidgets('shows slots left when capacity is configured', (tester) async {
      await _pump(
        tester,
        _session().copyWith(
          numberOfCourts: 2,
          maxPlayersPerCourt: 4,
          counts: const SessionCounts(players: 5),
        ),
      );

      expect(find.byKey(const Key('session-slots-badge')), findsOneWidget);
      expect(find.text('Còn 3 slot'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('session-slots-badge')),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not invent a badge when capacity is unknown', (
      tester,
    ) async {
      await _pump(tester, _session());

      expect(find.byKey(const Key('session-slots-badge')), findsNothing);
    });

    testWidgets('supports a compact status badge for hosted cards', (
      tester,
    ) async {
      final session = _session().copyWith(
        numberOfCourts: 2,
        maxPlayersPerCourt: 4,
        counts: const SessionCounts(players: 5),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('vi'),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SessionCard(
                session: session,
                compactStatusBadge: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final badge = find.byKey(const Key('session-slots-badge'));
      expect(tester.getSize(badge).height, lessThanOrEqualTo(18));
      expect(
        tester
            .widget<Text>(
              find.descendant(of: badge, matching: find.byType(Text)),
            )
            .style
            ?.fontSize,
        10,
      );
    });
  });
}
