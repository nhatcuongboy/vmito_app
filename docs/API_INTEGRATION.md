# API integration

The backend (`vmito-be`, NestJS) is shared with the web app and reused
unchanged. The app is a pure REST + Socket.IO client and reimplements no server
logic.

The only Next.js route handler in the whole web app is `/api/ai/chat`, a
streaming proxy that exists to hide the Gemini API key. If the app ever needs
the AI assistant, the key must be moved behind a backend endpoint — never
embedded in the binary.

## Base URL

`AppConfig.apiBaseUrl`, including the `/api` suffix. Socket.IO uses
`AppConfig.socketBaseUrl`, which is the same URL with `/api` stripped, because
the backend serves Socket.IO at the root and separates concerns by namespace.

Android emulators reach the host at `10.0.2.2`, not `localhost` — use
`env/dev.android.json`.

## The response envelope

Most endpoints wrap the payload:

```json
{ "success": true, "data": { ... } }
```

`TransformInterceptor` in `vmito-be/src/main.ts` is registered **globally**, so
this applies to every JSON response — including `/auth/refresh` and
`/auth/register`, which FLUTTER_PORT_ASSESSMENT.md claims are bare. Verified
against the live API: they are not. Routes using `@Res()` directly (the OAuth
redirects) bypass it.

The client still **sniffs for the `success` key** rather than assuming, so a
route that opts out keeps working:

```dart
final user = unwrap(response.data, User.fromJson);
final sessions = unwrapList(response.data, Session.fromJson);
```

Both shapes keep working, so a backend change here never needs a coordinated
app release.

## Writing a service

```dart
class SessionService {
  const SessionService(this._client);
  final ApiClient _client;

  Future<Session> byId(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.session(id),
    );
    return unwrap(response.data, Session.fromJson);
  }
}

final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(ref.watch(apiClientProvider)),
);
```

Rules:

- one class per web service file, **named the same**;
- takes `ApiClient`, never a bare `Dio`;
- returns domain models, never `Response` or raw maps;
- touches no app state — the controller does that;
- every path comes from `ApiEndpoints`.

## Authentication

Custom JWT. **Not NextAuth** — `next-auth` is in the web `package.json` with
zero imports, alongside unused `bcryptjs` and `jsonwebtoken`.

### Tokens

Access + refresh, stored in `flutter_secure_storage` (Keychain/Keystore).
`TokenStorage` caches the access token in memory so the request interceptor
stays synchronous — a platform-channel round trip per request is a real cost on
a list screen. Every write path keeps the cache in step.

### Refresh

`AuthInterceptor` performs **single-flight** refresh: the first 401 starts it,
concurrent 401s await the same future, and each request is replayed once with
the new token (`RequestOptions.isRetry` guards against a second attempt).

The refresh call itself goes through a **separate, interceptor-free Dio**;
using the main client would recurse.

Auth endpoints never trigger refresh — `/auth/refresh` above all, or a dead
refresh token loops forever.

A 401 with **no** stored refresh token is a guest hitting a protected endpoint.
That is not a session expiry: do not sign anyone out, just surface the error.

### Social login

Backend-driven OAuth redirect. The web app uses a plain `<a href>` to
`{API}/auth/{google,facebook}`, and the backend redirects back with tokens as
**query parameters**. There is no PKCE code exchange on the client.

In Flutter: `flutter_web_auth_2` with `AppConfig.authCallbackScheme`, plus one
allowlist entry on the backend for the custom scheme.

**Apple Sign-In does not exist on the backend.** Passport strategies present:
`google`, `facebook`, `local`, `jwt`. Because Google and Facebook login are
offered, App Store guideline 4.8 makes Sign in with Apple mandatory. It is real
backend work: verify `identityToken` against Apple's JWKS, key users on `sub`,
tolerate private-relay emails, and handle that **Apple returns name and email
only on the first authorization**.

### Guests

A guest holds no JWT. Identity is the player/session pair obtained from a join
code (`POST /players/join-by-code`). `AuthStatus.guest` covers this; guest
sockets connect with an empty token.

## Errors

Callers only ever see `ApiException`. `ApiErrorKind` classifies it
(`network`, `timeout`, `unauthorized`, `forbidden`, `notFound`, `validation`,
`server`, `cancelled`, `unknown`), and `isRetryable` drives retry buttons.

`HttpExceptionFilter` nests the payload one level down. Verified live:

```json
{ "success": false,
  "error": { "message": "Invalid credentials",
             "error": "Unauthorized",
             "statusCode": 401 },
  "statusCode": 401 }
```

`error.message` is a string, or a **list** for class-validator failures — which
`ApiException._extractMessage` joins so the user sees every offending field, not
just the first. Reading a top-level `message` finds nothing here; that shape is
kept only as a fallback.

Pass `apiOptions(skipGlobalError: true)` when the caller renders the failure
itself. Forms always do.

## GET de-duplication

`ApiClient.get` collapses identical concurrent GETs into one request, clearing
the entry once it settles so post-mutation data is always fresh.

The key is `token|path|sortedParams`. Sorting is deliberate: the web version
uses `JSON.stringify(params)`, whose output depends on insertion order, so
`{a,b}` and `{b,a}` miss each other's entry and fire duplicate requests.

Pass `dedup: false` when a caller genuinely needs its own request.

## Uploads

Backend-proxied to Cloudinary — **not** S3 presigned URLs. Every entity stores
an `xxx` / `xxxPublicId` pair.

Compress before uploading, matching the web app's budget: **1 MB / 1920 px**
(`browser-image-compression` there, `flutter_image_compress` here). Skipping
this puts full-resolution phone camera output on the wire.

## Payments

No gateway. `PaymentMethod` is `CASH | BANK_TRANSFER` only. The flow is a
manual bank-transfer ledger: the host publishes a static bank account plus a QR
image, the player transfers out-of-band and uploads a screenshot, the host
approves or rejects.

All amounts are **integer VND with no minor units** — format with
`decimalDigits: 0`.

## Matchmaking

`GET /courts/{id}/suggested-players?topCount&useAi&language&matchType` decides
who plays next. **Server-side.** The app renders suggestions and never computes
them.

## Codegen from OpenAPI (planned)

`@nestjs/swagger` ^11.2.3 is already configured in `vmito-be`
(`DocumentBuilder` at `src/main.ts:72`), so exporting `openapi.json` is a
script, not a setup task.

Two caveats:

1. **`nest-cli.json` does not enable the Swagger CLI plugin.** Without it
   NestJS cannot infer types or nullability from DTOs, and the generated Dart
   DTOs will be useless. **Enable it before running codegen even once.**
2. Swagger is gated on `NODE_ENV !== 'production'` (`src/main.ts:103`), so the
   CI job that exports the document must run in a non-production environment.

The decision is **generate DTOs, hand-write services**: 180 interfaces and
roughly 4,500 fields make hand-transcription weeks of work plus permanent drift
risk, but generated *clients* are a patching treadmill against imperfect
Swagger output, and hand-tuned signatures are needed for de-duplication and
`skipGlobalError`.
