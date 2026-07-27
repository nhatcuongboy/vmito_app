# Architecture

## Shape

Feature-first, with a shared `core/`. Four layers per feature:

```
features/session/
  data/          session_service.dart        HTTP, returns models
  domain/        session.dart, court.dart    freezed models + enums
  application/   session_controller.dart     Riverpod state owner
  presentation/  session_detail_screen.dart  UI
```

`core/` holds anything two features need: the HTTP client, the socket client,
the router, theme, storage, logging, and shared atoms.

### Dependency direction

```
presentation ──▶ application ──▶ data ──▶ core
```

Strictly one-way. A file in `core/` importing from `features/` is a bug —
it means infrastructure grew a dependency on a feature and can no longer be
reused.

`shared/models/` exists for models three or more features need. Two features
sharing a model is not enough: leave it in the owning feature's `domain/`.

## Composition root

`bootstrap.dart` is the only place `ProviderScope.overrides` is populated. It:

1. initialises the Flutter binding and the global error handler;
2. constructs `TokenStorage` and `ApiErrorBus`;
3. builds the configured `ApiClient` (`buildApiClient`);
4. creates the `ProviderContainer` with those three overridden;
5. **awaits `restoreSession()`** so auth status is known before the first frame;
6. calls `runApp`.

Step 5 is what stops the router flashing sign-in at a user who is in fact
signed in.

### The bootstrap cycle

`AuthInterceptor` needs to sign the user out when refresh fails, which means
calling into a controller that lives in the container that does not exist yet.
`bootstrap.dart` closes this with a `late final ProviderContainer` captured by
the callback. It is deliberate; do not "simplify" it into a service locator.

Providers that need construction-time configuration follow the same pattern:
declare the provider throwing `UnimplementedError`, override it in bootstrap.
A missing override then fails loudly at startup instead of silently at first
use.

## Network layer

`core/network/` is a small stack, each piece with one job:

| File | Job |
|---|---|
| `api_client.dart` | The public surface. GET/POST/PUT/PATCH/DELETE + GET de-duplication. |
| `auth_interceptor.dart` | Bearer header; single-flight 401 refresh with replay. |
| `error_interceptor.dart` | `DioException` → `ApiException`; publishes unhandled ones. |
| `api_exception.dart` | The only error type callers see. |
| `api_response.dart` | Unwraps the `{success, data}` envelope. |
| `api_options.dart` | Per-request flags (`skipGlobalError`, `isRetry`) in `extra`. |

`ApiClient._guard` unwraps the typed error the interceptor attached, so no
`DioException` ever escapes `core/network/`.

Details in [API_INTEGRATION.md](API_INTEGRATION.md).

## Routing

One `GoRouter`, rebuilt whenever auth status changes. `redirect` is the single
auth gate — **no screen checks auth for itself**.

Three states it distinguishes:

- **unresolved** — tokens are still being read. Hold on splash.
- **signed in** (including guests) — bounce away from splash and `/auth/*`.
- **signed out** — allow `AppRoutes.publicPaths`, redirect everything else to
  sign-in.

Unlike the web app there is no `[locale]` segment: locale is app state, not
part of the path. `AppRoutes.stripLocale` handles universal links arriving from
vmito.com with a `/vi`, `/en` or `/cn` prefix.

Public paths are not a convenience — App Store guideline 5.1.1(i) forbids
gating browsing behind registration. Browse, join, and QR scan must stay
reachable signed-out.

## Error surfacing

Three tiers, chosen by who can act on the failure:

1. **Caller handles it** — service passes `skipGlobalError: true`, the screen
   catches `ApiException` and renders inline. Forms use this.
2. **Nothing loaded** — the screen shows `AppErrorView` with a retry, gated on
   `ApiException.isRetryable`.
3. **Nobody handled it** — `ErrorInterceptor` publishes to `ApiErrorBus`, and
   `AppErrorListener` (mounted in `MaterialApp.builder`) shows a SnackBar.

401s are never published: on a public screen a guest hitting a protected
endpoint is normal, and surfacing it produces the unauthorized-toast spam the
web app had to special-case.

Raw response bodies never reach the UI — only `ApiException.message`. The
unsanitised body stays on `.raw` for the logger.

## Realtime

`SocketClient` per namespace, multiplexing all events onto one broadcast
stream. `SocketClient.on(name)` gives a screen just the events it wants.

The token is read *inside* the auth callback rather than captured, so a
reconnect after a token refresh picks up the new one without recreating the
socket.

See [REALTIME.md](REALTIME.md) for the lifecycle rules — they are the part
most likely to be got wrong.

## Configuration

Compile-time, via `--dart-define-from-file`. `AppConfig` reads
`String.fromEnvironment`, which is a const expression: flavor branches fold
away at build time and there is no runtime env lookup or `.env` file to ship.

`env/dev.json`, `env/dev.android.json` (emulator needs `10.0.2.2`),
`env/staging.json`, `env/production.json`.
