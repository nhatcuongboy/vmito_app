import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/registration/application/my_join_requests_controller.dart';
import 'package:vmito_app/features/registration/application/my_registration_controller.dart';
import 'package:vmito_app/features/registration/data/registration_repository.dart';
import 'package:vmito_app/features/registration/domain/my_join_request.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _MockRegistrationRepository extends Mock
    implements RegistrationRepository {}

const _request = MyJoinRequest(
  session: MyJoinRequestSession(id: 's1', name: 'Kèo một'),
  players: [
    MyJoinRequestPlayer(
      id: 'p1',
      playerNumber: 1,
      registrationStatus: RegistrationStatus.pending,
    ),
  ],
);

Page<MyJoinRequest> _page(
  List<MyJoinRequest> items, {
  int page = 1,
  int total = 1,
  int totalPages = 1,
}) => Page(
  items: items,
  total: total,
  page: page,
  limit: 20,
  totalPages: totalPages,
);

void main() {
  test('loads total, paginates and withdraws pending requests', () async {
    final repository = _MockRegistrationRepository();
    var withdrawn = false;
    when(
      () => repository.myJoinRequests(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      final page = invocation.namedArguments[#page] as int;
      if (withdrawn) return _page([], total: 0, totalPages: 0);
      return page == 1
          ? _page([_request], total: 2, totalPages: 2)
          : _page([_request], page: 2, total: 2, totalPages: 2);
    });
    when(
      () => repository.withdrawMyJoinRequest('s1'),
    ).thenAnswer((_) async => withdrawn = true);

    final container = ProviderContainer(
      overrides: [registrationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      myJoinRequestsControllerProvider.notifier,
    );

    await controller.loadInitial();
    expect(container.read(myJoinRequestsControllerProvider).total, 2);
    expect(container.read(myJoinRequestsControllerProvider).requests, [
      _request,
    ]);

    await controller.nextPage();
    expect(container.read(myJoinRequestsControllerProvider).page, 2);

    final success = await controller.withdraw(_request);
    expect(success, isTrue);
    expect(container.read(myJoinRequestsControllerProvider).requests, isEmpty);
    verify(() => repository.withdrawMyJoinRequest('s1')).called(1);
  });

  test('does not withdraw a request without pending rows', () async {
    final repository = _MockRegistrationRepository();
    const approved = MyJoinRequest(
      session: MyJoinRequestSession(id: 's1', name: 'Kèo một'),
      players: [
        MyJoinRequestPlayer(
          id: 'p1',
          playerNumber: 1,
          registrationStatus: RegistrationStatus.approved,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [registrationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(myJoinRequestsControllerProvider.notifier)
        .withdraw(approved);

    expect(success, isFalse);
    verifyNever(() => repository.withdrawMyJoinRequest(any()));
  });

  test('indexes registration statuses across every page', () async {
    final repository = _MockRegistrationRepository();
    const approvedRequest = MyJoinRequest(
      session: MyJoinRequestSession(id: 's2', name: 'Kèo hai'),
      players: [
        MyJoinRequestPlayer(
          id: 'p2',
          playerNumber: 1,
          registrationStatus: RegistrationStatus.approved,
        ),
      ],
    );
    when(
      () => repository.myJoinRequests(page: 1, limit: 100),
    ).thenAnswer((_) async => _page([_request], total: 2, totalPages: 2));
    when(
      () => repository.myJoinRequests(page: 2, limit: 100),
    ).thenAnswer(
      (_) async => _page(
        [approvedRequest],
        page: 2,
        total: 2,
        totalPages: 2,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        registrationRepositoryProvider.overrideWithValue(repository),
        isSignedInProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(myRegistrationStatusesProvider.future),
      {
        's1': RegistrationStatus.pending,
        's2': RegistrationStatus.approved,
      },
    );
  });
}
