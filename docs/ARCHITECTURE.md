# Architecture

This document is the standard the team builds against. It supersedes ad-hoc
screen placement decisions made before the P0–P3 organisation audit
(2026-08-01). [Migration mapping](#migration-mapping) has the file-by-file
table.

## Shape

Feature-first, with two shared layers. Four sub-layers per feature.

```
lib/
  core/                  cross-cutting infrastructure, zero feature imports
    theme/ router/ network/ realtime/ storage/ config/ constants/ utils/
  shared/                reusable, no app-wiring
    widgets/             AppCard, StatusBadge, LevelBadge, EmptyState, ...
    models/              models 3+ features need
    utils/               pure functions 3+ features need
  features/
    <feature>/
      presentation/      screens, feature-local widgets, controllers' views
      application/       Riverpod controllers — the state owners
      domain/            entities, repository interfaces, (optional) usecases
      data/               models/DTOs, datasources, repository implementations
    ...
  l10n/
```

### Finalised feature list

Business-domain boundaries, decided from the 2026-08-01 audit (see
[Migration mapping](#migration-mapping) for the file-level mapping). Each is a
top-level `features/` folder with its own `data/domain/application/presentation`:

| Feature | Owns | Notes |
|---|---|---|
| `auth` | sign in/up, password reset, OAuth | unchanged |
| `session` | browse, session detail, create, edit | player-facing kèo lifecycle |
| `session_hosting` | host management screen, run/court cards, player selection | split out of `session` — was one 1,154-line screen |
| `court` | live scoring, court call, badminton court view | real-time state of a session's courts; was `live_session` |
| `payment` | transaction dashboard, fee/expense ledger | split out of `session` — different business domain (money), mostly host-only |
| `club` | club CRUD, members, requests, announcements | split out of `social` |
| `feed` | posts, ratings, public profile | remainder of `social` after `club` split |
| `tournament` | — | **not yet built.** Backend + `packages/vmito_domain` scoring already support it; reserve this folder name so the first PR lands inside the convention instead of inventing one |
| `notification` | in-app notification list | unchanged |
| `profile` | own profile, delete account | unchanged |
| `home` | dashboard aggregating other features | unchanged — the one feature allowed to depend on several others |
| `splash` | boot screen | unchanged |

`core/` holds anything two or more **features** need that is *infrastructure*:
HTTP client, socket client, router, theme, storage, logging, and the handful
of app-wiring widgets that hook into a provider side-effect
(`AppErrorListener`, `CourtCallListener`). If a widget's only job is to render
props with no side-effect wiring, it is not `core/` — see
[Shared widgets](#shared-widgets).

### Dependency direction

```
presentation ──▶ application ──▶ domain ◀── data
                                   ▲
                                   └── shared/, core/ (from any layer)
```

Strictly one-way within a feature. `domain/` defines interfaces; `data/`
implements them and is the only layer allowed to know about `ApiClient` or
`SocketClient`. `presentation/` and `application/` never import anything from
`data/` directly — only the `domain/` repository interface.

A file in `core/` importing from `features/` is a bug — it means
infrastructure grew a dependency on a feature and can no longer be reused.

`shared/models/` exists for models three or more features need (e.g. `Court`
if both `session` and `payment` need a lightweight reference to it). Two
features sharing a model is not enough: leave it in the owning feature's
`domain/` and let the second feature import it directly — a real third caller
is the promotion signal, not a guess that one is coming.

## Naming conventions

| Kind | Convention | Example |
|---|---|---|
| File | `snake_case.dart` | `browse_sessions_screen.dart` |
| Class | `PascalCase` | `BrowseSessionsScreen` |
| Member / local | `camelCase`, private prefixed `_` | `isLoading`, `_debounce` |
| Screen class | `<Noun>Screen` | `SessionDetailScreen` |
| Controller class | `<Noun>Controller` | `BrowseSessionsController` |
| Provider | `<name>Provider` (matches the thing it provides) | `browseSessionsControllerProvider`, `sessionRepositoryProvider` |
| Repository interface | `<Noun>Repository` (abstract) in `domain/repositories/` | `SessionRepository` |
| Repository impl | `<Noun>RepositoryImpl` in `data/repositories/` | `SessionRepositoryImpl` |
| Datasource (only when needed, see [Data access](#data-access--repository-pattern)) | `<Noun>RemoteDataSource` / `<Noun>LocalDataSource` in `data/datasources/` | `SessionRemoteDataSource` |
| Use case (only when needed, see [Data access](#data-access--repository-pattern)) | `<Verb><Noun>UseCase` in `domain/usecases/` | `CreateSessionUseCase` |
| Route path constant | `AppRoutes.<camelCase>` | `AppRoutes.sessionDetail(id)` |
| Route name constant | `AppRoutes.name<PascalCase>` | `AppRoutes.nameSessionDetail` |
| Role-scoped presentation subfolder | `presentation/player/`, `presentation/host/` | see [Role separation](#role-separation) |

A service class historically kept the same name as its web counterpart
(`session.service.ts` → `SessionService`). Under the repository pattern that
role is split: the **class that does the HTTP call** keeps that lineage
(`SessionRemoteDataSource` or, when there is no separate datasource,
`SessionRepositoryImpl` itself) — comment the web source file it ports either
way.

## Screen rules ("thin screen")

A screen file may contain: a `ConsumerWidget`/`ConsumerStatefulWidget` `build`
method, layout, and reading/invoking a controller. It must **not** contain:

- Business logic (validation, computed derivations beyond trivial formatting)
  — that belongs in the controller or a domain entity method.
- Direct calls to `ApiClient`, `Dio`, `SocketClient`, or any `data/` class —
  only `ref.watch`/`ref.read` on an `application/` controller.
- `Navigator.push(MaterialPageRoute(...))` — see [Navigation](#navigation).

```dart
// GOOD — thin screen
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionDetailProvider(sessionId));
    return session.when(
      data: (s) => _SessionDetailView(session: s),
      loading: () => const SkeletonLoader.sessionDetail(),
      error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(sessionDetailProvider(sessionId))),
    );
  }
}
```

If a screen file is approaching the size limits in
[File size guardrails](#file-size-guardrails), the fix is almost always:
extract a child widget to `presentation/widgets/`, not "just this once put
logic in `build`".

## State management

Riverpod 3, manual `Notifier`/`AsyncNotifier` providers — unchanged from
[STATE_MANAGEMENT.md](STATE_MANAGEMENT.md). This document does not add a
second pattern; a controller is still the only thing that mutates state, and
it depends on the feature's `domain/` repository interface, not on `data/`
directly:

```dart
class BrowseSessionsController extends Notifier<BrowseSessionsState> {
  SessionRepository get _repo => ref.read(sessionRepositoryProvider);
  // ...
}
```

See [Data access & repository pattern](#data-access--repository-pattern) for
how `sessionRepositoryProvider` is wired.

## Data access & repository pattern

UI and controllers depend on an **abstract repository** declared in
`domain/repositories/`, never on the concrete HTTP/socket client. This is the
one substantive change from the current `XxxService` pattern
([STATE_MANAGEMENT.md](STATE_MANAGEMENT.md)'s example predates it):

```dart
// domain/repositories/session_repository.dart
abstract interface class SessionRepository {
  Future<Session> byId(String id);
  Future<List<Session>> browse(SessionFilter filter);
  Future<Session> create(CreateSessionRequest request);
}

// data/repositories/session_repository_impl.dart
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._client);
  final ApiClient _client;

  @override
  Future<Session> byId(String id) async =>
      Session.fromJson(await _client.get('/sessions/$id'));
  // ...
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepositoryImpl(ref.read(apiClientProvider)),
);
```

Controllers depend on the `sessionRepositoryProvider` **typed as the
interface**. A test overrides it with a fake implementing `SessionRepository`
— no `mocktail` on `Dio`, no network in unit tests.

**Do not build the full textbook split for every feature.** Two things stay
optional, added only when they earn their cost:

- **Separate `data/datasources/`** — split the repository impl into a
  `XxxRemoteDataSource` (raw calls) plus a thinner `XxxRepositoryImpl` that
  composes it, only when a feature genuinely reads from **two or more raw
  sources** (REST + socket, or REST + secure storage). `court` is the real
  candidate today: it merges `SessionRepository` REST reads with
  `SocketClient` court events. A feature with one HTTP backend does not need
  this split — the repository impl *is* the datasource.
- **`domain/usecases/`** — add a use case class only when an action
  orchestrates more than one repository, or carries a business rule beyond a
  passthrough call (e.g. `CreateSessionUseCase` validating a fee config
  before calling `SessionRepository.create`, or `JoinSessionUseCase` calling
  both `SessionRepository` and `PaymentRepository`). A controller method that
  just calls one repository method does not need a use case wrapping it —
  call the repository straight from the controller.

Models stay a single freezed class per entity, shared between `domain/` and
the wire format (unchanged from the existing convention — see CLAUDE.md).
Introducing a separate DTO-vs-entity split on top of the repository interface
would be two abstractions doing one job; the repository interface is the
boundary that earns its keep here, a DTO mapper is not.

## Navigation

One `GoRouter`, defined in `core/router/app_router.dart`, driven by
`core/router/app_routes.dart`. This is the **only** navigation surface in the
app.

Rules:

- **Every** route — including nested ones — has a `name`. No screen navigates
  by hand-building or concatenating a path string at the call site.
- Every parameterised route exposes a typed builder on `AppRoutes`
  (`AppRoutes.sessionDetail(String id)`), so a call site never writes
  `'/sessions/$id'` itself. The builder is the single place a path shape is
  known.
- Call sites use `context.goNamed(...)` / `context.pushNamed(...)` with
  `pathParameters` built from the same values passed to the `AppRoutes`
  builder — never `context.go(AppRoutes.sessionDetail(id))` as a plain path
  push once the named-route migration lands (tracked in
  [Migration mapping](#migration-mapping); today's code still does this and
  is not a blocker on its own, but new routes must use `goNamed`/`pushNamed`).
- `Navigator.push`/`Navigator.of(context).push` is reserved for **local,
  non-routed** UI — a confirmation dialog, a bottom sheet, a date picker.
  Anything that represents a distinct screen the user can deep-link to or
  back-button out of goes through `GoRouter`.
- go_router's own codegen (`go_router_builder`) is deliberately not adopted,
  for the same reason `riverpod_generator` is not: keep one analyzer-pin
  surface, not two. "Typed params" here means *centrally defined and reused*,
  not compiler-checked path segments.

See [Navigation tree](#navigation-tree) for the full tree.

## Role separation

Vmito's roles are `guest`, `player`, `host`, `admin`, `referee`
(`UserRole` in `auth/domain/user.dart`). The audit found **no admin surface in
this app** — admin is 16 pages of table CRUD, web-only, and stays there (see
[ROADMAP.md](ROADMAP.md)). Do not create `features/admin/`.

For `player` vs `host`, we reject a top-level `features/player/` +
`features/host/` split. It would force every business domain (session, club,
payment) to duplicate its `domain/` and `data/` layers per role, or reach
across a feature boundary to share them — exactly the coupling feature-first
architecture exists to avoid. A host managing a session and a player viewing
one are the same `Session` entity, same repository, different screens.

Instead, **role separation happens inside `presentation/` of the owning
feature**, as a subfolder:

```
features/session/presentation/
  player/    browse_sessions_screen.dart, session_detail_screen.dart,
             create_session_screen.dart, edit_session_screen.dart
  widgets/   session_card.dart — used by both player and host presentation
```

```
features/session_hosting/presentation/
  host_session_management_screen.dart
  widgets/   session_run_card.dart, host_court_card.dart,
             payment_settings_card.dart, player_selection_dialog.dart
```

This makes the role boundary visible in the file tree (exactly what the audit
found missing — `TransactionDashboardScreen`, host-only, sat next to
`BrowseSessionsScreen`, everyone-facing, with no folder signal) without
forking the domain model. `referee` has no screens yet; when it does, the same
subfolder pattern applies (`presentation/referee/`).

## Shared widgets

Two shelves, chosen by whether the widget wires into app-level side effects:

| Location | For | Existing examples |
|---|---|---|
| `core/widgets/` | Widgets that subscribe to a global provider or stream and act on it — app-wide plumbing, not swappable props | `AppErrorListener`, `CourtCallListener` |
| `shared/widgets/` | Pure presentational atoms/molecules: props in, callbacks out, no provider reads of their own | `AppCard`, `StatusBadge`, `LevelBadge`, `FilterSheet`, `StickyActionBar`, `EmptyState`, `SkeletonLoader` |

`shared/widgets/` is new — the audit found 32 duplicated
`Center(child: CircularProgressIndicator())` call sites and zero shared
loading/empty widgets. Minimum set to build first:

- `AppLoadingView` / `SkeletonLoader` — replaces the 32 duplicates. `shimmer`
  is already a dependency and unused; `SkeletonLoader` should use it.
- `EmptyState` — icon + message + optional CTA, for every "no data yet" list.
- `AppCard` — the base `Card` wrapper `SessionCard`, `_ClubCard`, and
  `SocialPostCard` each reimplement slightly differently today.
- `StatusBadge` — session status, payment status, request status: same shape
  (coloured pill + label), three copies today.
- `LevelBadge` — wraps the existing `packages/vmito_domain` level-rank logic
  in one visual (currently only `level_band_picker.dart`/`level_range_chips.dart`
  exist, both input widgets, not a display badge).
- `FilterSheet` — generalises `browse_sessions_screen.dart`'s private
  `_FilterSheet` so club/feed list filters do not reinvent it.
- `StickyActionBar` — the bottom-pinned primary-action bar pattern (join
  session, submit form) repeated inline per screen today.

Promotion rule unchanged from [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md): **two
independent callers**, not "this looks reusable."

## File size guardrails

Unchanged from the top-level project convention — repeated here because the
[Migration mapping](#migration-mapping) exists to fix violations of it:

| Kind | Target | Max |
|---|---|---|
| Screens | 150–250 | 300 |
| Widgets | 80–150 | 200 |
| Controllers | 100–200 | 250 |
| Repositories / datasources | 150–300 | 400 |
| Models | 50–150 | 200 |

A file that cannot fit is a design problem: extract a sub-widget, a second
controller, or split the repository by datasource.

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

## Auth redirect gate

`redirect` on the single `GoRouter` is the **only** auth gate — no screen
checks auth for itself. It is rebuilt whenever auth status changes and
distinguishes three states:

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

## Full example feature

`session` end to end, showing every rule above in one place. Not every file a
real `session` feature has — just the shape.

```
features/session/
  domain/
    entities/
      session.dart                    freezed model (doubles as wire format)
      session_filter.dart
    repositories/
      session_repository.dart         abstract interface class
  data/
    repositories/
      session_repository_impl.dart    implements SessionRepository via ApiClient
  application/
    player/
      browse_sessions_controller.dart Notifier<BrowseSessionsState>
      session_detail_controller.dart  FutureProvider.family<Session, String>
  presentation/
    player/
      browse_sessions_screen.dart     ConsumerStatefulWidget — filter UI state only
      session_detail_screen.dart      ConsumerWidget
      create_session_screen.dart
      edit_session_screen.dart
    widgets/
      session_card.dart               used by browse screen AND home dashboard
      section_title.dart
```

```dart
// domain/repositories/session_repository.dart
abstract interface class SessionRepository {
  Future<Session> byId(String id);
  Future<List<Session>> browse(SessionFilter filter);
}

// data/repositories/session_repository_impl.dart
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._client);
  final ApiClient _client;

  @override
  Future<Session> byId(String id) async =>
      Session.fromJson(await _client.get('/sessions/$id'));

  @override
  Future<List<Session>> browse(SessionFilter filter) async => (await _client
          .get('/sessions', queryParameters: filter.toQuery()) as List)
      .map((e) => Session.fromJson(e))
      .toList();
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepositoryImpl(ref.read(apiClientProvider)),
);

// application/player/browse_sessions_controller.dart
class BrowseSessionsController extends Notifier<BrowseSessionsState> {
  SessionRepository get _repo => ref.read(sessionRepositoryProvider);

  @override
  BrowseSessionsState build() => const BrowseSessionsState.initial();

  Future<void> applyFilter(SessionFilter filter) async {
    state = state.copyWith(sessions: const AsyncValue.loading());
    final sessions = await AsyncValue.guard(() => _repo.browse(filter));
    state = state.copyWith(sessions: sessions, filter: filter);
  }
}

final browseSessionsControllerProvider =
    NotifierProvider<BrowseSessionsController, BrowseSessionsState>(
  BrowseSessionsController.new,
);

// presentation/player/browse_sessions_screen.dart
class BrowseSessionsScreen extends ConsumerWidget {
  const BrowseSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browseSessionsControllerProvider);
    return Scaffold(
      body: state.sessions.when(
        data: (sessions) => sessions.isEmpty
            ? const EmptyState(message: 'Chưa có kèo nào')
            : ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (_, i) => SessionCard(
                  session: sessions[i],
                  onTap: () => context.pushNamed(
                    AppRoutes.nameSessionDetail,
                    pathParameters: {'id': sessions[i].id},
                  ),
                ),
              ),
        loading: () => const SkeletonLoader.list(),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.read(browseSessionsControllerProvider.notifier)
              .applyFilter(state.filter),
        ),
      ),
    );
  }
}
```

Test doubles override the interface, never `ApiClient`:

```dart
final container = ProviderContainer(
  overrides: [sessionRepositoryProvider.overrideWithValue(FakeSessionRepository())],
);
```

## Navigation tree

Bottom tabs are unchanged by this refactor — only which `features/` folder
owns each screen changes (see [Migration mapping](#migration-mapping)).
`(Host)` marks a route only a session/club host can reach; everything else is
reachable by any signed-in `player`, and browse/join stay reachable signed out
(App Store 5.1.1(i), see [Auth redirect gate](#auth-redirect-gate)).

```mermaid
flowchart TD
  Splash[/ splash /] --> Shell{Bottom tabs}

  Shell --> Home[/home]
  Home --> Notifications[/notifications]
  Home --> Transactions["/transactions (Host)"]
  Home --> CreateSession[/sessions/create]

  Shell --> Sessions[/sessions]
  Sessions --> SessionDetail["/sessions/:id"]
  SessionDetail --> LiveSession["/sessions/:id/live"]
  SessionDetail --> RateSession["/sessions/:id/rate"]
  SessionDetail --> EditSession["/sessions/:id/edit (Host)"]
  SessionDetail --> CloneSession["/sessions/:id/clone (Host)"]
  SessionDetail --> ManageSession["/sessions/:id/manage (Host)"]
  Sessions --> CreateSession

  Shell --> Feed[/feed]
  Feed --> PostDetail["/feed/:id"]
  Feed --> ClubDetail["/feed/clubs/:id"]
  Feed --> ManageClubs["/feed/manage (Host)"]
  ManageClubs --> CreateClub["/feed/manage/create (Host)"]
  ManageClubs --> ManageClubDetail["/feed/manage/:id (Host)"]
  ManageClubDetail --> EditClub["/feed/manage/:id/edit (Host)"]
  PostDetail --> PublicProfile[/user/:id]

  Shell --> Profile[/profile]
  Profile --> Notifications

  AuthGate[/auth/sign-in] -.redirect gate.-> Shell

  Tournament["/tournaments (not built — reserved)"]
  style Tournament stroke-dasharray: 5 5
```

Two gaps the audit found, to close alongside the rename, not before it:

- `AppRoutes.join` / `AppRoutes.scanQr` are declared as public paths but have
  no `GoRoute` — dead route, not shown above until it exists.
- `AppPlaceholderScreen` exists and is unused; either wire it to `join`/`scanQr`
  or delete it.

## Migration mapping

File-level moves this document authorises, once approved. No code changes
until then.

| Current path | Target path | Reason |
|---|---|---|
| `session/presentation/host_session_management_screen.dart` | `session_hosting/presentation/host_session_management_screen.dart` (split into itself + 5 widgets below) | 1,154 lines, owns 5 nested classes |
| ... `SessionRunCard`, `HostCourtCard`, `PaymentSettingsCard`, `SessionExpensesCard`, `PlayerSelectionDialog` (currently private classes inside the file above) | `session_hosting/presentation/widgets/*.dart` (one file each) | extract from the 1,154-line file |
| `session/application/host_session_management_controller.dart`, `hosted_sessions_controller.dart` | `session_hosting/application/` | follows the screen |
| `session/presentation/browse_sessions_screen.dart`, `session_detail_screen.dart`, `create_session_screen.dart`, `edit_session_screen.dart` | `session/presentation/player/` | role subfolder |
| `session/application/browse_sessions_controller.dart`, `create_session_controller.dart`, `session_detail_controller.dart` | `session/application/player/` | role subfolder |
| `session/presentation/widgets/court_tile.dart` | `court/presentation/widgets/court_tile.dart` | domain move |
| `session/domain/court.dart*` | `court/domain/entities/court.dart` (promote to `shared/models/` only if a third feature needs it) | domain move |
| `live_session/**` (all) | `court/presentation/live/`, `court/application/live/` | live scoring is court state, not a session variant |
| `session/presentation/transaction_dashboard_screen.dart` | `payment/presentation/transaction_dashboard_screen.dart` | different business domain (money) |
| `session/data/payment_service.dart`, `session/domain/payment.dart*` | `payment/data/repositories/payment_repository_impl.dart`, `payment/domain/` | repository rename + move |
| `social/presentation/club_*.dart`, `widgets/club_*.dart` | `club/presentation/` | domain split |
| `social/application/club_management_controller.dart` | `club/application/` | domain split |
| `social/presentation/social_hub_screen.dart`, `post_detail_screen.dart`, `session_rating_screen.dart`, `public_profile_screen.dart`, `widgets/social_post_card.dart` | `feed/presentation/` | remainder after club split |
| `social/application/social_controller.dart` | `feed/application/` — split `FeedController`/`ClubsController` if the audit confirms both live in this one file | remainder after club split |
| `social/data/social_service.dart` | `club/data/repositories/club_repository_impl.dart` + `feed/data/repositories/feed_repository_impl.dart` if the endpoints split cleanly; otherwise keep in `feed/` and have `club/` depend on `feed`'s repository — never the reverse of favouring the older, larger feature | audit before splitting the file |
| `social/presentation/club_detail_screen.dart` (`ref.read(socialServiceProvider)` at line 218), `session_rating_screen.dart` (line 182) | route through the new controller/repository, not a directly-read service | fixes the two layer-rule violations found |
| 32 inline `Center(child: CircularProgressIndicator())` sites | `shared/widgets/skeleton_loader.dart` / `AppLoadingView` | see [Shared widgets](#shared-widgets) |
| `core/api/generated/*` (unused OpenAPI client, ~17k lines, zero imports) | delete, or document why it stays | confirm with the team before deleting — verify no build script regenerates/depends on it first |
| `AppRoutes.join`, `AppRoutes.scanQr` | add real `GoRoute`s, or remove from `AppRoutes.publicPaths` | dead route |
| `core/widgets/app_placeholder_screen.dart` | delete if still unused after the above, or wire to `join`/`scanQr` | dead code |

