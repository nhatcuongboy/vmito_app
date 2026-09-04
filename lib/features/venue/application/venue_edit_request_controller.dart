import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue_edit_request.dart';

class VenueEditRequestState {
  const VenueEditRequestState({this.isSubmitting = false, this.error});

  final bool isSubmitting;
  final Object? error;
}

class VenueEditRequestController extends Notifier<VenueEditRequestState> {
  @override
  VenueEditRequestState build() => const VenueEditRequestState();

  Future<bool> submit({
    required String venueId,
    required VenueEditRequestDraft draft,
  }) async {
    if (state.isSubmitting) return false;
    state = const VenueEditRequestState(isSubmitting: true);
    try {
      await ref
          .read(venueServiceProvider)
          .createEditRequest(venueId: venueId, draft: draft);
      if (!ref.mounted) return false;
      state = const VenueEditRequestState();
      return true;
    } on Object catch (error) {
      if (!ref.mounted) return false;
      state = VenueEditRequestState(error: error);
      return false;
    }
  }
}

final NotifierProvider<VenueEditRequestController, VenueEditRequestState>
venueEditRequestControllerProvider =
    NotifierProvider.autoDispose<
      VenueEditRequestController,
      VenueEditRequestState
    >(VenueEditRequestController.new);
