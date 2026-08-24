import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/feedback/data/feedback_image_picker.dart';
import 'package:vmito_app/features/feedback/data/feedback_service.dart';
import 'package:vmito_app/features/feedback/domain/feedback.dart';

class FeedbackState {
  const FeedbackState({
    this.items = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.historyError,
    this.submissionError,
  });

  final List<FeedbackItem> items;
  final bool isLoading;
  final bool isSubmitting;
  final Object? historyError;
  final Object? submissionError;

  FeedbackState copyWith({
    List<FeedbackItem>? items,
    bool? isLoading,
    bool? isSubmitting,
    Object? historyError,
    bool clearHistoryError = false,
    Object? submissionError,
    bool clearSubmissionError = false,
  }) => FeedbackState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    historyError: clearHistoryError ? null : historyError ?? this.historyError,
    submissionError: clearSubmissionError
        ? null
        : submissionError ?? this.submissionError,
  );
}

class FeedbackController extends Notifier<FeedbackState> {
  @override
  FeedbackState build() => const FeedbackState();

  FeedbackService get _service => ref.read(feedbackServiceProvider);

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearHistoryError: true);
    try {
      final items = await _service.listMine();
      if (!ref.mounted) return;
      state = state.copyWith(items: items, isLoading: false);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, historyError: error);
    }
  }

  Future<bool> submit({
    required FeedbackDraft draft,
    PickedFeedbackImage? image,
  }) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearSubmissionError: true);
    try {
      var submission = draft;
      if (image != null) {
        final attachment = await _service.uploadImage(
          bytes: image.bytes,
          filename: image.filename,
        );
        if (!ref.mounted) return false;
        submission = FeedbackDraft(
          type: draft.type,
          title: draft.title,
          description: draft.description,
          attachment: attachment,
        );
      }
      final created = await _service.create(submission);
      if (!ref.mounted) return false;
      state = state.copyWith(
        items: <FeedbackItem>[
          created,
          ...state.items.where((item) => item.id != created.id),
        ],
        isSubmitting: false,
      );

      try {
        final items = await _service.listMine();
        if (!ref.mounted) return true;
        state = state.copyWith(items: items, clearHistoryError: true);
      } on Object catch (error) {
        if (ref.mounted) {
          state = state.copyWith(historyError: error);
        }
      }
      return true;
    } on Object catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(isSubmitting: false, submissionError: error);
      return false;
    }
  }
}

final NotifierProvider<FeedbackController, FeedbackState>
feedbackControllerProvider =
    NotifierProvider.autoDispose<FeedbackController, FeedbackState>(
      FeedbackController.new,
    );
