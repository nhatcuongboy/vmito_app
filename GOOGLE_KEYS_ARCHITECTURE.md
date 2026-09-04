# 🏗️ Google API Keys Architecture

## 📊 Tổng quan

App Vmito cần **2 loại API keys riêng biệt** vì sử dụng 2 dịch vụ khác nhau của Google:

```
┌─────────────────────────────────────────────────────────────┐
│                     VMITO MOBILE APP                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────┐      ┌─────────────────────────┐  │
│  │  🗺️ Hiển thị bản đồ │      │  🔍 Tìm kiếm địa chỉ   │  │
│  │                      │      │                          │  │
│  │  Feature: Map View   │      │  Feature: Autocomplete  │  │
│  │  ├─ Browse sessions  │      │  ├─ Create session     │  │
│  │  ├─ Browse venues    │      │  ├─ Create tournament  │  │
│  │  └─ Browse clubs     │      │  └─ Post composer      │  │
│  └──────────┬───────────┘      └────────────┬────────────┘  │
│             │                                │                │
│             ▼                                ▼                │
│  ┌─────────────────────┐      ┌─────────────────────────┐  │
│  │  google_maps_flutter│      │  GooglePlacesService    │  │
│  │  (Native SDK)       │      │  (HTTP API Client)      │  │
│  └──────────┬───────────┘      └────────────┬────────────┘  │
│             │                                │                │
└─────────────┼────────────────────────────────┼────────────────┘
              │                                │
              │                                │
        ┌─────▼──────────┐            ┌───────▼────────┐
        │  Maps SDK Key  │            │ Places API Key │
        └─────┬──────────┘            └───────┬────────┘
              │                                │
              │                                │
┌─────────────▼────────────────────────────────▼─────────────┐
│              GOOGLE CLOUD PLATFORM                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────┐   ┌──────────────────────────┐ │
│  │  Maps SDK for Android  │   │  Places API (New)        │ │
│  │  Maps SDK for iOS      │   │                          │ │
│  └────────────────────────┘   └──────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔑 Key Configuration Matrix

| Aspect | Maps SDK Key | Places API Key |
|--------|--------------|----------------|
| **Mục đích** | Hiển thị bản đồ Google Maps | Autocomplete địa chỉ |
| **Loại** | Native SDK | HTTP REST API |
| **Platform** | iOS + Android | Cross-platform |
| **Config file (iOS)** | `ios/Flutter/GoogleMaps.xcconfig` | - |
| **Config file (Android)** | `android/local.properties` | - |
| **Config file (Dart)** | - | `env/*.json` |
| **Dart variable** | - | `AppConfig.googlePlacesApiKey` |
| **APIs enabled** | • Maps SDK for Android<br>• Maps SDK for iOS | • Places API (New) ONLY |
| **Git status** | ❌ Gitignored | ⚠️ Có thể commit (với restrictions) |

---

## 🔒 Security Model

### Application Restrictions (Cả 2 keys)

```
┌─────────────────────────────────────────┐
│  Application Restrictions               │
├─────────────────────────────────────────┤
│                                          │
│  ✅ Android apps:                       │
│     • Package name: com.vmito.app       │
│     • SHA-1: [từ keystore]              │
│                                          │
│  ✅ iOS apps:                           │
│     • Bundle ID: com.vmito.app          │
│                                          │
└─────────────────────────────────────────┘
```

### API Restrictions (Khác nhau!)

```
┌──────────────────────┐     ┌──────────────────────┐
│  Maps SDK Key        │     │  Places API Key      │
├──────────────────────┤     ├──────────────────────┤
│                      │     │                      │
│  API Restrictions:   │     │  API Restrictions:   │
│  ✅ Maps SDK Android│     │  ✅ Places API (New)│
│  ✅ Maps SDK iOS    │     │  ❌ Maps SDK        │
│  ❌ Places API      │     │  ❌ Other APIs      │
│  ❌ Other APIs      │     │                      │
│                      │     │                      │
└──────────────────────┘     └──────────────────────┘
```

---

## 📁 File Flow

### Maps SDK Key Flow

```
Google Cloud Console
        │
        │ Create "Maps SDK Key"
        │ with restrictions
        │
        ▼
    Copy key
        │
        ├────────────────────────┬─────────────────────────┐
        │                        │                         │
        ▼                        ▼                         ▼
  iOS Config              Android Config           (Not used in Dart)
        │                        │
ios/Flutter/              android/
GoogleMaps.xcconfig       local.properties
        │                        │
GOOGLE_MAPS_API_KEY=...   MAPS_API_KEY=...
        │                        │
        ▼                        ▼
  Native iOS SDK          Native Android SDK
        │                        │
        └────────────┬───────────┘
                     │
                     ▼
            Google Maps Display
            ✅ Map tiles rendered
```

### Places API Key Flow

```
Google Cloud Console
        │
        │ Create "Places API Key"
        │ with restrictions
        │
        ▼
    Copy key
        │
        ├─────────────────────────┬──────────────────────┐
        │                         │                      │
        ▼                         ▼                      ▼
env/production.json    env/production.local.json   env/staging.json
        │                         │                      │
        │  "GOOGLE_PLACES_API_KEY": "AIza..."          │
        │                         │                      │
        └─────────────┬───────────┴──────────────────────┘
                      │
                      ▼
            Build time compilation
            (--dart-define-from-file)
                      │
                      ▼
        AppConfig.googlePlacesApiKey
            (String.fromEnvironment)
                      │
                      ▼
            GooglePlacesService
            (HTTP client with key in header)
                      │
                      ▼
        POST https://places.googleapis.com/v1/places:autocomplete
        Header: X-Goog-Api-Key: AIza...
                      │
                      ▼
            Autocomplete Results
            ✅ Suggestions displayed
```

---

## 🔄 Data Flow Examples

### Example 1: User nhấn nút "Bản đồ" trong trang "Tìm kèo"

```
User Action: Tap "Map View" button
    │
    ▼
Flutter: BrowseSessionsContent → SessionMapView
    │
    ▼
google_maps_flutter package
    │
    ├─ iOS: Reads GoogleMaps.xcconfig
    │   └─ Uses Maps SDK for iOS
    │
    ├─ Android: Reads local.properties
    │   └─ Uses Maps SDK for Android
    │
    ▼
Google Maps tiles downloaded & rendered
    │
    ▼
✅ User sees map with session markers
```

### Example 2: User gõ địa chỉ trong "Tạo kèo"

```
User Action: Type "sân cầu lông" in address field
    │
    ▼
Flutter: Debounce 300ms
    │
    ▼
GooglePlacesService.autocomplete()
    │
    ├─ HTTP POST to:
    │  https://places.googleapis.com/v1/places:autocomplete
    │
    ├─ Headers:
    │  X-Goog-Api-Key: [Places API Key from env/*.json]
    │  X-Goog-FieldMask: suggestions.placePrediction
    │
    ├─ Body:
    │  {
    │    "input": "sân cầu lông",
    │    "languageCode": "vi",
    │    "includedRegionCodes": ["vn"]
    │  }
    │
    ▼
Google Places API (New) processes request
    │
    ▼
Response: List of suggestions
    │
    ▼
Flutter: Renders suggestions in ListView
    │
    ▼
✅ User sees autocomplete suggestions
```

---

## 🎯 Common Issues & Root Causes

### Issue 1: Blank map (no tiles)

```
Symptom: Map area shows but no tiles load
         │
         ▼
Root Cause Analysis:
         │
         ├─ Maps SDK Key missing?
         │  Check: ios/Flutter/GoogleMaps.xcconfig
         │  Check: android/local.properties
         │
         ├─ Wrong API restrictions?
         │  ✅ Should enable: Maps SDK for Android/iOS
         │  ❌ Should NOT enable: Places API
         │
         ├─ Wrong Application restrictions?
         │  Bundle ID: com.vmito.app ✓
         │  Package: com.vmito.app ✓
         │  SHA-1: [check with ./scripts/get_sha1.sh]
         │
         └─ API not enabled in GCP?
            Enable: Maps SDK for Android
            Enable: Maps SDK for iOS
```

### Issue 2: Autocomplete không hoạt động

```
Symptom: Type address but no suggestions appear
         │
         ▼
Root Cause Analysis:
         │
         ├─ Places API Key missing or wrong?
         │  Check: env/production.json
         │  Check: AppConfig.googlePlacesApiKey
         │
         ├─ Wrong API restrictions?
         │  ✅ Should enable: Places API (New) ONLY
         │  ❌ Should NOT enable: Maps SDK
         │
         ├─ Build with wrong env file?
         │  Must use: --dart-define-from-file=env/production.json
         │
         ├─ Network error?
         │  Check logs: flutter run --verbose
         │  Look for: POST places.googleapis.com
         │
         └─ API not enabled in GCP?
            Enable: Places API (New)
```

---

## 🛠️ Verification Commands

```bash
# Check SHA-1 fingerprint
./scripts/get_sha1.sh

# Verify all keys configured
./scripts/verify_google_keys.sh

# Check Maps SDK keys
cat ios/Flutter/GoogleMaps.xcconfig
cat android/local.properties | grep MAPS_API_KEY

# Check Places API key
cat env/production.json | grep GOOGLE_PLACES_API_KEY

# Test autocomplete key with curl
curl -X POST \
  -H "X-Goog-Api-Key: YOUR_PLACES_KEY" \
  -H "X-Goog-FieldMask: suggestions.placePrediction" \
  -d '{"input":"sân cầu lông","languageCode":"vi"}' \
  "https://places.googleapis.com/v1/places:autocomplete"

# Build and run
flutter clean
flutter run --dart-define-from-file=env/production.json --verbose
```

---

## 📚 References

- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)
- [Places API (New) REST Docs](https://developers.google.com/maps/documentation/places/web-service/op-overview)
- [API Key Best Practices](https://developers.google.com/maps/api-security-best-practices)

---

**Last Updated:** Check git log for this file
**Project:** Vmito Mobile App (Flutter)
