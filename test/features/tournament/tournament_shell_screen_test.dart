import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_standings_preferences.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_detail_screen.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_shell_screen.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_standings_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TournamentService extends Mock implements TournamentService {}

class _Preferences implements TournamentStandingsPreferences {
  @override
  Future<bool> readShowPlayerNames() async => false;

  @override
  Future<void> writeShowPlayerNames({required bool value}) async {}
}

void main() {
  testWidgets('opens on the Home tab with a single app bar', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app(_service()));
    await tester.pumpAndSettle();

    expect(find.byType(TournamentHomeContent), findsOneWidget);
    // An embedded tab that forgot to drop its own Scaffold would show two.
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Vmito Open'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initialTab opens the standings tab directly', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      _app(_service(), initialTab: TournamentShellTab.standings),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TournamentStandingsScreen), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(_TournamentService service, {int initialTab = 0}) => ProviderScope(
  overrides: [
    tournamentServiceProvider.overrideWithValue(service),
    tournamentStandingsPreferencesProvider.overrideWithValue(_Preferences()),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TournamentShellScreen(idOrSlug: 'open', initialTab: initialTab),
  ),
);

_TournamentService _service() {
  final service = _TournamentService();
  when(() => service.detail('open')).thenAnswer((_) async => _tournament());
  when(() => service.matches('t1')).thenAnswer((_) async => []);
  when(() => service.sponsors('t1')).thenAnswer((_) async => []);
  when(() => service.standings('c1')).thenAnswer((_) async => []);
  when(() => service.courts('t1')).thenAnswer((_) async => []);
  when(() => service.categoryGroups('c1')).thenAnswer((_) async => []);
  return service;
}

TournamentDetail _tournament() => TournamentDetail(
  id: 't1',
  slug: 'open',
  name: 'Vmito Open',
  startDate: DateTime(2026, 8),
  endDate: DateTime(2026, 8, 2),
  hostId: 'host-1',
  status: TournamentStatus.finished,
  isPublished: true,
  categories: const [
    TournamentCategory(
      id: 'c1',
      name: 'Đôi nam',
      type: 'MEN_DOUBLES',
      registrationMode: TournamentRegistrationMode.team,
      format: TournamentCategoryFormat.roundRobin,
      registrationCount: 4,
    ),
  ],
  venues: const [],
  playerCount: 8,
  pairCount: 4,
);
