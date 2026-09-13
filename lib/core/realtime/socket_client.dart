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

typedef SocketFactory =
    io.Socket Function(String uri, Map<String, dynamic> options);

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
    this.observedEvents = SessionEvent.all,
    SocketFactory? socketFactory,
  }) : _tokens = tokenStorage,
       _socketFactory = socketFactory ?? (io.io);

  final TokenStorage _tokens;
  final String namespace;
  final List<String> observedEvents;
  final SocketFactory _socketFactory;

  io.Socket? _socket;
  String? _tournamentRoom;
  String? _authenticatedUserId;
  final Map<String, int> _sessionRoomReferences = {};
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
    final socket = _socketFactory('${AppConfig.socketBaseUrl}$namespace', {
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': (dynamic Function(Map<String, dynamic>) callback) {
        final token = _tokens.accessToken;
        callback({'token': token == null ? '' : 'Bearer $token'});
      },
    });

    for (final name in observedEvents) {
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
        for (final sessionId in _sessionRoomReferences.keys) {
          socket.emit(SocketCommand.joinSession, sessionId);
        }
        if (_authenticatedUserId case final userId?) {
          socket.emit(SocketCommand.joinUserRoom, {'userId': userId});
        }
        if (_tournamentRoom case final tournamentId?) {
          socket.emit(SocketCommand.joinTournament, tournamentId);
        }
      })
      ..onDisconnect((_) {
        AppLogger.debug('socket disconnected: $namespace');
        _connection.add(false);
      })
      ..onConnectError(
        (error) {
          _connection.add(false);
          AppLogger.warn('socket connect error', error: error);
        },
      );
  }

  /// Filtered view of one event type, for a screen that only cares about one.
  Stream<Map<String, dynamic>> on(String eventName) =>
      events.where((e) => e.name == eventName).map((e) => e.data);

  void joinSession(String sessionId) {
    final references = (_sessionRoomReferences[sessionId] ?? 0) + 1;
    _sessionRoomReferences[sessionId] = references;
    if (references == 1 && isConnected) {
      _socket?.emit(SocketCommand.joinSession, sessionId);
    }
  }

  void leaveSession(String sessionId) {
    final references = _sessionRoomReferences[sessionId] ?? 0;
    if (references > 1) {
      _sessionRoomReferences[sessionId] = references - 1;
      return;
    }
    _sessionRoomReferences.remove(sessionId);
    if (references > 0 && isConnected) {
      _socket?.emit(SocketCommand.leaveSession, sessionId);
    }
  }

  /// Changes the authenticated socket identity.
  ///
  /// Reconnecting is intentional: the JWT is part of the handshake, and the
  /// server clears old user rooms on disconnect. Active session rooms are
  /// restored by [connect]'s callback.
  void setAuthenticatedUser(String? userId) {
    if (_authenticatedUserId == userId) {
      connect();
      return;
    }
    _authenticatedUserId = userId;
    if (_socket == null) {
      connect();
    } else {
      reconnect();
    }
  }

  void joinTournament(String tournamentId) {
    _tournamentRoom = tournamentId;
    if (_socket?.connected ?? false) {
      _socket?.emit(SocketCommand.joinTournament, tournamentId);
    }
  }

  void leaveTournament(String tournamentId) {
    _socket?.emit(SocketCommand.leaveTournament, tournamentId);
    if (_tournamentRoom == tournamentId) _tournamentRoom = null;
  }

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

/// A short-lived public socket owned by one tournament detail screen.
// Provider-family declarations are clearer with their inferred Riverpod type.
// ignore: specify_nonobvious_property_types
final tournamentSocketClientProvider = Provider.family<SocketClient, String>((
  ref,
  _,
) {
  final client = SocketClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    namespace: SocketNamespace.tournaments,
    observedEvents: TournamentEvent.all,
  );
  ref.onDispose(client.dispose);
  return client;
});
