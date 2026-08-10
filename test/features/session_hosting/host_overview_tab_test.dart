import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_overview_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  const session = Session(
    id: 'overview-1',
    name: 'Kèo tối thứ Sáu',
    status: SessionStatus.inProgress,
    numberOfCourts: 2,
    maxPlayersPerCourt: 4,
    location: 'Gò Vấp',
    players: [
      SessionPlayer(
        id: 'p1',
        name: 'Sơn',
        gender: Gender.male,
      ),
      SessionPlayer(
        id: 'p2',
        name: 'Minh',
        gender: Gender.female,
        status: PlayerStatus.playing,
      ),
      SessionPlayer(
        id: 'p3',
        name: 'Nam',
        gender: Gender.male,
        status: PlayerStatus.ready,
      ),
    ],
  );

  testWidgets('shows session information and the four web overview stats', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HostOverviewTab(session: session)),
        ),
      ),
    );

    expect(find.text('THÔNG TIN KÈO'), findsOneWidget);
    expect(find.text('Gò Vấp'), findsOneWidget);
    expect(find.text('Thống kê kèo'), findsOneWidget);
    expect(find.text('Người chơi'), findsOneWidget);
    expect(find.text('Chờ'), findsOneWidget);
    expect(find.text('Đang chơi'), findsOneWidget);
    expect(find.text('Sẵn sàng'), findsOneWidget);
    expect(find.text('3/8'), findsOneWidget);
  });
}
