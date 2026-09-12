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

### Google Maps keys

Google Maps uses native SDK keys, so these two values are configured outside
`--dart-define-from-file` and are never committed:

- Android: add `MAPS_API_KEY=...` to `android/local.properties`.
- iOS: copy `ios/Flutter/GoogleMaps.xcconfig.example` to
  `ios/Flutter/GoogleMaps.xcconfig`, then replace the sample value.

Enable **Maps SDK for Android** and **Maps SDK for iOS** in Google Cloud. Use
separate keys restricted to Android package `com.vmito.app` (plus signing
certificate SHA-1) and iOS bundle id `com.vmito.app`.

Address autocomplete uses the native Places SDK. Enable **Places API (New)**
and create another pair of platform-restricted keys:

- Android Places key: Android restriction for `com.vmito.app` plus every
  signing SHA-1 used to distribute that build.
- iOS Places key: iOS restriction for bundle id `com.vmito.app`.

Copy the matching example to a git-ignored local file and insert only that
platform's key:

```sh
cp env/production.android.example.json env/production.android.local.json
cp env/production.ios.example.json env/production.ios.local.json
```

Do not put both Places keys in one define file. Each APK/IPA must contain only
the key restricted to that operating system. The Vmito backend does not own a
Google Places credential or expose a Places proxy.

The maintained native Places dependency currently requires iOS 16 or later;
the Runner deployment target is therefore 16.0.

## Running

Configuration is compile-time via `--dart-define-from-file`. There is no `.env`.

```sh
flutter run --dart-define-from-file=env/dev.json          # iOS sim / device
flutter run --dart-define-from-file=env/dev.android.json  # Android emulator
flutter run --dart-define-from-file=env/staging.json      # staging API

flutter build apk --release \
  --dart-define-from-file=env/production.android.local.json
flutter build ipa --release \
  --dart-define-from-file=env/production.ios.local.json
```

`env/dev.json` targets the staging API. `env/dev.android.json` targets a
backend running on the host machine; Android emulators reach it at
`10.0.2.2`.

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
