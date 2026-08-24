import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/registration/application/my_registration_controller.dart';
import 'package:vmito_app/features/registration/data/registration_repository.dart';
import 'package:vmito_app/features/registration/domain/my_join_request.dart';
import 'package:vmito_app/features/registration/domain/registration_player_draft.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _FakeRegistrationRepository implements RegistrationRepository {
  _FakeRegistrationRepository({this.players = const []});

  List<SessionPlayer> players;
  int myPlayersCalls = 0;
  final registered = <List<Map<String, dynamic>>>[];
  final withdrawn = <String>[];

  /// Player ids whose delete should fail, standing in for the backend's 403
  /// on a guest row and 400 on a player already on court.
  Set<String> failWithdrawFor = const {};

  @override
  Future<List<SessionPlayer>> myPlayers(String sessionId) async {
    myPlayersCalls++;
    return players;
  }

  @override
  Future<void> register(
    String sessionId,
    List<Map<String, dynamic>> payload,
  ) async {
    registered.add(payload);
  }

  @override
  Future<void> withdraw(String playerId) async {
    if (failWithdrawFor.contains(playerId)) throw StateError('403');
    withdrawn.add(playerId);
  }

  @override
  Future<Page<MyJoinRequest>> myJoinRequests({
    required int page,
    required int limit,
  }) async => const Page(
    items: [],
    total: 0,
    page: 1,
    limit: 20,
    totalPages: 0,
  );

  @override
  Future<void> withdrawMyJoinRequest(String sessionId) async {}
}

const _me = User(id: 'u1', email: 'me@vmito.com', role: UserRole.player);

ProviderContainer _container(
  _FakeRegistrationRepository repository, {
  bool signedIn = true,
}) {
  final container = ProviderContainer(
    overrides: [
      registrationRepositoryProvider.overrideWithValue(repository),
      isSignedInProvider.overrideWithValue(signedIn),
      currentUserProvider.overrideWithValue(signedIn ? _me : null),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

SessionPlayer _player(
  String id, {
  RegistrationStatus status = RegistrationStatus.pending,
}) => SessionPlayer(id: id, name: id, registrationStatus: status);

void main() {
  test('signed out reports no registration without calling the API', () async {
    final repository = _FakeRegistrationRepository();
    final container = _container(repository, signedIn: false);

    final players = await container.read(myRegistrationProvider('s1').future);

    expect(players, isEmpty);
    expect(repository.myPlayersCalls, 0);
    expect(container.read(myRegistrationStatusProvider('s1')), isNull);
  });

  test('status comes from the first row, matching web', () async {
    // Rows arrive oldest-first. A mixed registration reports its earliest
    // slot, deliberately the same quirk as the web client.
    final repository = _FakeRegistrationRepository(
      players: [
        _player('p1', status: RegistrationStatus.approved),
        _player('p2'),
      ],
    );
    final container = _container(repository);
    await container.read(myRegistrationProvider('s1').future);

    expect(
      container.read(myRegistrationStatusProvider('s1')),
      RegistrationStatus.approved,
    );
  });

  test('no rows means no status, not a default', () async {
    final container = _container(_FakeRegistrationRepository());
    await container.read(myRegistrationProvider('s1').future);

    expect(container.read(myRegistrationStatusProvider('s1')), isNull);
  });

  test('register sends one payload entry per draft, me row first', () async {
    final repository = _FakeRegistrationRepository();
    final container = _container(repository);
    await container.read(myRegistrationProvider('s1').future);

    await container.read(myRegistrationProvider('s1').notifier).register(const [
      RegistrationPlayerDraft(isMe: true, name: 'Cường', level: 4),
      RegistrationPlayerDraft(isMe: false, name: 'Khách', level: 4),
    ]);

    final payload = repository.registered.single;
    expect(payload, hasLength(2));
    expect(payload[0]['userId'], 'u1');
    expect(payload[1].containsKey('userId'), isFalse);
  });

  test('withdraw touches only pending rows', () async {
    final repository = _FakeRegistrationRepository(
      players: [
        _player('approved', status: RegistrationStatus.approved),
        _player('pending'),
        _player('rejected', status: RegistrationStatus.rejected),
      ],
    );
    final container = _container(repository);
    await container.read(myRegistrationProvider('s1').future);

    final outcome = await container
        .read(myRegistrationProvider('s1').notifier)
        .withdrawPending();

    expect(repository.withdrawn, ['pending']);
    expect(outcome.withdrawn, 1);
    expect(outcome.isCompleteSuccess, isTrue);
  });

  test('a refused row is reported, not swallowed', () async {
    // The backend's guard ignores who created a guest row, so deleting one
    // 403s. Claiming success there would tell the player their slot is gone
    // when it is not.
    final repository = _FakeRegistrationRepository(
      players: [_player('mine'), _player('guest')],
    )..failWithdrawFor = {'guest'};
    final container = _container(repository);
    await container.read(myRegistrationProvider('s1').future);

    final outcome = await container
        .read(myRegistrationProvider('s1').notifier)
        .withdrawPending();

    expect(outcome.withdrawn, 1);
    expect(outcome.failed, 1);
    expect(outcome.isCompleteSuccess, isFalse);
    // The failure must not abandon the remaining rows.
    expect(repository.withdrawn, ['mine']);
  });

  test('withdrawing re-reads the registration afterwards', () async {
    final repository = _FakeRegistrationRepository(
      players: [_player('p1')],
    );
    final container = _container(repository);
    await container.read(myRegistrationProvider('s1').future);
    expect(repository.myPlayersCalls, 1);

    await container
        .read(myRegistrationProvider('s1').notifier)
        .withdrawPending();
    await container.read(myRegistrationProvider('s1').future);

    expect(repository.myPlayersCalls, 2);
  });
}
