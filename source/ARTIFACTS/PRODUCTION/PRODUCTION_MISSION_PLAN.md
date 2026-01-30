# Urban Points Lebanon - Production Readiness Mission

## Mission Control Document
**Generated:** 2026-01-03T19:30:00+00:00  
**Target:** 95% Production Readiness  
**Status:** 🔴 EXECUTING

---

## Current State Assessment

### ✅ COMPLETED (Days 1-3)
- Firebase Auth integration (100%)
- Role-based access control (100%)
- Custom claims & token refresh (100%)
- Auth state management (100%)
- Mobile apps wired to auth (100%)

### ⚠️ PARTIAL (Needs Completion)
- Points system (40% - basic award only)
- QR validation (70% - core works, needs transactions)
- Payment webhooks (60% - code exists, disabled)
- Subscription automation (50% - code exists, scheduled disabled)
- Offers system (30% - approve/reject only)
- Testing (5% - 16 test files, ~3 real tests)

### ❌ MISSING (Critical Blockers)
- **Points Engine:** processPointsEarning(), processRedemption(), getPointsBalance()
- **Offers Engine:** createOffer(), updateOfferStatus(), handleOfferExpiration()
- **Firestore Transactions:** atomic operations everywhere
- **Replay Protection:** idempotency keys for all mutations
- **Audit Logging:** full audit trail
- **Stripe Integration:** end-to-end subscription flow
- **Comprehensive Tests:** unit + integration coverage

---

## Mission Phases

### **PHASE 1: Business Logic (Core Engine)**
**Target:** 8 hours | **Priority:** CRITICAL

#### 1A. Points Engine (3 hours)
**File:** `backend/firebase-functions/src/core/points.ts`

```typescript
// MUST IMPLEMENT:
export async function processPointsEarning(
  data: { customerId, merchantId, offerId, amount, redemptionId },
  context,
  deps: { db }
): Promise<EarningResponse>

export async function processRedemption(
  data: { customerId, offerId, qrToken },
  context,
  deps: { db }
): Promise<RedemptionResponse>

export async function getPointsBalance(
  data: { customerId },
  context,
  deps: { db }
): Promise<BalanceResponse>
```

**Requirements:**
- ✅ Firestore transactions for balance updates
- ✅ Idempotency via redemptionId (prevent double-earn)
- ✅ Balance breakdown (earned/spent/expired)
- ✅ Atomic operations (all-or-nothing)
- ✅ Real-time balance sync

**Success Criteria:**
- Cannot earn same redemption twice
- Balance always accurate (transaction-safe)
- Breakdown query < 500ms

#### 1B. Offers Engine (3 hours)
**File:** `backend/firebase-functions/src/core/offers.ts` (NEW)

```typescript
// MUST IMPLEMENT:
export async function createOffer(
  data: { merchantId, title, description, pointsValue, quota, validUntil },
  context,
  deps: { db }
): Promise<OfferResponse>

export async function updateOfferStatus(
  data: { offerId, status },
  context,
  deps: { db }
): Promise<StatusResponse>

export async function handleOfferExpiration(
  deps: { db }
): Promise<ExpirationResponse>

export async function aggregateOfferStats(
  data: { offerId },
  context,
  deps: { db }
): Promise<StatsResponse>
```

**Requirements:**
- ✅ Validation: quota > 0, validUntil > now
- ✅ Status flow: draft → pending → active → expired/cancelled
- ✅ Expiration cleanup (manual trigger for now)
- ✅ Stats: redemptions count, revenue impact

**Success Criteria:**
- Offers follow approval workflow
- Expired offers auto-marked
- Stats aggregation < 1s

#### 1C. Data Guarantees (2 hours)
**Files:** All mutation functions

**Requirements:**
- ✅ Replace all `db.collection().add()` with transactions
- ✅ Add idempotency keys to redemptions, payments, points
- ✅ Create audit_logs collection for every mutation
- ✅ Replay protection: check idempotency key before operation

**Implementation:**
```typescript
// Pattern for all mutations:
await db.runTransaction(async (t) => {
  // Check idempotency
  const existingOp = await t.get(idempotencyRef);
  if (existingOp.exists) return existingOp.data().result;
  
  // Perform operation
  // ...
  
  // Log audit
  t.set(auditRef, { operation, userId, timestamp, data });
  
  // Save idempotency record
  t.set(idempotencyRef, { result, timestamp });
});
```

**Success Criteria:**
- All mutations wrapped in transactions
- Audit log for every change
- Idempotent operations (safe to retry)

---

### **PHASE 2: Payments (Revenue Blocker)**
**Target:** 6 hours | **Priority:** CRITICAL

#### 2A. Stripe Subscriptions (2 hours)
**File:** `backend/firebase-functions/src/stripe.ts` (NEW)

```typescript
// MUST IMPLEMENT:
export async function initiatePayment(merchantId, planId)
export async function createCustomer(userId, email)
export async function createSubscription(customerId, planId, paymentMethodId)
export async function verifyPaymentStatus(subscriptionId)
```

**Requirements:**
- ✅ Stripe API integration (use stripe package)
- ✅ Customer creation in Stripe
- ✅ Subscription creation with payment method
- ✅ Payment intent confirmation
- ✅ Store Stripe IDs in Firestore

#### 2B. Webhooks (2 hours)
**File:** `backend/firebase-functions/src/stripe.ts`

```typescript
// MUST IMPLEMENT:
export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  // Verify signature
  // Handle: subscription.created, subscription.updated, subscription.deleted
  // Handle: payment_succeeded, payment_failed
});
```

**Requirements:**
- ✅ Signature verification (Stripe webhook secret)
- ✅ Idempotent webhook handling (check processed_webhooks collection)
- ✅ Update subscription status in Firestore
- ✅ Send notifications on status change

#### 2C. Access Control (2 hours)
**Files:** `backend/firebase-functions/src/core/*.ts`

**Requirements:**
- ✅ Check subscription status before offer creation
- ✅ Block merchant features if subscription inactive
- ✅ Grace period: 3 days after expiry
- ✅ Automatic downgrade on payment failure

**Implementation:**
```typescript
async function checkSubscriptionAccess(merchantId: string, db) {
  const sub = await getActiveSubscription(merchantId, db);
  if (!sub) throw new functions.https.HttpsError('permission-denied', 'No active subscription');
  
  // Check grace period
  const gracePeriodEnd = new Date(sub.end_date.toDate());
  gracePeriodEnd.setDate(gracePeriodEnd.getDate() + 3);
  if (new Date() > gracePeriodEnd) {
    throw new functions.https.HttpsError('permission-denied', 'Subscription expired');
  }
  return sub;
}
```

---

### **PHASE 3: Tests (Non-Negotiable)**
**Target:** 6 hours | **Priority:** CRITICAL

#### 3A. Backend Tests (4 hours)
**Directory:** `backend/firebase-functions/src/__tests__/`

**Coverage Required:**
```typescript
// points.test.ts
describe('Points Engine', () => {
  test('prevents double-earning same redemption')
  test('atomic balance updates')
  test('breakdown query performance')
});

// offers.test.ts
describe('Offers Engine', () => {
  test('creates offer with validation')
  test('status transitions follow workflow')
  test('expiration marking')
});

// stripe.test.ts
describe('Stripe Integration', () => {
  test('webhook signature verification')
  test('idempotent webhook handling')
  test('subscription status sync')
});

// integration.test.ts
describe('End-to-End Flows', () => {
  test('customer redemption flow')
  test('merchant offer creation flow')
  test('subscription payment flow')
});
```

**Requirements:**
- ✅ Minimum 80% code coverage
- ✅ All critical paths tested
- ✅ Mock Firestore with firebase-functions-test
- ✅ Mock Stripe API calls

#### 3B. Mobile Tests (1 hour)
**Files:** `apps/*/test/*_test.dart`

**Coverage Required:**
```dart
// auth_flow_test.dart
testWidgets('login and role validation', (tester) async {
  // Test auth flow
});

// points_test.dart
testWidgets('points earning and redemption', (tester) async {
  // Test points UI
});

// subscription_test.dart
testWidgets('subscription gating', (tester) async {
  // Test subscription checks
});
```

#### 3C. CI/CD Gates (1 hour)
**File:** `.github/workflows/fullstack-ci.yml`

**Requirements:**
- ✅ Run backend tests on every commit
- ✅ Fail pipeline if coverage < 80%
- ✅ Run mobile tests on every commit
- ✅ Block merge if any test fails

---

## Success Criteria

### ✅ MUST HAVE (Blockers)
- [ ] 0 known functional gaps
- [ ] Payments working end-to-end
- [ ] Points economy stable (transactions + idempotency)
- [ ] Tests passing (backend + mobile)
- [ ] Production readiness ≥ 95%

### ⚠️ SHOULD HAVE
- [ ] Audit logs for all mutations
- [ ] Webhook signature verification
- [ ] Grace period handling
- [ ] Expiration cleanup

### 💚 NICE TO HAVE
- [ ] Performance optimization
- [ ] Monitoring dashboards
- [ ] Error alerting

---

## Deliverables (Required on Disk)

### `/ARTIFACTS/PRODUCTION/`
1. **BUSINESS_LOGIC_REPORT.md**
   - What was implemented
   - Proof (function names, file paths, line counts)
   - Remaining risks
   - Manual test evidence

2. **PAYMENTS_REPORT.md**
   - Stripe integration details
   - Webhook implementation
   - End-to-end test proof
   - Subscription flow diagram

3. **TEST_COVERAGE_REPORT.md**
   - Test files created
   - Coverage percentages
   - CI/CD configuration
   - Test run logs

4. **FINAL_GO_NO_GO.md**
   - Production readiness score (target: ≥ 95%)
   - Remaining blockers (if any)
   - Risk assessment
   - GO/NO-GO decision with reasoning

---

## Rollback Plan

If any phase fails or blockers appear:

1. **STOP immediately**
2. **DO NOT deploy**
3. **Create NO-GO report** with:
   - Exact blocker description
   - Why it blocks production
   - Prerequisites to resolve
   - Estimated time to fix

---

## Execution Timeline

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| 1A. Points Engine | 3h | T+0 | T+3 |
| 1B. Offers Engine | 3h | T+3 | T+6 |
| 1C. Data Guarantees | 2h | T+6 | T+8 |
| 2A. Subscriptions | 2h | T+8 | T+10 |
| 2B. Webhooks | 2h | T+10 | T+12 |
| 2C. Access Control | 2h | T+12 | T+14 |
| 3A. Backend Tests | 4h | T+14 | T+18 |
| 3B. Mobile Tests | 1h | T+18 | T+19 |
| 3C. CI/CD | 1h | T+19 | T+20 |
| Final Reports | 1h | T+20 | T+21 |

**Total: 21 hours**

---

## Next Action

**EXECUTE PHASE 1A: Points Engine Implementation**

Starting with:
1. Create `processPointsEarning()` with transactions
2. Implement idempotency via redemptionId
3. Add `getPointsBalance()` with breakdown
4. Test double-earn prevention

**Command:** Begin implementation...

