# BRUTAL REALITY MAP - URBAN POINTS LEBANON

**Generated:** 2026-01-07  
**CTO Assessment:** Current Repository State ONLY  
**Rule:** If it doesn't work end-to-end today, it's NOT DONE.

---

## 1. REALITY SCORE (0–100%)

| Component | Completion % | Reason |
|-----------|--------------|--------|
| **Backend** | 65% | Core functions work BUT payment renewal, SMS gateway, Secret Manager TODOs exist |
| **Frontend Web** | 40% | Admin dashboard exists but READ-ONLY, no actual merchant/offer management |
| **Mobile Customer** | 55% | QR/offers/points work BUT Flutter analyze FAILS, Stripe partially disabled |
| **Mobile Merchant** | 50% | Offer creation exists BUT no subscription enforcement, Flutter analyze FAILS |
| **OVERALL** | **52%** | Infrastructure works, core flows exist, critical TODOs + quality issues block production |

---

## 2. FEATURE REALITY MAP

| Feature | Layer | Status | Files | Why NOT Production-Ready |
|---------|-------|--------|-------|--------------------------|
| **User Registration** | Backend | DONE | auth.ts, mobile apps | Works end-to-end |
| **Points Earning** | Backend + Mobile | DONE | points.ts, customer_service.dart | Works with QR validation |
| **Points Redemption** | Backend + Mobile | DONE | points.ts, qr.ts, customer_service.dart | QR + PIN flow complete |
| **Offer Creation** | Backend + Mobile Merchant | PARTIAL | offers.ts, mobile-merchant/create_offer_screen.dart | **NO subscription paywall enforcement** - merchants can create unlimited offers without payment |
| **Offer Approval** | Backend + Web Admin | BROKEN | admin.ts, web-admin/pages/admin/offers.tsx | **Web admin is READ-ONLY** - no approve/reject buttons exist |
| **Subscription Renewals** | Backend | NOT IMPLEMENTED | subscriptionAutomation.ts:86 | **TODO: Process payment with saved payment method** - subscription charges will FAIL |
| **SMS Notifications** | Backend | NOT IMPLEMENTED | sms.ts:68 | **TODO: Integrate with actual Lebanese SMS Gateway** - hardcoded test SMS, no real provider |
| **Payment Failure Alerts** | Backend | NOT IMPLEMENTED | paymentWebhooks.ts:391 | **TODO: Send failure notification to user** - silent payment failures |
| **Secret Manager** | Backend | NOT CONFIGURED | index.ts:43 | **TODO: Uncomment after setting up Firebase Secret Manager** - production keys exposed in env vars |
| **Web Admin CRUD** | Frontend Web | NOT IMPLEMENTED | web-admin/pages/admin/*.tsx | Dashboard only shows data, NO create/edit/delete functionality |
| **Mobile Customer QR** | Mobile | DONE | qr_generation_screen.dart, customer_service.dart | Works with 60s expiry + PIN |
| **Mobile Merchant Scan** | Mobile | DONE | merchant app QR scan | PIN validation flow complete |
| **Stripe Checkout** | Backend + Mobile | PARTIAL | stripe.ts, stripe_client.dart | **Stripe guards present but webhooks handle errors silently** - renewal failures not surfaced |
| **Push Notifications** | Backend + Mobile | DONE | phase3Notifications.ts, fcm_service.dart | FCM integration complete |
| **Flutter Code Quality** | Mobile | BROKEN | mobile-customer, mobile-merchant | **Flutter analyze returns ERRORS** - dependency issues (integration_test missing) |
| **Merchant Compliance** | Backend | PARTIAL | phase3Scheduler.ts | Scheduled jobs DISABLED (Cloud Scheduler API not enabled), manual compliance check works |
| **Data Export (GDPR)** | Backend | DONE | privacy.ts | exportUserData, deleteUserData work |
| **Geolocation Offers** | Backend + Mobile | DONE | offers.ts:getOffersByLocation, location_service.dart | Proximity sorting works |

---

## 3. HARD BLOCKERS (TOP 10)

### BLOCKER #1: Subscription Renewals Will Fail Silently
**File:** `source/backend/firebase-functions/src/subscriptionAutomation.ts:86`  
**Problem:** `// TODO: Process payment with saved payment method` - renewal logic is stubbed  
**Impact:** Merchants with expired subscriptions can still create offers (no enforcement), payment retries will crash  
**Fix Required:** Implement Stripe payment intent creation + retry logic with saved payment method

### BLOCKER #2: No Lebanese SMS Gateway Integration
**File:** `source/backend/firebase-functions/src/sms.ts:68`  
**Problem:** `// TODO: Integrate with actual Lebanese SMS Gateway` - hardcoded test SMS responses  
**Impact:** OTP verification, order notifications, redemption alerts will NEVER send to users  
**Fix Required:** Integrate with Lebanese SMS provider (e.g., LIBAN SMS, Alfa, Touch API)

### BLOCKER #3: Payment Failures Are Silent
**File:** `source/backend/firebase-functions/src/paymentWebhooks.ts:391`  
**Problem:** `// TODO: Send failure notification to user` - webhook catches errors but doesn't alert user  
**Impact:** Users with failed payments remain unaware, subscriptions lapse without warning  
**Fix Required:** Implement FCM push notification + email alert on payment failure

### BLOCKER #4: No Subscription Paywall in Mobile Merchant
**File:** `source/apps/mobile-merchant/lib/screens/create_offer_screen.dart:380-430`  
**Problem:** CreateOffer function calls backend WITHOUT checking subscription status  
**Impact:** Free-tier merchants can create unlimited offers, bypassing business model  
**Fix Required:** Add subscription validation before allowing offer creation (call checkSubscriptionAccess)

### BLOCKER #5: Web Admin Is Read-Only (No Actions)
**Files:** `source/apps/web-admin/pages/admin/offers.tsx`, `dashboard.tsx`, `merchants.tsx`  
**Problem:** Admin UI shows Firestore data but NO approve/reject/edit/delete buttons exist  
**Impact:** Admins cannot approve pending offers, cannot moderate merchants, MANUAL database edits required  
**Fix Required:** Implement approve/reject offer buttons calling approveOffer/rejectOffer functions

### BLOCKER #6: Flutter Analyze Errors Block App Store Submission
**Files:** `source/apps/mobile-customer`, `source/apps/mobile-merchant`  
**Problem:** `integration_test` dependency missing in pubspec.yaml, 32 outdated packages  
**Impact:** iOS App Store / Google Play automated review will REJECT apps with analyze errors  
**Fix Required:** Add integration_test to dev_dependencies, update package constraints

### BLOCKER #7: Secret Manager Not Configured (Production Keys Exposed)
**File:** `source/backend/firebase-functions/src/index.ts:43`  
**Problem:** `// TODO: Uncomment after setting up Firebase Secret Manager` - QR_TOKEN_SECRET, Stripe keys in .env  
**Impact:** Production secrets committed to git OR require manual .env file uploads, security risk  
**Fix Required:** Enable Firebase Secret Manager API, migrate all secrets, uncomment code block

### BLOCKER #8: No Merchant Offer Quota Enforcement
**File:** `source/backend/firebase-functions/src/phase3Scheduler.ts` (scheduled jobs DISABLED)  
**Problem:** `enforceMerchantCompliance` scheduler job commented out, merchants not blocked for non-compliance  
**Impact:** Qatar Spec requirement (5 offers/month) NOT enforced, merchants can go inactive without penalty  
**Fix Required:** Enable Cloud Scheduler API, uncomment scheduled job, add offer creation blocker

### BLOCKER #9: Payment Webhooks Disabled (IAM Permissions Missing)
**File:** `source/backend/firebase-functions/src/index.ts:69`  
**Problem:** `// export { omtWebhook, whishWebhook, cardWebhook }` - IAM permissions not granted  
**Impact:** OMT/Whish/Card payment gateway webhooks will return 404, payments won't complete  
**Fix Required:** Grant `cloudfunctions.functions.setIamPolicy` permission, uncomment exports

### BLOCKER #10: No Offer Expiration Automation
**File:** `source/backend/firebase-functions/src/index.ts` (scheduled version disabled)  
**Problem:** `expireOffers` only callable manually by admin, NO scheduled automation  
**Impact:** Expired offers remain ACTIVE status, customers can attempt redemptions on expired offers  
**Fix Required:** Enable Cloud Scheduler API, create scheduled trigger for expireOffers (daily cron)

---

## 4. EXECUTION ORDER (NO DISCUSSION)

### STEP 1: Fix Flutter Dependency Errors (2 hours)
**Files:** `source/apps/mobile-customer/pubspec.yaml`, `source/apps/mobile-merchant/pubspec.yaml`  
**Action:** Add `integration_test` to dev_dependencies, run `flutter pub get`, update constraints for 32 outdated packages  
**Verify:** `flutter analyze` exits 0 for both apps  
**Why First:** Blocks app store submission, easiest fix, unlocks testing

### STEP 2: Enable Cloud Scheduler API (10 minutes)
**Action:** Visit https://console.cloud.google.com/apis/library/cloudscheduler.googleapis.com?project=urbangenspark, click Enable  
**Verify:** API shows "Enabled" status  
**Why Now:** Required for Steps 3, 4, 8

### STEP 3: Implement Subscription Renewal Logic (8 hours)
**File:** `source/backend/firebase-functions/src/subscriptionAutomation.ts:86`  
**Action:**  
1. Replace TODO with Stripe PaymentIntent creation using saved payment method ID  
2. Implement retry logic (3 attempts over 7 days)  
3. Update subscription status to 'past_due' on failure  
4. Send FCM notification on final failure (link to Step 5)  
**Verify:** Create test subscription in Stripe, advance clock, verify renewal charge succeeds  
**Why Now:** Critical revenue flow, blocks subscription business model

### STEP 4: Integrate Lebanese SMS Gateway (6 hours)
**File:** `source/backend/firebase-functions/src/sms.ts:68`  
**Action:**  
1. Choose provider (LIBAN SMS recommended for Lebanon)  
2. Get API key, configure in Firebase Config (`firebase functions:config:set sms.api_key="..."`)  
3. Replace hardcoded test responses with actual HTTP requests to provider API  
4. Implement error handling + retry logic  
**Verify:** Send OTP to real Lebanese phone number, receive SMS within 30 seconds  
**Why Now:** Critical for user onboarding (OTP), redemption notifications

### STEP 5: Implement Payment Failure Notifications (4 hours)
**File:** `source/backend/firebase-functions/src/paymentWebhooks.ts:391`  
**Action:**  
1. Call `sendPersonalizedNotification` from phase3Notifications with failure message  
2. Include deep link to billing screen: `urbanpoints://billing`  
3. Update user subscription status to 'past_due' in Firestore  
4. Log failure event in `payment_failures` collection for audit  
**Verify:** Trigger test webhook with failed payment, verify FCM push received on mobile app  
**Why Now:** Depends on Step 3, prevents silent subscription failures

### STEP 6: Add Subscription Paywall to Mobile Merchant (3 hours)
**File:** `source/apps/mobile-merchant/lib/screens/create_offer_screen.dart:380-430`  
**Action:**  
1. Before calling `createOffer`, call `checkSubscriptionAccess` function  
2. If subscription inactive/expired, show dialog: "Subscription Required - Upgrade to create offers"  
3. Add "Upgrade" button linking to billing screen  
4. Block offer creation form if subscription check fails  
**Verify:** Set test merchant subscription to expired, attempt offer creation, verify blocked  
**Why Now:** Critical revenue enforcement, simple mobile-side change

### STEP 7: Build Web Admin Offer Approval UI (6 hours)
**File:** `source/apps/web-admin/pages/admin/offers.tsx`  
**Action:**  
1. Add "Approve" and "Reject" buttons next to each pending offer  
2. Wire buttons to call `approveOffer(offerId)` and `rejectOffer(offerId, reason)` functions  
3. Show reason textarea on reject  
4. Refresh offer list after action completes  
5. Add loading states + error handling  
**Verify:** Create test offer (status: pending), log in as admin, approve offer, verify status changes to approved  
**Why Now:** Unblocks admin workflow, required for Qatar Spec approval process

### STEP 8: Enable Merchant Compliance Scheduler (2 hours)
**File:** `source/backend/firebase-functions/src/index.ts` + `phase3Scheduler.ts`  
**Action:**  
1. Uncomment `enforceMerchantCompliance` scheduled function  
2. Deploy function: `firebase deploy --only functions:enforceMerchantCompliance`  
3. Add check in `createOffer` to block if merchant non-compliant (< 5 offers last month)  
**Verify:** Wait for scheduler to run (1 AM UTC daily), check `merchant_compliance` collection updated  
**Why Now:** Depends on Step 2, enforces Qatar Spec business rule

### STEP 9: Enable Offer Expiration Scheduler (2 hours)
**File:** `source/backend/firebase-functions/src/index.ts`  
**Action:**  
1. Create scheduled version of `expireOffers`: `functions.pubsub.schedule('0 2 * * *').onRun(...)`  
2. Deploy: `firebase deploy --only functions:expireOffersScheduled`  
**Verify:** Wait for 2 AM UTC run, check expired offers moved to 'expired' status  
**Why Now:** Depends on Step 2, prevents redemption of expired offers

### STEP 10: Migrate Secrets to Secret Manager (4 hours)
**File:** `source/backend/firebase-functions/src/index.ts:43`  
**Action:**  
1. Enable Secret Manager API  
2. Create secrets: `QR_TOKEN_SECRET`, `STRIPE_SECRET_KEY`, `SMS_API_KEY`  
3. Grant Cloud Functions service account access  
4. Update code to read from `functions.config()` instead of `process.env`  
5. Uncomment validation block (line 43)  
**Verify:** Deploy functions, verify QR generation still works with secret from Secret Manager  
**Why Last:** Non-blocking for functionality, security hardening

### STEP 11: Enable Payment Webhooks (2 hours)
**File:** `source/backend/firebase-functions/src/index.ts:69`  
**Action:**  
1. Grant IAM permission: `gcloud projects add-iam-policy-binding urbangenspark --member=serviceAccount:... --role=roles/cloudfunctions.invoker`  
2. Uncomment webhook exports  
3. Deploy: `firebase deploy --only functions:omtWebhook,functions:whishWebhook,functions:cardWebhook`  
4. Configure webhook URLs in payment gateway dashboards  
**Verify:** Trigger test payment, verify webhook receives event  
**Why Last:** Depends on IAM permissions (external dependency)

---

## 5. WHAT TO IGNORE FOR NOW

- **Stripe full migration**: Backend guards exist, works with STRIPE_ENABLED=0 (deferred feature)
- **REST API**: Alternative backend exists but Firebase Functions are primary (REST API not used by mobile apps)
- **Mobile Admin App**: Exists but not referenced in workflows, no critical features (web admin sufficient)
- **Advanced analytics**: Basic stats work (`calculateDailyStats`), fancy dashboards can wait
- **Geofencing**: Location-based offers work, radius filtering sufficient
- **Referral system**: Points referrer_bonus/referee_bonus defined but no UI triggers yet
- **GDPR automation**: Manual export/delete works, scheduled cleanup can wait
- **Performance tuning**: Functions work under load, premature optimization
- **UI polish**: Apps functional, design improvements non-critical
- **Multi-language**: English only currently, i18n can wait
- **Backup automation**: Firestore backups manual, not blocking
- **Load testing**: No evidence of scale issues yet
- **Documentation updates**: Code comments sufficient for now
- **Monitoring dashboards**: Sentry/Winston logging works, fancy UI later

---

## 6. FINAL VERDICT

**This project will PARTIALLY WORK IN PRODUCTION.**

**Why:** Core flows (QR redemption, points, auth) are implemented and tested. BUT revenue-critical features (subscription renewals, paywall enforcement) have TODOs that will cause silent failures. Mobile apps have Flutter errors blocking app store submission. Admin dashboard is read-only making moderation impossible. System will limp along for POC/beta but WILL FAIL under real merchant load or when first subscription renewals hit.

**Bottom Line:** 11 steps to production-ready. Steps 1-8 are CRITICAL (35 hours of work). Steps 9-11 are hardening (8 hours). Total: 43 hours to ship without embarrassment.
