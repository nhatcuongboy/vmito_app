# vmito_app

Flutter mobile client (iOS + Android) for **Vmito**, a badminton session and
tournament platform.

This is a port of the web frontend (`vmito-fe`) against the same NestJS backend
(`vmito-be`). The backend is shared and unchanged.

## Setup

```sh
flutter pub get
dart run build_runner build     # freezed / json_serializable models
flutter gen-l10n                # localizations from lib/l10n/*.arb
```

Both generated outputs are git-ignored, so run them after a fresh clone and
after touching any model or ARB file.

## Running

Configuration is compile-time via `--dart-define-from-file`. There is no `.env`.

```sh
flutter run --dart-define-from-file=env/dev.json          # iOS sim / device
flutter run --dart-define-from-file=env/dev.android.json  # Android emulator
flutter run --dart-define-from-file=env/staging.json      # staging API
```

`env/dev.json` points at `http://localhost:3001/api`, so `vmito-be` must be
running. Android emulators reach the host at `10.0.2.2` — hence the separate
file.

## Checks

```sh
flutter analyze     # must be clean
flutter test
dart format .
```

## Documentation

Start with [CLAUDE.md](CLAUDE.md) — conventions, non-negotiables, and file size
rules. Then:

| Doc | What it answers |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, dependency rules, bootstrap |
| [docs/PORTING_GUIDE.md](docs/PORTING_GUIDE.md) | Web → Flutter mapping, per concept |
| [docs/API_INTEGRATION.md](docs/API_INTEGRATION.md) | Envelope, auth, errors, uploads |
| [docs/STATE_MANAGEMENT.md](docs/STATE_MANAGEMENT.md) | Zustand → Riverpod |
| [docs/REALTIME.md](docs/REALTIME.md) | Sockets, lifecycle, the court call |
| [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | Tokens, theming, shared widgets |
| [docs/I18N.md](docs/I18N.md) | ARB pipeline, locale codes |
| [docs/TESTING.md](docs/TESTING.md) | Fixture oracle strategy |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Phases P0–P8 |
| [FLUTTER_PORT_ASSESSMENT.md](FLUTTER_PORT_ASSESSMENT.md) | The measured assessment behind the plan |

## Stack

Riverpod 3 · dio · go_router · freezed + json_serializable ·
socket_io_client · flutter_secure_storage · gen_l10n (vi/en/zh)
