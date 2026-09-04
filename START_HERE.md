# 🚀 START HERE - Google API Keys Setup

**Chào mừng!** File này sẽ hướng dẫn bạn bắt đầu setup Google API Keys cho Vmito app.

---

## ❓ Tại sao cần setup?

App của chúng ta sử dụng 2 tính năng Google:

1. **🗺️ Google Maps** - Hiển thị bản đồ trong trang "Tìm kèo"
2. **🔍 Places Autocomplete** - Tự động gợi ý địa chỉ khi tạo kèo

**Hiện tại:**
- ⚠️ Autocomplete chưa hoạt động hoàn toàn
- ⚠️ Maps sẽ không hiển thị nếu chưa có keys

---

## 📝 Bạn cần làm gì?

### Option 1: Setup nhanh (15-20 phút) ⚡

**Nếu bạn muốn setup ngay:**

1. Mở file: [`GOOGLE_KEYS_QUICK_START.md`](./GOOGLE_KEYS_QUICK_START.md)
2. Follow 4 bước trong đó
3. Done!

---

### Option 2: Đọc hiểu rồi setup (30-45 phút) 📖

**Nếu bạn muốn hiểu rõ trước khi làm:**

1. **Hiểu vấn đề:**
   - Đọc: [`GOOGLE_KEYS_ARCHITECTURE.md`](./GOOGLE_KEYS_ARCHITECTURE.md)
   - Xem diagrams và flow charts
   - Hiểu tại sao cần 2 keys riêng biệt

2. **Setup chi tiết:**
   - Đọc: [`SETUP_GOOGLE_KEYS_INSTRUCTIONS.md`](./SETUP_GOOGLE_KEYS_INSTRUCTIONS.md)
   - Follow từng bước với explanations
   - Troubleshooting nếu gặp lỗi

3. **Track progress:**
   - Mở: [`.setup-checklist.md`](./.setup-checklist.md)
   - Tick boxes khi hoàn thành mỗi bước

---

## 🛠️ Helper Tools

Trước khi bắt đầu, chạy scripts này:

### 1. Lấy SHA-1 fingerprint (cần cho Google Cloud)

```bash
./scripts/get_sha1.sh
```

**Output:** SHA-1 fingerprint (auto copied to clipboard)

---

### 2. Check trạng thái hiện tại

```bash
./scripts/verify_google_keys.sh
```

**Output:**
```
📍 Maps SDK Keys:
   ⚠️ iOS Maps SDK Key - Chưa cấu hình
   ⚠️ Android Maps SDK Key - Chưa cấu hình

📌 Places API Keys:
   ✅ Places API Key (production.json) - Configured
   ✅ Places API Key (production.local.json) - Configured

📊 Tóm tắt: 2/4 Passed
```

---

## 🎯 TL;DR - Quickest Path

Nếu bạn chỉ muốn "make it work" nhanh nhất:

```bash
# 1. Get SHA-1 (sẽ cần copy paste vào Google Cloud)
./scripts/get_sha1.sh

# 2. Đọc và follow hướng dẫn quick start
open GOOGLE_KEYS_QUICK_START.md

# Hoặc nếu không có `open` command:
cat GOOGLE_KEYS_QUICK_START.md

# 3. Sau khi update xong files, verify:
./scripts/verify_google_keys.sh

# 4. Build và test:
flutter clean
flutter pub get
flutter run --dart-define-from-file=env/production.json
```

**Time:** ~20 phút tổng cộng

---

## 📚 All Documentation

Tất cả files đã được tạo cho bạn:

| File | Purpose | Time |
|------|---------|------|
| 🚀 [`GOOGLE_KEYS_QUICK_START.md`](./GOOGLE_KEYS_QUICK_START.md) | Fastest setup guide | 15-20 min |
| 📖 [`SETUP_GOOGLE_KEYS_INSTRUCTIONS.md`](./SETUP_GOOGLE_KEYS_INSTRUCTIONS.md) | Detailed step-by-step | 30-45 min |
| 🏗️ [`GOOGLE_KEYS_ARCHITECTURE.md`](./GOOGLE_KEYS_ARCHITECTURE.md) | Architecture & diagrams | 20 min read |
| ✅ [`.setup-checklist.md`](./.setup-checklist.md) | Progress tracking | Use while setup |
| 📊 [`GOOGLE_KEYS_SUMMARY.md`](./GOOGLE_KEYS_SUMMARY.md) | Current status summary | 5 min read |
| 📘 [`GOOGLE_KEYS_README.md`](./GOOGLE_KEYS_README.md) | Overview of all docs | 10 min read |

**Scripts:**
- 🔑 `scripts/get_sha1.sh` - Get SHA-1 fingerprint
- ✅ `scripts/verify_google_keys.sh` - Verify configuration

---

## ⚡ Recommended Flow

```
START HERE.md (you are here!)
      │
      ▼
Get SHA-1: ./scripts/get_sha1.sh
      │
      ▼
GOOGLE_KEYS_QUICK_START.md
      │
      ├─── Follow 4 steps
      │    ├─ Step 1: Create Maps SDK Key on Google Cloud
      │    ├─ Step 2: Create Places API Key on Google Cloud  
      │    ├─ Step 3: Update config files
      │    └─ Step 4: Verify & Test
      │
      ▼
Verify: ./scripts/verify_google_keys.sh
      │
      ├─ All Passed (4/4) ✅
      │     │
      │     ▼
      │   Build & Test app
      │     │
      │     ▼
      │   ✅ DONE!
      │
      └─ Some Failed ❌
            │
            ▼
      Read Troubleshooting in:
      SETUP_GOOGLE_KEYS_INSTRUCTIONS.md
            │
            ▼
      Fix issues and retry
```

---

## 🎓 Learning Path

**Nếu muốn hiểu sâu:**

1. **Architecture first:**
   ```
   GOOGLE_KEYS_ARCHITECTURE.md
   → Hiểu tại sao cần 2 keys
   → Xem flow charts
   → Hiểu security model
   ```

2. **Then setup:**
   ```
   SETUP_GOOGLE_KEYS_INSTRUCTIONS.md
   → Follow detailed guide
   → Understand each step
   ```

3. **Track progress:**
   ```
   .setup-checklist.md
   → Tick boxes as you go
   → Take notes
   ```

---

## 🆘 If You're Stuck

1. **Check status:**
   ```bash
   ./scripts/verify_google_keys.sh
   ```

2. **Read troubleshooting:**
   - Quick fixes: `GOOGLE_KEYS_QUICK_START.md` → Troubleshooting section
   - Detailed fixes: `SETUP_GOOGLE_KEYS_INSTRUCTIONS.md` → Troubleshooting section

3. **Common issues:**
   - **Maps blank?** → Check `ios/Flutter/GoogleMaps.xcconfig` và `android/local.properties`
   - **Autocomplete not working?** → Check `env/production.json` và API restrictions
   - **API_KEY_INVALID?** → Check SHA-1 fingerprint và application restrictions

---

## ✅ Success Criteria

Setup hoàn thành khi:

- [x] `./scripts/verify_google_keys.sh` shows **4/4 Passed**
- [ ] Build app thành công
- [ ] Tab "Tìm kèo" → "Bản đồ" → Thấy Google Maps
- [ ] "Tạo kèo" → "Chọn địa điểm" → Autocomplete hoạt động

---

## 🎉 Ready?

**Let's go!** Open this file next:

```bash
open GOOGLE_KEYS_QUICK_START.md
# Or
cat GOOGLE_KEYS_QUICK_START.md
```

**Good luck!** 🚀

---

**Questions?**
- All documentation trong cùng folder này
- Helper scripts trong `scripts/`
- Google Cloud Console: https://console.cloud.google.com
