# 🚀 Google API Keys - Quick Start Guide

**Mục tiêu:** Setup 2 API keys để bật Google Maps và Places autocomplete.

---

## ⚡ Quick Steps

### 1️⃣ Lấy SHA-1 Fingerprint

```bash
./scripts/get_sha1.sh
```

Nếu chưa có debug keystore, run app trước:
```bash
flutter run
```

Sau đó chạy lại script trên để lấy SHA-1.

---

### 2️⃣ Tạo 2 API Keys trên Google Cloud

Truy cập: https://console.cloud.google.com/apis/credentials

#### Key A: Maps SDK Key
```
Tên: Vmito Mobile - Maps SDK

Application restrictions:
├─ Android: com.vmito.app + [SHA-1 từ bước 1]
└─ iOS: com.vmito.app

API restrictions:
├─ ✅ Maps SDK for Android
└─ ✅ Maps SDK for iOS
```

#### Key B: Places API Key
```
Tên: Vmito Mobile - Places API

Application restrictions:
├─ Android: com.vmito.app + [SHA-1 từ bước 1]
└─ iOS: com.vmito.app

API restrictions:
└─ ✅ Places API (New) ← CHỈ CÁI NÀY!
```

---

### 3️⃣ Cập nhật Config Files

#### Maps SDK Key:

**iOS:** `ios/Flutter/GoogleMaps.xcconfig`
```
GOOGLE_MAPS_API_KEY = [Maps SDK Key]
```

**Android:** `android/local.properties`
```
MAPS_API_KEY=[Maps SDK Key]
```

#### Places API Key:

**File:** `env/production.json` và `env/production.local.json`
```json
{
  ...
  "GOOGLE_PLACES_API_KEY": "[Places API Key]"
}
```

---

### 4️⃣ Verify & Test

```bash
# Kiểm tra cấu hình
./scripts/verify_google_keys.sh

# Nếu OK, build và test
flutter clean
flutter pub get
flutter run --dart-define-from-file=env/production.json
```

---

## ✅ Test Checklist

- [ ] **Bản đồ hiển thị:** Tab "Tìm kèo" → Nút "Bản đồ" → Thấy Google Map
- [ ] **Autocomplete hoạt động:** "Tạo kèo" → "Chọn địa điểm" → Gõ địa chỉ → Thấy suggestions

---

## 🐛 Troubleshooting

### Bản đồ không hiển thị?
→ Check Maps SDK key trong `ios/Flutter/GoogleMaps.xcconfig` và `android/local.properties`

### Autocomplete không hoạt động?
→ Check Places API key trong `env/production.json` và verify chỉ enable "Places API (New)"

### Cần hướng dẫn chi tiết?
→ Đọc file: `SETUP_GOOGLE_KEYS_INSTRUCTIONS.md`

---

## 📝 File Structure

```
vmito_app/
├── ios/Flutter/
│   └── GoogleMaps.xcconfig           ← Maps SDK Key (iOS)
├── android/
│   └── local.properties              ← Maps SDK Key (Android)
├── env/
│   ├── production.json               ← Places API Key
│   └── production.local.json         ← Places API Key (override)
└── scripts/
    ├── get_sha1.sh                   ← Helper: lấy SHA-1
    └── verify_google_keys.sh         ← Helper: verify config
```

---

## 🔐 Security Notes

**Không commit vào Git:**
- ❌ `android/local.properties` (đã trong .gitignore)
- ❌ `ios/Flutter/GoogleMaps.xcconfig` (đã trong .gitignore)
- ❌ `env/*.local.json` (đã trong .gitignore)

**Có thể commit (có application restrictions):**
- ✅ `env/production.json` (nếu key có restrictions)

---

**Need help?** → Xem `SETUP_GOOGLE_KEYS_INSTRUCTIONS.md` hoặc `.doc-google-api-keys-setup.md`
