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
| Sign-up, forgot-password, OAuth (`flutter_web_auth_2`) | **todo** |
| FCM + `flutter_local_notifications` wiring | **todo** — needs Firebase config files |
| App icons, splash, bundle IDs | **todo** |
| CI (analyze + test on PR) | **todo** |
| iOS time-sensitive notification entitlement | **todo** — request early, it has lead time |

## Backend work (in `vmito-be`)

Unblocked; can proceed in parallel with all Flutter work.

1. **Enable the Swagger CLI plugin in `nest-cli.json`** — before any codegen
   run. Without it, DTO types and nullability are missing and the generated
   Dart is worthless.
2. Add a script exporting `openapi.json`; run it in CI in a **non-production**
   environment (Swagger is gated on `NODE_ENV !== 'production'`).
3. `DELETE /users/me` with cascade handling across player records, payment
   history, and club membership. Guideline 5.1.1(v).
4. Apple Sign-In strategy + `POST /auth/apple`. Guideline 4.8.
5. `POST /notifications/devices` and `DELETE /notifications/devices/:token` —
   additive to the existing `src/notifications/` module.
6. ~~Normalize `/auth/refresh` and `/auth/register` to the envelope.~~ **Not
   needed** — `TransformInterceptor` is global and already covers them. The
   assessment was wrong; verified against the live API.

Also worth filing early, because it needs a web deploy cycle: serve
`apple-app-site-association` and `assetlinks.json` from vmito.com for
universal/app links.

## App Store blockers — all must ship in P1

Discovering any of these at review costs a rejection cycle. Two need backend
work.

1. **Sign in with Apple** (4.8) — mandatory because Google and Facebook login
   are offered. No Apple strategy exists on the backend today.
2. **In-app account deletion** (5.1.1(v)) — no endpoint deletes a user today.
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
