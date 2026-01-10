# PHASE 2: STRIPE CONFIGURATION - NO-GO ❌

**Objective:** Make payments REAL and verifiable

**Status:** ❌ **NO-GO** - Permission Blocker

---

## 🚨 BLOCKER IDENTIFIED

### **Error:**
```
Error: Request to https://runtimeconfig.googleapis.com/v1beta1/projects/urbangenspark/configs had HTTP Error: 403
The caller does not have permission
```

### **Root Cause:**
Firebase CLI does not have sufficient permissions to:
1. Read Firebase Functions configuration
2. Set Firebase Functions secrets
3. Deploy Firebase Functions

### **Required Permissions:**
- `firebase.projects.get`
- `cloudfunctions.functions.create`
- `cloudfunctions.functions.update`
- `runtimeconfig.configs.create`
- `runtimeconfig.configs.get`
- `runtimeconfig.configs.update`

---

## 🔄 ALTERNATIVE APPROACH: Environment Variables

Since Firebase Secrets Manager requires production deployment permissions, we can document the configuration requirements for manual setup:

### **Required Secrets:**

#### **1. STRIPE_SECRET_KEY**
```bash
# Production Stripe secret key
# Format: sk_live_xxxxxxxxxxxxxxxxxxxx
# OR for testing: sk_test_xxxxxxxxxxxxxxxxxxxx

# Set via Firebase Console or CLI:
firebase functions:secrets:set STRIPE_SECRET_KEY
```

#### **2. STRIPE_WEBHOOK_SECRET**
```bash
# Webhook signing secret from Stripe Dashboard
# Format: whsec_xxxxxxxxxxxxxxxxxxxx

# Set via Firebase Console or CLI:
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

---

## 📋 MANUAL CONFIGURATION STEPS

### **Step 1: Get Stripe Keys**
1. Go to: https://dashboard.stripe.com/
2. Navigate to: **Developers** → **API keys**
3. Copy:
   - **Secret key** (starts with `sk_test_` or `sk_live_`)
   - **Publishable key** (starts with `pk_test_` or `pk_live_`)

### **Step 2: Configure Webhook**
1. Go to: **Developers** → **Webhooks**
2. Click **Add endpoint**
3. Endpoint URL: `https://us-central1-urbangenspark.cloudfunctions.net/stripeWebhook`
4. Select events:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
5. Copy **Signing secret** (starts with `whsec_`)

### **Step 3: Set Firebase Secrets**

**Option A: Firebase Console**
1. Go to: https://console.firebase.google.com/project/urbangenspark/functions
2. Navigate to: **Functions** → **Configuration**
3. Add secrets:
   - Key: `STRIPE_SECRET_KEY`, Value: `sk_test_...` or `sk_live_...`
   - Key: `STRIPE_WEBHOOK_SECRET`, Value: `whsec_...`

**Option B: Firebase CLI (requires permissions)**
```bash
# Set secrets via CLI
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

**Option C: Cloud Functions Config (legacy)**
```bash
# Set via legacy config (fallback)
firebase functions:config:set stripe.secret_key="sk_test_..."
firebase functions:config:set stripe.webhook_secret="whsec_..."
```

---

## ✅ CODE ALREADY SUPPORTS MULTIPLE CONFIG METHODS

Our implementation in `stripe.ts` already supports fallback:

```typescript
// Line 378-379 in stripe.ts
const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;

// Line 390 in stripe.ts
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || functions.config().stripe?.webhook_secret || '';
```

**Config priority:**
1. Environment variable (Secrets Manager)
2. Firebase Functions config (legacy)
3. Fail gracefully with error message

---

## 🧪 VERIFICATION CHECKLIST

Once secrets are configured, verify:

### **1. Check secrets are set:**
```bash
firebase functions:config:get stripe
```

**Expected output:**
```json
{
  "secret_key": "sk_test_...",
  "webhook_secret": "whsec_..."
}
```

### **2. Deploy webhook function:**
```bash
cd /home/user/urbanpoints-lebanon-complete-ecosystem/backend/firebase-functions
firebase deploy --only functions:stripeWebhook
```

**Expected output:**
```
✔ Deploy complete!

Function URL (stripeWebhook):
https://us-central1-urbangenspark.cloudfunctions.net/stripeWebhook
```

### **3. Test webhook endpoint:**
```bash
curl -X POST https://us-central1-urbangenspark.cloudfunctions.net/stripeWebhook \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: test" \
  -d '{"type":"test.event"}'
```

**Expected response:**
- Status: 401 Unauthorized (signature verification fails - expected)
- OR: 500 if webhook secret not configured

### **4. Test with Stripe CLI:**
```bash
# Install Stripe CLI: https://stripe.com/docs/stripe-cli
stripe listen --forward-to https://us-central1-urbangenspark.cloudfunctions.net/stripeWebhook

# Trigger test event
stripe trigger payment_intent.succeeded
```

**Expected output:**
```
✓ Webhook received: payment_intent.succeeded
✓ Event processed successfully
```

---

## 📊 PHASE 2 DECISION: NO-GO

**Reason:** Cannot proceed without Firebase deployment permissions

**Blockers:**
1. ❌ Firebase CLI lacks `runtimeconfig` permissions
2. ❌ Cannot set Stripe secrets via CLI
3. ❌ Cannot deploy webhook function for testing
4. ❌ Cannot verify webhook endpoint is accessible

**What IS Complete:**
- ✅ Stripe integration code fully implemented
- ✅ Webhook handling with signature verification
- ✅ Subscription sync to Firestore
- ✅ Graceful config loading with fallbacks
- ✅ Documentation for manual setup

**What REQUIRES Manual Setup:**
- ⚠️ Stripe API keys configuration
- ⚠️ Webhook endpoint deployment
- ⚠️ Webhook URL configuration in Stripe Dashboard
- ⚠️ End-to-end payment testing

---

## 🔄 WORKAROUND: Continue to Phase 3

**Decision:** Proceed to Phase 3 (Testing) while documenting Stripe setup requirements.

**Rationale:**
- Validation integration is complete and tested
- Business logic is production-ready
- Tests can be written and run locally with emulators
- Stripe configuration is a deployment-time dependency, not a code dependency

**Risk Mitigation:**
- Document all Stripe setup steps
- Create deployment checklist
- Mark as production blocker requiring manual setup
- Continue parallel work that doesn't require Stripe

---

**Generated:** 2026-01-04  
**Mission:** Zero Gaps Production Readiness  
**Next Action:** Proceed to Phase 3 (Testing) while documenting deployment requirements
