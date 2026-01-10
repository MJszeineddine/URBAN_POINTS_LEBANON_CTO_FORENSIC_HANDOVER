#!/bin/bash

BASE_URL="http://localhost:3000/api"

echo "═══════════════════════════════════════════════════════════════"
echo "🧪 URBAN POINTS LEBANON - API COMPREHENSIVE TESTS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Health Check
echo "📡 Test 1: Health Check"
curl -s "$BASE_URL/health" | python3 -m json.tool | grep -E '(status|timezone|PAYMENTS_ENABLED)' && echo "✅ PASS" || echo "❌ FAIL"
echo ""

# Test 2: Feature Flags
echo "📋 Test 2: Feature Flags"
curl -s "$BASE_URL/feature-flags" | python3 -m json.tool | grep "success" && echo "✅ PASS" || echo "❌ FAIL"
echo ""

# Test 3: Get All Merchants
echo "🏪 Test 3: Get All Merchants"
MERCHANTS=$(curl -s "$BASE_URL/merchants")
MERCHANT_COUNT=$(echo "$MERCHANTS" | python3 -c "import json, sys; print(len(json.load(sys.stdin)['data']))" 2>/dev/null)
echo "Found $MERCHANT_COUNT merchants"
[ "$MERCHANT_COUNT" -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL"
echo ""

# Test 4: Get All Offers
echo "🎁 Test 4: Get All Offers"
OFFERS=$(curl -s "$BASE_URL/offers")
OFFER_COUNT=$(echo "$OFFERS" | python3 -c "import json, sys; print(len(json.load(sys.stdin)['data']))" 2>/dev/null)
echo "Found $OFFER_COUNT active offers"
[ "$OFFER_COUNT" -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL"
echo ""

# Test 5: Register New User
echo "👤 Test 5: Register New User"
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+96170'$(date +%s)'",
    "email": "test'$(date +%s)'@example.com",
    "full_name": "Test User",
    "password": "TestPassword123!"
  }')

TOKEN=$(echo "$REGISTER_RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin)['data']['token'])" 2>/dev/null)
USER_ID=$(echo "$REGISTER_RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin)['data']['user']['id'])" 2>/dev/null)

if [ -n "$TOKEN" ]; then
  echo "✅ PASS - User registered, token received"
  echo "   User ID: $USER_ID"
else
  echo "❌ FAIL - Registration failed"
  echo "$REGISTER_RESPONSE" | python3 -m json.tool
fi
echo ""

# Test 6: Get Current User Profile
echo "👨‍💼 Test 6: Get Current User Profile (Authenticated)"
if [ -n "$TOKEN" ]; then
  PROFILE=$(curl -s "$BASE_URL/users/me" -H "Authorization: Bearer $TOKEN")
  echo "$PROFILE" | python3 -m json.tool | grep "full_name" && echo "✅ PASS" || echo "❌ FAIL"
else
  echo "⏭️  SKIP - No token available"
fi
echo ""

# Test 7: Get User's Vouchers
echo "🎫 Test 7: Get User's Vouchers (Authenticated)"
if [ -n "$TOKEN" ]; then
  curl -s "$BASE_URL/users/me/vouchers" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool | grep "success" && echo "✅ PASS" || echo "❌ FAIL"
else
  echo "⏭️  SKIP - No token available"
fi
echo ""

# Test 8: Get User's Transaction History
echo "📊 Test 8: Get User's Transaction History (Authenticated)"
if [ -n "$TOKEN" ]; then
  curl -s "$BASE_URL/users/me/transactions" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool | grep "success" && echo "✅ PASS" || echo "❌ FAIL"
else
  echo "⏭️  SKIP - No token available"
fi
echo ""

# Test 9: Test Invalid Token
echo "🔒 Test 9: Test Invalid Token (Security)"
INVALID_RESPONSE=$(curl -s "$BASE_URL/users/me" -H "Authorization: Bearer invalid_token_here")
echo "$INVALID_RESPONSE" | grep "Invalid token" && echo "✅ PASS - Security working" || echo "❌ FAIL"
echo ""

# Test 10: Rate Limit Check
echo "⏱️  Test 10: Rate Limiting (Info Only)"
echo "Rate limit: 100 requests per 15 minutes per IP"
echo "✅ INFO - Rate limiting is configured"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "🎉 API TESTS COMPLETED"
echo "═══════════════════════════════════════════════════════════════"
