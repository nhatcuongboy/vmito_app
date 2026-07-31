# Release Guide — App Store & Google Play

How to take `vmito_app` from this repo to a build that is accepted on the App
Store and Google Play.

The repo is currently at the **default Flutter template state** for everything
release-related: template bundle identifiers, debug signing keys, default
launcher icons, and no release permissions. Nothing here is optional polish —
each item below is either a build failure, a runtime failure, or a review
rejection.

Read [§1](#1-blockers-in-the-current-repo) first. It is the list of things that
are wrong *today*, with file references. The rest of the document is the
procedure.

---

## Contents

1. [Blockers in the current repo](#1-blockers-in-the-current-repo)
2. [App identity](#2-app-identity)
3. [Android platform configuration](#3-android-platform-configuration)
4. [iOS platform configuration](#4-ios-platform-configuration)
5. [Signing](#5-signing)
6. [Versioning](#6-versioning)
7. [Build commands](#7-build-commands)
8. [Google Play Console setup](#8-google-play-console-setup)
9. [App Store Connect setup](#9-app-store-connect-setup)
10. [Policy compliance](#10-policy-compliance)
11. [Pre-submission checklist](#11-pre-submission-checklist)
12. [Post-submission](#12-post-submission)
13. [CI (optional, later)](#13-ci-optional-later)

---

## 1. Blockers in the current repo

| # | Problem | Where | Consequence |
|---|---|---|---|
| 1 | `applicationId = "com.example.vmito_app"` | [android/app/build.gradle.kts:19](../android/app/build.gradle.kts#L19) | Play rejects `com.example.*`. Cannot be changed after first upload. |
| 2 | `PRODUCT_BUNDLE_IDENTIFIER = com.example.vmitoApp` | [ios/Runner.xcodeproj/project.pbxproj:476](../ios/Runner.xcodeproj/project.pbxproj#L476) | Cannot register the App ID on Apple Developer. |
| 3 | Release build signed with the **debug** keystore | [android/app/build.gradle.kts:29-33](../android/app/build.gradle.kts#L29-L33) | Play refuses the upload. |
| 4 | `INTERNET` permission exists only in the debug manifest | [android/app/src/debug/AndroidManifest.xml](../android/app/src/debug/AndroidManifest.xml) | **Release APK/AAB has no network access.** Every API call fails on the store build only. |
| 5 | No iOS usage-description strings | [ios/Runner/Info.plist](../ios/Runner/Info.plist) | App **crashes** the first time `image_picker` / `mobile_scanner` opens. Automatic review rejection. |
| 6 | Google/Facebook OAuth callback not wired | Auth feature | done — `flutter_web_auth_2` captures the existing HTTPS web callback. |
| 7 | No `POST_NOTIFICATIONS` permission, no core-library desugaring | android/app | `flutter_local_notifications` 22 fails to build (desugaring) and is silently muted on Android 13+. |
| 8 | Default Flutter launcher icons and launch screen | `android/app/src/main/res/mipmap-*`, `ios/Runner/Assets.xcassets` | Apple rejects placeholder assets (4.3 / 2.3.8). |
| 9 | `android:label="vmito_app"`, `CFBundleName = vmito_app` | AndroidManifest.xml, Info.plist | Home-screen name shows the package slug. |
| 10 | **Sign in with Apple missing** while Google/Facebook login ships | product decision, [ROADMAP.md](ROADMAP.md#deferred-app-store-requirements) | Guideline 4.8 — guaranteed rejection. |
| 11 | **In-app account deletion missing** | product decision, [ROADMAP.md](ROADMAP.md#deferred-app-store-requirements) | Guideline 5.1.1(v) **and** Google Play's data-deletion policy. Guaranteed rejection on both stores. |

Items 10 and 11 are the only ones that need work outside this repo — they need
`vmito-be` endpoints (`POST /auth/apple`, `DELETE /users/me`). They are marked
"deferred by product direction" in the roadmap; that deferral is a decision to
**not ship to the App Store yet**, not a decision to ship without them.

---

## 2. App identity

Decide these once. Both identifiers are permanent after the first store upload.

| Field | Value to use |
|---|---|
| Android `applicationId` / `namespace` | `com.vmito.app` |
| iOS bundle identifier | `com.vmito.app` |
| Display name (both) | `Vmito` |

Use the same reverse-DNS id on both platforms; it keeps deep links, Firebase
projects, and analytics aligned.

### Android

```kotlin
// android/app/build.gradle.kts
android {
    namespace = "com.vmito.app"
    defaultConfig {
        applicationId = "com.vmito.app"
    }
}
```

The Kotlin package under `android/app/src/main/kotlin/` may stay at its current
path — `namespace` is what matters — but renaming the directory to
`com/vmito/app/` and updating the `package` line in `MainActivity.kt` keeps
things readable.

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application android:label="Vmito" ...>
```

### iOS

Change the bundle identifier in Xcode (Runner target → Signing & Capabilities),
not by hand-editing `project.pbxproj` — there are six occurrences and two of
them belong to `RunnerTests`.

```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleDisplayName</key><string>Vmito</string>
<key>CFBundleName</key><string>Vmito</string>
```

### Icons and launch screen

```sh
# add flutter_launcher_icons to dev_dependencies, then:
dart run flutter_launcher_icons
```

Requirements: a 1024×1024 PNG **with no alpha channel and no rounded corners**
for iOS (Apple rejects transparency), and an adaptive icon (foreground +
background layers) for Android. Replace the default Flutter launch screen in
`ios/Runner/Assets.xcassets/LaunchImage.imageset` and
`android/app/src/main/res/drawable*/launch_background.xml` with the Vmito mark
on `AppColors` background.

---

## 3. Android platform configuration

### 3.1 Permissions

Flutter's template puts `INTERNET` in the debug and profile manifests only.
Add it to the main manifest, along with the notification permission:

```xml
<!-- android/app/src/main/AndroidManifest.xml — above <application> -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

`mobile_scanner` and `image_picker` merge their own `CAMERA` and media
permissions; do not declare them again. After building, verify the final merged
set — an unexplained permission is a Play data-safety mismatch:

```sh
flutter build apk --release --dart-define-from-file=env/production.json
$ANDROID_HOME/build-tools/<ver>/aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk
```

### 3.2 OAuth callback

Google/Facebook reuse the backend's HTTPS `/{locale}/auth/callback` contract.
`flutter_web_auth_2` 5 captures the exact host and path through the browser's
authentication-tab result, so no custom Android callback activity is needed.

### 3.3 Core library desugaring

`flutter_local_notifications` ≥ 18 requires it; without it the Gradle build
fails outright.

```kotlin
// android/app/build.gradle.kts
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### 3.4 API levels

`minSdk`, `targetSdk` and `compileSdk` currently inherit from the Flutter SDK
(`flutter.targetSdkVersion`). Play enforces a rolling target-API requirement —
new apps and updates must target within one year of the latest Android release,
with the deadline falling each August. **Check the current requirement in the
Play Console** (Policy → App integrity) before every release; if the Flutter
SDK's default lags behind it, pin explicitly:

```kotlin
targetSdk = 36
compileSdk = 36
```

`minSdk` should stay at the Flutter default (21+) unless a plugin forces it
higher; `flutter_secure_storage` 10 and `mobile_scanner` 7 both want 21+.

Android 15+ devices also require **16 KB page size** support in native
libraries. Flutter 3.44 and current plugin versions comply, but confirm after
any plugin bump:

```sh
unzip -l build/app/outputs/bundle/release/app-release.aab | grep '\.so$'
# then check alignment with:
$ANDROID_HOME/cmdline-tools/latest/bin/... (or) llvm-objdump -p <lib.so> | grep LOAD
```

### 3.5 R8 / shrinking

Release builds shrink by default. Riverpod, Dio, `freezed`, and
`json_serializable` are all reflection-free, so no keep rules are needed today.
If a plugin ever needs one, put it in `android/app/proguard-rules.pro` and wire
it with `proguardFiles(...)` in the release build type — never disable
shrinking to work around a single class.

---

## 4. iOS platform configuration

### 4.1 Usage descriptions

Every one of these maps to a plugin already in `pubspec.yaml`. A missing string
is an instant crash, not a warning.

```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Vmito uses the camera to scan session QR codes and to take your profile photo.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Vmito needs access to your photos so you can set a profile or session image.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Vmito connects to the session server to keep court assignments live.</string>
```

Write them in the **user-facing tone and language of the primary market**.
Apple rejects generic strings like "This app needs camera access". Vietnamese
is the primary locale (`CFBundleLocalizations` lists `vi, en, zh`) — localize
these strings via `InfoPlist.strings` per locale if the reviewer's locale
matters.

`NSMicrophoneUsageDescription` is **not** needed: `image_picker` is used for
stills only. Adding an unused one triggers "declared but unused API" questions
at review.

### 4.2 Export compliance

The app uses only HTTPS, which is exempt. Declaring it up front skips the
manual question on every TestFlight build:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### 4.4 Device family

`Info.plist` currently declares iPad orientations, which means **App Review
will test on iPad**. Two options:

- **iPhone only** — set `TARGETED_DEVICE_FAMILY = 1` in the Runner target. The
  layouts were ported for phone; this is the honest choice for 1.0.
- **Keep iPad** — then every screen must be usable at iPad width, and
  `share_plus` calls must pass `sharePositionOrigin` or they crash on iPad.

Pick one before the first submission; switching later changes the store listing
requirements (iPad screenshots become mandatory).

### 4.5 Privacy manifest

Apple requires `PrivacyInfo.xcprivacy` for apps and SDKs using
"required-reason" APIs. Current plugin versions (`shared_preferences`,
`flutter_secure_storage`, `device_info_plus`, `package_info_plus`,
`connectivity_plus`, `path_provider`) ship their own. The app itself needs one
declaring its own data collection. Add it in Xcode (File → New → App Privacy
File) targeting Runner, and keep it consistent with the App Store privacy
labels from [§10](#10-policy-compliance).

### 4.6 Background modes

Per [REALTIME.md](REALTIME.md), voice court-calls are **foreground only** — iOS
cannot run TTS from a background push. Do **not** enable the Audio background
mode to work around it; Apple rejects background-audio entitlements used for
anything but continuous playback. Locked-device calls use a time-sensitive push
with a custom sound, which needs the **Time Sensitive Notifications**
entitlement requested in the Developer portal.

---

## 5. Signing

### 5.1 Android — upload keystore

Generate once. **Losing this file without Play App Signing enrolment means you
can never update the app.**

```sh
keytool -genkey -v \
  -keystore ~/vmito-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Store it outside the repo. Back it up somewhere that survives a laptop loss —
a password manager attachment or the team's secret store, not iCloud Drive
alone.

Create `android/key.properties` (**never committed**):

```properties
storePassword=<...>
keyPassword=<...>
keyAlias=upload
storeFile=/Users/<you>/vmito-upload-keystore.jks
```

Add to [.gitignore](../.gitignore):

```gitignore
# Release signing. Never commit.
android/key.properties
**/*.jks
**/*.keystore
ios/ExportOptions.plist
```

Wire it into Gradle:

```kotlin
// android/app/build.gradle.kts — above the `android { }` block
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

Enrol in **Play App Signing** at first upload (it is the default). Google then
holds the app signing key and your keystore is only an *upload* key — which can
be reset by support if lost.

### 5.2 iOS — certificates and profiles

Requires an **Apple Developer Program** membership (99 USD/year; the
organization type needs a D-U-N-S number and takes days to verify — start
early).

1. Register the App ID `com.vmito.app` with the capabilities the app uses:
   Push Notifications, Sign in with Apple, Associated Domains (for universal
   links), Time Sensitive Notifications.
2. In Xcode → Runner → Signing & Capabilities, set the team and let Xcode
   manage signing for development. For distribution, either keep automatic
   signing or manage an App Store distribution certificate + provisioning
   profile explicitly (needed for CI).
3. Create an **App Store Connect API key** (Users and Access → Integrations)
   for non-interactive uploads. Store the `.p8` outside the repo.

---

## 6. Versioning

One source of truth: the `version:` line in [pubspec.yaml](../pubspec.yaml),
currently `1.0.0+1`.

- `1.0.0` → Android `versionName`, iOS `CFBundleShortVersionString`. User-visible.
- `+1` → Android `versionCode`, iOS `CFBundleVersion`. **Must strictly increase
  on every upload**, including builds that never reach production. Never
  reuse a number; both stores reject it permanently.

Rules:

- Bump the build number for every upload, even a rejected one.
- Bump the patch/minor for anything users would notice.
- Keep Android and iOS on the same `version` string so support tickets are
  unambiguous.
- Tag the commit: `git tag v1.0.0+7 && git push --tags`. A store build must be
  reproducible from a tag.

Override at build time when needed: `--build-name=1.0.1 --build-number=8`.

---

## 7. Build commands

Always with `env/production.json` — a store build pointed at staging is the
single easiest catastrophic mistake here.

### Pre-flight

```sh
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
dart format .
flutter analyze                 # must be clean
flutter test                    # unit + widget
(cd packages/vmito_domain && dart test)
```

### Android App Bundle

```sh
flutter build appbundle \
  --release \
  --dart-define-from-file=env/production.json \
  --obfuscate \
  --split-debug-info=build/symbols/android/1.0.0+1
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

Test the exact artifact before uploading — `flutter run --release` is not the
same binary:

```sh
# Install the AAB the way Play will deliver it
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=/tmp/vmito.apks --connected-device \
  --ks=~/vmito-upload-keystore.jks --ks-key-alias=upload
bundletool install-apks --apks=/tmp/vmito.apks
```

### iOS

```sh
flutter build ipa \
  --release \
  --dart-define-from-file=env/production.json \
  --obfuscate \
  --split-debug-info=build/symbols/ios/1.0.0+1 \
  --export-method app-store
```

Output: `build/ios/ipa/*.ipa`. Upload with **Transporter.app**, or:

```sh
xcrun altool --upload-app -f build/ios/ipa/vmito_app.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

### About `--obfuscate`

It strips Dart symbols, so crash reports arrive unreadable. The
`--split-debug-info` directory is the only way back. **Archive it per build
number** alongside the tag — a symbol file that does not match the exact build
is useless. If Crashlytics/Sentry is added later, upload the symbols there as
part of the release step.

---

## 8. Google Play Console setup

One-time (25 USD, permanent):

1. Create the developer account. **If it is a personal account created after
   Nov 2023, production access requires a closed test with at least 12 testers
   opted in for 14 continuous days.** Plan two extra weeks into the schedule,
   or register as an organization (needs a D-U-N-S number) to skip it.
2. Complete identity verification and the payments profile.

Per app:

1. **Create app** → name `Vmito`, default language Vietnamese, category
   *Sports* or *Health & Fitness*, free.
2. **App content** — every section must be green before production:
   - Privacy policy URL (must be publicly reachable, e.g.
     `https://vmito.com/privacy`).
   - **Data safety** form. Declare accurately, matching what the app really
     sends: account identifiers, name/email, photos, and any device/crash data.
     Every collected type needs a stated purpose, whether it is encrypted in
     transit (yes — HTTPS), and whether users can request deletion. This form
     must agree with the iOS privacy labels; discrepancies get flagged.
   - **Account deletion** — Play requires both an in-app path *and* a
     publicly reachable web URL to request deletion for any app that lets users
     create an account. Currently missing (blocker #11).
   - Ads declaration (none), content rating questionnaire, target audience
     (not children), news app (no), COVID/health (no), government app (no).
   - Financial features: the app records **manual bank-transfer and cash
     ledgers with no payment gateway** — declare it as no in-app payment
     processing. Do not describe it as a payments feature.
3. **Store listing**: short description (80 chars), full description (4000),
   feature graphic 1024×500, app icon 512×512, and ≥ 2 phone screenshots
   (16:9 or 9:16, 1080p+). Localize into `vi`, `en`, `zh` to match the app's
   ARB locales.
4. **Release tracks**: internal → closed → production. Never upload straight
   to production for a first release.

---

## 9. App Store Connect setup

1. Create the app record: bundle ID `com.vmito.app`, SKU (any stable string,
   e.g. `vmito-app-001`), primary language Vietnamese.
2. **App Privacy** labels — same data as the Play data-safety form, expressed
   as Apple's categories, and consistent with `PrivacyInfo.xcprivacy`.
3. **Screenshots**: 6.9" iPhone and 6.5" iPhone are mandatory; iPad sizes too
   if the app supports iPad (see [§4.4](#44-device-family)).
4. **App Review Information** — the part most first submissions get wrong:
   - A working **demo account** (email + password) on the **production**
     backend. A reviewer who cannot get past the login screen rejects in hours.
   - Notes explaining that the app is a badminton session/tournament companion,
     that money handling is a **manual bank-transfer ledger with no payment
     processing**, and how to reach a live session (a pre-seeded session with a
     join code the reviewer can use, listed in the notes).
   - Contact phone and email that someone actually reads.
5. **TestFlight** the build internally first. Internal testers need no review;
   external groups do.

---

## 10. Policy compliance

The four rules that decide whether Vmito passes review:

### Sign in with Apple — Guideline 4.8

Mandatory because Google and Facebook login are offered. Needs
`POST /auth/apple` in `vmito-be` plus the `sign_in_with_apple` plugin and the
capability on the App ID. **Currently deferred** — this alone blocks the App
Store.

### Account deletion — Guideline 5.1.1(v) + Play data-deletion policy

Any app that creates accounts must let users delete them **from inside the
app**, not by emailing support. Needs `DELETE /users/me` with cascade handling
across player records, payment history, and club membership. Play additionally
wants a public web URL. **Currently deferred** — blocks both stores.

### No forced registration for browsing — 5.1.1(i)

Already satisfied: `AppRoutes.publicPaths` keeps browsing open, and guest
sessions work by join code.

### Data accuracy

The Play data-safety form, Apple privacy labels, and `PrivacyInfo.xcprivacy`
are three descriptions of the same thing. Fill the first one carefully and copy
it, rather than answering each from scratch.

### Known runtime gaps to weigh before submitting

- **Guest sessions do not survive a restart**
  ([ROADMAP.md](ROADMAP.md#known-gap-guest-sessions-do-not-survive-a-restart)).
  A reviewer who joins as a guest, backgrounds the app, and returns to a lost
  session will read that as a bug. Fix it, or make sure the review notes use a
  signed-in demo account only.
- **Push notifications** need `firebase_core` / `firebase_messaging` (still
  commented out in `pubspec.yaml`) plus `google-services.json` and
  `GoogleService-Info.plist`, which are gitignored by design. If the store
  listing mentions notifications, they must work.

---

## 11. Pre-submission checklist

Run through this for every store release.

**Configuration**

- [ ] `applicationId` / bundle identifier is not `com.example.*`
- [ ] Version bumped; build number strictly higher than every previous upload
- [ ] Built with `--dart-define-from-file=env/production.json`
- [ ] App points at the production API — confirmed on-device, not by reading JSON
- [ ] `flutter analyze` clean, `flutter test` green, domain tests green

**Android**

- [ ] `INTERNET` in the **main** manifest
- [ ] Release signing config wired; `key.properties` present and gitignored
- [ ] Desugaring enabled; release build succeeds
- [ ] `targetSdk` meets Play's current requirement
- [ ] AAB installed via `bundletool` on a real device and exercised

**iOS**

- [ ] All usage-description strings present and specific
- [ ] `CFBundleURLTypes` registered; social login round-trips on a device
- [ ] `ITSAppUsesNonExemptEncryption` set
- [ ] Device family decided; iPad layouts verified if iPad is supported
- [ ] Privacy manifest present and consistent with the labels
- [ ] TestFlight build installed and exercised on a physical device

**Both**

- [ ] Real launcher icon and launch screen — no Flutter default anywhere
- [ ] Display name reads `Vmito`
- [ ] No debug banner, no logs leaking tokens (`AppLogger` muted in production)
- [ ] Social login, QR scan, image upload, notifications, and voice court-call
      all verified on the **release** build, on a physical device
- [ ] Deep links open the right screen from a cold start
- [ ] Locales `vi` / `en` / `zh` all render without overflow
- [ ] Symbols archived at `build/symbols/<platform>/<version>`
- [ ] Commit tagged

---

## 12. Post-submission

- **Play**: review usually takes hours to a few days; a first submission from a
  new account takes longer. Use staged rollout (10% → 50% → 100%) for the first
  production release and watch Android vitals (ANR + crash rate) between steps.
- **Apple**: typically 24–48 hours. A rejection arrives in Resolution Center —
  reply there rather than resubmitting silently; a reply resolves most metadata
  rejections without a new build.
- Keep the upload keystore, the `.p8` API key, and the symbol archives together
  in the team's secret store. Losing the keystore without Play App Signing ends
  the app's update path.

---

## 13. CI (optional, later)

Worth adding once the manual path has succeeded at least once — automating a
process you have never completed by hand only hides where it breaks.

- **Fastlane** (`ios/fastlane`, `android/fastlane`) for `pilot` (TestFlight)
  and `supply` (Play track uploads).
- Secrets: keystore base64, `key.properties` values, the App Store Connect
  `.p8`, and the issuer/key IDs — as CI secrets, never in the repo.
- Trigger on tags matching `v*`, so a release is always reproducible from a
  tag.
- iOS builds need a macOS runner.

---

## Related

| Doc | What it answers |
|---|---|
| [ROADMAP.md](ROADMAP.md) | What ships when; the deferred store requirements |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Flavors, bootstrap, config |
| [REALTIME.md](REALTIME.md) | Why voice court-call is foreground-only on iOS |
| [API_INTEGRATION.md](API_INTEGRATION.md) | Envelope, auth, uploads |
