# 🔑 Hướng dẫn Setup Google API Keys - Vmito App

**Trạng thái hiện tại:**
- ✅ iOS Bundle ID: `com.vmito.app`
- ✅ Android Package: `com.vmito.app`
- ⚠️ Cần tạo 2 API keys riêng biệt
- ⚠️ Cần lấy SHA-1 fingerprint

---

## 📋 Chuẩn bị

### Bước 1: Lấy SHA-1 Certificate Fingerprint

#### Cho Debug Build (Development):

```bash
# Run app lần đầu để tạo debug keystore
cd /Users/cuongvnnguyen/Documents/vmito/vmito_app
flutter run

# Sau khi debug keystore được tạo, lấy SHA-1:
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

**Kết quả mẫu:**
```
SHA1: A1:B2:C3:D4:E5:F6:G7:H8:I9:J0:K1:L2:M3:N4:O5:P6:Q7:R8:S9:T0
```

📝 **Lưu SHA-1 này lại** - bạn sẽ cần nó ở các bước sau.

#### Cho Release Build (Production):

Nếu bạn có release keystore, lấy SHA-1:
```bash
keytool -list -v -keystore /path/to/your/release.keystore -alias your-alias
# Nhập password khi được yêu cầu
```

---

## 🎯 Bước 2: Tạo API Keys trên Google Cloud Console

### A. Tạo Maps SDK Key (Cho hiển thị bản đồ)

1. **Vào Google Cloud Console:**
   - Truy cập: https://console.cloud.google.com/
   - Chọn project của bạn

2. **Tạo API Key:**
   - Vào **APIs & Services** → **Credentials**
   - Click **+ CREATE CREDENTIALS** → **API key**
   - Key mới được tạo, copy lại
   - Click **EDIT API KEY** để cấu hình

3. **Đặt tên key:**
   ```
   Vmito Mobile - Maps SDK
   ```

4. **Set Application restrictions:**
   - Chọn tab **Application restrictions**
   - Chọn **Android apps**, click **ADD AN ITEM**:
     ```
     Package name: com.vmito.app
     SHA-1 certificate fingerprint: [SHA-1 từ bước 1]
     ```
   - Click **ADD AN ITEM** lại, chọn **iOS apps**:
     ```
     Bundle ID: com.vmito.app
     ```

5. **Set API restrictions:**
   - Chọn tab **API restrictions**
   - Chọn **Restrict key**
   - Select APIs dropdown, chọn:
     - ✅ **Maps SDK for Android**
     - ✅ **Maps SDK for iOS**
   - Bỏ chọn tất cả APIs khác
   - Click **SAVE**

6. **Copy API Key** - bạn sẽ cần nó cho file config

---

### B. Tạo Places API Key (Cho autocomplete địa chỉ)

1. **Tạo API Key mới:**
   - Vào **APIs & Services** → **Credentials**
   - Click **+ CREATE CREDENTIALS** → **API key**
   - Key mới được tạo, copy lại
   - Click **EDIT API KEY** để cấu hình

2. **Đặt tên key:**
   ```
   Vmito Mobile - Places API
   ```

3. **Set Application restrictions:**
   - Chọn tab **Application restrictions**
   - Chọn **Android apps**, click **ADD AN ITEM**:
     ```
     Package name: com.vmito.app
     SHA-1 certificate fingerprint: [SHA-1 từ bước 1]
     ```
   - Click **ADD AN ITEM** lại, chọn **iOS apps**:
     ```
     Bundle ID: com.vmito.app
     ```

4. **Set API restrictions:**
   - Chọn tab **API restrictions**
   - Chọn **Restrict key**
   - Select APIs dropdown, chỉ chọn:
     - ✅ **Places API (New)** ← CHỈ CÁI NÀY THÔI!
   - Bỏ chọn tất cả APIs khác (bao gồm Maps SDK)
   - Click **SAVE**

5. **Copy API Key** - bạn sẽ cần nó cho file config

---

## 📝 Bước 3: Enable APIs trong Project

1. **Vào Library:**
   - **APIs & Services** → **Library**

2. **Tìm và enable các APIs sau:**
   - ✅ **Maps SDK for Android**
   - ✅ **Maps SDK for iOS**
   - ✅ **Places API (New)**

3. Click **ENABLE** cho mỗi API nếu chưa được enable

---

## ⚙️ Bước 4: Cập nhật Config Files

### A. Cấu hình Maps SDK Key

#### iOS:
**File:** `ios/Flutter/GoogleMaps.xcconfig`

```bash
# Mở file và thay YOUR_MAPS_SDK_KEY_HERE bằng Maps SDK Key thực tế
GOOGLE_MAPS_API_KEY = AIzaSy...your-maps-sdk-key...
```

#### Android:
**File:** `android/local.properties`

```bash
# Mở file và thay YOUR_MAPS_SDK_KEY_HERE bằng Maps SDK Key thực tế
flutter.sdk=/Users/cuongvnnguyen/flutter

MAPS_API_KEY=AIzaSy...your-maps-sdk-key...
```

---

### B. Cấu hình Places API Key

#### Production environment:
**File:** `env/production.json`

```json
{
  "FLAVOR": "production",
  "API_BASE_URL": "https://vmito.com/api",
  "WEB_BASE_URL": "https://vmito.com",
  "GOOGLE_PLACES_API_KEY": "AIzaSy...your-places-api-key..."
}
```

**File:** `env/production.local.json` (nếu muốn override local)

```json
{
  "FLAVOR": "production",
  "API_BASE_URL": "https://vmito.com/api",
  "WEB_BASE_URL": "https://vmito.com",
  "GOOGLE_PLACES_API_KEY": "AIzaSy...your-places-api-key..."
}
```

#### Staging environment (optional):
**File:** `env/staging.json`

```json
{
  "FLAVOR": "staging",
  "API_BASE_URL": "https://staging.vmito.com/api",
  "WEB_BASE_URL": "https://staging.vmito.com",
  "GOOGLE_PLACES_API_KEY": "AIzaSy...your-places-api-key..."
}
```

---

## 🧪 Bước 5: Test & Verify

### 1. Clean và rebuild:

```bash
cd /Users/cuongvnnguyen/Documents/vmito/vmito_app
flutter clean
flutter pub get
flutter run --dart-define-from-file=env/production.json
```

### 2. Test trên iOS:

```bash
flutter run -d <ios-device-id> --dart-define-from-file=env/production.json
```

### 3. Test trên Android:

```bash
flutter run -d <android-device-id> --dart-define-from-file=env/production.json
```

### 4. Test các tính năng:

#### Test 1: Hiển thị bản đồ
1. Mở app
2. Vào tab **"Tìm kèo"** (Home/Discovery)
3. Nhấn nút **"Bản đồ"** (Map toggle)
4. ✅ **Kết quả mong đợi:** Thấy Google Map với markers của các session

#### Test 2: Autocomplete địa chỉ
1. Mở app
2. Vào **"Tạo kèo"** (Create Session)
3. Scroll xuống phần **"Địa điểm"**
4. Nhấn **"Chọn địa điểm"**
5. Gõ tên địa điểm (ví dụ: "Sân cầu lông")
6. ✅ **Kết quả mong đợi:** Thấy danh sách gợi ý địa điểm xuất hiện

---

## 🐛 Troubleshooting

### Vấn đề 1: Bản đồ không hiển thị (blank map)

**Triệu chứng:** Thấy loading rồi blank screen, không có map tiles

**Giải pháp:**
1. Kiểm tra Maps SDK key trong file config:
   ```bash
   cat ios/Flutter/GoogleMaps.xcconfig
   cat android/local.properties | grep MAPS_API_KEY
   ```

2. Kiểm tra API restrictions của Maps SDK key:
   - Vào Google Cloud Console → Credentials
   - Chọn "Vmito Mobile - Maps SDK" key
   - Xác nhận chỉ enable:
     - Maps SDK for Android
     - Maps SDK for iOS

3. Kiểm tra SHA-1 fingerprint đúng chưa:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

4. Rebuild app:
   ```bash
   flutter clean
   flutter run --dart-define-from-file=env/production.json
   ```

---

### Vấn đề 2: Autocomplete không hoạt động

**Triệu chứng:** Gõ địa chỉ nhưng không thấy suggestions

**Giải pháp:**
1. Kiểm tra Places API key trong env file:
   ```bash
   cat env/production.json | grep GOOGLE_PLACES_API_KEY
   ```

2. Check logs khi gõ địa chỉ:
   ```bash
   flutter run --dart-define-from-file=env/production.json
   # Gõ địa chỉ và xem logs
   ```

3. Kiểm tra API restrictions của Places API key:
   - Vào Google Cloud Console → Credentials
   - Chọn "Vmito Mobile - Places API" key
   - Xác nhận CHỈ enable:
     - Places API (New)
   - Không enable Maps SDK hoặc APIs khác

4. Test bằng curl (để verify key hoạt động):
   ```bash
   curl -X POST \
     -H "Content-Type: application/json" \
     -H "X-Goog-Api-Key: YOUR_PLACES_API_KEY" \
     -H "X-Goog-FieldMask: suggestions.placePrediction" \
     -d '{
       "input": "sân cầu lông",
       "languageCode": "vi",
       "includedRegionCodes": ["vn"]
     }' \
     "https://places.googleapis.com/v1/places:autocomplete"
   ```

5. Rebuild với clean:
   ```bash
   flutter clean
   flutter pub get
   flutter run --dart-define-from-file=env/production.json
   ```

---

### Vấn đề 3: "API_KEY_INVALID" error

**Nguyên nhân:**
- Key chưa được enable đúng APIs
- Application restrictions không match với app
- SHA-1 fingerprint không đúng

**Giải pháp:**
1. Double check Application restrictions:
   - Android package: `com.vmito.app`
   - iOS bundle: `com.vmito.app`
   - SHA-1 fingerprint đúng

2. Wait 5-10 phút sau khi tạo/sửa key để Google sync

3. Try với key không có restrictions (temporary test):
   - Edit key → Application restrictions → None
   - Test xem có hoạt động không
   - Nếu hoạt động → vấn đề ở restrictions
   - Sau khi test xong, set lại restrictions cho security

---

## 📊 Checklist

### Trước khi bắt đầu:
- [ ] Đã có Google Cloud Project
- [ ] Đã enable billing (nếu cần)
- [ ] Đã lấy được SHA-1 fingerprint

### Maps SDK Key:
- [ ] Đã tạo key "Vmito Mobile - Maps SDK"
- [ ] Đã set Application restrictions (Android + iOS)
- [ ] Đã set API restrictions (chỉ Maps SDK)
- [ ] Đã copy key vào `ios/Flutter/GoogleMaps.xcconfig`
- [ ] Đã copy key vào `android/local.properties`

### Places API Key:
- [ ] Đã tạo key "Vmito Mobile - Places API"
- [ ] Đã set Application restrictions (Android + iOS)
- [ ] Đã set API restrictions (chỉ Places API New)
- [ ] Đã copy key vào `env/production.json`
- [ ] Đã copy key vào `env/production.local.json` (nếu có)

### APIs Enabled:
- [ ] Maps SDK for Android
- [ ] Maps SDK for iOS
- [ ] Places API (New)

### Testing:
- [ ] Build thành công
- [ ] Bản đồ hiển thị đúng
- [ ] Autocomplete hoạt động

---

## 📚 Tài liệu tham khảo

- [Google Maps Platform Documentation](https://developers.google.com/maps/documentation)
- [Places API (New) Guide](https://developers.google.com/maps/documentation/places/web-service/op-overview)
- [API Key Best Practices](https://developers.google.com/maps/api-security-best-practices)
- [Get SHA-1 Fingerprint](https://developers.google.com/android/guides/client-auth)

---

## 🆘 Cần hỗ trợ thêm?

Nếu gặp vấn đề, check logs:
```bash
# Full logs
flutter run --dart-define-from-file=env/production.json --verbose

# Specific logs
adb logcat | grep -i "google\|places\|maps"  # Android
# iOS logs từ Xcode Console
```

Contact: Check project README.md cho thông tin liên hệ.
