#!/bin/bash

# Script để lấy SHA-1 fingerprint cho Android
# Sử dụng: ./scripts/get_sha1.sh

set -e

echo "🔍 Đang tìm SHA-1 Certificate Fingerprint..."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check debug keystore
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"

if [ -f "$DEBUG_KEYSTORE" ]; then
    echo -e "${GREEN}✅ Tìm thấy debug keystore${NC}"
    echo ""
    echo "📋 SHA-1 Fingerprint cho Debug Build:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    SHA1=$(keytool -list -v -keystore "$DEBUG_KEYSTORE" \
        -alias androiddebugkey \
        -storepass android \
        -keypass android 2>/dev/null | grep "SHA1:" | cut -d' ' -f3)
    
    if [ -n "$SHA1" ]; then
        echo -e "${GREEN}$SHA1${NC}"
        echo ""
        echo -e "${YELLOW}📝 Copy SHA-1 này để sử dụng trong Google Cloud Console${NC}"
        echo ""
        
        # Copy to clipboard if pbcopy exists (macOS)
        if command -v pbcopy &> /dev/null; then
            echo "$SHA1" | pbcopy
            echo -e "${GREEN}✅ Đã copy vào clipboard!${NC}"
        fi
    else
        echo -e "${RED}❌ Không lấy được SHA-1 từ keystore${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Debug keystore chưa tồn tại${NC}"
    echo ""
    echo "Debug keystore sẽ được tạo tự động khi bạn run app lần đầu:"
    echo ""
    echo -e "${YELLOW}flutter run${NC}"
    echo ""
    echo "Sau khi run app, chạy lại script này để lấy SHA-1."
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔐 Thông tin App:"
echo "   • Android Package: com.vmito.app"
echo "   • iOS Bundle ID: com.vmito.app"
echo ""
echo "📚 Next steps:"
echo "   1. Vào Google Cloud Console"
echo "   2. Tạo 2 API keys riêng biệt (Maps SDK + Places API)"
echo "   3. Set Application restrictions với thông tin trên"
echo "   4. Copy keys vào config files"
echo ""
echo "Chi tiết: xem file SETUP_GOOGLE_KEYS_INSTRUCTIONS.md"
echo ""
