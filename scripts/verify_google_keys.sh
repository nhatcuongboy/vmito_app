#!/bin/bash

# Script để verify Google API keys đã được cấu hình chưa
# Sử dụng: ./scripts/verify_google_keys.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "🔍 Kiểm tra cấu hình Google API Keys..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Counter
TOTAL=0
PASSED=0
FAILED=0

# Function to check file and extract key
check_file() {
    local file=$1
    local desc=$2
    local pattern=$3
    
    TOTAL=$((TOTAL + 1))
    
    if [ -f "$file" ]; then
        KEY=$(grep -o "$pattern" "$file" | head -1)
        
        if [ -n "$KEY" ]; then
            # Check if it's placeholder or real key
            if [[ "$KEY" == *"YOUR_"* ]] || [[ "$KEY" == *"_HERE"* ]]; then
                echo -e "${YELLOW}⚠️  $desc${NC}"
                echo -e "   📄 File: $file"
                echo -e "   ❌ Chưa thay placeholder bằng key thực tế"
                echo ""
                FAILED=$((FAILED + 1))
            else
                echo -e "${GREEN}✅ $desc${NC}"
                echo -e "   📄 File: $file"
                echo -e "   🔑 Key: ${KEY:0:20}...${KEY: -10}"
                echo ""
                PASSED=$((PASSED + 1))
            fi
        else
            echo -e "${RED}❌ $desc${NC}"
            echo -e "   📄 File: $file"
            echo -e "   ❌ Không tìm thấy key"
            echo ""
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "${RED}❌ $desc${NC}"
        echo -e "   📄 File: $file"
        echo -e "   ❌ File không tồn tại"
        echo ""
        FAILED=$((FAILED + 1))
    fi
}

# Check Maps SDK Keys
echo -e "${BLUE}📍 Maps SDK Keys (cho hiển thị bản đồ):${NC}"
echo ""

check_file \
    "ios/Flutter/GoogleMaps.xcconfig" \
    "iOS Maps SDK Key" \
    "GOOGLE_MAPS_API_KEY = .*"

check_file \
    "android/local.properties" \
    "Android Maps SDK Key" \
    "MAPS_API_KEY=.*"

# Check Places API Keys
echo -e "${BLUE}📌 Places API Keys (cho autocomplete):${NC}"
echo ""

check_file \
    "env/production.json" \
    "Places API Key (production.json)" \
    '"GOOGLE_PLACES_API_KEY": "[^"]*"'

check_file \
    "env/production.local.json" \
    "Places API Key (production.local.json)" \
    '"GOOGLE_PLACES_API_KEY": "[^"]*"'

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Tóm tắt:"
echo -e "   ✅ Passed: ${GREEN}$PASSED${NC}/$TOTAL"
echo -e "   ❌ Failed: ${RED}$FAILED${NC}/$TOTAL"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 Tất cả keys đã được cấu hình!${NC}"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Clean và rebuild app:"
    echo "      flutter clean && flutter pub get"
    echo ""
    echo "   2. Run app với production config:"
    echo "      flutter run --dart-define-from-file=env/production.json"
    echo ""
    echo "   3. Test các tính năng:"
    echo "      • Vào tab 'Tìm kèo' → Nhấn nút 'Bản đồ'"
    echo "      • Vào 'Tạo kèo' → 'Chọn địa điểm' → Gõ địa chỉ"
    echo ""
else
    echo -e "${YELLOW}⚠️  Còn $FAILED key(s) chưa được cấu hình${NC}"
    echo ""
    echo "📚 Hướng dẫn chi tiết:"
    echo "   → Xem file: SETUP_GOOGLE_KEYS_INSTRUCTIONS.md"
    echo ""
    echo "🔑 Để lấy SHA-1 fingerprint (cần cho Google Cloud):"
    echo "   ./scripts/get_sha1.sh"
    echo ""
fi

echo ""
