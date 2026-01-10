# 🗺️ BLUEPRINT MAP: COMPLETION PHASES

**Current State:** 72% Complete  
**Target:** 95% Production-Ready  
**Estimated Effort:** 80-120 hours (2-3 weeks full-time)

---

## 📊 PHASE BREAKDOWN

### **Phase 0: Unblock Deployment** (CRITICAL - Week 1)
**Status:** ⚠️ **BLOCKED**  
**Effort:** 8-16 hours  
**Priority:** 🔴 **HIGHEST**

**Objective:** Remove deployment blockers

**Tasks:**
1. **Resolve Firebase Deployment Permissions**
   - **Current Issue:** 403 error on `firebase functions:config:get`
   - **Action Required:** Grant service account permissions
   - **Owner:** DevOps/Infrastructure
   - **Evidence:** `/ARTIFACTS/ZERO_GAPS/PHASE2_STRIPE_CONFIG_REPORT.md`

2. **Configure Stripe Secrets**
   - **File:** Manual configuration via Firebase Console
   - **Required:**
     - `STRIPE_SECRET_KEY` (from Stripe Dashboard)
     - `STRIPE_WEBHOOK_SECRET` (from Stripe Dashboard)
   - **Alternative:** Use `functions.config().stripe.*` (legacy)
   - **Evidence:** `stripe.ts` line 115, 390

3. **Deploy Stripe Webhook Function**
   ```bash
   cd backend/firebase-functions
   firebase deploy --only functions:stripeWebhook
   ```
   - **Expected URL:** `https://us-central1-urbangenspark.cloudfunctions.net/stripeWebhook`

4. **Register Webhook in Stripe Dashboard**
   - **URL:** (from step 3)
   - **Events:** subscription.created, subscription.updated, subscription.deleted, invoice.payment_succeeded, invoice.payment_failed
   - **Copy:** Webhook signing secret to Firebase

5. **Test Stripe Integration**
   ```bash
   stripe trigger payment_intent.succeeded --forward-to [webhook-url]
   ```
   - **Success Criteria:** Webhook processed, subscription synced to Firestore

**Completion Criteria:**
- ✅ Firebase deployment succeeds
- ✅ Stripe webhook responds with 200 OK
- ✅ Test payment creates subscription in Firestore
- ✅ `checkSubscriptionAccess()` returns correct status

**Blockers If Not Done:**
- ❌ Payments completely broken
- ❌ Merchant subscriptions non-functional
- ❌ Cannot progress to Phase 1

---

### **Phase 1: Mobile Backend Integration** (Week 2)
**Status:** ⚠️ **NOT STARTED**  
**Effort:** 24-40 hours  
**Priority:** 🔴 **HIGH**  
**Depends On:** Phase 0 complete

**Objective:** Wire mobile apps to Cloud Functions

**Tasks:**

#### **1. Customer App Integration** (12-20 hours)

**File:** `apps/mobile-customer/lib/services/auth_service.dart`

**Add Methods:**
```dart
// Line 310+ (after existing methods)

// 1. Earn points
Future<Map<String, dynamic>> earnPoints({
  required String merchantId,
  required String offerId,
  required int amount,
  required String redemptionId,
}) async {
  final callable = _functions.httpsCallable('earnPoints');
  final result = await callable.call({
    'customerId': currentUser!.uid,
    'merchantId': merchantId,
    'offerId': offerId,
    'amount': amount,
    'redemptionId': redemptionId,
  });
  return result.data;
}

// 2. Redeem points
Future<Map<String, dynamic>> redeemPoints({
  required String offerId,
  required String qrToken,
  required String merchantId,
}) async {
  final callable = _functions.httpsCallable('redeemPoints');
  final result = await callable.call({
    'customerId': currentUser!.uid,
    'offerId': offerId,
    'qrToken': qrToken,
    'merchantId': merchantId,
  });
  return result.data;
}

// 3. Get points balance
Future<Map<String, dynamic>> getPointsBalance() async {
  final callable = _functions.httpsCallable('getBalance');
  final result = await callable.call({
    'customerId': currentUser!.uid,
  });
  return result.data;
}

// 4. Get points history
Future<List<Map<String, dynamic>>> getPointsHistory() async {
  // Query redemptions collection directly (backend doesn't have history function)
  final snapshot = await _firestore
      .collection('redemptions')
      .where('customer_id', isEqualTo: currentUser!.uid)
      .orderBy('created_at', descending: true)
      .limit(50)
      .get();
  return snapshot.docs.map((doc) => doc.data()).toList();
}
```

**Wire Screens:**
- `screens/offers_list_screen.dart` - Use getPointsBalance()
- `screens/offer_detail_screen.dart` - Use redeemPoints()
- `screens/points_history_screen.dart` - Use getPointsHistory()
- `screens/qr_generation_screen.dart` - Use backend generateSecureQRToken

**Error Handling:**
```dart
try {
  final result = await earnPoints(...);
  if (result['success']) {
    // Success UI
  } else {
    // Show error: result['error']
  }
} on FirebaseFunctionsException catch (e) {
  // Handle specific errors (unauthenticated, resource-exhausted, invalid-argument)
} catch (e) {
  // Generic error
}
```

#### **2. Merchant App Integration** (12-20 hours)

**File:** `apps/mobile-merchant/lib/services/auth_service.dart`

**Add Methods:**
```dart
// Line 310+ (after existing methods)

// 1. Check subscription access
Future<Map<String, dynamic>> checkSubscriptionAccess() async {
  final callable = _functions.httpsCallable('checkSubscriptionAccess');
  final result = await callable.call({
    'merchantId': currentUser!.uid,
  });
  return result.data;
}

// 2. Create offer
Future<Map<String, dynamic>> createOffer({
  required String title,
  required String description,
  required int pointsValue,
  required int quota,
  required DateTime validFrom,
  required DateTime validUntil,
  String? terms,
  String? category,
}) async {
  final callable = _functions.httpsCallable('createNewOffer');
  final result = await callable.call({
    'merchantId': currentUser!.uid,
    'title': title,
    'description': description,
    'pointsValue': pointsValue,
    'quota': quota,
    'validFrom': validFrom.toIso8601String(),
    'validUntil': validUntil.toIso8601String(),
    'terms': terms,
    'category': category,
  });
  return result.data;
}

// 3. Validate redemption (QR scan)
Future<Map<String, dynamic>> validateRedemption({
  required String qrToken,
  required String offerId,
}) async {
  final callable = _functions.httpsCallable('validateRedemption');
  final result = await callable.call({
    'qrToken': qrToken,
    'offerId': offerId,
    'merchantId': currentUser!.uid,
  });
  return result.data;
}

// 4. Get offer stats
Future<Map<String, dynamic>> getOfferStats(String offerId) async {
  final callable = _functions.httpsCallable('getOfferStats');
  final result = await callable.call({
    'offerId': offerId,
  });
  return result.data;
}
```

**Wire Screens:**
- `screens/create_offer_screen.dart` - Add subscription check + createOffer()
- `screens/validate_redemption_screen.dart` - Add QR scanning + validateRedemption()
- `screens/merchant_analytics_screen.dart` - Use getOfferStats()

**Subscription Paywall:**
```dart
// In create_offer_screen.dart - before showing form
Future<void> _checkSubscriptionBeforeCreate() async {
  try {
    final result = await AuthService().checkSubscriptionAccess();
    if (!result['hasAccess']) {
      // Show subscription paywall
      _showSubscriptionModal();
      return;
    }
    // Proceed to offer creation
  } catch (e) {
    // Handle error
  }
}
```

**QR Scanning Integration:**
- **Package:** `qr_code_scanner: ^1.0.1` (add to pubspec.yaml)
- **Screen:** `screens/validate_redemption_screen.dart`
- **Logic:** Scan QR → extract token → call validateRedemption()

**Completion Criteria:**
- ✅ Customer can earn points end-to-end
- ✅ Customer can view points balance and history
- ✅ Merchant cannot create offers without subscription
- ✅ Merchant can scan QR and validate redemptions
- ✅ All error cases handled gracefully

---

### **Phase 2: Testing & Quality Assurance** (Week 3)
**Status:** ⚠️ **6/40 TESTS COMPLETE**  
**Effort:** 40-60 hours  
**Priority:** 🔴 **CRITICAL**  
**Depends On:** Phase 0, 1 complete

**Objective:** Achieve 80% test coverage, fix critical bugs

**Tasks:**

#### **1. Backend Testing** (30-45 hours)

**Setup Firebase Emulators:**
```bash
cd backend/firebase-functions
firebase emulators:start --only firestore,auth
```

**Write Missing Tests:**

**A. Points Engine Tests** (6 existing + 4 new = 10 total)
- **File:** `src/__tests__/points.critical.test.ts`
- **Add:**
  - ✅ Concurrent earning (race condition test)
  - ✅ Total points earned tracking
  - ✅ Audit log creation
  - ✅ Transaction failure handling

**B. Offers Engine Tests** (0 existing + 8 new = 8 total)
- **File:** `src/__tests__/offers.test.ts` (create new)
- **Add:**
  - ✅ Create offer with valid data
  - ✅ Reject offer without merchant auth
  - ✅ Status transitions (draft → pending → active)
  - ✅ Admin approval workflow
  - ✅ Offer expiration
  - ✅ Subscription enforcement
  - ✅ Offer stats calculation
  - ✅ Quota management

**C. Redemption Tests** (0 existing + 6 new = 6 total)
- **File:** `src/__tests__/redemption.test.ts` (create new)
- **Add:**
  - ✅ Valid QR token redemption
  - ✅ Expired QR token rejection
  - ✅ Reused QR token rejection
  - ✅ Wrong merchant QR rejection
  - ✅ Balance update after redemption
  - ✅ Audit log creation

**D. Stripe Integration Tests** (0 existing + 8 new = 8 total)
- **File:** `src/__tests__/stripe.test.ts` (create new)
- **Add:**
  - ✅ Webhook signature verification
  - ✅ Invalid signature rejection
  - ✅ subscription.created event
  - ✅ subscription.updated event
  - ✅ subscription.deleted event
  - ✅ Firestore subscription sync
  - ✅ Merchant status update
  - ✅ Idempotency (duplicate events)

**E. Integration Tests** (0 existing + 8 new = 8 total)
- **File:** `src/__tests__/integration.test.ts` (enhance existing)
- **Add:**
  - ✅ Auth → user doc → claims → profile
  - ✅ Sign in → token → verify claims
  - ✅ Merchant without subscription → block offer
  - ✅ Merchant with subscription → create → approve → active
  - ✅ Customer earn → balance → redeem
  - ✅ Insufficient points → reject redemption
  - ✅ Payment → webhook → subscription active
  - ✅ End-to-end redemption flow

**Run Tests:**
```bash
firebase emulators:exec "npm test"
```

**Success Criteria:**
- ✅ 40+ tests passing
- ✅ 80%+ code coverage
- ✅ All edge cases covered
- ✅ Zero flaky tests

#### **2. Mobile Testing** (10-15 hours)

**Customer App Tests:**
- ✅ Auth flow (signup, signin, signout)
- ✅ Points earning flow
- ✅ Points balance display
- ✅ Points history display
- ✅ Offer redemption flow
- ✅ Error handling (network failures)

**Merchant App Tests:**
- ✅ Auth flow
- ✅ Subscription check
- ✅ Offer creation flow
- ✅ QR scanning
- ✅ Redemption validation
- ✅ Analytics display

**Manual Testing:**
- Real device testing (Android)
- Network offline/online scenarios
- Edge cases (expired tokens, insufficient points)

**Completion Criteria:**
- ✅ All backend tests pass
- ✅ 80%+ coverage achieved
- ✅ Mobile flows work end-to-end
- ✅ No critical bugs remain

---

### **Phase 3: Production Hardening** (Week 4)
**Status:** ⚠️ **NOT STARTED**  
**Effort:** 16-24 hours  
**Priority:** 🟡 **MEDIUM**  
**Depends On:** Phase 0, 1, 2 complete

**Objective:** Make system production-ready

**Tasks:**

#### **1. Deploy Rate Limiting** (2-4 hours)
- **Status:** Code exists, not wired
- **Action:** Validation integration complete (Day 2), just deploy
- **Test:** Exceed rate limits, verify 429 responses

#### **2. Deploy Input Validation** (0 hours)
- **Status:** ✅ **COMPLETE** (Day 2)
- **Deployed:** 4/15 functions validated
- **Action:** Add validation to remaining 11 functions (if needed)

#### **3. Security Hardening** (4-6 hours)
- **Firestore Rules:** Review and harden `/infra/firestore.rules`
- **Auth Rules:** Verify role-based access controls
- **API Keys:** Rotate and secure all keys
- **Secrets:** Use Firebase Secrets Manager (not legacy config)

#### **4. Monitoring & Alerts** (4-6 hours)
- **Logging:** Verify all critical operations log to Cloud Logging
- **Sentry:** Configure Sentry for error tracking (code exists in `monitoring.ts`)
- **Alerts:** Set up alerts for:
  - Failed payments
  - High error rates
  - Low subscription conversion

#### **5. CI/CD Pipeline** (6-8 hours)
- **File:** `.github/workflows/fullstack-ci.yml`
- **Add:**
  - Run `firebase emulators:exec "npm test"` before deploy
  - Block deploy on test failures
  - Run `flutter test` for mobile apps
  - Store test artifacts

**Example Workflow:**
```yaml
name: Full-Stack CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  backend-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install Firebase CLI
        run: npm install -g firebase-tools
      - name: Install dependencies
        run: cd backend/firebase-functions && npm install
      - name: Run tests with emulators
        run: cd backend/firebase-functions && firebase emulators:exec "npm test"
      - name: Upload coverage
        uses: codecov/codecov-action@v3

  backend-deploy:
    needs: backend-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Firebase
        run: firebase deploy --only functions
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}

  mobile-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.4'
      - name: Test Customer App
        run: cd apps/mobile-customer && flutter test
      - name: Test Merchant App
        run: cd apps/mobile-merchant && flutter test
```

**Completion Criteria:**
- ✅ Rate limiting deployed and tested
- ✅ Firestore rules hardened
- ✅ Monitoring configured
- ✅ CI/CD pipeline working
- ✅ All tests run before deploy

---

### **Phase 4: Soft Launch** (Week 4-5)
**Status:** ⚠️ **NOT STARTED**  
**Effort:** 8-16 hours  
**Priority:** 🟡 **MEDIUM**  
**Depends On:** Phase 0, 1, 2, 3 complete

**Objective:** Launch with limited users, gather feedback

**Tasks:**

#### **1. Production Deployment Checklist**
- ✅ All tests passing (40+)
- ✅ Stripe configured in production mode
- ✅ Firestore rules reviewed
- ✅ Monitoring configured
- ✅ Backup strategy in place
- ✅ Rollback plan documented

#### **2. Soft Launch Plan**
- **Users:** 10-50 test users (5-10 merchants, 20-40 customers)
- **Duration:** 1-2 weeks
- **Monitoring:** Daily error logs, user feedback
- **Metrics:** Signup rate, redemption rate, error rate

#### **3. User Onboarding**
- **Merchants:** Manual onboarding, subscription setup
- **Customers:** Invite-only links
- **Support:** Email support, feedback form

#### **4. Success Criteria**
- ✅ Zero critical bugs
- ✅ 80%+ successful redemptions
- ✅ <5% error rate
- ✅ Positive user feedback
- ✅ At least 3 paying merchants

**Completion Criteria:**
- ✅ Soft launch completed
- ✅ Bugs fixed
- ✅ Feedback incorporated
- ✅ Ready for public launch

---

## 📊 PHASE SUMMARY

| Phase | Status | Effort | Priority | Blockers |
|-------|--------|--------|----------|----------|
| **Phase 0: Unblock** | ⚠️ BLOCKED | 8-16h | 🔴 HIGHEST | Firebase permissions |
| **Phase 1: Mobile** | ⚠️ READY | 24-40h | 🔴 HIGH | Phase 0 |
| **Phase 2: Testing** | 🟡 15% | 40-60h | 🔴 CRITICAL | Phase 0, 1 |
| **Phase 3: Hardening** | ⚠️ READY | 16-24h | 🟡 MEDIUM | Phase 2 |
| **Phase 4: Launch** | ⚠️ READY | 8-16h | 🟡 MEDIUM | Phase 3 |

**Total Effort:** 96-156 hours (12-20 working days)  
**Critical Path:** Phase 0 → 1 → 2 → 3 → 4

---

## 🚨 RISK CONCENTRATION

### **Highest Risk:**
1. **Phase 0 blocked** - Cannot progress without deployment permissions
2. **Test coverage 15%** - Unknown bugs in production
3. **Mobile not integrated** - Core features non-functional

### **Medium Risk:**
1. **No CI/CD** - Manual deploys, human error
2. **No monitoring** - Cannot detect issues in production
3. **No rollback plan** - Recovery difficult if deploy fails

### **Low Risk:**
1. **Admin app missing** - Can use Firebase Console
2. **Documentation gaps** - Can fill in gradually
3. **Some dead code** - Doesn't affect functionality

---

## ✅ WHAT CAN BE SAFELY IGNORED

**For Launch:**
- ❌ Admin app (use Firebase Console)
- ❌ Push campaigns (not critical)
- ❌ SMS/OTP (use email auth only)
- ❌ Multi-language (English first)
- ❌ Advanced analytics (basic stats sufficient)
- ❌ Social features (not in MVP)

**For Later:**
- Multiple subscription tiers (single tier first)
- Gamification (not in code)
- Referral program (not in code)
- White-label/multi-tenant (single instance first)

---

## 🎯 REALISTIC COMPLETION TIMELINE

**Week 1:** Unblock deployment + Stripe configuration  
**Week 2:** Mobile backend integration  
**Week 3:** Testing (backend + mobile)  
**Week 4:** Production hardening + soft launch  

**Total:** **4-5 weeks to production-ready**

---

**Analysis Date:** 2026-01-04  
**Method:** Code-based effort estimation  
**Confidence:** 90% (assumes no major blockers beyond Phase 0)
