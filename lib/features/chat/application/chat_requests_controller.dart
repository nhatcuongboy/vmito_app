import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/chat/data/chat_service.dart';
import 'package:vmito_app/features/chat/domain/chat_request.dart';

class ChatRequestsState {
  const ChatRequestsState({
    this.requests = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ChatRequest> requests;
  final bool isLoading;
  final Object? error;
}

/// Incoming, still-pending chat requests (`GET /chat/requests`).
///
/// There is no endpoint for the current user's own *outgoing* pending
/// requests — those surface instead as a pending channel in the ordinary
/// channel list (see `ChatInboxScreen`), where `ChatChannelScreen` offers
/// Cancel. This controller only ever shows requests *to* the current user.
class ChatRequestsController extends Notifier<ChatRequestsState> {
  @override
  ChatRequestsState build() => const ChatRequestsState();

  ChatService get _service => ref.read(chatServiceProvider);

  Future<void> load() async {
    state = ChatRequestsState(requests: state.requests, isLoading: true);
    try {
      final requests = await _service.requests();
      state = ChatRequestsState(requests: requests);
    } on Object catch (error) {
      state = ChatRequestsState(requests: state.requests, error: error);
    }
  }

  Future<void> decline(String id) async {
    await _service.declineRequest(id);
    state = ChatRequestsState(
      requests: state.requests.where((r) => r.id != id).toList(growable: false),
    );
  }
}

final chatRequestsControllerProvider =
    NotifierProvider<ChatRequestsController, ChatRequestsState>(
      ChatRequestsController.new,
    );
