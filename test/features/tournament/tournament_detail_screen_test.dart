import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/web/app_web_view.dart';
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
  testWidgets('delegates tournament detail to the localized web page', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        tournamentTitleProvider.overrideWith(
          (ref, idOrSlug) async => 'Vmito Open',
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(tournamentTitleProvider('vmito open').future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TournamentDetailScreen(idOrSlug: 'vmito open'),
        ),
      ),
    );

    final webViewPage = tester.widget<AppWebViewPage>(
      find.byType(AppWebViewPage),
    );
    expect(webViewPage.page.title, 'Vmito Open');
    expect(
      webViewPage.page.path,
      '/vi/tournament/vmito%20open',
    );
    expect(webViewPage.page.embedded, isTrue);
    expect(find.byType(TournamentHomeContent), findsNothing);
  });

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

  testWidgets('opens competition rules in a mobile bottom sheet', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app(_state()));
    await tester.pump();
    final rules = find.text('Thể lệ thi đấu');
    await tester.scrollUntilVisible(
      rules,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(rules);
    await tester.pumpAndSettle();

    expect(find.text('Vòng tròn'), findsOneWidget);
    expect(find.textContaining('Thắng 2'), findsOneWidget);
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
