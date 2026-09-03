import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_management_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TournamentService extends Mock implements TournamentService {}

class _ManagementService extends Mock implements TournamentManagementService {}

void main() {
  test('normalizes legacy web management options', () {
    expect(normalizeTournamentManageOption('location'), 'venues');
    expect(normalizeTournamentManageOption('registration'), 'teams');
    expect(normalizeTournamentManageOption('results'), 'results');
    expect(normalizeTournamentManageOption(''), isNull);
  });

  testWidgets('host can switch from organization to every settings item', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      _app(
        const TournamentMyAccess(
          tournamentId: 't1',
          isHost: true,
          isAdmin: false,
          permissions: {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tổ chức'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
    await tester.tap(find.text('Cài đặt'));
    await tester.pump();

    expect(find.text('Trạng thái giải đấu'), findsOneWidget);
    expect(find.text('Tên & mô tả'), findsOneWidget);
    expect(find.text('Quản trị viên'), findsOneWidget);
    expect(find.text('Xóa giải đấu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manager sees only organization items in the granted scope', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      _app(
        const TournamentMyAccess(
          tournamentId: 't1',
          isHost: false,
          isAdmin: false,
          permissions: {TournamentPermission.participants},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đội'), findsOneWidget);
    expect(find.text('Người chơi'), findsOneWidget);
    expect(find.text('Hạng mục'), findsNothing);
    expect(find.text('Cài đặt'), findsNothing);
    expect(find.text('Quản trị viên'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout selects the requested settings panel', (
    tester,
  ) async {
    _setSize(tester, const Size(1000, 900));
    await tester.pumpWidget(
      _app(
        const TournamentMyAccess(
          tournamentId: 't1',
          isHost: true,
          isAdmin: false,
          permissions: {},
        ),
        option: 'contact',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tên liên hệ'), findsOneWidget);
    expect(find.text('Email liên hệ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(TournamentMyAccess access, {String? option}) {
  final tournamentService = _TournamentService();
  final managementService = _ManagementService();
  when(
    () => tournamentService.detail('open'),
  ).thenAnswer((_) async => _tournament());
  when(
    () => managementService.access('t1'),
  ).thenAnswer((_) async => access);
  return ProviderScope(
    overrides: [
      tournamentServiceProvider.overrideWithValue(tournamentService),
      tournamentManagementServiceProvider.overrideWithValue(
        managementService,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TournamentManagementScreen(
        idOrSlug: 'open',
        initialOption: option,
      ),
    ),
  );
}

TournamentDetail _tournament() => TournamentDetail(
  id: 't1',
  slug: 'open',
  name: 'Vmito Open',
  startDate: DateTime(2026, 9, 10),
  endDate: DateTime(2026, 9, 12),
  hostId: 'host-1',
  status: TournamentStatus.preparing,
  isPublished: false,
  categories: const [],
  venues: const [],
  playerCount: 0,
  pairCount: 0,
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
