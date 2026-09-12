import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_management/club_join_request_detail_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_action_bar.dart';
import 'package:vmito_app/shared/widgets/request_detail/request_not_found_view.dart';

ClubJoinRequest sampleRequest({
  String id = 'req-1',
  String status = 'PENDING',
  String? message,
  String? response,
}) => ClubJoinRequest(
  id: id,
  userId: 'user-1',
  userName: 'Người xin',
  userEmail: 'user@example.com',
  createdAt: DateTime.now().subtract(const Duration(days: 1)),
  clubId: 'club-1',
  status: status,
  message: message,
  response: response,
  club: const ClubJoinRequestClub(
    id: 'club-1',
    name: 'Nhóm cầu lông',
    hostName: 'Anh Long',
  ),
);

Widget harness({
  required List<ClubJoinRequest> requests,
  String requestId = 'req-1',
  bool canDecide = true,
}) => ProviderScope(
  overrides: [
    clubJoinRequestsProvider(
      'club-1',
    ).overrideWith((ref) async => requests),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ClubJoinRequestDetailScreen(
      clubId: 'club-1',
      requestId: requestId,
      canDecide: canDecide,
    ),
  ),
);

void main() {
  testWidgets('shows applicant info, club and message for a pending request', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(requests: [sampleRequest(message: 'Cho em xin vào nhóm')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Người xin'), findsOneWidget);
    expect(find.text('Nhóm cầu lông'), findsOneWidget);
    expect(find.text('Anh Long'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.textContaining('Cho em xin vào nhóm'), findsOneWidget);
    expect(find.byType(RequestActionBar), findsOneWidget);
  });

  testWidgets('hides the action bar when the viewer cannot decide', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(requests: [sampleRequest()], canDecide: false),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RequestActionBar), findsNothing);
  });

  testWidgets('hides the action bar once a request has been decided', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        requests: [sampleRequest(status: 'REJECTED', response: 'Đã đủ người')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RequestActionBar), findsNothing);
    expect(find.textContaining('Đã đủ người'), findsOneWidget);
  });

  testWidgets('shows a not-found state when the id is missing from the list', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(requests: [sampleRequest(id: 'other')]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RequestNotFoundView), findsOneWidget);
  });
}
