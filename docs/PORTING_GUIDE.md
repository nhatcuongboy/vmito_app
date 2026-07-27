# Porting guide: vmito-fe → vmito_app

How each web concept maps to Flutter. Read this before porting a screen.

## Concept map

| Web (vmito-fe) | Flutter (vmito_app) |
|---|---|
| Next.js App Router page | `GoRoute` + screen widget |
| `[locale]` route segment | app state; no URL segment. `AppRoutes.stripLocale` for deep links |
| Zustand store | Riverpod `Notifier` in `application/` |
| React context | Riverpod `Provider` |
| axios instance + interceptors | `ApiClient` + dio interceptors |
| `src/lib/api/*.service.ts` | `features/*/data/*_service.dart`, same class name |
| TypeScript interface | freezed model in `domain/` |
| `next-intl` + JSON messages | ARB + `gen_l10n` |
| Chakra UI component | Material widget + `core/widgets/` atom |
| Tailwind class | `AppSpacing` / `AppColors` / theme |
| `localStorage` (`auth-storage`) | `flutter_secure_storage` |
| `socket.io-client` | `socket_io_client` via `SocketClient` |
| `browser-image-compression` | `flutter_image_compress` |
| browser `Notification` | `flutter_local_notifications` + FCM |
| `speechSynthesis` | `flutter_tts` |
| `react-hook-form` + zod | `Form` + `TextFormField` validators |
| `react-tournament-brackets` | custom `CustomPaint` inside `InteractiveViewer` |

## Porting a screen: the order that works

1. **Read the web page** and every component it renders. Note which data it
   loads and from which service.
2. **Port the models first.** freezed + `json_serializable`, from
   `vmito-fe/src/lib/api/types.ts`. Run `build_runner`.
3. **Port the service.** Same class name as the web file. Only the methods this
   screen needs.
4. **Write the controller.** Owns loading/error/data. No UI.
5. **Then the screen.** If it exceeds 300 lines, split before continuing.
6. **Localise as you go.** Retrofitting ARB keys is far more work.

## Things that look portable and are not

### `src/components/ui/` — do not port

12,431 lines of Chakra wrappers. It has no Flutter counterpart: Material plus
roughly 20 shared atoms in `core/widgets/` replaces all of it. This is the
single largest deletion in the port.

### Anything over ~600 lines — redesign, do not transliterate

A 1,700-line web tab is a desktop layout. Rebuilt line-by-line it produces an
unusable phone screen and an unmaintainable file. Decide the mobile
information architecture first, then build to that.

### Admin, OBS overlays, projector scoreboard, SEO pages — out of scope

16 admin pages of table CRUD, the OBS overlays, the showcase/scoreboard
screens, and the SEO landing pages stay on web. Roughly 25% of the work, with
no loss of end-user value: admin table CRUD on a phone is worse UX than the
web version.

Scope is ~66 native screens, not the 95 `page.tsx` files in the repo.

### Dead web code — do not port

`/join/confirm` (367 lines), `/join/status` (804 — a near-duplicate of the
reachable `/guest/join/status`), `/player/sessions` (250),
`BaseSessionCard.old.tsx` (329), and the empty files in `src/types/`. The real
domain model is `src/lib/api/types.ts`.

## Known web defects — fix, don't reproduce

Found during the assessment. The Dart port should be correct even where the
web app is not:

1. **`dedupGet` cache key is order-dependent** (`base.ts:219` uses
   `JSON.stringify(params)`). Already fixed here: `ApiClient._dedupKey` sorts
   keys.
2. **`/tournaments` self-redirects** — `ROUTE_REDIRECTS['/tournaments']`
   resolves to `'/tournaments'`, so the middleware 302s to itself.
3. **Shared tournament links 404** — `/tournaments/[id]` redirects to
   `/browse/tournaments/[id]`, which has no page file.

(2) and (3) are web routing bugs; they affect which deep links the app can
expect to work from shared URLs.

## The hard widgets

### BadmintonCourt

`src/components/court/BadmintonCourt.tsx` (767 lines) plus `CourtPlayer.tsx`
(363) and `PlayerTooltip.tsx` (328).

Verified properties:

- aspect ratio `13.4 / 6.1` (`BadmintonCourt.tsx:66`), available as
  `AppSizes.courtAspectRatio`;
- three modes: `manage | view | selection`;
- two `CourtDirection` values: `HORIZONTAL` / `VERTICAL`.

**Direction must be a coordinate transform, not two widget trees.** Two trees
means every future change is made twice and drifts.

### Tournament brackets

`react-tournament-brackets` has no Flutter equivalent — 7 components, roughly
4,000 lines. Build from scratch: `CustomPaint` connectors inside an
`InteractiveViewer`. **Budget 2×.** Ship read-only before attempting
drag-reseeding.

## Business logic to port before any screen

Roughly 2,900 lines of pure algorithms, with no tests on the web side today:

| Lines | Web file |
|---|---|
| 296 | `src/utils/schedule-generator.ts` — greedy court×slot scheduler |
| 276 | `src/utils/match-result-utils.ts` |
| 260 | `src/lib/scoring/rally.ts` — rally engine, GROUP→KNOCKOUT→FINAL cascade |
| 222 | `src/lib/tournament/podium.ts` |
| 217 | `src/lib/tournament/bracketSlots.ts` |

Porting these first, against shared fixtures, is the cheapest correctness
insurance in the project. See [TESTING.md](TESTING.md).

`src/utils/auto-assign.ts` is client-side but is used **only** for tournament
group assignment. It is *not* court matchmaking — that is server-side
(`GET /courts/{id}/suggested-players`). Confusing the two is the single most
expensive misunderstanding available in this port.
