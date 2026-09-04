# 🛠️ Helper Scripts - Google API Keys

Scripts trong folder này giúp bạn setup và verify Google API keys.

---

## 📜 Available Scripts

### 1. `get_sha1.sh`

**Purpose:** Lấy SHA-1 certificate fingerprint cho Android

**Usage:**
```bash
./scripts/get_sha1.sh
```

**Output:**
- SHA-1 fingerprint từ debug keystore
- Auto copy to clipboard (macOS)
- App bundle/package information

**Example output:**
```
🔍 Đang tìm SHA-1 Certificate Fingerprint...

✅ Tìm thấy debug keystore

📋 SHA-1 Fingerprint cho Debug Build:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A1:B2:C3:D4:E5:F6:G7:H8:I9:J0:K1:L2:M3:N4:O5:P6:Q7:R8:S9:T0

📝 Copy SHA-1 này để sử dụng trong Google Cloud Console

✅ Đã copy vào clipboard!
```

**When to use:**
- Trước khi tạo API keys trên Google Cloud Console
- Cần SHA-1 để set Application restrictions

**Prerequisites:**
- Android development environment setup
- Debug keystore đã được tạo (chạy `flutter run` nếu chưa có)

---

### 2. `verify_google_keys.sh`

**Purpose:** Kiểm tra và verify tất cả Google API keys đã được cấu hình đúng

**Usage:**
```bash
./scripts/verify_google_keys.sh
```

**Output:**
```
🔍 Kiểm tra cấu hình Google API Keys...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📍 Maps SDK Keys (cho hiển thị bản đồ):

✅ iOS Maps SDK Key
   📄 File: ios/Flutter/GoogleMaps.xcconfig
   🔑 Key: GOOGLE_MAPS_API_KEY ...xgHbWA

✅ Android Maps SDK Key
   📄 File: android/local.properties
   🔑 Key: MAPS_API_KEY=AIza...xgHbWA

📌 Places API Keys (cho autocomplete):

✅ Places API Key (production.json)
   📄 File: env/production.json
   🔑 Key: "GOOGLE_PLACES_API_K...xU5xgHbWA"

✅ Places API Key (production.local.json)
   📄 File: env/production.local.json
   🔑 Key: "GOOGLE_PLACES_API_K...xU5xgHbWA"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Tóm tắt:
   ✅ Passed: 4/4
   ❌ Failed: 0/4

🎉 Tất cả keys đã được cấu hình!
```

**What it checks:**
- ✅ iOS Maps SDK key trong `ios/Flutter/GoogleMaps.xcconfig`
- ✅ Android Maps SDK key trong `android/local.properties`
- ✅ Places API key trong `env/production.json`
- ✅ Places API key trong `env/production.local.json`

**Pass criteria:**
- File exists
- Key is present
- Key is not a placeholder (không chứa "YOUR_" hoặc "_HERE")
- Key starts with "AIza" (valid Google API key format)

**When to use:**
- Sau khi cập nhật bất kỳ API key nào
- Trước khi build và test app
- Khi troubleshooting issues
- Để check current status

---

## 🔧 Script Details

### Permissions

Scripts cần executable permission:

```bash
chmod +x scripts/get_sha1.sh
chmod +x scripts/verify_google_keys.sh
```

**Already done:** Scripts đã có executable permission.

---

### Platform Support

**macOS:** ✅ Full support
- SHA-1 extraction works
- Auto copy to clipboard
- Color output

**Linux:** ✅ Works (without clipboard)
- SHA-1 extraction works
- No auto copy (install `xclip` for clipboard support)
- Color output

**Windows:** ⚠️ Use Git Bash or WSL
- Scripts are bash scripts
- Need bash environment

---

## 📝 Workflow

### Complete Setup Workflow

```bash
# 1. Get SHA-1 fingerprint
./scripts/get_sha1.sh
# → Copy the SHA-1 output

# 2. Go to Google Cloud Console
# → Create 2 API keys with the SHA-1

# 3. Update config files
# → ios/Flutter/GoogleMaps.xcconfig
# → android/local.properties
# → env/production.json
# → env/production.local.json

# 4. Verify configuration
./scripts/verify_google_keys.sh
# → Should show 4/4 Passed

# 5. Build and test
flutter clean
flutter pub get
flutter run --dart-define-from-file=env/production.json
```

---

## 🐛 Troubleshooting

### `get_sha1.sh` issues

**Problem:** "Debug keystore không tồn tại"

**Solution:**
```bash
# Run app once to create debug keystore
flutter run

# Then run script again
./scripts/get_sha1.sh
```

---

**Problem:** Script không có permission

**Solution:**
```bash
chmod +x scripts/get_sha1.sh
./scripts/get_sha1.sh
```

---

### `verify_google_keys.sh` issues

**Problem:** Shows "Chưa thay placeholder"

**Solution:**
- Open the file mentioned
- Replace `YOUR_*_KEY_HERE` with actual API key
- Run verify script again

---

**Problem:** File not found error

**Solution:**
```bash
# Make sure you're in project root
cd /Users/cuongvnnguyen/Documents/vmito/vmito_app

# Check file exists
ls -la ios/Flutter/GoogleMaps.xcconfig
ls -la android/local.properties

# If not, create them (see documentation)
```

---

## 📚 Related Documentation

**For complete setup instructions:**
- [`START_HERE.md`](../START_HERE.md) - Start point
- [`GOOGLE_KEYS_QUICK_START.md`](../GOOGLE_KEYS_QUICK_START.md) - Quick guide
- [`SETUP_GOOGLE_KEYS_INSTRUCTIONS.md`](../SETUP_GOOGLE_KEYS_INSTRUCTIONS.md) - Full guide

**For understanding:**
- [`GOOGLE_KEYS_ARCHITECTURE.md`](../GOOGLE_KEYS_ARCHITECTURE.md) - Architecture diagrams
- [`GOOGLE_KEYS_README.md`](../GOOGLE_KEYS_README.md) - Documentation overview

---

## 🔄 Script Maintenance

Scripts are located at:
```
vmito_app/
└── scripts/
    ├── get_sha1.sh              ← SHA-1 extraction
    ├── verify_google_keys.sh    ← Configuration verification
    └── README.md                ← This file
```

**Version:** 1.0  
**Last Updated:** 2024-09-04

---

**Need help?** Check parent folder documentation or run scripts with no arguments for usage info.
