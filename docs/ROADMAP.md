# Roadmap

Derived from [FLUTTER_PORT_ASSESSMENT.md](../FLUTTER_PORT_ASSESSMENT.md), which
records the measurements behind these decisions.

## Scope

**Mobile-first companion.** Admin (16 pages of table CRUD), OBS overlays, the
projector scoreboard/showcase, and SEO landing pages stay on web. That cuts
roughly 25% of the work with no loss of end-user value — admin table CRUD on a
phone is worse UX than the web version.

**~66 native screens**, not the 95 `page.tsx` files in `vmito-fe`.

## Phases

| Phase | Content | Weight |
|---|---|---|
| **P0-A** | Foundation: dio client + interceptors, auth, sockets, go_router, ARB pipeline, FCM, CI | L |
| **P0-B** | *Parallel.* Port ~2,900 lines of pure algorithms to Dart + correctness harness | M |

**P0-B is now just-in-time, not up-front.** The harness is built and proven, so
the remaining modules are mechanical. None of them is on P1's path:
`schedule-generator`, `standings`, `match-result-utils`, `bracketSlots` and
`podium` all serve tournaments (P5/P6). Port each one immediately before the
phase that consumes it, when its callers are known. `rally.ts` was done first
because it was the highest-risk module and the harness had to be proven on
something real.

What P1 *does* need from `vmito_domain`: `notifications/content.ts` and
`notifications/routing.ts` (court call text and deep-link resolution).
| **P1** | **Store release 1.0** — join funnel + live court view + voice court-call + push | L |
| **P2** | Player lifecycle: browse/filters, session detail tabs, fees, notifications, profile | L |
| **P3** | Host session management: create/run sessions, courts, roster, fees, payment ledger | XL |
| **P4** | Social: clubs, newsfeed, profiles, ratings, maps, share images | L |
| **P5** | Tournament viewing + referee scoring (read-only bracket first) | L |
| **P6** | Tournament management — contains `manage/` at 29,917 lines | XL |
| **P7** | Venues + court rental | L |
| **P8** | Polish: AI assistant, product tour, accessibility, performance, ASO | M |

Weights are single-developer-equivalent: **S** ≤1 week · **M** 2–4 · **L** 5–8 ·
**XL** 9+. Total ≈ **60 developer-weeks** — roughly 7–8 calendar months with two
Flutter developers plus part-time backend. Treat as ±30%.

### Two sequencing decisions worth preserving

**P5 precedes P6.** A read-only bracket de-risks the hardest custom widget
before drag-reseeding is attempted, and phone-based referee scoring delivers
far more value per line of code than tournament administration.

**P6 is last.** `vmito-fe/src/components/tournament/manage/` is the single most
expensive area in the repository.

## P0-A status

| Item | Status |
|---|---|
| Project scaffold, dependencies, lints | done |
| `AppConfig` + flavor env files | done |
| Design tokens + light/dark theme | done |
| `ApiClient` + auth/error interceptors + GET dedup | done |
| `TokenStorage` (Keychain/Keystore) | done |
| `SocketClient` + event constants | done |
| `go_router` + auth gate | done |
| ARB pipeline (vi/en/zh) | done |
| Auth feature: model, service, controller, sign-in screen | done |
| OpenAPI export + DTO codegen pipeline | done |
| `vmito_domain` pure-Dart package + fixture harness | done |
| `rally.ts` ported (6,570 fixtures, 8/8 mutations caught) | done |
| Browse sessions (public, P1 entry point) | done |
| Session detail (public, read-only) | done |
| Money/date formatters (`Money.vnd`, `Dates`) | done |
| `levels.ts` ported (6/6 mutations caught) | done |
| Browse card at web parity: skill band, price, time range, host, crawled badge | done |
| Bottom-nav shell (`StatefulShellRoute`, 4 branches) | done |
| Join by code / QR | **todo** — deferred |
| **Guest session persistence** | **todo** — see below |
| Sign-up | done |
| Forgot/reset password | done |
| Google/Facebook OAuth (`flutter_web_auth_2`) | done |
| FCM + `flutter_local_notifications` wiring | **todo** — needs Firebase config files and device-token backend endpoints |
| App icons, splash, bundle IDs | done — synced from `vmito-fe/public/icons`, `com.vmito.app` |
| CI (analyze + test on PR) | done |
| iOS time-sensitive notification entitlement | client wired — Apple portal approval pending |

## P1/P2 mobile implementation status

Join by code/QR and guest persistence remain deferred by product direction.

| Item | Status |
|---|---|
| Live court + REST/socket lifecycle | done |
| Foreground modal, local notification and localized TTS | done |
| Browse search + source/level/available-slot filters | done |
| Session detail tabs: overview, courts, players, fees | done |
| Localized player status and level presentation | done |
| Notification pagination, unread state and pull-to-refresh | done |
| Mark one/all read, socket insertion and session routing | done |
| Profile summary, language, notifications and sign-out | done |
| Sign in with Apple | done — `POST /auth/apple`, JWKS-verified, entitlement wired |
| In-app account deletion | done — `DELETE /users/me`, anonymizing (guideline 5.1.1(v)) |

Backend-authored notification title/message remains unchanged. Only client
labels and known presentation values are localized.

## P3 — host session management (done)

| Item | Status |
|---|---|
| `POST /sessions` — create session form | done |
| Hosted-sessions list on Home + create FAB | done |
| `LevelBandPicker` (display order, not id order) | done |
| Auth gate for protected routes under public prefixes | done |
| Courts tab management (assign/swap, start/end match) | done |
| Roster, check-in, waitlist, join approvals | done |
| Payment ledger + host payment settings | done |
| Session expenses, transaction dashboard | done |
| Edit / clone / cancel a session | done |

The create form carries six decisions, not the web form's ~30 fields: venue
linkage, image galleries, club association and crawled-post metadata all have
working defaults or belong to later phases.

## P4 — social (done)

| Item | Status |
|---|---|
| Newsfeed pagination + pull-to-refresh | done |
| Create text post, like, comment and repost | done |
| Native share sheet with canonical web link | done |
| Post image display and carousel | done |
| Club browse, search and detail | done |
| Club join request and external map directions | done |
| Public player profile + rating statistics/reviews | done |
| Create post with compressed image upload | done — ≤10 images, 1920 px / 82% JPEG |
| Submit session/player rating | done — eligibility-gated after finished sessions |
| Generated share-card image | done — rendered post card PNG via `RepaintBoundary` |
| Club management (create/edit, members, announcements) | done |

The feed remains authenticated because `PostsController` applies
`JwtAuthGuard` to `/posts/feed`. Club details and public player profiles use
their public backend endpoints; mutations continue to require a signed-in user.

### Known gap: guest sessions do not survive a restart

`AuthController.signInAsGuest` sets state only — nothing is written to disk. A
guest who joins by code and then backgrounds the app long enough to be killed
loses their player identity and has to re-enter the join code, at the venue,
mid-session.

Signed-in accounts are unaffected: tokens go to the Keychain and are restored
before the first frame (verified on-device by
`integration_test/session_persistence_test.dart`).

The fix belongs in `shared_preferences`, **not** secure storage: a guest's
`playerId` / `sessionId` / `joinCode` are identifiers, not secrets, and the
plan calls this out explicitly. Do it with the join funnel, since that is what
creates a guest in the first place.

## Backend work (in `vmito-be`)

Unblocked; can proceed in parallel with all Flutter work.

1. **Enable the Swagger CLI plugin in `nest-cli.json`** — before any codegen
   run. Without it, DTO types and nullability are missing and the generated
   Dart is worthless.
2. ~~Add a script exporting `openapi.json`.~~ **Done** — `npm run openapi:export`
   plus `.github/workflows/openapi.yml`. Runs in Nest preview mode, so it needs
   no database.
3. ~~`DELETE /users/me` with cascade handling across player records, payment
   history, and club membership.~~ **Done.** Guideline 5.1.1(v).
4. ~~Apple Sign-In strategy + `POST /auth/apple`.~~ **Done.** Guideline 4.8.
5. `POST /notifications/devices` and `DELETE /notifications/devices/:token` —
   additive to the existing `src/notifications/` module.
6. ~~Normalize `/auth/refresh` and `/auth/register` to the envelope.~~ **Not
   needed** — `TransformInterceptor` is global and already covers them. The
   assessment was wrong; verified against the live API.

Also worth filing early, because it needs a web deploy cycle: serve
`apple-app-site-association` and `assetlinks.json` from vmito.com for
universal/app links.

## App Store requirements status

1. **Sign in with Apple** (4.8) — done.
2. **In-app account deletion** (5.1.1(v)) — done.
3. **No forced registration for browsing** (5.1.1(i)) — enforced by
   `AppRoutes.publicPaths`.

## Top risks

1. **Bracket rendering** — `react-tournament-brackets` has no Flutter
   equivalent; 7 components, ~4,000 lines. `CustomPaint` connectors inside an
   `InteractiveViewer`. **Budget 2×.** Ship read-only first.
2. **iOS TTS when backgrounded or locked** — cannot run from a background push.
   Voice is foreground-only; locked-device court calls use a time-sensitive
   push with a custom sound. Entitlement must be requested in P0.
3. **App Store rejection** — the three items above.
4. **Missed socket events across app lifecycle** — every handler an idempotent
   patch, every screen rebuildable from one REST call, forced refetch on
   resume. See [REALTIME.md](REALTIME.md).
5. **Offline expectations** — gyms have poor wifi. V1 ships a read cache with a
   staleness banner and fail-fast mutations, no generic write queue. Referee
   scoring is the one exception, safe because the protocol already carries
   `clientId` and `seq`.
6. **Two frontends drifting on business rules** — mitigated by shared
   `fixtures/`. See [TESTING.md](TESTING.md).
