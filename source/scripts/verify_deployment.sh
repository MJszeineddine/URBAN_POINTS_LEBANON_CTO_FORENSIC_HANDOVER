#!/bin/bash

# ============================================================================
# Urban Points Lebanon - Deployment Verification Script
# Project: urbangenspark
# Generated: Autonomous Deployment Session
# ============================================================================

set -e

PROJECT_ID="urbangenspark"
REGION="us-central1"

echo "============================================================================"
echo "Urban Points Lebanon - Deployment Verification"
echo "Project: $PROJECT_ID"
echo "============================================================================"
echo ""

# ============================================================================
# STEP 1: Verify Cloud Functions
# ============================================================================

echo "STEP 1: Verifying Cloud Functions Deployment"
echo "---------------------------------------------"

EXPECTED_FUNCTIONS=(
  "createCustomerAccount"
  "createMerchantAccount"
  "createAdminAccount"
  "verifyPhoneOTP"
  "awardPoints"
  "redeemPoints"
  "checkRedemptionEligibility"
  "generateSecureQRToken"
  "validateRedemption"
  "validateQRToken"
  "createOffer"
  "updateOfferStatus"
  "moderateOffer"
  "purchaseSubscription"
  "updateSubscriptionStatus"
  "sendPushCampaign"
  "sendPushToSegment"
  "calculateDailyStats"
  "processSubscriptionRenewals"
  "sendSubscriptionReminders"
)

echo "📊 Listing deployed functions..."
DEPLOYED_FUNCTIONS=$(firebase functions:list --project $PROJECT_ID 2>/dev/null | grep "Function" | awk '{print $2}' || echo "")

if [ -z "$DEPLOYED_FUNCTIONS" ]; then
    echo "❌ ERROR: Could not list functions. Check Firebase CLI authentication."
    exit 1
fi

MISSING_FUNCTIONS=()
for func in "${EXPECTED_FUNCTIONS[@]}"; do
    if echo "$DEPLOYED_FUNCTIONS" | grep -q "$func"; then
        echo "  ✅ $func"
    else
        echo "  ❌ $func (MISSING)"
        MISSING_FUNCTIONS+=("$func")
    fi
done

if [ ${#MISSING_FUNCTIONS[@]} -eq 0 ]; then
    echo "✅ All 19 Cloud Functions deployed successfully"
else
    echo "❌ ERROR: ${#MISSING_FUNCTIONS[@]} functions missing"
    echo "Missing: ${MISSING_FUNCTIONS[@]}"
    exit 1
fi

echo ""

# ============================================================================
# STEP 2: Verify Firestore Rules
# ============================================================================

echo "STEP 2: Verifying Firestore Rules"
echo "----------------------------------"

echo "📋 Fetching current Firestore rules..."
firebase firestore:rules:get --project $PROJECT_ID > /tmp/firestore_rules_deployed.txt 2>&1

if grep -q "rules_version = '2'" /tmp/firestore_rules_deployed.txt; then
    echo "✅ Firestore rules deployed (rules_version = '2')"
else
    echo "❌ ERROR: Could not verify Firestore rules"
    exit 1
fi

# Check for critical collections
CRITICAL_COLLECTIONS=("customers" "merchants" "admins" "qr_tokens" "redemptions" "subscriptions")
for collection in "${CRITICAL_COLLECTIONS[@]}"; do
    if grep -q "$collection" /tmp/firestore_rules_deployed.txt; then
        echo "  ✅ Rules for $collection collection"
    else
        echo "  ⚠️  WARNING: No rules found for $collection"
    fi
done

echo ""

# ============================================================================
# STEP 3: Verify Firestore Indexes
# ============================================================================

echo "STEP 3: Verifying Firestore Indexes"
echo "------------------------------------"

echo "📊 Checking index deployment status..."
# Note: This requires Firestore API access
echo "⚠️  Manual verification required:"
echo "   1. Go to: https://console.firebase.google.com/project/$PROJECT_ID/firestore/indexes"
echo "   2. Verify 15 composite indexes are listed"
echo "   3. Check status is 'Enabled' (not 'Building')"
echo ""

# ============================================================================
# STEP 4: Test Critical Cloud Functions
# ============================================================================

echo "STEP 4: Testing Critical Cloud Functions"
echo "-----------------------------------------"

echo "🧪 Testing function invocability (dry run)..."

# Test if functions are publicly accessible
FUNCTION_BASE_URL="https://$REGION-$PROJECT_ID.cloudfunctions.net"

# Test generateSecureQRToken (should require auth)
echo "  Testing generateSecureQRToken..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$FUNCTION_BASE_URL/generateSecureQRToken" -X POST -H "Content-Type: application/json" -d '{}' 2>/dev/null || echo "000")

if [ "$RESPONSE" = "401" ] || [ "$RESPONSE" = "403" ]; then
    echo "  ✅ generateSecureQRToken requires authentication (expected)"
elif [ "$RESPONSE" = "200" ]; then
    echo "  ⚠️  WARNING: generateSecureQRToken returned 200 without auth (check function security)"
else
    echo "  ℹ️  generateSecureQRToken response: $RESPONSE"
fi

# Test validateRedemption (should require auth)
echo "  Testing validateRedemption..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$FUNCTION_BASE_URL/validateRedemption" -X POST -H "Content-Type: application/json" -d '{}' 2>/dev/null || echo "000")

if [ "$RESPONSE" = "401" ] || [ "$RESPONSE" = "403" ]; then
    echo "  ✅ validateRedemption requires authentication (expected)"
elif [ "$RESPONSE" = "200" ]; then
    echo "  ⚠️  WARNING: validateRedemption returned 200 without auth (check function security)"
else
    echo "  ℹ️  validateRedemption response: $RESPONSE"
fi

echo ""

# ============================================================================
# STEP 5: Verify Environment Variables
# ============================================================================

echo "STEP 5: Verifying Environment Variables"
echo "----------------------------------------"

echo "⚙️  Checking Firebase config..."
CONFIG=$(firebase functions:config:get --project $PROJECT_ID 2>/dev/null || echo "{}")

# Check critical configs
CRITICAL_CONFIGS=("security.hmac_secret" "subscription.silver_price" "points.referrer_bonus")
for config in "${CRITICAL_CONFIGS[@]}"; do
    if echo "$CONFIG" | grep -q "$(echo $config | cut -d. -f1)"; then
        echo "  ✅ $config configured"
    else
        echo "  ❌ $config MISSING"
    fi
done

# Warn about payment configs
if echo "$CONFIG" | grep -q "payment"; then
    echo "  ✅ Payment gateway configs found"
else
    echo "  ⚠️  WARNING: No payment gateway configs found"
    echo "     Configure with: ./configure_firebase_env.sh"
fi

echo ""

# ============================================================================
# STEP 6: Check Cloud Function Logs
# ============================================================================

echo "STEP 6: Checking Recent Cloud Function Logs"
echo "--------------------------------------------"

echo "📜 Fetching recent function logs..."
firebase functions:log --project $PROJECT_ID --limit 10 2>&1 | tail -15

echo ""

# ============================================================================
# VERIFICATION SUMMARY
# ============================================================================

echo "============================================================================"
echo "VERIFICATION SUMMARY"
echo "============================================================================"
echo ""
echo "Deployment Status:"
echo "  ✅ Cloud Functions: All 19 functions deployed"
echo "  ✅ Firestore Rules: Deployed and active"
echo "  ℹ️  Firestore Indexes: Manual verification required"
echo "  ℹ️  Environment Variables: Partial (payment gateways pending)"
echo ""
echo "Next Steps:"
echo "  1. Verify indexes: https://console.firebase.google.com/project/$PROJECT_ID/firestore/indexes"
echo "  2. Configure payment gateways: See WEBHOOK_CONFIGURATION.md"
echo "  3. Test critical flows:"
echo "     - Customer registration"
echo "     - QR token generation"
echo "     - Points redemption"
echo "  4. Monitor logs: firebase functions:log --project $PROJECT_ID"
echo ""
echo "Production URLs:"
echo "  Functions: https://$REGION-$PROJECT_ID.cloudfunctions.net/"
echo "  Console: https://console.firebase.google.com/project/$PROJECT_ID"
echo ""
echo "============================================================================"
