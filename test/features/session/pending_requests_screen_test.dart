import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/presentation/player/pending_requests_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

const _me = User(id: 'u1', email: 'me@vmito.com', role: UserRole.host);

pagination.Page<T> _page<T>(List<T> items) => pagination.Page(
  items: items,
  total: items.length,
  page: 1,
  limit: 20,
  totalPages: 1,
);

Future<void> _pump(
  WidgetTester tester,
  SessionRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_me),
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open-pending-requests'),
                onPressed: () => unawaited(showPendingRequestsSheet(context)),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-pending-requests')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows pending requests list and handles approve/reject decisions',
    (
      tester,
    ) async {
      final repository = _MockSessionRepository();
      var decided = false;
      const request = PendingJoinRequest(
        id: 'p1',
        sessionId: 's1',
        sessionName: 'Kèo chiều',
        playerName: 'Bình',
      );

      when(
        () => repository.pendingJoinRequests(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => _page(decided ? [] : [request]));
      when(repository.pendingJoinRequestCount).thenAnswer((_) async => 0);
      when(
        () => repository.updateRegistration(
          any(),
          any(),
          approved: any(named: 'approved'),
        ),
      ).thenAnswer((_) async => decided = true);

      await _pump(tester, repository);

      expect(find.text('Yêu cầu tham gia'), findsOneWidget);
      expect(find.text('Bình'), findsOneWidget);
      expect(find.text('Kèo chiều'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('approve-request-p1')));
      await tester.pumpAndSettle();

      verify(
        () => repository.updateRegistration('s1', 'p1', approved: true),
      ).called(1);
      expect(find.text('Bình'), findsNothing);
      expect(find.text('Không có yêu cầu tham gia đang chờ'), findsOneWidget);
    },
  );

  testWidgets('renders empty pending requests UI when list is empty', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    when(
      () => repository.pendingJoinRequests(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => _page([]));

    await _pump(tester, repository);

    expect(find.text('Yêu cầu tham gia'), findsOneWidget);
    expect(find.text('Không có yêu cầu tham gia đang chờ'), findsOneWidget);
    expect(
      find.text(
        'Các yêu cầu xin tham gia từ người chơi khác sẽ hiển thị tại đây.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('pending-requests-close')));
    await tester.pumpAndSettle();
    expect(find.text('Yêu cầu tham gia'), findsNothing);
  });
}
