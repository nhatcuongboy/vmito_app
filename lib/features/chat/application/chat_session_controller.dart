import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_persistence/stream_chat_persistence.dart';
import 'package:vmito_app/core/notifications/push_registration_manager.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/chat/data/chat_service.dart';
import 'package:vmito_app/features/chat/domain/chat_session.dart';

class ChatSessionState {
  const ChatSessionState({
    this.session,
    this.isLoading = false,
    this.error,
    this.client,
  });

  final ChatSession? session;
  final bool isLoading;
  final Object? error;

  /// Non-null once [session] is connectable and `connectUserWithProvider`
  /// has resolved. Kept in state (rather than recreated per screen) so every
  /// chat screen shares one socket connection.
  final StreamChatClient? client;

  bool get isResolved => session != null || error != null;

  ChatSessionState copyWith({
    ChatSession? session,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    StreamChatClient? client,
    bool clearClient = false,
  }) => ChatSessionState(
    session: session ?? this.session,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    client: clearClient ? null : (client ?? this.client),
  );
}

/// Owns the chat session (consent + Stream token) and the single
/// [StreamChatClient] connection for the app's lifetime.
///
/// Mirrors how `SocketIdentityLifecycle` owns the Socket.IO identity: one
/// controller, driven by auth state, that every chat screen reads from
/// rather than each managing its own connection.
class ChatSessionController extends Notifier<ChatSessionState> {
  // `StreamChatClient` doesn't expose the api key it was built with, so it's
  // tracked here to detect the (practically never happening, but cheap to
  // guard) case where a redeployed backend starts returning a different one.
  String? _connectedApiKey;

  @override
  ChatSessionState build() => const ChatSessionState();

  ChatService get _service => ref.read(chatServiceProvider);

  /// Fetches `/chat/session` and connects (or disconnects) the Stream client
  /// to match. Safe to call repeatedly, e.g. on every sign-in.
  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _service.session();
      state = state.copyWith(session: session, isLoading: false);
      await _syncClient(session);
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  /// Records consent for the current terms version, then connects.
  ///
  /// Throws on failure — the consent screen surfaces that itself rather than
  /// silently sitting on the checkbox form.
  Future<void> acceptTerms() async {
    final termsVersion = state.session?.termsVersion;
    if (termsVersion == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _service.acceptTerms(termsVersion);
      state = state.copyWith(session: session, isLoading: false);
      await _syncClient(session);
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, error: error);
      rethrow;
    }
  }

  Future<void> _syncClient(ChatSession session) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (!session.isConnectable || userId == null) {
      await _disposeClient();
      return;
    }

    var client = state.client;
    if (client != null && _connectedApiKey != session.apiKey) {
      await _disposeClient();
      client = null;
    }
    if (client == null) {
      client = StreamChatClient(session.apiKey!)
        ..chatPersistenceClient = StreamChatPersistenceClient();
      _connectedApiKey = session.apiKey;
      state = state.copyWith(client: client);
    }

    if (client.state.currentUser?.id == userId) return;
    await client.connectUserWithProvider(
      User(id: userId),
      (_) async {
        final refreshed = await _service.session();
        return refreshed.token ?? (throw StateError('Chat session revoked'));
      },
    );
    await _registerPushDevice(client);
  }

  /// Registers the same FCM token already used for Vmito's own push
  /// notifications with Stream, so a new message can be delivered while the
  /// app is backgrounded. Best-effort — a failure here must not block chat.
  Future<void> _registerPushDevice(StreamChatClient client) async {
    if (!supportsNativePushNotifications) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await client.addDevice(token, PushProvider.firebase);
      }
    } on Object catch (error) {
      AppLogger.warn('chat push device registration failed', error: error);
    }
  }

  Future<void> _disposeClient() async {
    final client = state.client;
    if (client == null) return;
    _connectedApiKey = null;
    state = state.copyWith(clearClient: true);
    try {
      await client.dispose();
    } on Object {
      // Best-effort — the reference is already dropped from state above.
    }
  }

  /// Removes the push device, disconnects and wipes the local message cache.
  /// Called from sign-out via `sessionCleanupProvider` in `bootstrap.dart`.
  Future<void> disconnectAndClear() async {
    final client = state.client;
    _connectedApiKey = null;
    state = const ChatSessionState();
    if (client == null) return;
    if (supportsNativePushNotifications) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          await client.removeDevice(token);
        }
      } on Object catch (error) {
        AppLogger.warn('chat push device removal failed', error: error);
      }
    }
    try {
      await client.disconnectUser(flushChatPersistence: true);
    } on Object {
      // Sign-out must proceed even if Stream is unreachable.
    }
  }
}

final chatSessionControllerProvider =
    NotifierProvider<ChatSessionController, ChatSessionState>(
      ChatSessionController.new,
    );

/// The connected client, or null before consent/connection resolves.
///
/// Prefer this over `chatSessionControllerProvider.select((s) => s.client)`
/// at call sites — same effect, shorter and more discoverable.
final chatClientProvider = Provider<StreamChatClient?>(
  (ref) => ref.watch(chatSessionControllerProvider).client,
);
