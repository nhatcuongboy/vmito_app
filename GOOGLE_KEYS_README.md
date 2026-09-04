# 🔑 Google API Keys Setup - README

**Last Updated:** 2024-09-04  
**Status:** ⚠️ Setup required

---

## 📚 Tài liệu có sẵn

Tôi đã tạo đầy đủ tài liệu hướng dẫn setup Google API keys cho app. Chọn tài liệu phù hợp với nhu cầu:

### 1. 🚀 Quick Start (Recommended)
**File:** [`GOOGLE_KEYS_QUICK_START.md`](./GOOGLE_KEYS_QUICK_START.md)

**Dành cho:** Bạn muốn setup nhanh, ngắn gọn, đủ dùng.

**Nội dung:**
- ⚡ 4 bước chính để setup
- ✅ Test checklist
- 🐛 Quick troubleshooting

**Time:** ~15-20 phút

---

### 2. 📖 Full Instructions
**File:** [`SETUP_GOOGLE_KEYS_INSTRUCTIONS.md`](./SETUP_GOOGLE_KEYS_INSTRUCTIONS.md)

**Dành cho:** Bạn muốn hướng dẫn chi tiết từng bước.

**Nội dung:**
- Hướng dẫn step-by-step với screenshots mô tả
- Giải thích tại sao cần 2 keys riêng biệt
- Troubleshooting chi tiết cho từng vấn đề
- Security best practices
- File structure và configuration details

**Time:** ~30-45 phút (đọc kỹ)

---

### 3. 🏗️ Architecture & Deep Dive
**File:** [`GOOGLE_KEYS_ARCHITECTURE.md`](./GOOGLE_KEYS_ARCHITECTURE.md)

**Dành cho:** Developers muốn hiểu deep về cách hoạt động.

**Nội dung:**
- System architecture diagrams
- Data flow charts
- Key configuration matrix
- Security model
- Root cause analysis cho common issues

**Time:** ~20 phút (nếu bạn thích diagrams 📊)

---

### 4. ✅ Setup Checklist
**File:** [`.setup-checklist.md`](./.setup-checklist.md)

**Dành cho:** Track progress khi đang setup.

**Nội dung:**
- Checklist từng phase
- Boxes để tick ✅
- Spaces để ghi notes
- Verification steps

**Usage:** Print ra hoặc mở song song khi setup

---

### 5. 📘 Original Detailed Guide
**File:** [`.doc-google-api-keys-setup.md`](./.doc-google-api-keys-setup.md)

**Dành cho:** Backup documentation.

**Nội dung:** Tương tự Full Instructions nhưng format khác

---

## 🛠️ Helper Scripts

### Script 1: Lấy SHA-1 Fingerprint
**File:** [`scripts/get_sha1.sh`](./scripts/get_sha1.sh)

```bash
./scripts/get_sha1.sh
```

**Output:**
- SHA-1 fingerprint cho Android debug keystore
- Auto copy to clipboard (macOS)
- Bundle ID và Package name info

---

### Script 2: Verify Configuration
**File:** [`scripts/verify_google_keys.sh`](./scripts/verify_google_keys.sh)

```bash
./scripts/verify_google_keys.sh
```

**Output:**
- ✅/❌ status cho từng key
- File paths where keys are configured
- Summary report với pass/fail count

---

## 🎯 Quick Reference

### App Info
```
iOS Bundle ID:     com.vmito.app
Android Package:   com.vmito.app
```

### Keys cần tạo
```
1. Maps SDK Key    → For displaying Google Maps
2. Places API Key  → For address autocomplete
```

### Config files cần update

| File | Purpose | Key Type | Git Status |
|------|---------|----------|------------|
| `ios/Flutter/GoogleMaps.xcconfig` | iOS Maps | Maps SDK | ❌ gitignored |
| `android/local.properties` | Android Maps | Maps SDK | ❌ gitignored |
| `env/production.json` | Places API | Places | ✅ can commit |
| `env/production.local.json` | Places API (override) | Places | ❌ gitignored |

---

## 🚦 Current Status

Run verification script để check:

```bash
./scripts/verify_google_keys.sh
```

**Expected final result:**
```
✅ iOS Maps SDK Key: Passed
✅ Android Maps SDK Key: Passed  
✅ Places API Key (production.json): Passed
✅ Places API Key (production.local.json): Passed

📊 Tóm tắt: 4/4 Passed
```

---

## 📝 Which Document to Use?

**Choose your path:**

```
Bạn chưa biết gì về Google API Keys?
    │
    ├─ YES → Đọc SETUP_GOOGLE_KEYS_INSTRUCTIONS.md (full guide)
    │
    └─ NO → Already familiar?
            │
            ├─ Chỉ cần setup nhanh
            │   → GOOGLE_KEYS_QUICK_START.md
            │   → .setup-checklist.md (track progress)
            │
            └─ Muốn hiểu architecture
                → GOOGLE_KEYS_ARCHITECTURE.md
```

---

## 🆘 Troubleshooting Priority

1. **Bản đồ không hiển thị?**
   - Check: `ios/Flutter/GoogleMaps.xcconfig`
   - Check: `android/local.properties`
   - Verify: Maps SDK key có đúng API restrictions
   - Rebuild: `flutter clean && flutter run`

2. **Autocomplete không hoạt động?**
   - Check: `env/production.json`
   - Check: Build command có `--dart-define-from-file`
   - Verify: Places API key chỉ enable Places API (New)
   - Test: Curl command trong instructions

3. **Cả 2 đều fail?**
   - Check: SHA-1 fingerprint đúng chưa (`./scripts/get_sha1.sh`)
   - Check: Application restrictions có com.vmito.app
   - Check: APIs đã enable trong Google Cloud
   - Wait: 5-10 phút sau khi tạo/sửa keys

---

## 📞 Resources

**Google Cloud Console:**
- Main: https://console.cloud.google.com
- Credentials: https://console.cloud.google.com/apis/credentials
- Library: https://console.cloud.google.com/apis/library
- Dashboard: https://console.cloud.google.com/apis/dashboard

**Official Docs:**
- [Google Maps Platform](https://developers.google.com/maps/documentation)
- [Places API (New)](https://developers.google.com/maps/documentation/places/web-service/op-overview)
- [API Key Best Practices](https://developers.google.com/maps/api-security-best-practices)

---

## ✅ Next Steps

**If you haven't started:**
1. Read: `GOOGLE_KEYS_QUICK_START.md`
2. Run: `./scripts/get_sha1.sh`
3. Follow the 4 steps in Quick Start
4. Verify: `./scripts/verify_google_keys.sh`
5. Test: Build và test app

**If you're stuck:**
1. Check: Current status với verify script
2. Read: Troubleshooting section trong instructions
3. Check: Google Cloud Console cho errors
4. Review: Architecture doc để hiểu flow

**After successful setup:**
1. ✅ Test both features (Maps + Autocomplete)
2. ✅ Document keys cho team
3. ✅ Setup cho other environments (staging, dev)
4. ✅ Commit updated env files (if applicable)

---

**Happy Coding!** 🚀

> **Pro tip:** Bookmark GOOGLE_KEYS_QUICK_START.md - đó là tài liệu bạn sẽ reference nhiều nhất.
