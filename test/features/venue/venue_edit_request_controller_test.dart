import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/venue/application/venue_edit_request_controller.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue_edit_request.dart';

class _MockVenueService extends Mock implements VenueService {}

const _draft = VenueEditRequestDraft(
  name: 'Sân A',
  sportTypes: ['BADMINTON'],
  street: '12 Nguyễn Huệ',
  newCity: 'Hồ Chí Minh',
  newDistrict: 'Phường Sài Gòn',
);

void main() {
  late _MockVenueService service;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(_draft));
  setUp(() {
    service = _MockVenueService();
    container = ProviderContainer(
      overrides: [venueServiceProvider.overrideWithValue(service)],
    );
    final subscription = container.listen(
      venueEditRequestControllerProvider,
      (previous, next) {},
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
  });

  test('reports success and clears submission state', () async {
    when(
      () => service.createEditRequest(
        venueId: any(named: 'venueId'),
        draft: any(named: 'draft'),
      ),
    ).thenAnswer((_) async {});

    final result = await container
        .read(venueEditRequestControllerProvider.notifier)
        .submit(venueId: 'venue-1', draft: _draft);

    expect(result, isTrue);
    expect(
      container.read(venueEditRequestControllerProvider).isSubmitting,
      isFalse,
    );
    expect(container.read(venueEditRequestControllerProvider).error, isNull);
  });

  test('keeps a safe error state when submission fails', () async {
    when(
      () => service.createEditRequest(
        venueId: any(named: 'venueId'),
        draft: any(named: 'draft'),
      ),
    ).thenThrow(StateError('secret backend detail'));

    final result = await container
        .read(venueEditRequestControllerProvider.notifier)
        .submit(venueId: 'venue-1', draft: _draft);

    expect(result, isFalse);
    expect(
      container.read(venueEditRequestControllerProvider).error,
      isA<StateError>(),
    );
  });

  test('prevents a duplicate submission while pending', () async {
    final pending = Completer<void>();
    when(
      () => service.createEditRequest(
        venueId: any(named: 'venueId'),
        draft: any(named: 'draft'),
      ),
    ).thenAnswer((_) => pending.future);

    final first = container
        .read(venueEditRequestControllerProvider.notifier)
        .submit(venueId: 'venue-1', draft: _draft);
    final second = await container
        .read(venueEditRequestControllerProvider.notifier)
        .submit(venueId: 'venue-1', draft: _draft);

    expect(second, isFalse);
    verify(
      () => service.createEditRequest(
        venueId: any(named: 'venueId'),
        draft: any(named: 'draft'),
      ),
    ).called(1);
    pending.complete();
    expect(await first, isTrue);
  });
}
