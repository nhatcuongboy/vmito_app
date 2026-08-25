import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/tournament/application/tournament_detail_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_detail_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(TournamentDetailState state) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: TournamentHomeContent(
        state: state,
        onRefresh: () async {},
        onRetryMatches: () async {},
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'renders the complete home hierarchy on a phone without overflow',
    (
      tester,
    ) async {
      _setSize(tester, const Size(390, 844));
      await tester.pumpWidget(_app(_state()));
      await tester.pump();

      expect(find.text('Vmito Open'), findsOneWidget);
      expect(find.text('Trận đấu'), findsOneWidget);
      expect(find.text('Hạng mục'), findsOneWidget);
      expect(find.text('Thể lệ thi đấu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses a four-column quick-action layout on a wide window', (
    tester,
  ) async {
    _setSize(tester, const Size(900, 1000));
    await tester.pumpWidget(_app(_state()));
    await tester.pump();

    expect(find.text('Trận đấu'), findsOneWidget);
    expect(find.text('Bảng xếp hạng'), findsOneWidget);
    expect(find.text('Điểm live'), findsOneWidget);
    expect(find.text('Showcase'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

TournamentDetailState _state() => TournamentDetailState(
  tournament: TournamentDetail(
    id: 't1',
    slug: 'vmito-open',
    name: 'Vmito Open',
    description: 'Thông tin giải đấu',
    startDate: DateTime(2026, 8, 25),
    endDate: DateTime(2026, 8, 26),
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
    venues: const [
      TournamentVenue(
        id: 'v1',
        name: 'Vmito Arena',
        address: '1 Nguyễn Huệ',
      ),
    ],
    playerCount: 8,
    pairCount: 4,
  ),
);
