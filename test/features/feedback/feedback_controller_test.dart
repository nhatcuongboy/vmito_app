import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/feedback/application/feedback_controller.dart';
import 'package:vmito_app/features/feedback/data/feedback_image_picker.dart';
import 'package:vmito_app/features/feedback/data/feedback_service.dart';
import 'package:vmito_app/features/feedback/domain/feedback.dart';

class _MockFeedbackService extends Mock implements FeedbackService {}

const _draft = FeedbackDraft(
  type: FeedbackType.bugReport,
  title: 'Bug',
  description: 'Details',
);

FeedbackItem _item(String id) => FeedbackItem(
  id: id,
  type: FeedbackType.bugReport,
  status: FeedbackStatus.pending,
  title: 'Bug',
  description: 'Details',
  createdAt: DateTime.utc(2026, 8, 25),
);

void main() {
  late _MockFeedbackService service;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_draft);
  });

  setUp(() {
    service = _MockFeedbackService();
    container = ProviderContainer(
      overrides: [feedbackServiceProvider.overrideWithValue(service)],
    );
    final subscription = container.listen(
      feedbackControllerProvider,
      (previous, next) {},
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
  });

  test('loads the current user feedback', () async {
    when(() => service.listMine()).thenAnswer((_) async => [_item('one')]);

    await container.read(feedbackControllerProvider.notifier).load();

    expect(container.read(feedbackControllerProvider).items.single.id, 'one');
    expect(container.read(feedbackControllerProvider).historyError, isNull);
  });

  test('uploads image, creates feedback and refreshes history', () async {
    const attachment = FeedbackAttachment(
      imageUrl: 'https://example.com/image.jpg',
      imagePublicId: 'feedback/image',
    );
    when(
      () => service.uploadImage(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer((_) async => attachment);
    when(() => service.create(any())).thenAnswer((_) async => _item('new'));
    when(() => service.listMine()).thenAnswer((_) async => [_item('new')]);

    final result = await container
        .read(feedbackControllerProvider.notifier)
        .submit(
          draft: _draft,
          image: PickedFeedbackImage(
            bytes: Uint8List.fromList([1, 2, 3]),
            filename: 'bug.jpg',
          ),
        );

    expect(result, isTrue);
    final captured =
        verify(() => service.create(captureAny())).captured.single
            as FeedbackDraft;
    expect(captured.attachment?.imagePublicId, 'feedback/image');
    expect(container.read(feedbackControllerProvider).items.single.id, 'new');
  });

  test('upload failure does not create feedback', () async {
    when(
      () => service.uploadImage(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    ).thenThrow(StateError('upload failed'));

    final result = await container
        .read(feedbackControllerProvider.notifier)
        .submit(
          draft: _draft,
          image: PickedFeedbackImage(
            bytes: Uint8List.fromList([1]),
            filename: 'bug.jpg',
          ),
        );

    expect(result, isFalse);
    verifyNever(() => service.create(any()));
    expect(
      container.read(feedbackControllerProvider).submissionError,
      isA<StateError>(),
    );
  });

  test('prevents duplicate submissions while one is pending', () async {
    final pending = Completer<FeedbackItem>();
    when(() => service.create(any())).thenAnswer((_) => pending.future);
    when(() => service.listMine()).thenAnswer((_) async => [_item('new')]);
    final controller = container.read(feedbackControllerProvider.notifier);

    final first = controller.submit(draft: _draft);
    await Future<void>.delayed(Duration.zero);
    final duplicate = await controller.submit(draft: _draft);
    pending.complete(_item('new'));

    expect(duplicate, isFalse);
    expect(await first, isTrue);
    verify(() => service.create(any())).called(1);
  });

  test('keeps submission successful when history refresh fails', () async {
    when(() => service.create(any())).thenAnswer((_) async => _item('new'));
    when(() => service.listMine()).thenThrow(StateError('refresh failed'));

    final result = await container
        .read(feedbackControllerProvider.notifier)
        .submit(draft: _draft);

    expect(result, isTrue);
    final state = container.read(feedbackControllerProvider);
    expect(state.items.single.id, 'new');
    expect(state.historyError, isA<StateError>());
    expect(state.submissionError, isNull);
  });
}
