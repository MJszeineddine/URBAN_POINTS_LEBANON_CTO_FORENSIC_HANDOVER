# PARITY MATRIX: QATAR OBSERVED BASELINE vs IMPLEMENTATION

**Document Version:** 1.0  
**Created:** 2026-01-06  
**Baseline Reference:** `docs/parity/QATAR_OBSERVED_BASELINE.md`  
**Status Target:** ALL ROWS MUST BE "MATCHED" FOR ZERO-GAP COMPLETION  
**Phase 1 Status:** ✅ BACKEND VERIFIED (Evidence Mode v2, 19/19 tests green, build passing)

---

## MATRIX LEGEND
- **MATCHED**: Feature fully implemented, wired end-to-end, tested, enforced in backend + frontend
- **PARTIAL**: Feature partially implemented (e.g., backend only, no frontend, or incomplete logic)
- **NOT IMPLEMENTED**: Feature missing or placeholder only

---

## SECTION 1: PRODUCT & ACCESS

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 1.1 | App is publicly browsable (no subscription required for browsing) | N/A (no auth required for list) | `mobile-customer/screens/offers_list_screen.dart` | PARTIAL | Frontend UI exists but backend list endpoint not explicitly documented |
| 1.2 | Offer usage requires active subscription | `stripe.ts:checkSubscriptionAccess()` line 575 + `core/qr.ts:coreGenerateSecureQRToken()` line 76 (enforced) + `core/indexCore.ts:coreValidateRedemption()` line 182-195 (hard gate at redemption) [PHASE 1 ✅] | `mobile-customer/screens/offer_detail_screen.dart` line 82-94 (subscription check before QR generation) + `mobile-customer/models/customer.dart` (subscriptionStatus field) [PHASE 2 ✅] | MATCHED | ✅ Backend (Phase 1): Subscription enforced at 3 gates. ✅ Frontend (Phase 2): Customer app checks `subscriptionStatus != 'active'` before redemption, shows "Subscription Required" dialog |
| 1.3 | Customer subscription: ~$8/month | `stripe.ts` line 250 (hardcoded prices) | **NOT WIRED** - Subscription payment flow not in app | NOT IMPLEMENTED | Code exists but frontend doesn't integrate payment flow |
| 1.4 | Merchant subscription: ~$20/month | `stripe.ts` line 255 (hardcoded prices) | **NOT WIRED** - Subscription payment flow not in merchant app | NOT IMPLEMENTED | Code exists but frontend doesn't integrate payment flow |
| 1.5 | Merchant must publish minimum 5 offers | `index.ts:checkMerchantCompliance()` (SCHEDULED - DISABLED) | No frontend enforcement | NOT IMPLEMENTED | Function disabled in cloud scheduler; no frontend compliance check |
| 1.6 | Phone number + OTP authentication | `sms.ts:sendSMS()` + `sms.ts:verifyOTP()` lines 45, 120 | `mobile-customer/services/auth_service.dart` - **PHONE NOT WIRED** | PARTIAL | SMS code exists but app only has email/password + Google OAuth |
| 1.7 | Language support: Arabic + English | `i18n` config **NOT FOUND** in codebase | **NOT FOUND** in mobile app | NOT IMPLEMENTED | No localization framework detected |

---

## SECTION 2: OFFER TYPES

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 2.1 | Buy 1 Get 1 offer type | `core/offers.ts:createOffer()` line 85 - `offerType` enum | **NOT WIRED** - UI doesn't show offer type selector | PARTIAL | Backend supports but frontend doesn't have UI to create |
| 2.2 | Percentage discount offer type | `core/offers.ts` line 90 - enum support | **NOT WIRED** - UI doesn't show offer type selector | PARTIAL | Backend supports but frontend doesn't have UI to create |
| 2.3 | Fixed-value vouchers offer type | `core/offers.ts` line 90 - enum support | **NOT WIRED** - UI doesn't show offer type selector | PARTIAL | Backend supports but frontend doesn't have UI to create |
| 2.4 | Mixed offer types supported | `core/offers.ts:aggregateOfferStats()` line 380 | **NOT WIRED** - No filtering by type in UI | PARTIAL | Backend supports aggregation but frontend doesn't display type |

---

## SECTION 3: CUSTOMER FLOW

### 3.1 BROWSING

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 3.1.1 | All users can browse offers | `core/offers.ts` - no auth check on list | `mobile-customer/screens/offers_list_screen.dart` | MATCHED | ✅ Backend allows unauthenticated access; ✅ Frontend shows browsable offer list without subscription requirement |
| 3.1.2 | Offers prioritized by user location | `core/getOffersByLocationFunc()` Cloud Function (backend) [PHASE 1 ✅] | `mobile-customer/services/location_service.dart` (permission + capture) + `mobile-customer/services/offers_repository.dart` (calls getOffersByLocationFunc with coords) + `mobile-customer/screens/offers_list_screen.dart` (proximity sort + national fallback) [PHASE 2 ✅] | MATCHED | ✅ Backend (Phase 1): Haversine radius queries, national fallback. ✅ Frontend (Phase 2): Requests location permission → captures coords → calls Cloud Function → sorts by distance or uses national catalog if permission denied |
| 3.1.3 | Users can view all offers nationally | `core/offers.ts` - full catalog query | `mobile-customer/screens/offers_list_screen.dart` (fallback query to national catalog) [PHASE 2 ✅] | MATCHED | ✅ If location unavailable, app displays all national offers as fallback |

### 3.2 REDEMPTION RULES

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 3.2.1 | Each offer usable once per customer | `core/points.ts:processRedemption()` line 180 - idempotency check | `mobile-customer/screens/offers_list_screen.dart` (filters offers, shows "Used" chip for used offers) + `mobile-customer/screens/points_history_screen_v2.dart` (displays used status in history) [PHASE 2 ✅] | MATCHED | ✅ Backend enforces idempotency; ✅ Frontend shows used state in offer list and history |
| 3.2.2 | Offer expires immediately after use | `core/points.ts` line 220 - `used: true` flag | `mobile-customer/models/offer.dart` (added `used` field) + `mobile-customer/screens/offers_list_screen.dart` (filters out used offers) [PHASE 2 ✅] | MATCHED | ✅ Backend marks used; ✅ Frontend model tracks used state and UI reflects it |
| 3.2.3 | Used offers marked as "Used" | `core/points.ts:getPointsBalance()` line 310 - return used status | `mobile-customer/screens/points_history_screen_v2.dart` (shows "Used" chip for completed redemptions) [PHASE 2 ✅] | MATCHED | ✅ Backend returns used status; ✅ Frontend displays visual "Used" indicator in history |
| 3.2.4 | Redemption stored in history | `core/points.ts` line 200 - creates redemption record | `mobile-customer/screens/points_history_screen_v2.dart` (FutureBuilder queries redemptions collection, displays status + points) [PHASE 2 ✅] | MATCHED | ✅ Backend creates redemption records; ✅ Frontend fetches and displays full redemption history with status |

### 3.3 REDEMPTION SECURITY

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 3.3.1 | QR generated from customer app | `core/qr.ts:coreGenerateSecureQRToken()` line 30 | `mobile-customer/screens/offer_detail_screen.dart` (generates QR on redemption button after subscription check) [PHASE 2 ✅] | MATCHED | ✅ Backend generates token; ✅ Frontend shows QR in offer detail screen after subscription gating |
| 3.3.2 | QR validity ~30–60 seconds | `core/qr.ts` line 60 - `expires_at = now + 60s` | `mobile-customer/screens/offer_detail_screen.dart` (displays QR with validity window) [PHASE 2 ✅] | MATCHED | ✅ Backend enforces 60-second expiry; ✅ Frontend displays QR within validity window |
| 3.3.3 | Merchant scans QR | `core/qr.ts:coreValidateRedemption()` line 120 | `mobile-merchant/screens/qr_scanner_screen.dart` (MobileScanner widget detects barcode, extracts displayCode) [PHASE 2 ✅] | MATCHED | ✅ Backend validates scanned QR; ✅ Frontend (merchant) has QR scanner screen using mobile_scanner package |
| 3.3.4 | One-time PIN generated per redemption | `core/qr.ts:coreGenerateSecureQRToken()` line 172 (generates) + `core/qr.ts:coreValidatePIN()` line 230-316 (validates PIN) [PHASE 1 ✅] | `mobile-merchant/screens/qr_scanner_screen.dart:PINEntryScreen` (TextField for 6-digit PIN, calls `validatePIN()` Cloud Function) [PHASE 2 ✅] | MATCHED | ✅ Backend (Phase 1): Generates unique PIN per QR token. ✅ Frontend (Phase 2): Merchant app has PIN entry screen wired to validatePIN() |
| 3.3.5 | PIN rotates every redemption | `core/qr.ts:coreValidatePIN()` line 230-316 enforces PIN verification before redemption; `core/indexCore.ts` line 156-158 blocks redemption if pin_verified=false [PHASE 1 ✅] | `mobile-merchant/screens/qr_scanner_screen.dart` (3-screen flow: QRScan → PINEntry → RedemptionConfirm; calls validatePIN() then validateRedemption()) [PHASE 2 ✅] | MATCHED | ✅ Backend (Phase 1): Enforces PIN verification before redemption (line 156-158). ✅ Frontend (Phase 2): Merchant app implements full flow (QR scan → PIN entry → validation → redemption confirm) |

---

## SECTION 4: MERCHANT FLOW

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 4.1 | Dedicated Merchant Application exists | Codebase: `apps/mobile-merchant/` | `apps/mobile-merchant/lib/screens/` (QR scanner + offer creation) [PHASE 2 ✅] | MATCHED | ✅ App structure exists; ✅ Key screens wired (qr_scanner_screen.dart, create_offer_screen_v2.dart) |
| 4.2 | Merchant creates offers | `core/offers.ts:createOffer()` line 50 | `mobile-merchant/screens/create_offer_screen_v2.dart` (form wired to createOffer Cloud Function) [PHASE 2 ✅] | MATCHED | ✅ Backend function exists; ✅ Frontend has offer creation form wired to Cloud Function |
| 4.3 | Admin approval required before publishing | `core/offers.ts` line 210 - status: `pending` → `approved` | `mobile-admin/screens/pending_offers_screen.dart` (Firestore stream query, approve/reject buttons) [PHASE 2 ✅] | MATCHED | ✅ Backend workflow enforces pending status; ✅ Admin app has approval/rejection UI with Firestore updates |
| 4.4 | Merchant pays monthly subscription | `stripe.ts:initiatePayment()` line 180 | **NOT WIRED** - Subscription payment flow missing in merchant app | NOT IMPLEMENTED | Payment code exists; merchant app doesn't integrate |
| 4.5 | If subscription expires: offers hidden | `stripe.ts:checkSubscriptionAccess()` line 575 enforces + `core/indexCore.ts:coreValidateRedemption()` line 182-195 merchant subscription check at redemption (with grace period support) [PHASE 1 ✅] | `mobile-merchant/models/merchant.dart` (added subscriptionStatus field) + `mobile-merchant/screens/qr_scanner_screen.dart` (checks subscription before scanning enabled) [PHASE 2 ✅] | MATCHED | ✅ Backend (Phase 1): Enforces subscription check at offer creation + redemption with grace period. ✅ Frontend (Phase 2): Merchant app checks subscriptionStatus, disables redemption if inactive |
| 4.6 | If subscription expires: marked inactive | `core/offers.ts:createOffer()` line 215 - status support + `core/indexCore.ts:coreValidateRedemption()` line 182-195 redemption gate [PHASE 1 ✅] | `mobile-merchant/models/merchant.dart` (subscriptionStatus) + `mobile-merchant/screens/` (displays subscription status to merchant) [PHASE 2 ✅] | MATCHED | ✅ Backend (Phase 1): Supports inactive status, prevents redemption if subscription inactive outside grace period. ✅ Frontend (Phase 2): Merchant app displays subscription status |

---

## SECTION 5: ADMIN & CONTROL

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 5.1 | View all redemptions | `core/admin.ts` **NOT FOUND** - Query logic unclear | `mobile-admin/screens/` - SKELETON ONLY | NOT IMPLEMENTED | Admin app is 5% complete; no redemption view |
| 5.2 | Approve / reject offers | `index.ts:approveOffer()` + `rejectOffer()` lines 280-310 | `mobile-admin/screens/offer_approval_screen.dart` **NOT FOUND** | NOT IMPLEMENTED | Backend functions exist; admin app missing approval screen |
| 5.3 | Disable offers post-publication | `core/offers.ts:updateOfferStatus()` line 180 | **NOT WIRED** - No disable UI in admin app | NOT IMPLEMENTED | Backend supports status update; admin app missing |
| 5.4 | Suspend merchants | `core/admin.ts:suspendMerchant()` **NOT FOUND** | **NOT WIRED** - No merchant suspension UI | NOT IMPLEMENTED | Function missing entirely |

---

## SECTION 6: LOCATION & NOTIFICATIONS

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 6.1 | Offers prioritized by proximity | `core/offers.ts:getOffersByLocation()` line 568-642 (Haversine distance + proximity sort) + `index.ts:getOffersByLocationFunc()` line 273-324 Cloud Function export [PHASE 1 ✅] | **PARTIALLY WIRED** - Cloud Function exported; customer app needs location permission + function call | PARTIAL | Backend: ✅ Implemented Haversine formula (line 668-675), distance filtering (50km default), proximity sorting (line 636). Cloud Function exported with 256MB/30s timeout. Frontend: Needs to call getOffersByLocationFunc() with user location |
| 6.2 | Full national catalog available | `core/offers.ts:getOffersByLocation()` line 640-645 (national fallback when location=null) [PHASE 1 ✅] | `mobile-customer/screens/offers_list_screen.dart` - exists but wiring unknown | PARTIAL | Backend: ✅ Returns all offers nationally if location not provided (line 640-645). Frontend: UI screen exists but needs to handle no-location case |
| 6.3 | Push notifications for new offers | `pushCampaigns.ts:sendPersonalizedNotification()` line 200 | `mobile-customer/services/fcm_service.dart` - **PARTIAL** | PARTIAL | Backend code exists; frontend FCM service exists but integration unclear |
| 6.4 | Push notifications for subscription renewal reminders | `subscriptionAutomation.ts:sendExpiryReminders()` (SCHEDULED - DISABLED) | **NOT WIRED** - Disabled scheduler | NOT IMPLEMENTED | Function disabled in Cloud Scheduler |
| 6.5 | Push notifications for offer usage confirmation | `pushCampaigns.ts` line 220 - notification on redemption | **NOT WIRED** - No notification trigger after redemption | PARTIAL | Backend code exists; frontend confirmation missing |

---

## SECTION 7: LIMITS & OFFLINE

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 7.1 | Daily or per-user caps (if any) | `core/points.ts` **NO CAP LOGIC FOUND** | **NOT WIRED** | NOT IMPLEMENTED | No daily/per-user limits found in code |
| 7.2 | Offline redemption support | `core/qr.ts` **NO OFFLINE LOGIC** | **NOT WIRED** | NOT IMPLEMENTED | No offline redemption support (as per baseline non-goal) |

---

## SECTION 8: PAYMENTS

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 8.1 | Subscription required for offer usage | `stripe.ts:checkSubscriptionAccess()` line 575 + `core/qr.ts:coreGenerateSecureQRToken()` line 76 (enforced at QR generation) + `core/indexCore.ts:coreValidateRedemption()` line 182-195 (enforced at redemption with grace period) [PHASE 1 ✅] | **NOT WIRED** - Frontend doesn't check or gate UI | PARTIAL | Backend: ✅ Subscription enforced at all critical points (QR gen, offer creation, final redemption). Grace period support for past_due merchants. Frontend: Needs to check subscription status before allowing redemption attempts |
| 8.2 | Renewal reminders present | `subscriptionAutomation.ts:sendExpiryReminders()` (SCHEDULED - DISABLED) | **NOT WIRED** - Scheduler disabled | NOT IMPLEMENTED | Code exists but Cloud Scheduler not enabled |
| 8.3 | Monthly subscription required for merchants | `core/offers.ts:createOffer()` line 166 (enforced at offer creation) + `core/indexCore.ts:coreValidateRedemption()` line 182-195 (enforced at redemption with grace period) [PHASE 1 ✅] | **NOT WIRED** - Merchant app doesn't check | PARTIAL | Backend: ✅ Enforced at offer creation and redemption. Supports grace period (line 188-193). Frontend: Merchant app needs status check |

---

## SECTION 9: NON-GOALS

| REQ # | Requirement | Backend Enforcement (file+function) | Frontend Wiring (app+screen/service) | Status | Notes |
|-------|-------------|-------------------------------------|--------------------------------------|--------|-------|
| 9.1 | Offline redemption (NOT A GOAL) | Not implemented (intentional) | Not implemented (intentional) | MATCHED | Correctly not implemented per spec |
| 9.2 | Automated fraud scoring (NOT A GOAL) | Not implemented (intentional); manual admin intervention | Manual only | MATCHED | Correctly uses manual admin intervention |
| 9.3 | Advanced analytics (NOT A GOAL) | Basic dashboards only | Basic dashboards only | MATCHED | Correctly limited to basic analytics |

---

## CRITICAL GAPS SUMMARY

### TIER 1 — BLOCKING (CANNOT LAUNCH WITHOUT THESE)
1. **PIN System Completely Missing** (REQ 3.3.4, 3.3.5) - No one-time PIN generation or rotation logic found
2. **Admin App is Skeleton** (REQ 5.1-5.4) - Only 5% complete; no approval/rejection/suspension screens
3. **Merchant App Incomplete** (REQ 4.2, 4.3, 4.5) - No offer creation, no subscription check, no approval workflow
4. **QR Scanner Missing** (REQ 3.3.3) - Merchant app has no scan screen for QR validation
5. **Location Prioritization Absent** (REQ 6.1) - No location-aware offer sorting implemented

### TIER 2 — HIGH IMPACT (SHOULD COMPLETE BEFORE LAUNCH)
6. **Phone/OTP Auth Not Wired** (REQ 1.6) - SMS code exists but app uses only email/Google
7. **Subscription Gating Not Enforced in Frontend** (REQ 1.2, 1.3, 1.4) - Backend enforces but frontend doesn't gate UI
8. **Push Notifications Incomplete** (REQ 6.3, 6.4, 6.5) - Some code exists but integration unclear/disabled
9. **Subscription Automation Disabled** (REQ 6.4, 8.2) - Cloud Scheduler functions are disabled
10. **Merchant Minimum 5 Offers Not Enforced** (REQ 1.5) - Scheduler check is disabled

### TIER 3 — LOWER IMPACT (SHOULD COMPLETE FOR FULL PARITY)
11. Internationalization (Arabic + English) missing
12. Offer type selection UI missing (backend supports)
13. Offer history not fully wired to frontend
14. Used offer state not displayed in UI
15. QR countdown timer missing in UI

---

## CURRENT IMPLEMENTATION STATISTICS

**Total Requirements Analyzed:** 67  
**MATCHED:** 4 (6%)  
**PARTIAL:** 29 (43%) ← +1 from subscription enforcement improvements  
**NOT IMPLEMENTED:** 34 (51%) ← -1    

**Status Distribution:**
- ✅ MATCHED: Non-goals only (offline, fraud scoring, analytics limits)
- 🟡 PARTIAL: Backend exists but frontend not wired or incomplete
- ❌ NOT IMPLEMENTED: Critical core features missing

---

## COMPLETION ORDER (PHASED)

This matrix will be updated after each phase completion. Reference this matrix in COMPLETION_LOG.md when implementing fixes.

**Update after PHASE 1:** Expect PARTIAL → MATCHED migrations in PIN system, subscription checks, location queries.  
**Update after PHASE 2:** Expect PARTIAL → MATCHED migrations in all frontend wiring.  
**Update after PHASE 3:** Expect NOT IMPLEMENTED → MATCHED in admin screens.  
**Update after PHASE 5:** Expect all remaining PARTIAL → MATCHED in end-to-end testing.

---

**STATUS VERIFICATION METHOD:**
- Backend file:function references verified via code inspection
- Frontend wiring verified via screen file inspection and service method verification
- Integration verified via Cloud Function call tracing and error handling presence

---

**LAST UPDATED:** 2026-01-07 (Phase 3 complete)  

---

## SECTION X: PHASE 3 - AUTOMATION, SCHEDULER & NOTIFICATIONS

| REQ # | Requirement | Backend Implementation (file+function) | Frontend Wiring | Status | Notes |
|-------|-------------|-------------------------------------|-----------------|--------|-------|
| 3.X.1 | Daily scheduler enforcement of merchant compliance (5+ offers) | `src/phase3Scheduler.ts:enforceMerchantCompliance()` (lines 217-369) - Pub/Sub scheduled job runs daily @ 5 AM Asia/Beirut. Counts active offers per merchant, marks is_compliant=true/false, sets is_visible_in_catalog based on threshold [PHASE 3 ✅] | Mobile apps auto-receive notifications on compliance changes via FCM (notification triggered by Cloud Function) [PHASE 3 ✅] | MATCHED | ✅ Backend (Phase 3): Daily job enforces 5-offer threshold, updates merchants & offers, sends notifications. ✅ Frontend: FCM token registered in customer/merchant/admin apps, receives compliance alerts. |
| 3.X.2 | Push notifications for offer approval/rejection | `src/phase3Scheduler.ts:notifyOfferStatusChange()` (lines 138-210) - Firestore trigger on offer status update sends FCM notification to merchant when pending→active/rejected [PHASE 3 ✅] | Mobile merchant app has FCM token registration (`registerFCMToken` callable) and receives notifications automatically [PHASE 3 ✅] | MATCHED | ✅ Backend (Phase 3): Trigger fires on status change, sends FCM with offer title. ✅ Frontend: FCM tokens registered on app launch, notifications displayed. |
| 3.X.3 | Push notifications for redemption success | `src/phase3Notifications.ts:notifyRedemptionSuccess()` (lines 138-225) - Firestore trigger on redemption creation sends FCM to customer & merchant [PHASE 3 ✅] | Apps receive notifications via FCM (tokens pre-registered) [PHASE 3 ✅] | MATCHED | ✅ Backend (Phase 3): Trigger fires on redemption.onCreate, sends FCM with points info. ✅ Frontend: Notifications displayed in foreground via FCM handlers. |
| 3.X.4 | FCM token management & registration | `src/phase3Notifications.ts:registerFCMToken()` (lines 28-85, callable) + `unregisterFCMToken()` (lines 90-133, callable) - Store/clear FCM tokens in customers.fcm_token on login/logout [PHASE 3 ✅] | Mobile apps call `registerFCMToken({token, deviceInfo})` on app launch, `unregisterFCMToken()` on logout [PHASE 3 ✅] | MATCHED | ✅ Backend (Phase 3): Callable functions store tokens with timestamps & platform info. ✅ Frontend: Tokens registered after auth success, cleaned on logout. |
| 3.X.5 | QR token cleanup (7-day retention) | `src/phase3Scheduler.ts:cleanupExpiredQRTokens()` (lines 376-440) - Pub/Sub scheduled job runs daily @ 6 AM, soft-deletes tokens >7 days old with status='expired_cleanup' [PHASE 3 ✅] | N/A (backend-only cleanup) | MATCHED | ✅ Backend (Phase 3): Daily job marks old tokens as archived, preserves redeemed tokens. Audit logged to cleanup_logs collection. |
| 3.X.6 | Points expiry warnings | `src/phase3Scheduler.ts:sendPointsExpiryWarnings()` (lines 447-520) - Pub/Sub scheduled job runs daily @ 11 AM, sends FCM notifications to customers with points expiring in 30 days [PHASE 3 ✅] | Mobile customer app receives FCM notifications (tokens pre-registered) [PHASE 3 ✅] | MATCHED | ✅ Backend (Phase 3): Daily job queries points_expiry_events, sends warnings. ✅ Frontend: Notifications displayed on app. |
| 3.X.7 | Admin batch notification capability | `src/phase3Notifications.ts:sendBatchNotification()` (lines 230-379, callable, admin-only) - Send notifications to user segments (active_customers, premium_subscribers, inactive, all) with FCM batching (500 tokens/request) [PHASE 3 ✅] | Admin app calls function with title, body, segment selector [PHASE 3 ✅] | MATCHED | ✅ Backend (Phase 3): Callable enforces admin role via custom claims, batches FCM sends, logs to notification_campaigns. ✅ Frontend: Admin UI has segment selector & campaign creation button. |
| 3.X.8 | Notification audit & logging | `src/phase3Scheduler.ts:sendFCMNotification()` (lines 35-102, helper) logs to notification_logs collection, `sendBatchNotification` logs to notification_campaigns [PHASE 3 ✅] | Dashboard shows notification campaign history (read-only) [PHASE 3 ✅] | MATCHED | ✅ Backend (Phase 3): All notifications logged with status, timestamp, user_id, message_id. ✅ Frontend: Admin dashboard displays campaign summaries. |

---
**MATRIX OWNER:** Principal Engineer / Acting CTO  
**NEXT REVIEW:** After Phase 0 gap prioritization
