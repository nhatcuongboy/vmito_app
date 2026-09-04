import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/venue_detail_screen.dart';
import 'package:vmito_app/features/venue/presentation/venue_edit_request_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _units = [
  NewAdminUnit(
    city: 'Hồ Chí Minh',
    wards: ['Phường Sài Gòn', 'Phường Bến Thành'],
  ),
  NewAdminUnit(city: 'Hà Nội', wards: ['Phường Hoàn Kiếm']),
];

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'player-1',
      email: 'player@example.com',
      role: UserRole.player,
    ),
  );
}

Widget _app(Venue venue) => ProviderScope(
  overrides: [newAdminUnitsProvider.overrideWith((ref) async => _units)],
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
    home: VenueEditRequestScreen(venue: venue),
  ),
);

void main() {
  testWidgets('reveals validation only after submit and rewards correction', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Venue(
          id: 'venue-1',
          name: 'Sân A',
          streetAddress: '12 Nguyễn Huệ',
          newCity: 'Hồ Chí Minh',
          newDistrict: 'Phường Sài Gòn',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('venue-edit-name')), '');
    await tester.pump();
    expect(find.text('Vui lòng nhập thông tin bắt buộc'), findsNothing);

    await tester.tap(find.byKey(const Key('venue-edit-submit')));
    await tester.pump();
    expect(find.text('Vui lòng nhập thông tin bắt buộc'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('venue-edit-name')), 'Sân B');
    await tester.pump();
    expect(find.text('Vui lòng nhập thông tin bắt buộc'), findsNothing);
  });

  testWidgets(
    'extracts a clean street and expands mobile-safe optional fields',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          const Venue(
            id: 'venue-1',
            name: 'Sân A',
            address: '123 Nguyễn Văn Trỗi, Phường 8, Quận Phú Nhuận',
            newCity: 'Hồ Chí Minh',
            newDistrict: 'Phường Sài Gòn',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('venue-edit-extract-street')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('venue-edit-extract-street')));
      await tester.pump();
      expect(find.text('123 Nguyễn Văn Trỗi'), findsOneWidget);
      expect(find.byKey(const Key('venue-edit-extract-street')), findsNothing);

      await tester.tap(find.byKey(const Key('venue-edit-additional-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('venue-edit-court-count')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changing city clears the previous ward selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Venue(
          id: 'venue-1',
          name: 'Sân A',
          streetAddress: '12 Nguyễn Huệ',
          newCity: 'Hồ Chí Minh',
          newDistrict: 'Phường Sài Gòn',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('venue-edit-city')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hà Nội').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('venue-edit-ward-Hà Nội')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phường Hoàn Kiếm').last);
    await tester.pumpAndSettle();
    expect(find.text('Phường Hoàn Kiếm'), findsOneWidget);
  });

  testWidgets('venue detail prompts signed-out users before editing', (
    tester,
  ) async {
    await tester.pumpWidget(_detailApp(authenticated: false));
    await tester.pumpAndSettle();
    await _tapEditFromDetail(tester);

    expect(find.text('Yêu cầu đăng nhập'), findsOneWidget);
    expect(find.byType(VenueEditRequestScreen), findsNothing);
  });

  testWidgets('venue detail opens the full-screen editor when authenticated', (
    tester,
  ) async {
    await tester.pumpWidget(_detailApp(authenticated: true));
    await tester.pumpAndSettle();
    await _tapEditFromDetail(tester);

    expect(find.byType(VenueEditRequestScreen), findsOneWidget);
    expect(find.byKey(const Key('venue-edit-submit')), findsOneWidget);
  });
}

Widget _detailApp({required bool authenticated}) {
  const venue = Venue(
    id: 'venue-1',
    name: 'Sân A',
    streetAddress: '12 Nguyễn Huệ',
    newCity: 'Hồ Chí Minh',
    newDistrict: 'Phường Sài Gòn',
  );
  return ProviderScope(
    overrides: [
      venueDetailProvider('venue-1').overrideWith((ref) async => venue),
      venuePriceBooksProvider('venue-1').overrideWith((ref) async => const []),
      newAdminUnitsProvider.overrideWith((ref) async => _units),
      if (authenticated)
        authControllerProvider.overrideWith(_AuthenticatedController.new),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const VenueDetailScreen(venueId: 'venue-1'),
    ),
  );
}

Future<void> _tapEditFromDetail(WidgetTester tester) async {
  final edit = find.byKey(const Key('venue-request-update-button'));
  await tester.drag(
    find.byKey(const Key('venue-detail-scroll')),
    const Offset(0, -2000),
  );
  await tester.pumpAndSettle();
  await tester.tap(edit);
  await tester.pumpAndSettle();
}
