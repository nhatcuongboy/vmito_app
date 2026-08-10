import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/domain/player_detail.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_share_service.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_statistics_section.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

const _session = Session(
  id: 's1',
  name: 'Kèo tối thứ Sáu',
  status: SessionStatus.inProgress,
  location: 'Gò Vấp',
);

const _players = [
  PlayerStatistics(
    playerId: 'p1',
    playerNumber: 1,
    name: 'An',
    gender: Gender.male,
    level: 4,
    totalMatches: 4,
    regularMatches: 4,
    extraMatches: 0,
    wins: 4,
    losses: 0,
    winRate: 100,
    averageScore: 0,
    scoredMatches: 4,
    averagePointDifferential: 3,
    totalPlayTime: 80,
    totalWaitTime: 10,
    status: PlayerStatus.waiting,
  ),
  PlayerStatistics(
    playerId: 'p2',
    playerNumber: 2,
    name: 'Bình',
    gender: Gender.female,
    level: 3,
    totalMatches: 4,
    regularMatches: 4,
    extraMatches: 0,
    wins: 3,
    losses: 1,
    winRate: 75,
    averageScore: 0,
    scoredMatches: 4,
    averagePointDifferential: 1,
    totalPlayTime: 70,
    totalWaitTime: 20,
    status: PlayerStatus.ready,
  ),
];

class _FakeShareService implements PlayerStatisticsShareService {
  Uint8List? bytes;
  String? fileName;

  @override
  Future<void> sharePng(
    Uint8List bytes, {
    required String fileName,
    Rect? origin,
  }) async {
    this.bytes = bytes;
    this.fileName = fileName;
  }
}

class _FakeCaptureService implements PlayerStatisticsCaptureService {
  @override
  Future<Uint8List?> capture(RenderRepaintBoundary boundary) async =>
      Uint8List.fromList([137, 80, 78, 71]);
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<List<PlayerStatistics>> Function(Ref) statistics,
  PlayerDetail? detail,
  PlayerStatisticsShareService? shareService,
  PlayerStatisticsCaptureService? captureService,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(430, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerStatisticsProvider('s1').overrideWith(statistics),
        showShuttlecockCountProvider.overrideWith((ref) async => false),
        if (detail != null)
          playerDetailProvider(detail.id).overrideWith(
            (ref) async => detail,
          ),
        if (shareService != null)
          playerStatisticsShareServiceProvider.overrideWithValue(shareService),
        if (captureService != null)
          playerStatisticsCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: PlayerStatisticsSection(session: _session),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders data, cycles sorting and toggles gender MVP', (
    tester,
  ) async {
    await _pump(tester, statistics: (ref) async => _players);

    expect(find.text('Thống kê người chơi'), findsOneWidget);
    expect(
      find.byKey(const Key('host-player-statistics-table')),
      findsOneWidget,
    );
    expect(find.text('MVP'), findsOneWidget);

    var table = tester.widget<DataTable>(find.byType(DataTable));
    table.columns[7].onSort!(7, true);
    await tester.pump();
    var rows = tester.widget<DataTable>(find.byType(DataTable)).rows;
    expect(rows.first.key, const ValueKey('host-player-statistics-p2'));

    table = tester.widget<DataTable>(find.byType(DataTable));
    table.columns[7].onSort!(7, true);
    await tester.pump();
    rows = tester.widget<DataTable>(find.byType(DataTable)).rows;
    expect(rows.first.key, const ValueKey('host-player-statistics-p1'));

    await tester.tap(
      find.byKey(const Key('host-player-statistics-gender-mvp')),
    );
    await tester.pump();
    expect(find.text('MVP Nam'), findsOneWidget);
    expect(find.text('MVP Nữ'), findsOneWidget);
  });

  testWidgets('keeps an error inside the statistics section', (
    tester,
  ) async {
    await _pump(
      tester,
      statistics: (ref) => Future<List<PlayerStatistics>>.error('offline'),
    );
    expect(find.text('Không thể tải thống kê người chơi.'), findsOneWidget);
    expect(
      find.byKey(const Key('host-player-statistics-retry')),
      findsOneWidget,
    );
  });

  testWidgets('shows an empty state inside the statistics section', (
    tester,
  ) async {
    await _pump(tester, statistics: (ref) async => const []);
    expect(find.text('Không có thống kê người chơi.'), findsOneWidget);
  });

  testWidgets('opens the player detail sheet from a statistics row', (
    tester,
  ) async {
    await _pump(
      tester,
      statistics: (ref) async => _players,
      detail: const PlayerDetail(
        id: 'p1',
        playerNumber: 1,
        name: 'An',
        status: PlayerStatus.waiting,
        currentWaitTime: 5,
        totalWaitTime: 12,
        matchesPlayed: 4,
      ),
    );

    await tester.tap(find.text('An'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-player-detail-sheet')), findsOneWidget);
    expect(find.text('Chi tiết người chơi'), findsOneWidget);
    expect(find.text('5 phút'), findsOneWidget);
  });

  testWidgets('captures a PNG and delegates to the share service', (
    tester,
  ) async {
    final share = _FakeShareService();
    await _pump(
      tester,
      statistics: (ref) async => _players,
      shareService: share,
      captureService: _FakeCaptureService(),
    );

    await tester.tap(find.byKey(const Key('host-player-statistics-export')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('player-statistics-export-card')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('share-player-statistics-image')));
    await tester.pumpAndSettle();

    expect(share.bytes, isNotEmpty);
    expect(share.fileName, contains('statistics.png'));
  });
}
