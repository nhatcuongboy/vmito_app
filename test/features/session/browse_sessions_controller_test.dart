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
      ),
    ).called(2);
  });
}
