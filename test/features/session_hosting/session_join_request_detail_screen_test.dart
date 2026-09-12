import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/session_join_request_detail_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_action_bar.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_not_found_view.dart';

const session = Session(
  id: 'session-1',
  name: 'Kèo tối thứ 5',
  status: SessionStatus.preparing,
  numberOfCourts: 2,
  maxPlayersPerCourt: 4,
  venue: SessionVenue(id: 'venue-1', name: 'Nhà thi đấu Cầu Giấy'),
  players: [
    SessionPlayer(
      id: 'p-1',
      name: 'Sơn',
      playerNumber: 1,
      level: 4,
      registrationStatus: RegistrationStatus.pending,
    ),
    SessionPlayer(
      id: 'p-2',
      name: 'Minh',
      playerNumber: 2,
      level: 5,
    ),
  ],
);

Widget harness({
  String requestId = 'p-1',
  bool canDecide = true,
}) => ProviderScope(
  overrides: [
    sessionDetailProvider('session-1').overrideWith((ref) async => session),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SessionJoinRequestDetailScreen(
      sessionId: 'session-1',
      requestId: requestId,
      canDecide: canDecide,
    ),
  ),
);

void main() {
  testWidgets('shows applicant and session info for a pending registration', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Sơn'), findsOneWidget);
    expect(find.text('Kèo tối thứ 5'), findsOneWidget);
    expect(find.text('Nhà thi đấu Cầu Giấy'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.byType(RequestActionBar), findsOneWidget);
  });

  testWidgets('hides the action bar for an approved registration', (
    tester,
  ) async {
    await tester.pumpWidget(harness(requestId: 'p-2'));
    await tester.pumpAndSettle();

    expect(find.text('Minh'), findsOneWidget);
    expect(find.byType(RequestActionBar), findsNothing);
  });

  testWidgets('hides the action bar when the viewer cannot decide', (
    tester,
  ) async {
    await tester.pumpWidget(harness(canDecide: false));
    await tester.pumpAndSettle();

    expect(find.byType(RequestActionBar), findsNothing);
  });

  testWidgets('shows a not-found state when the player id is missing', (
    tester,
  ) async {
    await tester.pumpWidget(harness(requestId: 'missing'));
    await tester.pumpAndSettle();

    expect(find.byType(RequestNotFoundView), findsOneWidget);
  });
}
