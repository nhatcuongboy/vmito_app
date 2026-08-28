import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/browse_clubs_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TestClubsController extends ClubsController {
  _TestClubsController(this.initialState);

  final ClubsState initialState;

  @override
  ClubsState build() => initialState;

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
  }) async {}
}

class _TestLocationPreferencesController extends LocationPreferencesController {
  @override
  LocationPreferences build() => const LocationPreferences(isRestored: true);
}

void main() {
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
    expect(find.text('Thứ Hai – Thứ Sáu · 19:00–21:00'), findsOneWidget);
    expect(find.text('Sân Trung tâm'), findsOneWidget);
    expect(find.byIcon(AppIcons.clock), findsOneWidget);
    expect(find.byIcon(AppIcons.location), findsOneWidget);

    final logo = tester.widget<Container>(
      find.byKey(const Key('club-card-logo')),
    );
    final decoration = logo.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.border, isNotNull);
    expect(decoration.border!.top.color, Colors.white);
  });
}
