# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

**vmito_app** is the Flutter (iOS + Android) client for **Vmito**, a badminton
session and tournament platform. It is a *port* of the web frontend, not a
greenfield app.

Three sibling repos live under `~/Documents/vmito/`:

| Repo | Role |
|---|---|
| `vmito-be` | NestJS backend. **Shared, unchanged.** The single source of truth for business rules. |
| `vmito-fe` | Next.js web app. ~199k lines, feature-complete. **The reference implementation.** |
| `vmito_app` | This repo. Flutter mobile client. |

`vmito-fe/` is the spec. Before building any screen, read the matching web
page and components. Behaviour that differs from web is a decision, not an
accident — say so in the PR.

## Commands

```sh
flutter run --dart-define-from-file=env/dev.json          # iOS sim / physical
flutter run --dart-define-from-file=env/dev.android.json  # Android emulator
flutter run --dart-define-from-file=env/staging.json      # against staging API

flutter analyze                    # must be clean before every commit
flutter test                       # unit + widget tests
flutter test test/integration/     # needs vmito-be on :3001; self-skips otherwise
flutter test integration_test/ -d <device-id> --dart-define-from-file=env/dev.json  # on-device
dart format .                      # 80-column formatter
dart fix --apply                   # auto-fix lints

dart run build_runner build        # after touching any freezed/json model
dart run build_runner watch        # during model work
flutter gen-l10n                   # after touching lib/l10n/*.arb
```

There is no `.env` file. Configuration is compile-time via `--dart-define-from-file`
(see `lib/core/config/app_config.dart` and `env/`).

## Architecture

```
lib/
  main.dart              entry point, nothing else
  bootstrap.dart         composition root — the ONLY place providers are overridden
  app.dart               MaterialApp.router wiring
  core/                  cross-feature infrastructure
    config/              AppConfig — compile-time flavor + URLs
    constants/           ApiEndpoints
    network/             ApiClient, interceptors, ApiException, envelope unwrap
    realtime/            SocketClient, socket event names
    router/              AppRoutes (paths), AppRouter (GoRouter + auth gate)
    storage/             TokenStorage (Keychain/Keystore)
    theme/               AppColors / AppSpacing / AppTheme — ported design tokens
    utils/               AppLogger, formatters, validators
    widgets/             shared atoms used by 2+ features
  features/<name>/
    data/                services — one class per vmito-fe service file
    domain/              freezed models + enums
    application/         Riverpod controllers (Notifier) — the state owners
    presentation/        screens and feature-local widgets
  l10n/                  ARB files (vi, en, zh) + generated localizations
  shared/models/         models used by 3+ features
```

**Dependency direction is one-way**: `presentation → application → data → core`.
A `core/` file must never import from `features/`.

### Layer rules

- **`data/`** — takes `ApiClient`, never a bare `Dio`. Returns domain models,
  never `Response` or raw maps. Touches no app state.
- **`application/`** — owns state. The only layer that writes tokens or user
  state. Throws `ApiException` upward; does not show UI.
- **`presentation/`** — no direct service calls. Reads controllers via
  `ref.watch`, invokes them via `ref.read(...notifier)`.

## Non-negotiables

These come from measured facts about the backend and the web app. Getting any
of them wrong costs days.

1. **Tokens live in `flutter_secure_storage`**, never `shared_preferences`.
2. **`PlayerLevel` is an `int`, never a Dart enum.** Values are non-contiguous:
   1–8, then 9 = `BEGINNER_MINUS`, 10 = `BEGINNER_PLUS`. An enum reorders them
   silently.
3. **Money is integer VND with no minor units.** Format with
   `decimalDigits: 0`. There is no payment gateway — `PaymentMethod` is
   `CASH | BANK_TRANSFER` and the flow is a manual bank-transfer ledger.
4. **Court matchmaking is server-side.** `GET /courts/{id}/suggested-players`
   decides who plays next. The app renders suggestions; it never computes them.
5. **Every socket handler must be an idempotent state patch,** and every screen
   must be rebuildable from a single REST call. iOS kills sockets on background.
   Refetch on resume.
6. **All user-facing text goes through ARB.** No hardcoded strings, matching the
   web app's rule.
7. **Never call an API path inline.** Add it to `ApiEndpoints`.
8. **Never catch `DioException` outside `core/network/`.** Catch `ApiException`.

## Code conventions

### Naming

- Files: `snake_case.dart`. Classes: `PascalCase`. Members: `camelCase`,
  private prefixed `_`.
- Booleans read as predicates: `isLoading`, `hasToken`, `shouldRetry`.
- Handlers: `_handleX` / `_onX` for callbacks, `_submit` for form actions.
- A service class keeps the **same name** as its web counterpart:
  `session.service.ts` → `SessionService` in `features/session/data/session_service.dart`.
- Providers end in `Provider`: `authControllerProvider`, `apiClientProvider`.

### Dart

- No `dynamic` unless the backend genuinely sends a union (e.g. `expiresIn`).
  Say why in a comment when you do.
- `const` constructors on every widget that can take one.
- Prefer `switch` expressions and pattern matching over if-else chains.
- Models are `freezed` + `json_serializable`. Never hand-write `fromJson`.

### State

Riverpod 3 with **manual providers** — `riverpod_generator` is not installed
(its analyzer pin conflicts with `json_serializable ^6.14`). Write
`NotifierProvider`, `Provider`, `FutureProvider` by hand. Do not add
`riverpod_annotation` back without resolving that conflict first.

See [docs/STATE_MANAGEMENT.md](docs/STATE_MANAGEMENT.md).

### Data mutations

After a create/update/delete succeeds, patch local state or refetch only the
affected resource. Never rebuild the whole screen or pop-and-push to see fresh
data — that is a sign the state layer is out of sync, and the fix belongs
there.

## File size guidelines

This project starts clean, so the limits are hard, not aspirational.

| Kind | Target | Max |
|---|---|---|
| Screens | 150–250 | 300 |
| Widgets | 80–150 | 200 |
| Controllers | 100–200 | 250 |
| Services | 150–300 | 400 |
| Models | 50–150 | 200 |
| Utils | 100–200 | 300 |

If a file cannot fit, that is a design problem, not a formatting one. Split by
responsibility: extract a sub-widget, a helper, or a second controller.

**Hard rule inherited from the port plan:** any React component over ~600 lines
gets **redesigned for mobile, not transliterated**. Named offenders include
`RoundsPanel` (2,159 lines), `PublicTournamentStandingsTab` (1,738),
`VenueDetailClient` (1,725), `TournamentHomeTab` (1,656), `BaseSessionCard`
(1,482), `ScoreEntryBoard` (1,345).

## Testing

- Pure logic (scoring, scheduling, standings, brackets) is tested against
  **fixtures shared with the web app** — see [docs/TESTING.md](docs/TESTING.md).
  Both languages read the same corpus so business rules cannot drift.
- Controllers: `ProviderContainer` with overridden services (`mocktail`).
- Screens: widget tests for the states that matter (loading, error, empty).

## Documentation

- New docs go in `/docs/` in **English**.
- Comments explain *why*, not *what*. A comment restating the code is noise;
  a comment recording a decision, a backend quirk, or a measured constraint is
  the point.

## Reference documents

| Doc | What it answers |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, dependency rules, bootstrap |
| [docs/PORTING_GUIDE.md](docs/PORTING_GUIDE.md) | Web → Flutter mapping, per concept |
| [docs/API_INTEGRATION.md](docs/API_INTEGRATION.md) | Envelope, auth, errors, uploads |
| [docs/STATE_MANAGEMENT.md](docs/STATE_MANAGEMENT.md) | Zustand → Riverpod, patterns |
| [docs/REALTIME.md](docs/REALTIME.md) | Sockets, lifecycle, the court call |
| [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | Tokens, theming, shared widgets |
| [docs/I18N.md](docs/I18N.md) | ARB pipeline, locale codes, migration from next-intl |
| [docs/TESTING.md](docs/TESTING.md) | Fixture oracle strategy |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Phases P0–P8, what ships when |
| [FLUTTER_PORT_ASSESSMENT.md](FLUTTER_PORT_ASSESSMENT.md) | The measured assessment this plan came from |

## Backend work this app depends on

Tracked in [docs/ROADMAP.md](docs/ROADMAP.md); all live in `vmito-be`:

1. Enable the Swagger CLI plugin in `nest-cli.json` **before** any Dart codegen.
2. Export `openapi.json` in CI (Swagger is gated on `NODE_ENV !== 'production'`).
3. `DELETE /users/me` — App Store guideline 5.1.1(v) requires in-app deletion.
4. Apple Sign-In strategy + `POST /auth/apple` — guideline 4.8 makes it
   mandatory because Google and Facebook login are offered.
5. `POST /notifications/devices` for FCM tokens.
6. ~~Normalize `/auth/refresh` and `/auth/register` to the envelope.~~ **Not
   needed** — `TransformInterceptor` is global and already covers them
   (verified live; the assessment doc is wrong on this point).
