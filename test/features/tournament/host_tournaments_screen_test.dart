import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/host_tournaments_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _MockTournamentService extends Mock implements TournamentService {}

class _MockManagementService extends Mock
    implements TournamentManagementService {}

const _host = User(id: 'host-1', email: 'host@vmito.com', role: UserRole.host);

/// IN_PROGRESS with an end day long past: always overdue, whatever the clock.
final _overdueDraft = TournamentSummary(
  id: 't1',
  slug: 'giai-mua-he',
  name: 'Giải mùa hè',
  hostId: 'host-1',
  startDate: DateTime.utc(2020, 6, 6),
  endDate: DateTime.utc(2020, 6, 6),
  status: TournamentStatus.inProgress,
  isPublished: false,
  categoryCount: 2,
  venueName: 'Sân Phúc Lộc',
);

Widget _harness(
  TournamentService service, {
  User user = _host,
  TournamentManagementService? management,
}) => ProviderScope(
  overrides: [
    currentUserProvider.overrideWithValue(user),
    tournamentServiceProvider.overrideWithValue(service),
    if (management != null)
      tournamentManagementServiceProvider.overrideWithValue(management),
  ],
  child: MaterialApp(
    locale: const Locale('vi'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HostTournamentsScreen(),
  ),
);

void main() {
  late _MockTournamentService service;

  setUp(() => service = _MockTournamentService());

  testWidgets('shows card skeletons during the first load', (tester) async {
    final pending = Completer<List<TournamentSummary>>();
    when(service.mine).thenAnswer((_) => pending.future);

    await tester.pumpWidget(_harness(service));
    await tester.pump();

    expect(find.byKey(const Key('host-tournaments-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('host-tournaments-create-fab')), findsNothing);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    var calls = 0;
    when(service.mine).thenAnswer((_) async {
      if (calls++ == 0) {
        throw const ApiException(kind: ApiErrorKind.network, message: 'x');
      }
      return [_overdueDraft];
    });

    await tester.pumpWidget(_harness(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Giải mùa hè'), findsOneWidget);
  });

  testWidgets('a host with no tournaments is invited to create one', (
    tester,
  ) async {
    when(service.mine).thenAnswer((_) async => []);

    await tester.pumpWidget(_harness(service));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có giải đấu nào'), findsOneWidget);
    expect(find.text('Tạo giải đấu đầu tiên'), findsOneWidget);
    expect(
      find.byKey(const Key('host-tournaments-create-fab')),
      findsOneWidget,
    );
  });

  testWidgets('renders overdue and draft badges and filters by tab', (
    tester,
  ) async {
    when(service.mine).thenAnswer((_) async => [_overdueDraft]);

    await tester.pumpWidget(_harness(service));
    await tester.pumpAndSettle();

    expect(find.text('Giải mùa hè'), findsOneWidget);
    expect(find.text('Đã quá hạn'), findsOneWidget);
    expect(find.text('Bản nháp'), findsOneWidget);
    expect(find.text('Sân Phúc Lộc'), findsOneWidget);
    expect(find.text('2 hạng mục'), findsOneWidget);

    // Overdue still counts as open on web, so "ended" has nothing.
    await tester.tap(find.text('Đã kết thúc'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy giải đấu phù hợp'), findsOneWidget);
  });

  testWidgets('search narrows the list by name', (tester) async {
    when(service.mine).thenAnswer((_) async => [_overdueDraft]);

    await tester.pumpWidget(_harness(service));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('host-tournaments-search')),
      'không có',
    );
    await tester.pumpAndSettle();

    expect(find.text('Giải mùa hè'), findsNothing);
    expect(find.text('Không tìm thấy giải đấu phù hợp'), findsOneWidget);
  });

  testWidgets('a referee officiates and cannot delete or create', (
    tester,
  ) async {
    when(service.mine).thenAnswer((_) async => [_overdueDraft]);
    const referee = User(
      id: 'ref-1',
      email: 'ref@vmito.com',
      role: UserRole.referee,
    );

    await tester.pumpWidget(_harness(service, user: referee));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-tournament-more-t1')));
    await tester.pumpAndSettle();

    expect(find.text('Điều hành'), findsOneWidget);
    expect(find.text('Chia sẻ'), findsOneWidget);
    expect(find.text('Xóa'), findsNothing);
    expect(find.byKey(const Key('host-tournaments-create-fab')), findsNothing);
  });

  testWidgets('a co-manager is not offered delete', (tester) async {
    when(service.mine).thenAnswer((_) async => [_overdueDraft]);
    const manager = User(
      id: 'someone-else',
      email: 'm@vmito.com',
      role: UserRole.host,
    );

    await tester.pumpWidget(_harness(service, user: manager));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-tournament-more-t1')));
    await tester.pumpAndSettle();

    expect(find.text('Quản lý'), findsOneWidget);
    expect(find.text('Xóa'), findsNothing);
  });

  testWidgets('the host deletes after confirming', (tester) async {
    when(service.mine).thenAnswer((_) async => [_overdueDraft]);
    final management = _MockManagementService();
    when(() => management.deleteTournament('t1')).thenAnswer((_) async {});

    await tester.pumpWidget(_harness(service, management: management));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-tournament-more-t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-tournament-delete-confirm')));
    await tester.pumpAndSettle();

    verify(() => management.deleteTournament('t1')).called(1);
    expect(find.text('Giải mùa hè'), findsNothing);
    expect(find.text('Đã xoá giải đấu'), findsOneWidget);
  });
}
