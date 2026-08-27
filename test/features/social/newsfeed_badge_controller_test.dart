import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';
import 'package:vmito_app/features/social/data/newsfeed_badge_service.dart';

class _MockNewsfeedBadgeService extends Mock implements NewsfeedBadgeService {}

void main() {
  late _MockNewsfeedBadgeService service;
  late ProviderContainer container;
  late NewsfeedBadgeController controller;

  setUp(() {
    service = _MockNewsfeedBadgeService();
    container = ProviderContainer(
      overrides: [newsfeedBadgeServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    controller = container.read(newsfeedBadgeControllerProvider.notifier);
  });

  test('deduplicates concurrent unread-count requests', () async {
    final completion = Completer<int>();
    when(service.unreadCount).thenAnswer((_) => completion.future);

    final first = controller.fetchCount();
    final duplicate = controller.fetchCount();

    expect(identical(first, duplicate), isTrue);
    verify(service.unreadCount).called(1);
    completion.complete(7);
    await first;
    expect(container.read(newsfeedBadgeControllerProvider).count, 7);
  });

  test('an older GET cannot overwrite mark-as-read', () async {
    final oldCount = Completer<int>();
    var calls = 0;
    when(service.unreadCount).thenAnswer((_) {
      calls++;
      return calls == 1 ? oldCount.future : Future.value(0);
    });
    when(service.markAsRead).thenAnswer((_) async {});

    final fetching = controller.fetchCount();
    await controller.markAsRead();
    oldCount.complete(9);
    await fetching;

    expect(calls, 2);
    expect(container.read(newsfeedBadgeControllerProvider).count, 0);
  });

  test('a failed optimistic mark is reconciled from REST', () async {
    when(service.markAsRead).thenThrow(Exception('offline'));
    when(service.unreadCount).thenAnswer((_) async => 4);
    controller.handleRealtimeHint();
    await controller.fetchCount();

    await controller.markAsRead();
    await controller.fetchCount();

    final state = container.read(newsfeedBadgeControllerProvider);
    expect(state.count, 4);
    expect(state.error, isNull);
  });

  test('reset isolates requests from a previous identity', () async {
    final oldCount = Completer<int>();
    var calls = 0;
    when(service.unreadCount).thenAnswer((_) {
      calls++;
      return calls == 1 ? oldCount.future : Future.value(2);
    });

    final previousIdentity = controller.fetchCount();
    controller.reset();
    final currentIdentity = controller.fetchCount();
    oldCount.complete(11);
    await Future.wait([previousIdentity, currentIdentity]);

    expect(container.read(newsfeedBadgeControllerProvider).count, 2);
  });

  test('a realtime hint invalidates an older REST response', () async {
    final oldCount = Completer<int>();
    var calls = 0;
    when(service.unreadCount).thenAnswer((_) {
      calls++;
      return calls == 1 ? oldCount.future : Future.value(6);
    });

    final fetching = controller.fetchCount();
    controller.handleRealtimeHint();
    oldCount.complete(1);
    await fetching;

    expect(calls, 2);
    expect(container.read(newsfeedBadgeControllerProvider).count, 6);
  });
}
