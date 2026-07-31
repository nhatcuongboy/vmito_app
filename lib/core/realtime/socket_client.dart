import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/core/utils/logger.dart';

/// One event as delivered to listeners.
class SocketEvent {
  const SocketEvent(this.name, this.data);

  final String name;
  final Map<String, dynamic> data;
}

/// Socket.IO connection for one namespace.
///
/// iOS tears down sockets when the app backgrounds, so **every** handler must
/// be an idempotent state patch and every screen must be rebuildable from a
/// single REST call. Refetch on resume rather than trusting the stream to have
/// been continuous. See docs/REALTIME.md.
class SocketClient {
  SocketClient({
    required TokenStorage tokenStorage,
    this.namespace = SocketNamespace.sessions,
  }) : _tokens = tokenStorage;

  final TokenStorage _tokens;
  final String namespace;

  io.Socket? _socket;
  final _events = StreamController<SocketEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  /// All server events on this namespace, multiplexed.
  Stream<SocketEvent> get events => _events.stream;

  /// Connection state changes — drives the "reconnecting" banner.
  Stream<bool> get connectionState => _connection.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket != null) return;

    // The token is read inside the auth callback, not captured, so every
    // reconnect picks up the current one after a refresh without recreating
    // the socket. Guests connect with an empty token.
    final socket = io.io('${AppConfig.socketBaseUrl}$namespace', {
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': (dynamic Function(Map<String, dynamic>) callback) {
        final token = _tokens.accessToken;
        callback({'token': token == null ? '' : 'Bearer $token'});
      },
    });

    for (final name in SessionEvent.all) {
      socket.on(name, (dynamic payload) {
        if (payload is Map) {
          _events.add(SocketEvent(name, Map<String, dynamic>.from(payload)));
        }
      });
    }

    _socket = socket
      ..onConnect((_) {
        AppLogger.debug('socket connected: $namespace');
        _connection.add(true);
      })
      ..onDisconnect((_) {
        AppLogger.debug('socket disconnected: $namespace');
        _connection.add(false);
      })
      ..onConnectError(
        (error) => AppLogger.warn('socket connect error', error: error),
      );
  }

  /// Filtered view of one event type, for a screen that only cares about one.
  Stream<Map<String, dynamic>> on(String eventName) =>
      events.where((e) => e.name == eventName).map((e) => e.data);

  void joinSession(String sessionId) =>
      _socket?.emit(SocketCommand.joinSession, sessionId);

  void leaveSession(String sessionId) =>
      _socket?.emit(SocketCommand.leaveSession, sessionId);

  void emit(String event, Map<String, dynamic> payload) =>
      _socket?.emit(event, payload);

  /// Forces a reconnect with a fresh handshake — call after sign-in or
  /// sign-out so the server re-evaluates the identity on the socket.
  void reconnect() {
    _socket?.dispose();
    _socket = null;
    connect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    unawaited(_events.close());
    unawaited(_connection.close());
  }
}

/// Sessions-namespace client, alive for the whole app session.
final socketClientProvider = Provider<SocketClient>((ref) {
  final client = SocketClient(tokenStorage: ref.watch(tokenStorageProvider));
  ref.onDispose(client.dispose);
  return client;
});
