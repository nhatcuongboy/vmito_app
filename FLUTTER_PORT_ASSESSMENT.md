# Flutter Port — Codebase Assessment & Session Context

**Date:** 2026-07-27
**Branch at time of assessment:** `staging` (clean, HEAD `d5cd592b`)
**Question asked:** In what order should the web modules be ported to a Flutter app (iOS + Android), and what tech stack should the Flutter app use?
**Roadmap deliverable:** `~/.claude/plans/t-i-mu-n-clone-web-ticklish-meteor.md` (Vietnamese, 8-phase roadmap, approved)

This document is the durable, verified companion to that roadmap. It records **what was measured**, **what was decided**, and **what blocks the first phase** — so the roadmap can be re-derived or handed to another developer without repeating the investigation.

Every number below was verified by direct measurement against the repo unless explicitly flagged otherwise.

---

## Status update — 2026-07-28

This document records what was measured on 2026-07-27. Two things have changed
since; everything else below still holds.

**§5 local environment is resolved.** Flutter 3.44.8, Dart 3.12.2, full Xcode
26.3 and CocoaPods are installed. The app builds and runs on an iOS simulator,
and on-device integration tests pass against a live backend. Android SDK is
still absent — a deliberate deferral, blocking only APK builds and FCM push
testing.

**§4 / §10 are wrong about the response envelope.** The claim that
`/auth/refresh` and `/auth/register` return the payload bare is incorrect.
`TransformInterceptor` is registered **globally** in `vmito-be/src/main.ts` and
wraps every JSON response, including those two. Verified by direct request
against the running API. Track B item 6 is therefore **not needed**.

Two error-shape facts the original assessment did not capture, both verified
live and both load-bearing for the client:

- `HttpExceptionFilter` nests the payload: the message is at `error.message`,
  not at the top level, and is a **list** for class-validator failures.
- The Swagger CLI plugin (Track B item 1, now enabled) crashes
  `createDocument` at boot on `CreateCategoryRegistrationDto`, whose
  `xorValidation?: undefined` property the plugin resolves as a self-reference.
  Fixed with `@ApiHideProperty()`.

Live progress is tracked in [docs/ROADMAP.md](docs/ROADMAP.md), not here.

---

## 1. Verified codebase inventory

| Metric | Value |
|---|---|
| Total lines in `src/` (.ts + .tsx) | **198,735** |
| TS/TSX files in `src/` | **842** |
| `page.tsx` route files | **95** |
| API service files (`src/lib/api/*.service.ts`) | **34** |
| `src/lib/api/types.ts` | **2,095** lines, **180** exported interfaces/enums/types |
| Zustand stores | **12** |
| Custom hooks (`src/hooks/*.ts`) | **36** |
| Total `src/components/` | **139,707** lines / 492 files |
| Locales | 3 (vi, en, cn) |
| i18n leaf keys | vi **5,978** · en 5,958 · cn 5,919 |
| i18n `pages` namespace alone | **2,811 keys = 47% of vi** |
| Existing test files | **10 files / 1,333 lines** |

### Component weight by directory

| Lines | Directory |
|---|---|
| 51,445 | `src/components/tournament/` (of which `manage/` = **29,917**) |
| 41,537 | `src/components/session/` |
| 12,431 | `src/components/ui/` — Chakra wrappers, **deleted entirely in the port** |
| 7,174 | `src/components/venue/` |
| 4,254 | `src/components/payment/` |
| 4,171 | `src/components/venue-rental/` |
| 3,917 | `src/components/player/` |
| 1,992 | `src/components/court/` |
| 1,969 | `src/components/post/` |
| 1,310 / 1,113 | `src/components/club/` / `clubs/` |

### Derived scope for the Flutter app

95 web pages − 16 admin − 2 OBS overlay − scoreboard − showcase − `san-cau-long/[slug]` − `[...slug]` − root redirect − 5 dead/stub pages = **~66 native screens**.

That is the number to plan against, not 95. Separately, `src/components/ui/` (12,431 lines) is Chakra wrapper code with no Flutter counterpart to build — it is replaced by Material/Cupertino plus roughly 20 shared atoms, making it the single largest deletion in the port.

---

## 2. Architectural facts that shape the port

**The backend is fully reusable.** `vmito-be` is a separate NestJS service; the web frontend is a pure REST + Socket.IO client. The only Next.js route handler in the entire app is `/api/ai/chat`, a streaming proxy that exists solely to hide the Gemini API key. The Flutter app calls the backend directly and reimplements no server logic.

**Auth is custom JWT, not NextAuth.** `next-auth@5.0.0-beta.25` is in `package.json` with **zero imports** in `src/` (alongside unused `bcryptjs` and `jsonwebtoken`). Social login is a backend-driven OAuth redirect — a plain `<a href>` to `{API}/auth/{google,facebook}` — with tokens returned as **query parameters** to `/{locale}/auth/callback`. This is why the Flutter port needs only `flutter_web_auth_2` plus one backend allowlist entry, with no code exchange.

**Tokens live in `localStorage`** via Zustand `persist` under key `auth-storage`. In Flutter these must move to `flutter_secure_storage` (Keychain/Keystore).

**Court matchmaking is server-side.** `GET /courts/{id}/suggested-players?topCount&useAi&language&matchType` decides who plays next. `src/utils/auto-assign.ts` is client-side but is used **only for tournament group assignment**. The app renders suggestions; it never computes them. This is the single most expensive misunderstanding available in this port.

**Payments have no gateway.** `PaymentMethod` is `CASH | BANK_TRANSFER` only. The flow is a manual bank-transfer ledger: the host publishes a static bank account plus QR image, the player transfers out-of-band and uploads a screenshot, the host approves or rejects. All amounts are **integer VND with no minor units** — formatters must use `decimalDigits: 0`.

**Uploads are backend-proxied to Cloudinary,** not S3 presigned. Every entity stores an `xxx` / `xxxPublicId` pair. The client compresses before upload via `browser-image-compression` (1 MB / 1920 px), which `flutter_image_compress` must match.

**Two Socket.IO namespaces.** `/sessions` (authenticated or empty-token guest) and `/tournaments` (token optional, for public scoreboards). Tournament score payloads carry `clientId` plus a monotonic `seq` for echo suppression — which is precisely what makes an offline write-ahead log safe for referee scoring.

### The court-call feature (P1 critical path)

Verified at `src/contexts/SocketContext.tsx:333-395`. On a `players_selected` event in the user's room, filtered by `data.userId === userId`, the web app shows a modal, fires a browser notification, then speaks `"Mời bạn vào sân số ${courtNumber}"` with `lang: 'vi-VN'`, `rate: 1.0`, **repeated 3 times at 1,500 ms gaps** via chained `onend` handlers.

This is the clearest native win in the project: on web it dies when the tab closes. On mobile it becomes a time-sensitive push with a custom sound.

### The hardest widget (P1 blocking)

`src/components/court/BadmintonCourt.tsx` (767 lines) plus `CourtPlayer.tsx` (363) and `PlayerTooltip.tsx` (328). Verified properties: `aspectRatio = 13.4 / 6.1` (line 66), three modes (`manage | view | selection`), and two `CourtDirection` values (HORIZONTAL / VERTICAL). Direction must be implemented as a **coordinate transform, not two widget trees**.

---

## 3. Decisions made

| Decision | Choice | Rationale |
|---|---|---|
| **Scope** | Mobile-first companion | Admin (16 pages of table CRUD), OBS overlays, projector scoreboard/showcase, and SEO landing pages stay on web. Cuts roughly 25% of the work with no loss of end-user value; admin table CRUD on a phone is worse UX than the web version. |
| **State / stack** | Riverpod 2 + freezed + dio + go_router | Riverpod maps near 1:1 onto the existing Zustand stores; dio reproduces the axios interceptor semantics directly; go_router matches the existing route structure. Lowest boilerplate at this scale. |
| **Backend** | Modifiable | Enables FCM device-token registration, envelope normalization, and OpenAPI export for Dart codegen. |
| **First store release** | Join funnel + live court view | Auth, browse, QR/code join, live court board, voice court-call, push. Concentrates the first release on the capabilities where native beats web outright. |

**Models: generate DTOs, hand-write services.** With 180 interfaces and roughly 4,500 fields across 391 call sites, hand-writing freezed models is weeks of transcription plus permanent drift risk. But generated *clients* are a patching treadmill against imperfect NestJS Swagger output, and hand-tuned signatures are needed for `dedupGet` and `skipGlobalError`. So: generate DTOs from a committed `openapi.json`, hand-write the 34 service classes named 1:1 with their TS counterparts.

**`PlayerLevel` must be `int`, never a Dart enum.** The values are non-contiguous: 1–8, then 9 = `BEGINNER_MINUS`, 10 = `BEGINNER_PLUS`. A generated enum will silently reorder them.

---

## 4. Backend readiness (`vmito-be`)

Verified by direct inspection of the sibling repo.

**Cheaper than planned — Swagger already exists.** `@nestjs/swagger` ^11.2.3 with a fully configured `DocumentBuilder` at `src/main.ts:72` (Bearer auth, 10 tags). The P0 task shrinks from "set up Swagger" to "add a script that writes the document to a JSON file."

Two caveats that raise the codegen-quality risk:

1. **`nest-cli.json` does not enable the Swagger CLI plugin.** Without it NestJS cannot infer types or nullability from DTOs, so the generated `openapi.json` will be missing critical metadata and the resulting Dart DTOs will be largely useless. **Enable this before running codegen even once** — otherwise you generate a worthless DTO set and only discover it later.
2. Swagger is gated on `NODE_ENV !== 'production'` (`src/main.ts:103`), so the CI job that exports `openapi.json` must run in a non-production environment.

**Cheaper than planned — the notifications module already exists.** `src/notifications/` has a controller, service, and DTOs. Device-token registration is additive to an existing module, not a new one.

**More expensive than planned — Apple Sign-In does not exist.** Passport strategies present: `google`, `facebook`, `local`, `jwt`. There is **no** Apple strategy (and no Zalo strategy, despite the commented-out Zalo link on web). Because Google and Facebook login are offered, App Store Guideline 4.8 makes Sign in with Apple mandatory. This is real backend work: verify `identityToken` against Apple's JWKS, key users on `sub`, tolerate private-relay emails, and handle that **Apple returns name and email only on the first authorization**.

**More expensive than planned — no account deletion endpoint.** A sweep of every `@Delete(` across all controllers found deletes for payment-settings, tournaments, umpires, and schedules, but **nothing that deletes a user or account**. Guideline 5.1.1(v) requires in-app account deletion for any app supporting account creation. Needs `DELETE /users/me` with cascade handling across player records, payment history, and club membership — not trivial.

**No push infrastructure at all.** No Firebase, FCM, or device-token handling anywhere in `vmito-be`. Confirmed matching the frontend finding: the web app only uses the foreground-only browser `Notification` constructor (`src/utils/notifications.ts`, 31 lines).

---

## 5. Local environment readiness — currently blocking

| Tool | Status |
|---|---|
| `flutter` | **Not installed** |
| `dart` | **Not installed** |
| Xcode | **Command Line Tools only** — full Xcode required for iOS builds |
| CocoaPods | **Not installed** |
| Android SDK | **Not present** at the default path |

No Flutter work can begin until this is resolved. Installing full Xcode from the App Store takes the longest and should be started first. The backend P0 tasks in §4 are unblocked and can proceed in parallel.

---

## 6. Issues found in the web repo — actionable independently of the port

These are pre-existing defects surfaced during the assessment. They affect production users today and are worth fixing regardless of whether the Flutter port proceeds.

**`/tournaments` self-redirects.** `ROUTE_REDIRECTS['/tournaments'] = ROUTES.BROWSE.TOURNAMENTS.LIST`, and that constant is literally `'/tournaments'` (`src/constants/routes.ts:97` and `:368`). The middleware sees a truthy target and issues a 302 from `/vi/tournaments` to itself, so the browse-tournaments page and its 674-line client component are likely unreachable in production.

**Shared tournament links 404.** `/tournaments/[id]` redirects to `/browse/tournaments/[id]`, which has no page file. The pattern key `'/browse/tournaments/:id(.*)'` (`routes.ts:370`) is only ever looked up as a literal string, so the second hop never fires. Previously shared tournament URLs are dead for real users.

**`dedupGet` cache key is order-dependent.** `src/lib/api/base.ts:219` builds the key with `JSON.stringify(config?.params)`, which depends on property insertion order — so `{a, b}` and `{b, a}` miss each other's cache entry and issue duplicate requests. Sort the keys. (The Dart port should fix this rather than reproduce it.)

**Dead code that should not be ported, and could simply be deleted:** `/join/confirm` (367 lines), `/join/status` (804 — a near-duplicate of the reachable `/guest/join/status` at 784), `/player/sessions` (250), `BaseSessionCard.old.tsx` (329), and two empty route directories `pricing-preview/` and `__pricing-preview/`. Also six **empty** files in `src/types/` (`session-new.ts`, `player.ts`, `match.ts`, `court.ts`, `common.ts`, `index.ts`) from an abandoned refactor — the real domain model is `src/lib/api/types.ts`.

**Unused dependencies:** `next-auth`, `bcryptjs`, `jsonwebtoken` have zero imports in `src/`. Both `dayjs` and `date-fns` are present and redundant.

---

## 7. Testing posture — and a correction

**There is no E2E suite.** The `e2e/` directory exists but is **empty** (it contains only an empty `.auth/` subdirectory), and Playwright is **not** in `package.json`. An early assumption that a Playwright suite existed to port was wrong. `patrol` will be the product's first E2E suite.

**Existing tests: 10 files, 1,333 lines**, all covering pure algorithms:

| Lines | File |
|---|---|
| 264 | `src/utils/standings.test.ts` |
| 219 | `src/utils/auto-assign.test.ts` |
| 148 | `src/components/venue/pricing/pricing-utils.test.ts` |
| 147 | `src/utils/round-robin.test.ts` |
| 110 | `src/components/venue-rental/schedule-validation.test.ts` |
| 98 | `src/utils/match-repeat-warning.test.ts` |
| 98 | `src/components/club/club-venue-schedule.test.ts` |
| 95 | `src/utils/session-player-ranking.test.js` |
| 85 | `src/components/tournament/manage/panels/resultsRealtime.test.js` |
| 69 | `src/lib/tournament/teamRoster.test.ts` |

**Only 3 of these 10 have an npm script** (`test:ranking`, `test:venue-pricing`, `test:venue-schedule`). The other 7 have no runner and therefore never execute in CI. Wiring all 10 into CI is worth doing in this repo immediately, independent of the port.

**The five highest-value algorithms have no tests at all:** `src/lib/scoring/rally.ts` (260 — the rally scoring engine, with a GROUP→KNOCKOUT→FINAL rules cascade), `src/utils/schedule-generator.ts` (296 — greedy court×slot scheduler), `src/lib/tournament/bracketSlots.ts` (217), `src/lib/tournament/podium.ts` (222), and `src/utils/match-result-utils.ts` (276). For these, the port must **create the oracle**: drive the existing TypeScript with generated and real inputs, dump input/output pairs to a committed `fixtures/` directory, then assert the Dart port reproduces them exactly — and finally refactor the JS tests to read the same fixtures so the two implementations cannot drift silently.

Porting roughly 2,900 lines of pure logic to Dart **before writing the first screen** is the cheapest correctness insurance available in this project.

---

## 8. Roadmap summary

Full detail, exit criteria, package list, and risk register live in `~/.claude/plans/t-i-mu-n-clone-web-ticklish-meteor.md`.

| Phase | Content | Weight |
|---|---|---|
| **P0-A** | Foundation: dio client + interceptors, auth, sockets, go_router, ARB pipeline, FCM, CI | L |
| **P0-B** | *Parallel.* Port ~2,900 lines of pure algorithms to Dart + correctness harness | M |
| **P1** | **Store release 1.0** — join funnel + live court view + voice court-call + push | L |
| **P2** | Player lifecycle: full browse/filters, session detail tabs, fees, notifications, profile | L |
| **P3** | Host session management: create/run sessions, courts, roster, fees, payment ledger | XL |
| **P4** | Social: clubs, newsfeed, profiles, ratings, maps, share images | L |
| **P5** | Tournament viewing + referee scoring (read-only bracket first) | L |
| **P6** | Tournament management — contains `manage/` at 29,917 lines, the most expensive area | XL |
| **P7** | Venues + court rental | L |
| **P8** | Polish: AI assistant, product tour, accessibility, performance, ASO | M |

Weights are single-developer-equivalent: **S** ≤1 week · **M** 2–4 · **L** 5–8 · **XL** 9+. Total ≈ **60 developer-weeks**, roughly 7–8 calendar months with two Flutter developers plus part-time backend. Treat as ±30%.

**Two sequencing decisions worth preserving:** P5 (tournament viewing and refereeing) deliberately precedes P6 (tournament management), because a read-only bracket de-risks the hardest custom widget before drag-reseeding is attempted, and phone-based referee scoring delivers far more value per line of code. P6 is last because `src/components/tournament/manage/` is the single most expensive area in the repository.

**Hard rule for every phase:** any React component over roughly 600 lines gets **redesigned for mobile, not transliterated**. Named offenders: `RoundsPanel` (2,159 — the largest file in the repo), `PublicTournamentStandingsTab` (1,738), `VenueDetailClient` (1,725), `TournamentHomeTab` (1,656), `BaseSessionCard` (1,482), `ScoreEntryBoard` (1,345), `FindSessionList` (1,239), `SetupPoolsModal` (1,219), `NotificationBell` (1,204).

---

## 9. Top risks

1. **Bracket rendering** — `react-tournament-brackets` has no Flutter equivalent; 7 components / ~4,000 lines. Build from scratch with `CustomPaint` connectors inside an `InteractiveViewer`; **budget 2×**; ship read-only before drag-reseeding.
2. **iOS TTS when backgrounded or locked** — TTS cannot run from a background push on iOS. Product decision required: voice is foreground-only, and locked-device court calls use a time-sensitive push with a custom sound. The `com.apple.developer.usernotifications.time-sensitive` entitlement must be requested in P0.
3. **App Store rejection** — Apple Sign-In (4.8), in-app account deletion (5.1.1(v)), and no forced registration for browsing (5.1.1(i)) must all ship in **P1**. Discovering any of these at review costs a rejection cycle. Both of the first two require new backend work (§4).
4. **Missed socket events across app lifecycle** — iOS kills sockets on background. Every socket handler must be an idempotent state patch, and every screen must be rebuildable from a single REST call, with a forced refetch on resume.
5. **Offline expectations** — users are in gyms with poor wifi. Version 1 ships a read cache with a staleness banner and fail-fast mutations, with **no generic write queue**; referee scoring is the single exception, justified because the protocol already carries `clientId` and `seq`.
6. **Two frontends drifting on business rules** — mitigated by making `fixtures/` the shared contract: both the JS and Dart test suites read the same corpus in CI, so any rule change must update fixtures and thereby move both languages together. This is the most effective single mitigation identified.

---

## 10. Immediate next steps

Two tracks, independent and parallelizable:

**Track A — local environment (blocking all Flutter work):** install full Xcode from the App Store first (longest lead time), then the Flutter SDK, CocoaPods, and Android Studio.

**Track B — backend P0 (unblocked, can start now, in `vmito-be`):**
1. Enable the Swagger CLI plugin in `nest-cli.json` — **do this before any codegen run.**
2. Add a script that exports `openapi.json`, and wire it into CI in a non-production environment.
3. Design and implement `DELETE /users/me` with cascade handling.
4. Implement the Apple Sign-In strategy and `POST /auth/apple`.
5. Add `POST /notifications/devices` and `DELETE /notifications/devices/:token` to the existing notifications module.
6. Normalize `/auth/refresh` and `/auth/register` to the `{success, data}` envelope. (The Dart client should sniff for the `success` key rather than allowlist URLs, so this needs no coordinated app release.)

**Track C — this repo, optional but cheap:** fix the two routing defects and the `dedupGet` cache key from §6, wire the 7 orphaned test files into CI, and delete the dead code and unused dependencies.

Also worth filing early because it needs a web deploy cycle: serve `apple-app-site-association` and `assetlinks.json` from vmito.com for universal/app links.
