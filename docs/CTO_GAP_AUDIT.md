# Urban Points Lebanon - CTO Gap Audit Report
**Generated:** 2026-01-14  
**Auditor:** System (Code-Only Analysis)  
**Repository:** URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER

---

## Executive Summary

This audit analyzed the Urban Points Lebanon full-stack codebase to identify gaps between implemented code and production-ready requirements. Analysis was conducted exclusively from code (no PDFs, chats, or roadmaps).

**Completion Status:**
- **Total Requirements:** 80
- **READY (56%):** 45 requirements fully implemented end-to-end
- **PARTIAL (13%):** 10 requirements partially implemented with gaps
- **MISSING (31%):** 25 requirements not implemented

**Critical Finding:** The project has substantial implementation (56% ready) but 31% of features are completely missing. Most missing features have backend code ready but lack UI integration.

---

## Surfaces Audited

✅ **mobile-customer** (Flutter): source/apps/mobile-customer  
✅ **mobile-merchant** (Flutter): source/apps/mobile-merchant  
✅ **web-admin** (Next.js): source/apps/web-admin  
✅ **backend-functions** (Firebase Functions): source/backend/firebase-functions  
✅ **backend-rest** (Express API): source/backend/rest-api  
❌ **mobile-admin** (Flutter): NOT FOUND - no code exists

---

## Gaps Fixed During This Session

### 1. Requirements Specification
**Gap:** No single source of truth for completion tracking with READY/PARTIAL/MISSING/BLOCKED status.  
**Fixed:** Created `spec/requirements.yaml` with 80 requirements, each with:
- Status (READY | PARTIAL | MISSING | BLOCKED)
- Frontend anchors (file paths + symbols)
- Backend anchors (file paths + functions)
- Tests (empty for now, pending test implementation)
- Notes with classification evidence

**Evidence:** [spec/requirements.yaml](spec/requirements.yaml)

---

## Gaps Identified (Not Yet Fixed)

### HIGH PRIORITY: Missing Features with Backend Ready

#### 1. WhatsApp OTP Authentication (CUST-AUTH-003, MERCH-AUTH-003)
**Status:** MISSING  
**Backend:** ✅ READY
- `source/backend/firebase-functions/src/whatsapp.ts:sendWhatsAppOTP`
- `source/backend/firebase-functions/src/whatsapp.ts:verifyWhatsAppOTP`
- `source/backend/firebase-functions/src/whatsapp.ts:getWhatsAppVerificationStatus`

**Frontend:** ❌ MISSING
- Customer app: No WhatsApp auth screens, no service methods, no navigation routes
- Merchant app: No WhatsApp auth screens, no service methods, no navigation routes

**Impact:** Twilio WhatsApp Business API fully implemented but users cannot access it. Wasted backend code or missed feature.

**Required Fix:**
1. Add WhatsApp auth screens to both apps (phone number input → OTP verification)
2. Wire to backend callables
3. Add auth flow routing (LoginScreen → WhatsAppAuthScreen)
4. Test OTP send/verify with real Twilio credentials OR remove backend code

**Blocker:** May require Twilio WhatsApp Business API credentials. If unavailable, create `docs/BLOCKER_WHATSAPP_AUTH.md` and mark as BLOCKED.

---

#### 2. Deep Link Handling (CUST-NOTIF-003)
**Status:** MISSING  
**Backend:** ✅ Sends notification data payloads (type: points_earned, offer_available, tier_upgrade)  
**Frontend:** ❌ MISSING

**Current State:**
- FCM service has `_handleMessageOpenedApp()` with hardcoded `Navigator.push()` logic
- Only works when app is backgrounded, NOT when app is closed/terminated
- No URL scheme configuration in iOS Info.plist or Android AndroidManifest.xml
- No uni_links or go_router integration

**Impact:** Push notifications can't deep link to specific screens when app is closed. Users must manually navigate after opening app from notification.

**Required Fix:**
1. Add uni_links package to both Flutter apps
2. Configure URL schemes (e.g., `urbanpoints://offer/123`, `urbanpoints://wallet`)
3. Add deep link handler in main.dart
4. Parse incoming links and navigate to appropriate screens
5. Test notification deep links with app in all states (foreground, background, closed)

---

#### 3. GDPR Compliance UI (CUST-GDPR-001, CUST-GDPR-002)
**Status:** MISSING  
**Backend:** ✅ READY
- `source/backend/firebase-functions/src/privacy.ts:deleteUserData` (anonymizes user, deletes PII)
- `source/backend/firebase-functions/src/privacy.ts:exportUserData` (generates JSON export)

**Frontend:** ❌ MISSING
- No "Delete Account" button in customer settings
- No "Export My Data" button in customer settings

**Impact:** Legal compliance risk. Users cannot exercise GDPR rights (right to erasure, data portability).

**Required Fix:**
1. Add "Delete Account" button to `source/apps/mobile-customer/lib/screens/settings/settings_screen.dart`
2. Add confirmation dialog with warning text
3. Call `deleteUserData` callable
4. Add "Export My Data" button to settings
5. Call `exportUserData` callable
6. Display download link or email export to user

---

#### 4. Push Campaign Management (ADMIN-CAMPAIGN-001, ADMIN-CAMPAIGN-002, ADMIN-CAMPAIGN-003)
**Status:** MISSING  
**Backend:** ✅ READY
- `source/backend/firebase-functions/src/campaigns.ts:createCampaignCallable`
- `source/backend/firebase-functions/src/campaigns.ts:sendCampaignCallable`
- `source/backend/firebase-functions/src/campaigns.ts:getCampaignStatsCallable`

**Frontend:** ❌ MISSING
- No admin web pages for campaign creation
- No campaign compose UI (title, message, target audience, schedule)
- No campaign send button
- No campaign stats/analytics dashboard

**Impact:** Marketing/engagement tool fully implemented in backend but admins cannot use it. Wasted investment.

**Required Fix:**
1. Create `source/apps/web-admin/pages/campaigns/index.tsx` (list campaigns)
2. Create `source/apps/web-admin/pages/campaigns/create.tsx` (compose form)
3. Create `source/apps/web-admin/pages/campaigns/[id].tsx` (stats view)
4. Wire to backend callables
5. Add navigation link in admin sidebar

---

#### 5. Fraud Detection Dashboard (ADMIN-FRAUD-001, MERCH-REDEEM-005)
**Status:** MISSING  
**Backend:** ✅ READY
- `source/backend/firebase-functions/src/fraud.ts:detectFraudPatterns` (rate limits, duplicate check, geo validation)

**Frontend:** ❌ MISSING
- No admin web fraud dashboard showing alerts
- No flagged users list
- No suspicious redemptions view
- Merchant app has no fraud warning UI

**Impact:** Fraud detection logic exists but no visibility. Security risks hidden from operators.

**Required Fix:**
1. Create `source/apps/web-admin/pages/fraud/index.tsx` (fraud dashboard)
2. Display flagged transactions, users, merchants
3. Add fraud score visualization
4. Add merchant app banner when redemption flagged as suspicious
5. Wire to backend callable

---

### HIGH PRIORITY: Security Issues

#### 6. FCM Token Registration Bypass (BACKEND-SECURITY-001)
**Status:** MISSING (Security Fix)  
**Current State:**
- Customer/merchant apps write FCM tokens directly to Firestore `user_tokens/{uid}` collection
- Code location: `source/apps/mobile-customer/lib/services/fcm_service.dart:saveTokenToFirestore`
- Bypasses backend callable: `source/backend/firebase-functions/src/fcm.ts:registerFCMTokenCallable`

**Backend Callable Features (Not Used):**
- Validation (token format, device info)
- Rate limiting
- Max token limit (5 per user, auto-prune oldest)
- Audit logging

**Impact:** Security/scalability risk. No token validation, no rate limits, no max token enforcement.

**Required Fix:**
1. Refactor `FCMService.saveTokenToFirestore()` to call `registerFCMTokenCallable` instead of direct Firestore write
2. Remove direct Firestore write
3. Update Firestore security rules to block direct writes to `user_tokens` collection
4. Test token registration with 6+ devices to verify auto-prune

---

#### 7. Mock Data in Analytics (BACKEND-DATA-001)
**Status:** MISSING (Data Quality Fix)  
**Backend:** `source/backend/firebase-functions/src/analytics.ts:calculateDailyStats` contains placeholder/mock data  
**Frontend:** `source/apps/web-admin/pages/dashboard/index.tsx` displays these stats

**Impact:** Admin dashboard shows fake data. Cannot trust analytics for business decisions.

**Required Fix:**
1. Implement real aggregation queries in `calculateDailyStats` OR
2. Remove function completely and update admin dashboard to fetch data directly from Firestore OR
3. Document as "sample data for demo only" and create blocker for production use

---

### MEDIUM PRIORITY: Partial Features

#### 8. Offer Search & Filters (CUST-OFFER-002, CUST-OFFER-003)
**Status:** PARTIAL  
**Current:** Search UI exists but only filters local cached offers by title. Filters (category, location, points) applied client-side.  
**Gap:** No backend full-text search, no Firestore compound query optimization.

**Required Fix:**
1. Integrate Algolia or Firestore full-text search (if needed for large datasets)
2. OR document as "client-side only" and accept limitation
3. OR implement Firestore compound queries for filter combinations

---

#### 9. Favorite Offers List Screen (CUST-OFFER-005)
**Status:** PARTIAL  
**Current:** Favorite toggle button exists in OfferDetailScreen, writes to Firestore `users/{uid}/favorites`  
**Gap:** No dedicated favorites list screen or navigation route

**Required Fix:**
1. Create `source/apps/mobile-customer/lib/screens/offers/favorites_screen.dart`
2. Fetch favorites from Firestore subcollection
3. Add navigation route in main.dart
4. Add "Favorites" button/icon in OffersScreen or navigation bar

---

#### 10. Redemption Confirmation Screen (CUST-REDEEM-002)
**Status:** MISSING  
**Current:** Backend validates redemptions, merchant app confirms  
**Gap:** Customer app has no confirmation screen showing redemption success/details after merchant scans

**Required Fix:**
1. Create `source/apps/mobile-customer/lib/screens/redemption/redemption_confirmation_screen.dart`
2. Display offer name, merchant, points redeemed, timestamp
3. Add "Success" icon/animation
4. Navigate to this screen after QR scanned by merchant (requires notification or polling)

---

#### 11. Redemption History Enhancements (CUST-REDEEM-003, MERCH-REDEEM-004)
**Status:** PARTIAL  
**Current:** Customer shows redemptions in generic points history list. Merchant shows basic redemption list.  
**Gap:** No detailed redemption history view with offer details, merchant info, timestamps, filters, export.

**Required Fix:**
1. Create dedicated redemption history screens for both apps
2. Add filters (date range, offer, merchant)
3. Add detailed view with full context
4. Add CSV export for merchant

---

#### 12. Admin Points Management UI (ADMIN-POINTS-001, ADMIN-POINTS-002, ADMIN-POINTS-003)
**Status:** MISSING  
**Backend:** ✅ READY
- `adjustPointsManual`, `transferPointsCallable`, `expirePointsManual`

**Frontend:** ❌ MISSING

**Required Fix:**
1. Create admin web forms for manual points adjustment
2. Create user-to-user points transfer UI
3. Create manual points expiration UI
4. Add to admin "Points Management" page

---

#### 13. Admin User Search (ADMIN-USER-001)
**Status:** PARTIAL  
**Current:** Search bar present but only filters loaded results (client-side)  
**Gap:** No backend full-text search

**Required Fix:**
1. Integrate Algolia or backend search endpoint
2. OR document as "client-side only, admins must load more pages manually"

---

#### 14. Media Upload (MERCH-OFFER-006, MERCH-PROFILE-001)
**Status:** MISSING  
**Gap:** Offer schema has `imageUrl` field but no image picker or Firebase Storage upload UI in merchant app create/edit offer screens. Store profile has no logo/banner upload.

**Required Fix:**
1. Add image_picker package to merchant app
2. Add Firebase Storage upload logic
3. Add image upload UI in CreateOfferScreen and EditOfferScreen
4. Add logo/banner upload in MerchantProfileScreen
5. Update Firestore with uploaded image URLs

---

#### 15. Merchant Staff Management (MERCH-STAFF-001)
**Status:** MISSING  
**Gap:** No multi-user merchant account system. Single merchant owner only.

**Decision Required:**
- If multi-user needed: requires new backend role system + staff invite/management UI
- If not needed: document as "single owner only" and remove from requirements

---

#### 16. Stripe Integration Pages (ADMIN-PAYMENT-004)
**Status:** MISSING  
**Backend:** ✅ Stripe webhook exists: `source/backend/firebase-functions/src/webhooks/stripe.ts:stripeWebhook`  
**Frontend:** ❌ No admin UI for Stripe transactions, refunds, disputes

**Decision Required:**
- If Stripe needed: create admin pages for transaction management
- If not needed: remove webhook or document as "webhook-only, no admin UI"

---

### CRITICAL: Testing Gap

#### 17. Zero Unit Tests (TEST-CUSTOMER-001, TEST-MERCHANT-001, TEST-WEB-001, TEST-BACKEND-001)
**Status:** MISSING  
**Gap:** No test directories or unit tests found in any surface.

**Impact:** No automated quality assurance. Regression risk high.

**Required Fix (Minimal):**
1. Customer app: Add tests for auth, points service, QR generation
2. Merchant app: Add tests for auth, redemption, offer management
3. Admin web: Add tests for auth, API calls, form validation
4. Backend: Add tests for OTP, redemption, points adjustments

**Master File Requirement:** STEP 5 requires running `flutter test`, `npm test`, etc. Must add minimal tests first.

---

### INFRASTRUCTURE GAPS

#### 18. Firestore Security Rules Audit (INFRA-RULES-001)
**Status:** PARTIAL  
**File:** `source/firestore.rules`  
**Gap:** Rules exist but need audit to ensure they match all access patterns and block direct writes to privileged collections (e.g., `user_tokens`, `campaigns`, `admin_logs`).

**Required Fix:**
1. Audit all Firestore rules
2. Ensure `user_tokens` collection blocks direct writes (force callable use)
3. Ensure admin-only collections require role='admin'
4. Test rules with Firebase Emulator Suite

---

## Backend Orphan Functions (47 Functions)

**Issue:** 47 backend functions exported but not called by any client app.

**Categories:**
- **Triggers (3):** Firebase-invoked, no action needed
  - `onUserCreate`, `notifyOfferStatusChange`, `notifyRedemptionSuccess`
- **Scheduled (11):** Cloud Scheduler, no action needed
  - `cleanupExpiredOTPs`, `cleanupExpiredWhatsAppOTPs`, `processSubscriptionRenewals`, etc.
- **Webhooks (4):** External APIs, no action needed
  - `omtWebhook`, `whishWebhook`, `cardWebhook`, `stripeWebhook`
- **No UI Integration (27):** MUST either integrate with UI, deprecate, or document as admin-only
  - WhatsApp functions (3): `sendWhatsAppMessage`, `sendWhatsAppOTP`, `verifyWhatsAppOTP`
  - Privacy/GDPR (3): `exportUserData`, `deleteUserData`, `cleanupExpiredData`
  - FCM/Campaigns (6): `registerFCMTokenCallable`, `unregisterFCMTokenCallable`, `createCampaignCallable`, `sendCampaignCallable`, `getCampaignStatsCallable`, `scheduleCampaign`
  - Points management (3): `transferPointsCallable`, `expirePointsManual`, `adjustPointsManual`
  - Fraud/Security (2): `detectFraudPatternsCallable`, `revokeQRTokenCallable`
  - Admin utilities (5): `setCustomClaims`, `sendSMS`, `verifyOTP`, `sendBatchNotification`, `sendPersonalizedNotification`
  - Payments (2): `recordManualPayment`, `getManualPaymentHistory`
  - QR History (1): `getQRHistoryCallable`
- **Integration Unclear (2):** Need investigation
  - `editOfferCallable`, `cancelOfferCallable` (might be called, needs verification)

**Required Action:**
1. For "No UI Integration" functions: implement UI (see gaps above) OR
2. Remove functions if truly unnecessary OR
3. Document as "admin-only" and create admin CLI tools/scripts to invoke

---

## Summary of Required Actions

### Immediate (Before Declaring "100% Complete"):

1. ✅ Create `spec/requirements.yaml` (DONE)
2. ⏳ Create `docs/CTO_GAP_AUDIT.md` (THIS FILE)
3. ⏳ Create `docs/PM_BACKLOG.md` (NEXT)
4. ⏳ Create `tools/gates/cto_verify.py` (PENDING)
5. ⏳ Implement missing features OR mark as BLOCKED (PENDING)
6. ⏳ Add minimal unit tests to all surfaces (PENDING)
7. ⏳ Run all required commands (flutter analyze, npm build, etc.) (PENDING)
8. ⏳ Run `tools/gates/cto_verify.py` until PASS (PENDING)

### Recommended Priority Order (From Master File):

1. **Fix build/lint/test baselines** for each surface
2. **WhatsApp OTP end-to-end** (backend + both apps) OR remove backend code
3. **Deep link handling** + notification routing (both apps)
4. **Redemption end-to-end** enhancements (customer confirmation screen, detailed history)
5. **Admin Web operational coverage** (campaigns, fraud, redemption audit, points adjustments, Stripe pages if needed)
6. **GDPR UI** + backend wiring (delete account, export data buttons)
7. **Security hardening** (FCM token bypass fix, rules audit, index alignment)
8. **Remove unused orphan backend exports** OR integrate them with UI
9. **Final polish** (consistent error handling, loading states, empty states)

---

## Blocker Candidates

If any of the following are true, create blocker docs and mark requirements as BLOCKED:

1. **WhatsApp Auth:** Requires Twilio WhatsApp Business API credentials
   - If unavailable: Create `docs/BLOCKER_WHATSAPP_AUTH.md`
2. **Stripe Integration:** Requires Stripe webhook secret and test account
   - If unavailable: Create `docs/BLOCKER_STRIPE.md`
3. **Firebase Deploy:** Requires Firebase project selection and deploy permissions
   - If unavailable: Create `docs/BLOCKER_FIREBASE_DEPLOY.md`

---

## Evidence Artifacts

- **Surface Map:** [local-ci/verification/surface_map.json](local-ci/verification/surface_map.json)
- **Requirements Spec:** [spec/requirements.yaml](spec/requirements.yaml)
- **Reality Map (Previous Audit):** [docs/REALITY_MAP_FULL_STACK.md](docs/REALITY_MAP_FULL_STACK.md)
- **Reality Map YAML:** [spec/REALITY_MAP_FULL_STACK.yaml](spec/REALITY_MAP_FULL_STACK.yaml)

---

## Conclusion

The Urban Points Lebanon codebase has **56% ready features** with substantial infrastructure and core functionality implemented. However, **31% of features are completely missing**, primarily due to:
1. Backend functions with no client UI integration
2. Zero unit tests across all surfaces
3. Security bypasses (FCM token direct writes)
4. Mock data in critical analytics functions

**Next Steps:** Follow master file's implementation order (STEP 2-3) to complete missing features, add tests, and run completion gates. Only declare "100% complete" when `tools/gates/cto_verify.py` passes.

---

**Report End**
