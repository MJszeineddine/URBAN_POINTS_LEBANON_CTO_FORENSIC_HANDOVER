#!/bin/bash

# ============================================================================
# Urban Points Lebanon - Firebase Environment Configuration
# Project: urbangenspark
# Generated: Autonomous Deployment Session
# ============================================================================

set -e

PROJECT_ID="urbangenspark"

echo "============================================================================"
echo "Firebase Environment Configuration"
echo "Project: $PROJECT_ID"
echo "============================================================================"
echo ""

# ============================================================================
# CRITICAL SECURITY: HMAC Secret Generation
# ============================================================================

echo "🔐 Generating HMAC Secret for QR Token Signing..."
HMAC_SECRET=$(openssl rand -base64 32)
echo "✅ HMAC Secret generated"
echo ""

# ============================================================================
# Set Firebase Environment Variables
# ============================================================================

echo "⚙️  Configuring Firebase Environment Variables..."
echo ""

# Security configuration
echo "Setting security.hmac_secret..."
firebase functions:config:set security.hmac_secret="$HMAC_SECRET" --project $PROJECT_ID

# Subscription pricing
echo "Setting subscription pricing..."
firebase functions:config:set \
  subscription.silver_price="4.99" \
  subscription.gold_price="9.99" \
  --project $PROJECT_ID

# Points economy
echo "Setting points economy rules..."
firebase functions:config:set \
  points.referrer_bonus="500" \
  points.referee_bonus="100" \
  points.default_rate="1" \
  --project $PROJECT_ID

# Rate limiting
echo "Setting rate limits..."
firebase functions:config:set \
  rate_limit.otp_per_hour="5" \
  rate_limit.otp_per_day="10" \
  --project $PROJECT_ID

# Geofencing (disabled by default)
echo "Setting geofencing config..."
firebase functions:config:set \
  geofence.enabled="false" \
  geofence.radius_km="5" \
  --project $PROJECT_ID

echo ""
echo "✅ Core configuration complete"
echo ""

# ============================================================================
# Payment Gateway Configuration (MANUAL SETUP REQUIRED)
# ============================================================================

echo "============================================================================"
echo "⚠️  MANUAL CONFIGURATION REQUIRED: Payment Gateways"
echo "============================================================================"
echo ""
echo "You need to configure payment gateway credentials manually:"
echo ""
echo "1. OMT Payment Gateway:"
echo "   firebase functions:config:set \\"
echo "     payment.omt_merchant_id=\"YOUR_OMT_MERCHANT_ID\" \\"
echo "     payment.omt_api_key=\"YOUR_OMT_API_KEY\" \\"
echo "     payment.omt_secret_key=\"YOUR_OMT_SECRET_KEY\" \\"
echo "     --project $PROJECT_ID"
echo ""
echo "2. Whish Money:"
echo "   firebase functions:config:set \\"
echo "     payment.whish_merchant_id=\"YOUR_WHISH_MERCHANT_ID\" \\"
echo "     payment.whish_api_key=\"YOUR_WHISH_API_KEY\" \\"
echo "     --project $PROJECT_ID"
echo ""
echo "3. Stripe (Credit/Debit Cards):"
echo "   firebase functions:config:set \\"
echo "     payment.stripe_secret_key=\"YOUR_STRIPE_SECRET_KEY\" \\"
echo "     payment.stripe_webhook_secret=\"YOUR_STRIPE_WEBHOOK_SECRET\" \\"
echo "     --project $PROJECT_ID"
echo ""
echo "4. Slack Webhook (System Alerts):"
echo "   firebase functions:config:set \\"
echo "     slack.webhook_url=\"YOUR_SLACK_WEBHOOK_URL\" \\"
echo "     --project $PROJECT_ID"
echo ""

# ============================================================================
# Verify Configuration
# ============================================================================

echo "============================================================================"
echo "Current Firebase Configuration:"
echo "============================================================================"
firebase functions:config:get --project $PROJECT_ID

echo ""
echo "✅ Configuration script complete"
echo ""
echo "Next Steps:"
echo "  1. Configure payment gateway credentials (see above)"
echo "  2. Run: ./deploy_production.sh"
echo "============================================================================"
