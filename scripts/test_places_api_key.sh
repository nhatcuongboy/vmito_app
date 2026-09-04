#!/bin/bash

# Script để test Google Places API key
# Usage: ./scripts/test_places_api_key.sh [API_KEY]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "🔍 Testing Google Places API Key..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get API key
if [ -n "$1" ]; then
    API_KEY="$1"
else
    # Try to read from env file
    if [ -f "env/production.local.json" ]; then
        API_KEY=$(grep -o '"GOOGLE_PLACES_API_KEY": "[^"]*"' env/production.local.json | cut -d'"' -f4)
    elif [ -f "env/production.json" ]; then
        API_KEY=$(grep -o '"GOOGLE_PLACES_API_KEY": "[^"]*"' env/production.json | cut -d'"' -f4)
    fi
fi

if [ -z "$API_KEY" ]; then
    echo -e "${RED}❌ Error: No API key found${NC}"
    echo ""
    echo "Usage:"
    echo "  ./scripts/test_places_api_key.sh YOUR_API_KEY"
    echo ""
    echo "Or make sure env/production.json or env/production.local.json has GOOGLE_PLACES_API_KEY"
    exit 1
fi

echo -e "${BLUE}📋 API Key Info:${NC}"
echo "   Key: ${API_KEY:0:20}...${API_KEY: -10}"
echo ""

# Test the API key
echo -e "${BLUE}🧪 Testing API request...${NC}"
echo ""

RESPONSE=$(curl -s -w "\n__HTTP_STATUS__:%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -H "X-Goog-Api-Key: $API_KEY" \
  -H "X-Goog-FieldMask: suggestions.placePrediction" \
  -d '{
    "input": "sân cầu lông",
    "languageCode": "vi",
    "includedRegionCodes": ["vn"]
  }' \
  "https://places.googleapis.com/v1/places:autocomplete" 2>&1)

# Extract status code
HTTP_STATUS=$(echo "$RESPONSE" | grep -o "__HTTP_STATUS__:[0-9]*" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed 's/__HTTP_STATUS__:.*//')

echo -e "${BLUE}📨 Response:${NC}"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo ""
echo -e "${BLUE}📊 HTTP Status: ${NC}$HTTP_STATUS"
echo ""

# Analyze response
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}🔎 Analysis:${NC}"
echo ""

if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ API Key hoạt động hoàn hảo!${NC}"
    echo ""
    echo "Suggestions returned:"
    echo "$BODY" | grep -o '"text":"[^"]*"' | head -5 || echo "   (Could not parse suggestions)"
    echo ""
    echo "✅ Key đã được cấu hình đúng"
    echo "✅ API restrictions đúng"
    echo "✅ Application restrictions (nếu có) cho phép request này"
    echo ""
    
elif echo "$BODY" | grep -q "API_KEY_IOS_APP_BLOCKED"; then
    echo -e "${YELLOW}⚠️  Key có Application Restrictions (iOS)${NC}"
    echo ""
    echo "Error: API_KEY_IOS_APP_BLOCKED"
    echo ""
    echo "Nguyên nhân:"
    echo "   • Key có iOS Bundle ID restrictions"
    echo "   • Curl request không match với Bundle ID"
    echo ""
    echo "Giải pháp:"
    echo "   1. Key VẪN hoạt động trong app (vì app có đúng Bundle ID)"
    echo "   2. Để test bằng curl, cần:"
    echo "      • Tạo key test không có restrictions HOẶC"
    echo "      • Test trực tiếp trong app"
    echo ""
    echo -e "${GREEN}✅ Key HỢP LỆ - Sẽ hoạt động trong app iOS với Bundle ID: com.vmito.app${NC}"
    echo ""
    
elif echo "$BODY" | grep -q "API_KEY_ANDROID_APP_BLOCKED"; then
    echo -e "${YELLOW}⚠️  Key có Application Restrictions (Android)${NC}"
    echo ""
    echo "Error: API_KEY_ANDROID_APP_BLOCKED"
    echo ""
    echo "Nguyên nhân:"
    echo "   • Key có Android Package restrictions"
    echo "   • Curl request không match với Package name"
    echo ""
    echo "Giải pháp:"
    echo "   1. Key VẪN hoạt động trong app (vì app có đúng Package)"
    echo "   2. Để test bằng curl, cần key không có restrictions"
    echo ""
    echo -e "${GREEN}✅ Key HỢP LỆ - Sẽ hoạt động trong app Android với Package: com.vmito.app${NC}"
    echo ""
    
elif echo "$BODY" | grep -q "API_KEY_INVALID"; then
    echo -e "${RED}❌ API Key không hợp lệ${NC}"
    echo ""
    echo "Vấn đề:"
    echo "   • Key sai hoặc đã bị xóa"
    echo "   • Key chưa được tạo trên Google Cloud"
    echo ""
    echo "Giải pháp:"
    echo "   1. Check key trong Google Cloud Console"
    echo "   2. Tạo key mới nếu cần"
    echo "   3. Update vào env/production.json"
    echo ""
    
elif echo "$BODY" | grep -q "PERMISSION_DENIED"; then
    echo -e "${YELLOW}⚠️  Permission Denied${NC}"
    echo ""
    
    if echo "$BODY" | grep -q "iosBundleId"; then
        echo "Chi tiết: iOS Bundle ID restriction"
        echo ""
        BUNDLE_ID=$(echo "$BODY" | grep -o '"iosBundleId":"[^"]*"' | cut -d'"' -f4)
        echo "   Expected Bundle ID: com.vmito.app"
        echo "   Current: $BUNDLE_ID"
        echo ""
        
        if [ "$BUNDLE_ID" = "<empty>" ]; then
            echo "Nguyên nhân: Curl không có Bundle ID"
            echo ""
            echo -e "${GREEN}✅ Key HỢP LỆ - Hoạt động trong app với Bundle ID đúng${NC}"
        fi
    else
        echo "Có thể do:"
        echo "   • Application restrictions không match"
        echo "   • API restrictions chưa enable Places API (New)"
        echo "   • Permissions issue"
    fi
    echo ""
    
elif echo "$BODY" | grep -q "RESOURCE_EXHAUSTED"; then
    echo -e "${RED}❌ Quota exceeded${NC}"
    echo ""
    echo "Key hợp lệ nhưng đã hết quota/quyền sử dụng"
    echo "Check Google Cloud Console > Quotas & Billing"
    echo ""
    
else
    echo -e "${RED}❌ Unknown error${NC}"
    echo ""
    echo "Full response above. Check:"
    echo "   1. API enabled: Places API (New)"
    echo "   2. Key restrictions trong Google Cloud Console"
    echo "   3. Billing enabled (nếu cần)"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo ""

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Build app và test autocomplete:"
    echo "   flutter run --dart-define-from-file=env/production.json"
    echo ""
elif echo "$BODY" | grep -q "API_KEY_.*_BLOCKED"; then
    echo "✅ Key đúng! Test trong app:"
    echo "   flutter run --dart-define-from-file=env/production.json"
    echo ""
    echo "📍 Test autocomplete:"
    echo "   1. Vào 'Tạo kèo'"
    echo "   2. Nhấn 'Chọn địa điểm'"
    echo "   3. Gõ ít nhất 2 ký tự"
    echo "   4. Xem suggestions"
    echo ""
else
    echo "❌ Fix key trong Google Cloud Console"
    echo ""
    echo "Check list:"
    echo "   • API enabled: Places API (New)"
    echo "   • Application restrictions:"
    echo "     - iOS Bundle ID: com.vmito.app"
    echo "     - Android Package: com.vmito.app + SHA-1"
    echo "   • API restrictions: CHỈ Places API (New)"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
