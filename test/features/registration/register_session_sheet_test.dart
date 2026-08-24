import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/registration/data/registration_repository.dart';
import 'package:vmito_app/features/registration/domain/my_join_request.dart';
import 'package:vmito_app/features/registration/presentation/register_session_sheet.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _FakeRepository implements RegistrationRepository {
  final registered = <List<Map<String, dynamic>>>[];

  @override
  Future<List<SessionPlayer>> myPlayers(String sessionId) async => const [];

  @override
  Future<void> register(String s, List<Map<String, dynamic>> p) async =>
      registered.add(p);

  @override
  Future<void> withdraw(String playerId) async {}

  @override
  Future<pagination.Page<MyJoinRequest>> myJoinRequests({
    required int page,
    required int limit,
  }) async => const pagination.Page<MyJoinRequest>(
    items: <MyJoinRequest>[],
    total: 0,
    page: 1,
    limit: 20,
    totalPages: 0,
  );

  @override
  Future<void> withdrawMyJoinRequest(String sessionId) async {}
}

const _me = User(
  id: 'u1',
  email: 'me@vmito.com',
  role: UserRole.player,
  name: 'Cường',
  phone: '0901234567',
);

Session _session({
  List<int> requiredLevels = const [9, 1],
  SessionFeeConfig? feeConfig,
}) => Session(
  id: 's1',
  name: 'Kèo test',
  status: SessionStatus.preparing,
  numberOfCourts: 2,
  maxPlayersPerCourt: 8,
  requiredLevels: requiredLevels,
  feeConfig: feeConfig,
);

Future<void> _openSheet(
  WidgetTester tester, {
  required Session session,
  required _FakeRepository repository,
  bool asGuest = false,
}) async {
  tester.view
    ..physicalSize = const Size(1170, 4000)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        registrationRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWithValue(_me),
        isSignedInProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showRegisterSessionSheet(
                  context,
                  session: session,
                  asGuest: asGuest,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prefills the me row from the signed-in user', (tester) async {
    await _openSheet(
      tester,
      session: _session(),
      repository: _FakeRepository(),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('Cường'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    // One row so far, and it is not removable.
    expect(find.text('Submit registration (1)'), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsNothing);
  });

  testWidgets('add-guest mode starts with an empty guest row', (tester) async {
    await _openSheet(
      tester,
      session: _session(),
      repository: _FakeRepository(),
      asGuest: true,
    );

    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('You'), findsNothing);
    expect(find.text('Cường'), findsNothing);
  });

  testWidgets('adding a guest appends a removable row', (tester) async {
    await _openSheet(
      tester,
      session: _session(),
      repository: _FakeRepository(),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add guest'));
    await tester.pumpAndSettle();

    expect(find.text('Submit registration (2)'), findsOneWidget);
    // Only the guest row can be removed; the me row never can.
    expect(find.byIcon(AppIcons.delete), findsOneWidget);
  });

  testWidgets('a blank name blocks submission', (tester) async {
    final repository = _FakeRepository();
    await _openSheet(
      tester,
      session: _session(),
      repository: repository,
      asGuest: true,
    );

    await tester.tap(find.textContaining('Submit registration'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a name'), findsOneWidget);
    expect(repository.registered, isEmpty);
  });

  testWidgets('an unchosen level blocks submission', (tester) async {
    final repository = _FakeRepository();
    // No required levels means no default is preselected, so the player has
    // to pick one explicitly.
    await _openSheet(
      tester,
      session: _session(requiredLevels: const []),
      repository: repository,
    );

    await tester.tap(find.textContaining('Submit registration'));
    await tester.pumpAndSettle();

    expect(find.text('Please select a level'), findsOneWidget);
    expect(repository.registered, isEmpty);
  });

  testWidgets('a valid form submits the wire payload', (tester) async {
    final repository = _FakeRepository();
    await _openSheet(
      tester,
      session: _session(),
      repository: repository,
    );

    await tester.tap(find.textContaining('Submit registration'));
    await tester.pumpAndSettle();

    final payload = repository.registered.single.single;
    expect(payload['name'], 'Cường');
    expect(payload['userId'], 'u1');
    // Defaulted to the session's first accepted level, in display-rank order:
    // 9 (Yếu-) sorts before 1 (Yếu).
    expect(payload['level'], 9);
  });

  testWidgets('a priced session offers only male and female', (tester) async {
    await _openSheet(
      tester,
      session: _session(
        feeConfig: const SessionFeeConfig(maleFee: 80000, femaleFee: 70000),
      ),
      repository: _FakeRepository(),
    );

    await tester.tap(find.byType(DropdownButtonFormField<Gender>));
    await tester.pumpAndSettle();

    // The fee table has no bucket for "Other", so it must not be offered.
    expect(find.text('Other'), findsNothing);
    expect(find.text('Female'), findsWidgets);
  });

  testWidgets('the level dropdown is limited to the accepted levels', (
    tester,
  ) async {
    await _openSheet(
      tester,
      session: _session(),
      repository: _FakeRepository(),
    );

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();

    expect(find.text('TB'), findsNothing);
    expect(find.text('Yếu-'), findsWidgets);
  });
}
