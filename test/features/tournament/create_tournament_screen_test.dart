import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/data/session_form_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_create_form.dart';
import 'package:vmito_app/features/tournament/domain/tournament_create_request.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/create_tournament_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TournamentService extends Mock implements TournamentService {}

class _SessionFormService extends Mock implements SessionFormService {}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app({
  TournamentService? service,
  SessionFormService? sessionFormService,
  bool router = false,
}) {
  final child = router
      ? MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.createTournament,
            routes: [
              GoRoute(
                path: AppRoutes.createTournament,
                builder: (_, _) => const CreateTournamentScreen(),
              ),
              GoRoute(
                path: AppRoutes.home,
                builder: (_, state) => Text(
                  'destination-${state.uri.queryParameters['tab']}',
                ),
              ),
            ],
          ),
        )
      : MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CreateTournamentScreen(),
        );
  return ProviderScope(
    overrides: [
      if (service != null) tournamentServiceProvider.overrideWithValue(service),
      if (sessionFormService != null)
        sessionFormServiceProvider.overrideWithValue(sessionFormService),
    ],
    child: child,
  );
}

Future<void> _chooseToday(WidgetTester tester, String control) async {
  await tester.tap(find.byKey(Key('tournament-$control-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      TournamentCreateRequest(
        name: 'Fallback',
        sportType: TournamentSportType.badminton,
        startDate: DateTime(2026, 8, 25),
        endDate: DateTime(2026, 8, 25),
      ),
    );
  });

  testWidgets('mobile form validates required fields without overflow', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('Tạo giải mới'), findsOneWidget);
    expect(find.byKey(const Key('tournament-submit-button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('tournament-submit-button')),
        matching: find.byIcon(AppIcons.add),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('tournament-cancel-button')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('tournament-submit-button'))).width,
      closeTo(358, 0.01),
    );
    await tester.tap(find.byKey(const Key('tournament-submit-button')));
    await tester.pump();

    expect(find.text('Hãy nhập tên giải đấu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide form renders inline actions without overflow', (
    tester,
  ) async {
    _setSize(tester, const Size(900, 900));
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byKey(const Key('tournament-submit-button')), findsOneWidget);
    expect(find.byKey(const Key('tournament-cancel-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects and clears a Google Places location', (tester) async {
    _setSize(tester, const Size(390, 844));
    final places = _SessionFormService();
    when(
      () => places.autocompletePlaces(
        input: any(named: 'input'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (_) async => const [
        PlaceSuggestion(
          placeId: 'place-1',
          primaryText: 'Vmito Arena',
          secondaryText: 'Quận 1, Hồ Chí Minh',
        ),
      ],
    );
    when(
      () => places.placeDetails(
        placeId: any(named: 'placeId'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (_) async => const PlaceDetails(
        placeId: 'place-1',
        address: '123 Nguyễn Huệ, Quận 1',
        latitude: 10.77,
        longitude: 106.7,
        district: 'Quận 1',
        city: 'Hồ Chí Minh',
      ),
    );
    await tester.pumpWidget(_app(sessionFormService: places));
    await tester.pump();

    final location = find.byKey(const Key('tournament-location-field'));
    await tester.scrollUntilVisible(
      location,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(location);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('tournament-location-search')),
      'Vmito',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vmito Arena'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('tournament-selected-location')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('tournament-clear-location')));
    await tester.pump();
    expect(
      find.byKey(const Key('tournament-selected-location')),
      findsNothing,
    );
  });

  testWidgets('shows a localized error when the API create fails', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _TournamentService();
    when(() => service.create(any())).thenThrow(StateError('network'));
    await tester.pumpWidget(_app(service: service));
    await tester.pump();
    final fieldContext = tester.element(
      find.byKey(const Key('tournament-name-field')),
    );
    final form = ReactiveForm.of(fieldContext, listen: false)! as FormGroup;
    final now = DateTime.now();
    form.patchValue({
      TournamentCreateControl.name: 'Vmito Open',
      TournamentCreateControl.startDate: now,
      TournamentCreateControl.endDate: now,
    });
    await tester.pump();

    await tester.tap(find.byKey(const Key('tournament-submit-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể tạo giải đấu. Vui lòng kiểm tra và thử lại.'),
      findsOneWidget,
    );
  });

  testWidgets('successful submit navigates to Find tournaments', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _TournamentService();
    when(() => service.create(any())).thenAnswer(
      (_) async => TournamentSummary(
        id: 't1',
        name: 'Vmito Open',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        status: TournamentStatus.preparing,
        isPublished: false,
      ),
    );
    await tester.pumpWidget(_app(service: service, router: true));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tournament-name-field')),
      'Vmito Open',
    );
    await _chooseToday(tester, 'startDate');
    await _chooseToday(tester, 'endDate');
    await tester.tap(find.byKey(const Key('tournament-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('destination-tournaments'), findsOneWidget);
    verify(() => service.create(any())).called(1);
  });
}
