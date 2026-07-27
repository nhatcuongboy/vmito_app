# Testing

## The problem this strategy solves

Two frontends will implement the same business rules in two languages. Without
a shared contract they drift, and the drift shows up as a scoring dispute in a
gym, not as a failing test.

The mitigation: **`fixtures/` is the contract.** Both the JS and Dart suites
read the same corpus in CI, so changing a rule requires updating fixtures,
which moves both languages together. This is the single most effective
mitigation identified in the assessment.

## Building the oracle

The five highest-value algorithms on web have **no tests at all**:

| Lines | File |
|---|---|
| 296 | `src/utils/schedule-generator.ts` |
| 276 | `src/utils/match-result-utils.ts` |
| 260 | `src/lib/scoring/rally.ts` |
| 222 | `src/lib/tournament/podium.ts` |
| 217 | `src/lib/tournament/bracketSlots.ts` |

For these, the port must create the oracle:

1. Drive the existing TypeScript with generated and real inputs.
2. Dump input/output pairs to a committed `fixtures/` directory.
3. Assert the Dart port reproduces them **exactly**.
4. Refactor the JS tests to read the same fixtures, so the two implementations
   cannot drift silently.

Porting roughly 2,900 lines of pure logic to Dart **before writing the first
screen** is the cheapest correctness insurance in this project.

## Existing web tests

10 files, 1,333 lines, all covering pure algorithms — and **only 3 have an npm
script**, so the other 7 never run in CI:

`standings.test.ts` (264), `auto-assign.test.ts` (219), `pricing-utils.test.ts`
(148), `round-robin.test.ts` (147), `schedule-validation.test.ts` (110),
`match-repeat-warning.test.ts` (98), `club-venue-schedule.test.ts` (98),
`session-player-ranking.test.js` (95), `resultsRealtime.test.js` (85),
`teamRoster.test.ts` (69).

Wiring all 10 into CI is worth doing in `vmito-fe` immediately, independent of
the port.

There is **no E2E suite** on web: `e2e/` is empty and Playwright is not in
`package.json`. `patrol` will be this product's first E2E suite.

## What to test here

| Layer | Approach |
|---|---|
| Pure logic | fixture-driven, shared with web |
| Services | mock the `Dio` adapter; assert path, params, and parsing |
| Controllers | `ProviderContainer` with overridden services (`mocktail`) |
| Screens | widget tests for loading / error / empty / loaded |
| Flows | `patrol` for join → court view → court call |

Never let a test hit the network.

## Conventions

- Mirror `lib/` in `test/`: `lib/core/network/api_client.dart` →
  `test/core/network/api_client_test.dart`.
- Test names state behaviour, not method names: *"passes a bare payload through
  unchanged"*, not *"unwrap works"*.
- A comment on a regression test says what broke. The `isPublic` test in
  `test/core/router/app_routes_test.dart` is the model: splash is `'/'`, so a
  naive `startsWith` made every route public and the auth gate never fired.

```sh
flutter test
flutter test test/core/network/
flutter test --coverage
```

## The live-backend test

`test/integration/live_backend_test.dart` drives the real `ApiClient` against a
running `vmito-be`. It is the only test that proves dio, the interceptors and
the error mapping agree with what the backend actually sends — unit tests assert
against captured payloads, which go stale.

It skips itself when nothing is listening on `localhost:3001`, so a normal
`flutter test` run never breaks.

Two constraints, both learned the hard way:

1. **Do not call `TestWidgetsFlutterBinding.ensureInitialized()` in that file.**
   The binding makes every HTTP request return 400 without touching the
   network, which silently defeats the whole point.
2. **Because there is no binding, platform channels cannot be mocked** — so
   `TokenStorage` gets `FakeSecureStorage` from `test/support/`. Without it, a
   401 on a protected endpoint reaches for the Keychain and the test hangs to
   its 30-second timeout instead of failing.

Keep `/auth/login` assertions few: the endpoint is rate-limited to 5 requests
per minute.

This test is what caught the `whenComplete` deadlock that hung every
deduplicated GET. Unit tests with a stubbed adapter now cover the same ground
(`test/core/network/api_client_test.dart`), but the live run found it first.

## The on-device test

`integration_test/sign_in_flow_test.dart` runs the real app on a real device
against a running backend. It covers the three things no VM test can reach:
**App Transport Security**, the **Keychain**, and the widget tree wired to the
live API.

```sh
flutter test integration_test/ -d <device-id> \
    --dart-define-from-file=env/dev.json
```

Verified on an iOS 26.3 simulator:

- **ATS does not block `http://localhost`.** iOS exempts it, so `env/dev.json`
  works untouched and `ios/Runner/Info.plist` needs no exception. A non-loopback
  cleartext host (a LAN IP for a physical device) *would* need
  `NSAllowsLocalNetworking`.
- **Keychain reads work, and Keychain items outlive app deletion.** A stale
  token from an earlier install was picked up by `restoreSession`, `/users/me`
  answered `404 User not found`, and the app correctly cleared it and routed to
  sign-in. Do not assume a fresh install means a fresh token.

It also caught a double-submit: `onFieldSubmitted` had no `_isSubmitting`
guard, so tapping the button and pressing the keyboard's "done" in the same
frame sent two logins against a 5-per-minute limit.
