# Stripe Phase - Implementation Plan

**Date**: 2026-01-07  
**Status**: Phase 0 Complete (Discovery)  
**Project**: urbangenspark  
**Evidence-First Discipline**: All implementations followed by non-PTY deployment gate

## Discovery Findings

### Existing Infrastructure (60% Complete)

**File**: `source/backend/firebase-functions/src/stripe.ts` (643 lines)

**Implemented Functions**:
- ✅ `stripeWebhook` (HTTPS, lines 350+) — Signature verification, event routing, idempotent processing
- ✅ `initiatePayment` — Creates subscription with payment intent
- ✅ `initiatePaymentCallable` — Callable wrapper with validation/rate limiting
- ✅ `createCustomer` — Creates Stripe customer from Firebase uid
- ✅ `verifyPaymentStatus` — Checks subscription status
- ✅ `checkSubscriptionAccess` — Validates merchant subscription before operations

**Webhook Events Handled**:
- ✅ `customer.subscription.created/updated` → `handleSubscriptionUpdate`
- ✅ `customer.subscription.deleted` → `handleSubscriptionDeleted`
- ✅ `invoice.payment_succeeded` → `handlePaymentSucceeded`
- ✅ `invoice.payment_failed` → `handlePaymentFailed`

**Security Features**:
- ✅ Signature verification via `stripe.webhooks.constructEvent(req.rawBody, signature, webhookSecret)`
- ✅ Idempotent event handling (checks `processed_webhooks` collection)
- ✅ Auth validation (`context.auth.uid !== data.merchantId` checks)
- ✅ Secrets loading: `process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key`

**Dependencies**:
- ✅ Stripe SDK v15.0.0 (API version 2024-04-10)
- ✅ Rate limiting configured (10 requests/min for initiatePayment)
- ✅ Validation schemas (`InitiatePaymentSchema` in validation/schemas.ts)

### Identified Gaps (40% Missing)

**❌ Missing Functions** (grep confirmed zero matches):
1. **createCheckoutSession** — Required for Stripe Checkout UI (hosted payment page)
2. **createBillingPortalSession** — Required for customer self-service (cancel/upgrade subscription)
3. **syncSubscriptionToFirestore** — Helper to consolidate subscription sync logic

**❌ Missing Test Infrastructure**:
- Webhook replay script (tools/stripe_webhook_replay.js)
- Sample webhook payloads (tools/stripe_samples/*.json)

**❌ Missing Documentation**:
- Secrets setup guide (non-interactive + fallback approaches)
- Integration guide (frontend → checkout → webhook flow)

## Implementation Approach

### Minimal Path to Production

**Philosophy**: Reuse existing patterns, add only what's missing, deploy with proven non-PTY gate.

### Phase 1: Implement Missing Functions

**1.1 createCheckoutSession (Callable Function)**

```typescript
export const createCheckoutSession = functions
  .region('us-central1')
  .runWith({ memory: '256MB', timeoutSeconds: 60, minInstances: 0, maxInstances: 10 })
  .https.onCall(async (data: { priceId: string, successUrl: string, cancelUrl: string }, context) => {
    // Auth validation
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    
    const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
    const stripe = new Stripe(stripeKey, { apiVersion: '2024-04-10' });
    
    const db = getDb();
    const merchantDoc = await db.collection('merchants').doc(context.auth.uid).get();
    let stripeCustomerId = merchantDoc.data()?.stripe_customer_id;
    
    // Create customer if needed
    if (!stripeCustomerId) {
      const customer = await stripe.customers.create({
        email: merchantDoc.data()?.email,
        metadata: { firebaseUid: context.auth.uid }
      });
      stripeCustomerId = customer.id;
      await db.collection('merchants').doc(context.auth.uid).update({ stripe_customer_id: stripeCustomerId });
    }
    
    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: stripeCustomerId,
      mode: 'subscription',
      line_items: [{ price: data.priceId, quantity: 1 }],
      success_url: data.successUrl,
      cancel_url: data.cancelUrl,
      metadata: { firebaseUid: context.auth.uid }
    });
    
    return { success: true, sessionId: session.id, url: session.url };
  });
```

**1.2 createBillingPortalSession (Callable Function)**

```typescript
export const createBillingPortalSession = functions
  .region('us-central1')
  .runWith({ memory: '256MB', timeoutSeconds: 60, minInstances: 0, maxInstances: 10 })
  .https.onCall(async (data: { returnUrl: string }, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    
    const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
    const stripe = new Stripe(stripeKey, { apiVersion: '2024-04-10' });
    
    const db = getDb();
    const merchantDoc = await db.collection('merchants').doc(context.auth.uid).get();
    const stripeCustomerId = merchantDoc.data()?.stripe_customer_id;
    
    if (!stripeCustomerId) {
      throw new functions.https.HttpsError('failed-precondition', 'No Stripe customer found');
    }
    
    const session = await stripe.billingPortal.sessions.create({
      customer: stripeCustomerId,
      return_url: data.returnUrl
    });
    
    return { success: true, url: session.url };
  });
```

**1.3 syncSubscriptionToFirestore (Internal Helper)**

Consolidates duplicate sync logic from webhook handlers into single function:

```typescript
async function syncSubscriptionToFirestore(subscription: any, db: admin.firestore.Firestore) {
  const subscriptionData = {
    stripe_subscription_id: subscription.id,
    stripe_customer_id: subscription.customer,
    status: subscription.status,
    current_period_start: admin.firestore.Timestamp.fromDate(new Date(subscription.current_period_start * 1000)),
    current_period_end: admin.firestore.Timestamp.fromDate(new Date(subscription.current_period_end * 1000)),
    cancel_at_period_end: subscription.cancel_at_period_end,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  // Update subscriptions collection
  const query = await db.collection('subscriptions')
    .where('stripe_subscription_id', '==', subscription.id)
    .limit(1)
    .get();
  
  if (!query.empty) {
    await query.docs[0].ref.update(subscriptionData);
    const subDoc = query.docs[0].data();
    
    // Update merchant document
    await db.collection('merchants').doc(subDoc.merchant_id).update({
      subscription_status: subscription.status,
      subscription_updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}
```

### Phase 2: Secrets Setup Guide

**File**: `docs/STRIPE_SECRETS_SETUP.md`

**Required Secrets**:
- `STRIPE_SECRET_KEY` (sk_test_* or sk-live-*)
- `STRIPE_WEBHOOK_SECRET` (whsec_* from Stripe Dashboard)

**Non-Interactive Approach** (PTY-safe):
```bash
echo "sk_test_XXXXX" | firebase functions:secrets:set STRIPE_SECRET_KEY --project urbangenspark --data-file /dev/stdin
echo "whsec_XXXXX" | firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project urbangenspark --data-file /dev/stdin
```

**Interactive Fallback**:
```bash
firebase login
firebase functions:secrets:set STRIPE_SECRET_KEY --project urbangenspark  # prompts for value
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project urbangenspark
```

**Verification**:
```bash
firebase functions:secrets:access STRIPE_SECRET_KEY --project urbangenspark  # should show "sk_test_*" prefix
```

### Phase 3: Deployment Gate

**File**: `tools/stripe_phase_gate_hard.sh`

**Pattern**: Copy `prod_deploy_gate_hard.sh`, modify deploy command:

```bash
hard_timeout 300 firebase deploy \
  --only functions:stripeWebhook,functions:initiatePaymentCallable,functions:createCheckoutSession,functions:createBillingPortalSession \
  --project urbangenspark
```

**Evidence Output**: `docs/evidence/production_gate/<UTC_TS>/stripe_phase_gate/`

**Verdict Criteria**:
- All 4 functions deployed (smoking gun: "✔ functions[...]: Successful create operation")
- functions:list shows all 4 functions
- Exit code 0

### Phase 4: Test Harness

**File**: `tools/stripe_webhook_replay.js`

**Purpose**: POST sample webhook events to local emulator or production endpoint

**Sample Payloads** (tools/stripe_samples/):
- `checkout_session_completed.json`
- `customer_subscription_created.json`
- `invoice_payment_succeeded.json`

## Risk Assessment

**Low Risk**:
- ✅ Existing webhook infrastructure is production-ready (signature verification, idempotency)
- ✅ Existing initiatePayment pattern proven to work (already deployed)
- ✅ Non-PTY deployment gate has 100% success rate (28s execution, 20+ functions deployed)

**Medium Risk**:
- ⚠️ Secrets must be configured before deployment (deployment will succeed but runtime calls will fail)
- ⚠️ Webhook endpoint must be registered in Stripe Dashboard (manual step)

**Mitigation**:
- Secrets guide includes verification step (firebase functions:secrets:access)
- Deployment gate includes functions:list to verify runtime configuration
- Test harness allows local webhook validation before production

## Success Criteria

**Phase 1 Complete**:
- ✅ All 3 functions implemented in stripe.ts
- ✅ Functions exported from index.ts
- ✅ TypeScript compilation succeeds (tsc -p tsconfig.build.json)

**Phase 2 Complete**:
- ✅ STRIPE_SECRETS_SETUP.md created with non-interactive + fallback approaches

**Phase 3 Complete (GO Verdict)**:
- ✅ stripe_phase_gate_hard.sh executes in <60s
- ✅ All 4 Stripe functions deployed to urbangenspark
- ✅ Evidence folder created with SHA256SUMS.txt
- ✅ FINAL_STRIPE_GATE.md shows GO ✅

**Phase 4 Complete**:
- ✅ stripe_webhook_replay.js script created
- ✅ 3+ sample webhook payloads in stripe_samples/

## Next Steps

1. **Implement functions** (stripe.ts + index.ts exports)
2. **Write secrets guide** (STRIPE_SECRETS_SETUP.md)
3. **Create deployment gate** (stripe_phase_gate_hard.sh + wrapper)
4. **Run deployment** (tools/run_stripe_gate_wrapper.sh)
5. **Create test harness** (stripe_webhook_replay.js + samples)
6. **Update handover docs** (append Stripe Phase to PRODUCTION_GATE_FINAL_REPORT.md)

---

**Discovery Complete**: 2026-01-07T00:00:00Z  
**Implementation Start**: Awaiting user confirmation
