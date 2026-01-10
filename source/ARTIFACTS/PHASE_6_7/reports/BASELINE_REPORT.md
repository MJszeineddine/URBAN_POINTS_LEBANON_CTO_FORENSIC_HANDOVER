# PHASE 6-7 BASELINE REPORT
**Date:** 2026-01-03 08:09 UTC  
**Repository:** `/home/user/urbanpoints-lebanon-complete-ecosystem`  
**Phase:** Pre-Production Configuration & Backend Test Fixes

---

## REPOSITORY STRUCTURE VERIFICATION ✅

**Confirmed Repo Root:** `/home/user/urbanpoints-lebanon-complete-ecosystem`

**Top-Level Structure:**
```
apps/
  mobile-customer/
  mobile-merchant/
  mobile-admin/
  web-admin/
backend/
  firebase-functions/
  rest-api/
infra/
  firestore.rules
  firestore.indexes.json
  firebase.json
  .firebaserc
```

**Artifact Location:** `ARTIFACTS/PHASE_6_7/{logs,reports,diffs}/`

---

## BACKEND BASELINE

### Backend Test Results
**Command:** `cd backend/firebase-functions && npm test`  
**Exit Code:** `1` (FAILED)  
**Log:** `logs/backend_test_baseline.log`

**Summary:**
- **Total Tests:** 210
- **Passed:** 197
- **Failed:** 13
- **Test Suites:** 5 failed, 11 passed, 16 total
- **Coverage:** 76.51% statements, 80.69% branches, 83.33% functions

### Failing Tests Breakdown

#### 1. Payment Webhooks (4 failures)
**File:** `src/__tests__/paymentWebhooks.test.ts`

**Failures:**
1. ✗ `should process valid completed payment` - NOT_FOUND: no entity to update for customers
2. ✗ `should process valid whish payment` - NOT_FOUND: no entity to update for customers
3. ✗ `should process valid card payment` - NOT_FOUND: no entity to update for customers
4. ✗ `should activate subscription for subscription payment` - NOT_FOUND: no entity to update for customers

**Root Cause:** Tests expect customer documents to exist but aren't creating them first. All failures show:
```
5 NOT_FOUND: no entity to update: app: "dev~urbangenspark-test"
path < Element { type: "customers" ...
```

---

#### 2. Push Campaigns (5 failures)
**File:** `src/__tests__/pushCampaigns.test.ts`

**Failures:**
1. ✗ `should handle FCM send failures` - Expected: 1, Received: 0
2. ✗ `should handle batch sending with multiple tokens` - Expected: 1, Received: 0
3. ✗ `should handle sendEachForMulticast throwing error` - Matcher error: received value must be a number or bigint
4. ✗ `should handle segment with subscription_plan criteria` - Expected: 1, Received: 0
5. ✗ `getAllUserIds should return all customer IDs` - Expected: 2, Received: 3

**Root Cause:**
- Test assertions expect specific counts but actual behavior differs
- Mock data setup may be incomplete or inconsistent
- Type errors in assertions (number vs bigint)

---

#### 3. Subscription Automation (2 failures)
**File:** `src/__tests__/subscriptionAutomation.test.ts`

**Failures:**
1. ✗ `should skip subscriptions without auto_renew` - TypeError: Cannot read properties of undefined (reading 'points_balance')
2. ✗ `should handle batch commit errors` - Expected: > 0, Received: 0

**Root Cause:**
- Customer document not created or returned as undefined
- Batch commit error handling not triggering as expected

---

#### 4. Admin Branches (2 failures)
**File:** `src/__tests__/admin.branches.test.ts`

**Details:** Log truncated, need to inspect full test output

---

### Backend Build
**Command:** `cd backend/firebase-functions && npm run build`  
**Exit Code:** `0` (SUCCESS)  
**Log:** `logs/backend_build_baseline.log`  
**Result:** TypeScript compilation successful ✅

---

## FLUTTER APPS BASELINE

### Customer App
**Command:** `cd apps/mobile-customer && flutter analyze`  
**Exit Code:** `1` (ISSUES FOUND)  
**Log:** `logs/customer_analyze_baseline.log`

**Issues Found:** 17
- **Errors:** 1
  - `argument_type_not_assignable` - String can't be assigned to DateTime parameter
- **Warnings:** 7
  - Dead code, dead null-aware expressions, unnecessary null checks, unused imports
- **Info:** 9
  - `use_build_context_synchronously` warnings (6 occurrences)
  - `avoid_types_as_parameter_names` (1)
  - `depend_on_referenced_packages` (1)
  - `unnecessary_non_null_assertion` (1)

**Critical Error Location:**
```
lib/screens/offer_detail_screen.dart:303:39 - argument_type_not_assignable
The argument type 'String' can't be assigned to the parameter type 'DateTime'.
```

---

### Merchant App
**Command:** `cd apps/mobile-merchant && flutter analyze`  
**Exit Code:** `1` (ISSUES FOUND)  
**Log:** `logs/merchant_analyze_baseline.log`

**Issues Found:** 32
- **Errors:** 11
  - `undefined_getter` - The getter 'status' isn't defined for type 'Offer' (multiple occurrences in `my_offers_screen.dart`)
- **Warnings:** 14
  - `unused_import`, deprecated `withOpacity()` usage
- **Info:** 7
  - `deprecated_member_use`, `depend_on_referenced_packages`

**Critical Errors:**
- `lib/screens/my_offers_screen.dart` - Multiple references to non-existent `offer.status` field

---

### Admin App
**Command:** `cd apps/mobile-admin && flutter analyze`  
**Exit Code:** `1` (ISSUES FOUND)  
**Log:** `logs/admin_analyze_baseline.log`

**Issues Found:** 3 ✅ (CLEANEST APP)
- **Warnings:** 1
  - `unused_import` in test file
- **Info:** 2
  - `avoid_types_as_parameter_names` (2 occurrences)

**Status:** Admin app has minimal issues, mostly code style warnings

---

## SUMMARY

### Backend
- ✅ Compiles successfully
- ❌ 13 failing tests across 5 test suites
- 🎯 **Fix Target:** Payment webhooks (4), Push campaigns (5), Subscription automation (2), Admin branches (2)

### Flutter Apps
- ✅ All apps compile and build (web builds successful from previous session)
- ❌ Customer app: 17 analyze issues (1 error)
- ❌ Merchant app: 32 analyze issues (11 errors)
- ✅ Admin app: 3 analyze issues (no errors)

---

## NEXT STEPS

**Phase 2:** Production Environment Configuration
- Identify all .env placeholders (QR_TOKEN_SECRET, STRIPE, OMT, WHISH, TWILIO, SLACK)
- Create .env.example files
- Document production config requirements

**Phase 3:** Fix Failing Backend Tests
- Fix customer document creation in payment webhook tests
- Fix push campaign mock data and assertions
- Fix subscription automation customer document handling
- Ensure 100% test pass rate

**Phase 4:** Fix Flutter Analyze Issues
- Fix customer app DateTime type error
- Add 'status' field to Offer model or remove references
- Clean up unused imports and deprecated code

---

**END OF BASELINE REPORT**
