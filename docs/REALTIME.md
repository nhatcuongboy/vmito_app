# Realtime

Socket.IO, two namespaces, served at `AppConfig.socketBaseUrl` (the API URL
with `/api` stripped — the backend serves Socket.IO at the root and separates
concerns by namespace).

| Namespace | Auth | Used for |
|---|---|---|
| `/sessions` | authenticated, or empty token for guests | live session, courts, players, notifications |
| `/tournaments` | token optional | public scoreboards, referee scoring |

## Authentication

The token is read **inside** the auth callback, not captured when the socket is
created. A reconnect after a token refresh therefore picks up the new token
without recreating the socket.

Guests connect with an empty token. The server handles that for public session
features — do not block the connection client-side.

## The lifecycle rules

These are the rules most likely to be broken, and the breakage is intermittent,
which makes it expensive.

### 1. Every handler is an idempotent state patch

iOS kills sockets when the app backgrounds. You will miss events. A handler
that increments, appends, or toggles will be wrong after a single missed
message. A handler that *sets* a value from the payload will not.

```dart
// wrong — drifts the moment one event is missed
state = state.copyWith(playerCount: state.playerCount + 1);

// right — converges regardless of what was missed
state = state.copyWith(players: {...state.players, player.id: player});
```

### 2. Every screen is rebuildable from a single REST call

The socket is an optimisation, never the source of truth. If a screen cannot
restore itself with one REST call, it cannot recover from a backgrounded
socket.

### 3. Force a refetch on resume

Observe `AppLifecycleState.resumed` and refetch. Do not assume the stream was
continuous.

### 4. Show connection state

`SocketClient.connectionState` drives a "reconnecting" banner. Users in gyms
have poor wifi; silent staleness reads as a broken app.

## Events

Names live in `SessionEvent` (`core/realtime/socket_events.dart`), mirroring the
backend's `SessionEventType` and the enum in `vmito-fe/src/contexts/SocketContext.tsx`.
A typo there is a silently dead listener — always reference the constant.

Subscribe to one event type:

```dart
ref.listen(socketEventProvider(SessionEvent.courtUpdated), (_, event) {
  // idempotent patch
});
```

## The court call

The clearest native win in the project. On web it dies when the tab closes.

Verified behaviour at `vmito-fe/src/contexts/SocketContext.tsx:333-395`:

1. `players_selected` arrives on the user's room;
2. filtered by `data.userId === userId`;
3. a modal is shown;
4. a browser notification fires;
5. TTS speaks `"Mời bạn vào sân số ${courtNumber}"` with `lang: 'vi-VN'`,
   `rate: 1.0`, **repeated 3 times at 1,500 ms gaps** via chained `onend`
   handlers.

The mobile version keeps all of it and adds a push so it works with the app
closed. The string is `courtCallAnnouncement` in ARB — TTS reads the localised
text, not a hardcoded Vietnamese one.

### The iOS constraint

**TTS cannot run from a background push on iOS.** This is a platform limit, not
a bug to work around. The product decision:

- **foreground** — modal + local notification + spoken announcement ×3;
- **backgrounded or locked** — a **time-sensitive push with a custom sound**,
  no speech.

The `com.apple.developer.usernotifications.time-sensitive` entitlement must be
requested in P0. It has lead time; do not discover it during release prep.

## Tournament scoring

Score payloads on `/tournaments` carry a `clientId` and a monotonic `seq` for
echo suppression.

That protocol is what makes an offline write-ahead log **safe** for referee
scoring — the server can already discard duplicates and order writes. Referee
scoring is therefore the one exception to the no-offline-writes rule.

## Offline posture

Users are in gyms with poor wifi. Version 1 ships:

- a **read cache** with a staleness banner;
- **fail-fast mutations** — no generic write queue;
- **one exception**: referee scoring, justified by `clientId` + `seq` above.

A generic write queue against a REST API with no idempotency keys produces
duplicate sessions, duplicate payments, and duplicate players. Do not build one
without server-side idempotency.
