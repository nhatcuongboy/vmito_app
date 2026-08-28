import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(<SessionTimeRange>{});
    registerFallbackValue(<int>{});
    registerFallbackValue(<SessionSport>{});
    registerFallbackValue(<String>{});
  });

  test('load and refresh keep the complete applied filter', () async {
    final repository = _MockSessionRepository();
    when(
      () => repository.browseAvailable(
        limit: any(named: 'limit'),
        page: any(named: 'page'),
        search: any(named: 'search'),
        date: any(named: 'date'),
        timeRanges: any(named: 'timeRanges'),
        levels: any(named: 'levels'),
        sports: any(named: 'sports'),
        hasSlots: any(named: 'hasSlots'),
        sessionType: any(named: 'sessionType'),
        city: any(named: 'city'),
        districts: any(named: 'districts'),
        minFee: any(named: 'minFee'),
        maxFee: any(named: 'maxFee'),
        splitEvenly: any(named: 'splitEvenly'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        sortByDistance: any(named: 'sortByDistance'),
        venueId: any(named: 'venueId'),
        sortBy: any(named: 'sortBy'),
        sortOrder: any(named: 'sortOrder'),
      ),
    ).thenAnswer(
      (_) async => const Page<Session>(
        items: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 1,
      ),
    );
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      browseSessionsControllerProvider.notifier,
    );
    final filters = BrowseSessionFilters(
      search: 'Sunday',
      date: DateTime(2026, 8, 16),
      timeRanges: const {SessionTimeRange.morning},
      levels: const {4, 5},
      sports: const {SessionSport.pickleball},
      hasSlots: true,
      nearMe: true,
      city: 'Hồ Chí Minh',
      districts: const {'Phường An Đông'},
      minFee: 50000,
      maxFee: 100000,
      splitEvenly: true,
      latitude: 10.77,
      longitude: 106.69,
      venueId: 'venue-1',
      venueName: 'Sân A',
    );

    await controller.load(filters: filters);
    await controller.refresh();

    expect(container.read(browseSessionsControllerProvider).filters, filters);
    verify(
      () => repository.browseAvailable(
        limit: 20,
        search: 'Sunday',
        date: DateTime(2026, 8, 16),
        timeRanges: const {SessionTimeRange.morning},
        levels: const {4, 5},
        sports: const {SessionSport.pickleball},
        hasSlots: true,
        sessionType: 'all',
        city: 'Hồ Chí Minh',
        districts: const {'Phường An Đông'},
        minFee: 50000,
        maxFee: 100000,
        splitEvenly: true,
        latitude: 10.77,
        longitude: 106.69,
        sortByDistance: true,
        venueId: 'venue-1',
        sortBy: 'date',
        sortOrder: 'asc',
      ),
    ).called(2);
  });

  test(
    'loadMap requests the complete filtered result without replacing list',
    () async {
      final repository = _MockSessionRepository();
      const mapped = Session(
        id: 'mapped',
        name: 'Mapped session',
        status: SessionStatus.preparing,
        venue: SessionVenue(
          id: 'venue-1',
          lat: 10.77,
          lng: 106.69,
        ),
      );
      when(
        () => repository.browseAvailable(
          limit: any(named: 'limit'),
          page: any(named: 'page'),
          search: any(named: 'search'),
          date: any(named: 'date'),
          timeRanges: any(named: 'timeRanges'),
          levels: any(named: 'levels'),
          sports: any(named: 'sports'),
          hasSlots: any(named: 'hasSlots'),
          sessionType: any(named: 'sessionType'),
          city: any(named: 'city'),
          districts: any(named: 'districts'),
          minFee: any(named: 'minFee'),
          maxFee: any(named: 'maxFee'),
          splitEvenly: any(named: 'splitEvenly'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          sortByDistance: any(named: 'sortByDistance'),
          venueId: any(named: 'venueId'),
          sortBy: any(named: 'sortBy'),
          sortOrder: any(named: 'sortOrder'),
        ),
      ).thenAnswer(
        (invocation) async => Page<Session>(
          items: invocation.namedArguments[#limit] == 500 ? [mapped] : const [],
          total: 1,
          page: 1,
          limit: invocation.namedArguments[#limit] as int,
          totalPages: 1,
        ),
      );
      final container = ProviderContainer(
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        browseSessionsControllerProvider.notifier,
      );

      await controller.loadMap();

      final state = container.read(browseSessionsControllerProvider);
      expect(state.sessions, isEmpty);
      expect(state.mapSessions, [mapped]);
      verify(
        () => repository.browseAvailable(
          limit: 500,
          search: '',
          timeRanges: const {},
          levels: const {},
          sports: const {},
          sessionType: 'all',
          districts: const {},
          splitEvenly: false,
          sortByDistance: false,
          sortBy: 'date',
          sortOrder: 'asc',
        ),
      ).called(1);
    },
  );

  test('a late map response cannot replace markers for a newer city', () async {
    final repository = _MockSessionRepository();
    final oldResult = Completer<Page<Session>>();
    final newResult = Completer<Page<Session>>();
    when(
      () => repository.browseAvailable(
        limit: any(named: 'limit'),
        page: any(named: 'page'),
        search: any(named: 'search'),
        date: any(named: 'date'),
        timeRanges: any(named: 'timeRanges'),
        levels: any(named: 'levels'),
        sports: any(named: 'sports'),
        hasSlots: any(named: 'hasSlots'),
        sessionType: any(named: 'sessionType'),
        city: any(named: 'city'),
        districts: any(named: 'districts'),
        minFee: any(named: 'minFee'),
        maxFee: any(named: 'maxFee'),
        splitEvenly: any(named: 'splitEvenly'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        sortByDistance: any(named: 'sortByDistance'),
        venueId: any(named: 'venueId'),
        sortBy: any(named: 'sortBy'),
        sortOrder: any(named: 'sortOrder'),
      ),
    ).thenAnswer((invocation) {
      final limit = invocation.namedArguments[#limit] as int;
      if (limit == 20) {
        return Future.value(
          Page<Session>(
            items: const [],
            total: 0,
            page: 1,
            limit: limit,
            totalPages: 1,
          ),
        );
      }
      return invocation.namedArguments[#city] == 'Hồ Chí Minh'
          ? oldResult.future
          : newResult.future;
    });
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      browseSessionsControllerProvider.notifier,
    );

    await controller.load(
      filters: const BrowseSessionFilters(city: 'Hồ Chí Minh'),
    );
    final pendingOldMap = controller.loadMap();
    await controller.load(filters: const BrowseSessionFilters(city: 'Hà Nội'));
    final pendingNewMap = controller.loadMap();
    newResult.complete(
      const Page<Session>(
        items: [
          Session(
            id: 'new-city',
            name: 'New city',
            status: SessionStatus.preparing,
          ),
        ],
        total: 1,
        page: 1,
        limit: 500,
        totalPages: 1,
      ),
    );
    await pendingNewMap;
    oldResult.complete(
      const Page<Session>(
        items: [
          Session(
            id: 'old-city',
            name: 'Old city',
            status: SessionStatus.preparing,
          ),
        ],
        total: 1,
        page: 1,
        limit: 500,
        totalPages: 1,
      ),
    );
    await pendingOldMap;

    expect(
      container
          .read(browseSessionsControllerProvider)
          .mapSessions
          .map((session) => session.id),
      ['new-city'],
    );
  });
}
