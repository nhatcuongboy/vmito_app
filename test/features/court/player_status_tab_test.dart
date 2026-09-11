import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/court/domain/player_live_session.dart';
import 'package:vmito_app/features/court/presentation/widgets/player_status_tab.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

const _me = SessionPlayer(
  id: 'p1',
  userId: 'u1',
  name: 'Nhật Cường',
  playerNumber: 3,
  status: PlayerStatus.ready,
  currentCourtId: 'c1',
  position: 1,
);
const _partner = SessionPlayer(
  id: 'p2',
  name: 'Minh',
  playerNumber: 2,
  status: PlayerStatus.ready,
  currentCourtId: 'c1',
  position: 0,
);
const _opponent1 = SessionPlayer(
  id: 'p3',
  name: 'Nam',
  playerNumber: 1,
  status: PlayerStatus.ready,
  currentCourtId: 'c1',
  position: 2,
);
const _opponent2 = SessionPlayer(
  id: 'p4',
  name: 'Yến',
  playerNumber: 4,
  status: PlayerStatus.ready,
  currentCourtId: 'c1',
  position: 3,
);

const _court = Court(
  id: 'c1',
  courtNumber: 1,
  status: CourtStatus.ready,
  currentPlayers: [_me, _partner, _opponent1, _opponent2],
);

void main() {
  testWidgets('ready player sees the status header, court and pairing', (
    tester,
  ) async {
    await _pump(
      tester,
      session: const Session(
        id: 's1',
        name: 'Tuesday badminton',
        status: SessionStatus.inProgress,
        courts: [_court],
        players: [_me, _partner, _opponent1, _opponent2],
      ),
      player: _me,
    );

    expect(find.text('Chuẩn bị sẵn sàng'), findsOneWidget);
    expect(
      find.text('Bạn đã sẵn sàng để chơi. Vui lòng đợi lượt của bạn.'),
      findsOneWidget,
    );
    expect(find.text('Sân 1'), findsOneWidget);
    expect(find.textContaining('#2 Minh'), findsOneWidget);
    expect(find.textContaining('#1 Nam'), findsOneWidget);
    expect(find.textContaining('#4 Yến'), findsOneWidget);
    // READY falls into the same footer branch as FINISHED, matching web.
    expect(find.text('Cảm ơn bạn đã tham gia kèo này'), findsOneWidget);
  });

  testWidgets('playing player sees the playing footer and elapsed badge', (
    tester,
  ) async {
    final court = _court.copyWith(
      status: CourtStatus.inUse,
      currentMatch: Match(
        id: 'm1',
        sessionId: 's1',
        courtId: 'c1',
        startTime: DateTime.now(),
      ),
    );
    final me = _me.copyWith(status: PlayerStatus.playing);

    await _pump(
      tester,
      session: Session(
        id: 's1',
        name: 'Tuesday badminton',
        status: SessionStatus.inProgress,
        courts: [court],
        players: [
          me,
          _partner.copyWith(status: PlayerStatus.playing),
          _opponent1.copyWith(status: PlayerStatus.playing),
          _opponent2.copyWith(status: PlayerStatus.playing),
        ],
      ),
      player: me,
    );

    expect(find.text('Đang chơi'), findsOneWidget);
    expect(find.text('Kết quả sẽ được host cập nhật sau trận'), findsOneWidget);

    // Unmount so the autoDispose match-elapsed ticker's pending Timer is
    // cancelled before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('waiting player with no court sees the waiting hint', (
    tester,
  ) async {
    const me = SessionPlayer(
      id: 'p1',
      userId: 'u1',
      name: 'Nhật Cường',
      playerNumber: 3,
      currentWaitTime: 5,
    );

    await _pump(
      tester,
      session: const Session(
        id: 's1',
        name: 'Tuesday badminton',
        status: SessionStatus.inProgress,
        players: [me],
      ),
      player: me,
    );

    expect(find.text('Đang chờ chơi'), findsOneWidget);
    expect(find.text('Bạn chưa được gọi vào sân'), findsOneWidget);
    expect(
      find.text('Hãy giữ ứng dụng luôn mở để không mất vị trí trong hàng chờ'),
      findsOneWidget,
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Session session,
  required SessionPlayer player,
}) async {
  // Tall enough that every card in the ListView is built up front, rather
  // than lazily as the sliver viewport would otherwise defer them.
  await tester.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PlayerStatusTab(
            projection: PlayerLiveSession(session: session, player: player),
            onRefresh: () async {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
