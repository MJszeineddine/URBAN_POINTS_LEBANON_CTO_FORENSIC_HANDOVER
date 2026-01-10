# Stripe Secrets Setup Guide

**Project**: urbangenspark  
**Date**: 2026-01-07  
**Purpose**: Configure Stripe API keys for production deployment

## Required Secrets

### 1. STRIPE_SECRET_KEY

**Description**: Stripe API secret key for authenticating API requests.

**Format**:
- Test mode: `sk_test_XXXXXXXXXXXXXXXXXXX`
- Live mode: `sk_live_XXXXXXXXXXXXXXXXXXX`

**Where to get it**: [Stripe Dashboard](https://dashboard.stripe.com/apikeys)

### 2. STRIPE_WEBHOOK_SECRET

**Description**: Webhook endpoint secret for verifying webhook signatures.

**Format**: `whsec_XXXXXXXXXXXXXXXXXXX`

**Where to get it**:
1. Go to [Stripe Webhooks](https://dashboard.stripe.com/webhooks)
2. Add endpoint: `https://us-central1-urbangenspark.cloudfunctions.net/stripeWebhook`
3. Select events to listen for:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
4. Copy the "Signing secret" (starts with `whsec_`)

## Setup Methods

### Method 1: Non-Interactive (PTY-Safe) ✅ RECOMMENDED

**Use this method for automated deployments and when terminal hangs are a risk.**

```bash
# Set STRIPE_SECRET_KEY
echo "sk_test_XXXXXXXXXXXXXXXXXXXXX" | firebase functions:secrets:set STRIPE_SECRET_KEY \
  --project urbangenspark \
  --data-file /dev/stdin

# Set STRIPE_WEBHOOK_SECRET
echo "whsec_XXXXXXXXXXXXXXXXXXXXX" | firebase functions:secrets:set STRIPE_WEBHOOK_SECRET \
  --project urbangenspark \
  --data-file /dev/stdin
```

**Verification**:
```bash
firebase functions:secrets:access STRIPE_SECRET_KEY --project urbangenspark
# Should output: sk_test_* or sk_live_*

firebase functions:secrets:access STRIPE_WEBHOOK_SECRET --project urbangenspark
# Should output: whsec_*
```

### Method 2: Interactive (Fallback)

**Use this method if non-interactive approach fails or for manual setup.**

```bash
# Ensure authenticated
firebase login

# Set secrets (will prompt for values)
firebase functions:secrets:set STRIPE_SECRET_KEY --project urbangenspark
# Enter secret: sk_test_XXXXXXXXXXXXXXXXXXXXX

firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project urbangenspark
# Enter secret: whsec_XXXXXXXXXXXXXXXXXXXXX
```

### Method 3: Environment Variables (Local Development Only)

**For running Firebase Functions Emulator locally.**

Create `.env` file in `source/backend/firebase-functions/`:

```bash
STRIPE_SECRET_KEY=sk_test_XXXXXXXXXXXXXXXXXXXXX
STRIPE_WEBHOOK_SECRET=whsec_XXXXXXXXXXXXXXXXXXXXX
```

**Load environment variables before starting emulator**:
```bash
source .env
firebase emulators:start --only functions
```

## Secrets Access Pattern in Code

The Stripe functions use a fallback pattern:

```typescript
const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || functions.config().stripe?.webhook_secret;
```

**Priority**:
1. `process.env.STRIPE_SECRET_KEY` (Firebase Functions Secrets, preferred)
2. `functions.config().stripe.secret_key` (legacy Firebase config, fallback)

## Deployment Impact

**After setting secrets**, redeploy affected functions:

```bash
firebase deploy \
  --only functions:stripeWebhook,functions:initiatePaymentCallable,functions:createCheckoutSession,functions:createBillingPortalSession \
  --project urbangenspark
```

**Functions requiring secrets**:
- ✅ `stripeWebhook` — Verifies webhook signatures
- ✅ `initiatePaymentCallable` — Creates payment intents
- ✅ `createCheckoutSession` — Creates checkout sessions
- ✅ `createBillingPortalSession` — Creates billing portal sessions

## Verification Steps

### 1. Verify Secrets Exist

```bash
firebase functions:secrets:access STRIPE_SECRET_KEY --project urbangenspark | head -c 10
# Should output: sk_test_ or sk_live_

firebase functions:secrets:access STRIPE_WEBHOOK_SECRET --project urbangenspark | head -c 10
# Should output: whsec_
```

### 2. Test Function Runtime Access

**Call createCheckoutSession with Firebase Functions shell**:

```bash
firebase functions:shell --project urbangenspark
```

In shell:
```javascript
createCheckoutSession({ priceId: 'price_TESTXXXXX', successUrl: 'https://example.com/success', cancelUrl: 'https://example.com/cancel' })
```

Expected output: `{ success: true, sessionId: 'cs_test_...', url: 'https://checkout.stripe.com/...' }`

If error `"Payment system not configured"` → Secret not loaded correctly

### 3. Test Webhook Signature Verification

**Send test webhook from Stripe Dashboard**:
1. Go to [Webhooks](https://dashboard.stripe.com/webhooks)
2. Select your endpoint
3. Click "Send test webhook"
4. Select event: `customer.subscription.created`

**Check Cloud Functions logs**:
```bash
firebase functions:log --project urbangenspark --only stripeWebhook --limit 10
```

Expected: `"Webhook processed"` (200 status)  
If error: `"Invalid signature"` → STRIPE_WEBHOOK_SECRET mismatch

## Security Checklist

- ✅ Use **test mode keys** (`sk_test_*`) during development
- ✅ Use **live mode keys** (`sk_live_*`) only in production
- ✅ Never commit secrets to git (`.env` in `.gitignore`)
- ✅ Rotate keys if compromised (generate new keys in Stripe Dashboard)
- ✅ Restrict API key permissions in Stripe Dashboard (uncheck unnecessary permissions)
- ✅ Monitor Stripe Dashboard for unauthorized API calls

## Troubleshooting

### Error: "STRIPE_SECRET_KEY not configured"

**Cause**: Secret not set or not loaded by function runtime.

**Fix**:
1. Verify secret exists: `firebase functions:secrets:access STRIPE_SECRET_KEY --project urbangenspark`
2. If missing, run Method 1 (non-interactive setup)
3. Redeploy functions: `firebase deploy --only functions:createCheckoutSession --project urbangenspark`

### Error: "Invalid signature" in webhook logs

**Cause**: STRIPE_WEBHOOK_SECRET mismatch between code and Stripe Dashboard.

**Fix**:
1. Go to Stripe Dashboard → Webhooks → Select endpoint
2. Click "Reveal" signing secret (starts with `whsec_`)
3. Copy exact value (no extra spaces)
4. Re-run Method 1 setup with correct value
5. Wait 1-2 minutes for secret propagation
6. Send test webhook again

### Error: "Could not load the default credentials"

**Cause**: Firebase CLI not authenticated.

**Fix**:
```bash
firebase login --no-localhost
firebase projects:list  # Verify authentication
```

## References

- [Stripe API Keys](https://dashboard.stripe.com/apikeys)
- [Stripe Webhooks](https://dashboard.stripe.com/webhooks)
- [Firebase Functions Secrets](https://firebase.google.com/docs/functions/config-env#secret-manager)
- [Stripe Webhook Signature Verification](https://stripe.com/docs/webhooks/signatures)

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-07  
**Maintainer**: CTO Handover Documentation
