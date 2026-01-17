# Urban Points Lebanon - PM Backlog
**Generated:** 2026-01-14  
**Source:** Code analysis + Master completion file requirements  
**Status:** Ordered by implementation priority (as per master file)

---

## Backlog Execution Rules

1. Tasks are ordered by priority - execute in sequence unless explicitly marked as parallel
2. Each task has acceptance criteria that must be met before marking complete
3. Evidence paths must be created/updated during execution
4. Do NOT claim task complete without passing acceptance criteria
5. If a task is blocked, create `docs/BLOCKER_<NAME>.md` and move to next task

---

## PHASE 1: BUILD & TEST BASELINES (CRITICAL FOUNDATION)

### Task 1.1: Add Minimal Unit Tests to Customer App
**Status:** NOT_STARTED  
**Priority:** P0 (Required before master file STEP 5)  
**Requirement IDs:** TEST-CUSTOMER-001  
**Estimated Effort:** 2-4 hours

**Description:**
Create minimal unit tests for customer app to enable `flutter test` command execution.

**Acceptance Criteria:**
- [ ] Create `source/apps/mobile-customer/test/` directory
- [ ] Add `auth_service_test.dart` with tests for email/password signin, Google signin
- [ ] Add `points_service_test.dart` with tests for getBalance, getHistory
- [ ] Add `qr_service_test.dart` with tests for generateQRToken
- [ ] Add `fcm_service_test.dart` with tests for token registration
- [ ] Run `cd source/apps/mobile-customer && flutter test` - must exit 0
- [ ] Capture output to `local-ci/verification/customer_app_test.log`

**Evidence Path:**
- Tests: `source/apps/mobile-customer/test/*.dart`
- Log: `local-ci/verification/customer_app_test.log`

---

### Task 1.2: Add Minimal Unit Tests to Merchant App
**Status:** NOT_STARTED  
**Priority:** P0  
**Requirement IDs:** TEST-MERCHANT-001  
**Estimated Effort:** 2-4 hours

**Description:**
Create minimal unit tests for merchant app to enable `flutter test` command execution.

**Acceptance Criteria:**
- [ ] Create `source/apps/mobile-merchant/test/` directory
- [ ] Add `auth_service_test.dart`
- [ ] Add `offer_service_test.dart` with tests for createOffer, editOffer
- [ ] Add `redemption_service_test.dart` with tests for validateRedemption
- [ ] Run `cd source/apps/mobile-merchant && flutter test` - must exit 0
- [ ] Capture output to `local-ci/verification/merchant_app_test.log`

**Evidence Path:**
- Tests: `source/apps/mobile-merchant/test/*.dart`
- Log: `local-ci/verification/merchant_app_test.log`

---

### Task 1.3: Add Minimal Tests to Admin Web
**Status:** NOT_STARTED  
**Priority:** P0  
**Requirement IDs:** TEST-WEB-001  
**Estimated Effort:** 2-3 hours

**Description:**
Create minimal tests for admin web to enable `npm test` command execution.

**Acceptance Criteria:**
- [ ] Add `source/apps/web-admin/__tests__/` directory (if using Jest) OR `source/apps/web-admin/tests/` (if using Vitest)
- [ ] Add `auth.test.ts` with tests for signInWithEmailPassword, requireAdmin
- [ ] Add `api.test.ts` with tests for callable function invocations
- [ ] Update `package.json` scripts to include test command if missing
- [ ] Run `cd source/apps/web-admin && npm test` - must exit 0
- [ ] Capture output to `local-ci/verification/web_admin_test.log`

**Evidence Path:**
- Tests: `source/apps/web-admin/__tests__/*.test.ts` OR `source/apps/web-admin/tests/*.test.ts`
- Log: `local-ci/verification/web_admin_test.log`

---

### Task 1.4: Add Minimal Tests to Backend Functions
**Status:** NOT_STARTED  
**Priority:** P0  
**Requirement IDs:** TEST-BACKEND-001  
**Estimated Effort:** 3-4 hours

**Description:**
Create minimal unit tests for backend functions to enable test execution.

**Acceptance Criteria:**
- [ ] Create `source/backend/firebase-functions/test/` directory
- [ ] Add `whatsapp.test.ts` with tests for sendWhatsAppOTP, verifyWhatsAppOTP (mocked Twilio)
- [ ] Add `redemption.test.ts` with tests for validateRedemption (mocked Firestore)
- [ ] Add `points.test.ts` with tests for adjustPointsManual, transferPointsCallable
- [ ] Add test script to `package.json` if missing
- [ ] Run `cd source/backend/firebase-functions && npm test` - must exit 0
- [ ] Capture output to `local-ci/verification/backend_functions_test.log`

**Evidence Path:**
- Tests: `source/backend/firebase-functions/test/*.test.ts`
- Log: `local-ci/verification/backend_functions_test.log`

---

### Task 1.5: Verify Build/Lint Commands for All Surfaces
**Status:** NOT_STARTED  
**Priority:** P0  
**Estimated Effort:** 1-2 hours

**Description:**
Run build and lint commands for all surfaces and capture output. Fix any critical errors.

**Acceptance Criteria:**
- [ ] Customer app: `flutter pub get && flutter analyze` exits 0
- [ ] Merchant app: `flutter pub get && flutter analyze` exits 0
- [ ] Admin web: `npm ci && npm run build` exits 0
- [ ] Backend functions: `npm ci && npm run build` exits 0
- [ ] Backend rest: `npm ci && npm run build` exits 0 (if build script exists)
- [ ] Capture all outputs to `local-ci/verification/*_build.log`

**Evidence Path:**
- Logs: `local-ci/verification/customer_app_build.log`, `merchant_app_build.log`, `web_admin_build.log`, `backend_functions_build.log`, `backend_rest_build.log`

---

## PHASE 2: CRITICAL SECURITY FIXES

### Task 2.1: Fix FCM Token Registration Bypass
**Status:** NOT_STARTED  
**Priority:** P0 (Security Critical)  
**Requirement IDs:** BACKEND-SECURITY-001  
**Estimated Effort:** 2-3 hours

**Description:**
Refactor customer and merchant apps to use backend callable for FCM token registration instead of direct Firestore writes.

**Acceptance Criteria:**
- [ ] Update `source/apps/mobile-customer/lib/services/fcm_service.dart:saveTokenToFirestore()`:
  - Replace direct Firestore write with call to `registerFCMTokenCallable`
  - Pass device info (platform, model, app version)
  - Handle errors from callable
- [ ] Update `source/apps/mobile-merchant/lib/services/fcm_service.dart:saveTokenToFirestore()` (same changes)
- [ ] Update Firestore security rules to block direct writes to `user_tokens` collection (allow write: if false)
- [ ] Test token registration with multiple devices
- [ ] Test max token limit (register 6+ tokens, verify oldest is pruned)
- [ ] Document changes in `docs/CTO_GAP_AUDIT.md`

**Evidence Path:**
- Modified files: `source/apps/mobile-customer/lib/services/fcm_service.dart`, `source/apps/mobile-merchant/lib/services/fcm_service.dart`
- Updated rules: `source/firestore.rules`
- Test log: `local-ci/verification/fcm_token_security_fix.log`

---

### Task 2.2: Audit and Harden Firestore Security Rules
**Status:** NOT_STARTED  
**Priority:** P1  
**Requirement IDs:** INFRA-RULES-001  
**Estimated Effort:** 2-3 hours

**Description:**
Audit all Firestore security rules to ensure they match access patterns and block unauthorized writes.

**Acceptance Criteria:**
- [ ] Audit `source/firestore.rules` line by line
- [ ] Ensure `user_tokens` collection blocks direct writes (force callable use)
- [ ] Ensure `campaigns` collection requires role='admin'
- [ ] Ensure `admin_logs` collection requires role='admin'
- [ ] Ensure user documents allow self-read but callable-only write
- [ ] Test rules with Firebase Emulator Suite
- [ ] Document rule changes in `local-ci/verification/firestore_rules_audit.log`

**Evidence Path:**
- Updated rules: `source/firestore.rules`
- Audit log: `local-ci/verification/firestore_rules_audit.log`

---

## PHASE 3: HIGH-IMPACT FEATURE COMPLETION

### Task 3.1: Implement WhatsApp OTP Authentication (Customer App)
**Status:** NOT_STARTED  
**Priority:** P1 (OR mark as BLOCKED if no Twilio credentials)  
**Requirement IDs:** CUST-AUTH-003  
**Estimated Effort:** 4-6 hours  
**Blocker Check:** Requires Twilio WhatsApp Business API credentials

**Description:**
Implement WhatsApp OTP authentication flow in customer app, wiring to existing backend functions.

**Acceptance Criteria:**
- [ ] Create `source/apps/mobile-customer/lib/screens/auth/whatsapp_auth_screen.dart`
  - Phone number input field with country code selector
  - "Send OTP" button
  - OTP verification code input (6 digits)
  - "Verify" button
  - Error handling UI
- [ ] Create `source/apps/mobile-customer/lib/services/whatsapp_auth_service.dart`
  - `sendOTP(phoneNumber)` → calls `sendWhatsAppOTP` callable
  - `verifyOTP(phoneNumber, code)` → calls `verifyWhatsAppOTP` callable
  - `getVerificationStatus(phoneNumber)` → calls `getWhatsAppVerificationStatus` callable
- [ ] Update `LoginScreen` to add "Sign in with WhatsApp" button
- [ ] Add route in `main.dart` for WhatsAppAuthScreen
- [ ] Test with real Twilio credentials (send OTP, verify, check status)
- [ ] If Twilio credentials unavailable: Create `docs/BLOCKER_WHATSAPP_AUTH.md` and mark CUST-AUTH-003 as BLOCKED

**Evidence Path:**
- New files: `source/apps/mobile-customer/lib/screens/auth/whatsapp_auth_screen.dart`, `source/apps/mobile-customer/lib/services/whatsapp_auth_service.dart`
- Updated file: `source/apps/mobile-customer/lib/screens/auth/login_screen.dart`
- Test log: `local-ci/verification/whatsapp_auth_customer_test.log` OR blocker doc: `docs/BLOCKER_WHATSAPP_AUTH.md`

---

### Task 3.2: Implement WhatsApp OTP Authentication (Merchant App)
**Status:** NOT_STARTED  
**Priority:** P1 (OR mark as BLOCKED if no Twilio credentials)  
**Requirement IDs:** MERCH-AUTH-003  
**Estimated Effort:** 3-4 hours  
**Depends On:** Task 3.1 (reuse service pattern)

**Description:**
Mirror Task 3.1 for merchant app.

**Acceptance Criteria:**
- [ ] Create `source/apps/mobile-merchant/lib/screens/auth/whatsapp_auth_screen.dart`
- [ ] Create `source/apps/mobile-merchant/lib/services/whatsapp_auth_service.dart`
- [ ] Update merchant `LoginScreen` to add "Sign in with WhatsApp" button
- [ ] Add route in merchant `main.dart`
- [ ] Test with real Twilio credentials
- [ ] If Twilio credentials unavailable: Reference `docs/BLOCKER_WHATSAPP_AUTH.md` and mark MERCH-AUTH-003 as BLOCKED

**Evidence Path:**
- New files: `source/apps/mobile-merchant/lib/screens/auth/whatsapp_auth_screen.dart`, `source/apps/mobile-merchant/lib/services/whatsapp_auth_service.dart`
- Updated file: `source/apps/mobile-merchant/lib/screens/auth/login_screen.dart`
- Test log: `local-ci/verification/whatsapp_auth_merchant_test.log` OR blocker doc: `docs/BLOCKER_WHATSAPP_AUTH.md`

---

### Task 3.3: Implement Deep Link Handling (Customer App)
**Status:** NOT_STARTED  
**Priority:** P1  
**Requirement IDs:** CUST-NOTIF-003  
**Estimated Effort:** 4-6 hours

**Description:**
Add deep link handling to customer app for notification tap routing when app is closed.

**Acceptance Criteria:**
- [ ] Add `uni_links` package to `pubspec.yaml`
- [ ] Configure iOS URL scheme in `ios/Runner/Info.plist`:
  ```xml
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>urbanpoints</string>
      </array>
    </dict>
  </array>
  ```
- [ ] Configure Android intent filter in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="urbanpoints" />
  </intent-filter>
  ```
- [ ] Add deep link handler in `main.dart`:
  - Listen to `uni_links` stream
  - Parse incoming links (e.g., `urbanpoints://offer/123`, `urbanpoints://wallet`, `urbanpoints://points_earned`)
  - Navigate to appropriate screens
- [ ] Update FCM `_handleMessageOpenedApp()` to use deep link handler
- [ ] Test notification deep links with app in all states (foreground, background, closed)
- [ ] Document URL scheme patterns in code comments

**Evidence Path:**
- Updated files: `source/apps/mobile-customer/pubspec.yaml`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`
- Test log: `local-ci/verification/deep_links_customer_test.log`

---

### Task 3.4: Implement Deep Link Handling (Merchant App)
**Status:** NOT_STARTED  
**Priority:** P1  
**Requirement IDs:** (Implied for merchant notifications)  
**Estimated Effort:** 3-4 hours  
**Depends On:** Task 3.3 (reuse pattern)

**Description:**
Mirror Task 3.3 for merchant app.

**Acceptance Criteria:**
- [ ] Same steps as Task 3.3 but for merchant app
- [ ] URL scheme patterns: `urbanpoints-merchant://redemption/123`, `urbanpoints-merchant://analytics`, etc.
- [ ] Test notification deep links

**Evidence Path:**
- Updated files: `source/apps/mobile-merchant/pubspec.yaml`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`
- Test log: `local-ci/verification/deep_links_merchant_test.log`

---

### Task 3.5: Implement GDPR Account Deletion UI
**Status:** NOT_STARTED  
**Priority:** P1 (Legal Compliance)  
**Requirement IDs:** CUST-GDPR-001  
**Estimated Effort:** 2-3 hours

**Description:**
Add "Delete Account" button to customer settings screen with backend callable integration.

**Acceptance Criteria:**
- [ ] Update `source/apps/mobile-customer/lib/screens/settings/settings_screen.dart`:
  - Add "Delete Account" button (red/warning color)
  - Add confirmation dialog with warning text: "This will permanently delete your account and all data. This action cannot be undone. Are you sure?"
  - Add secondary confirmation: "Type 'DELETE' to confirm"
  - Call `deleteUserData` callable on confirmation
  - Show loading spinner during deletion
  - Navigate to login screen after success
  - Handle errors (show alert dialog)
- [ ] Test deletion flow end-to-end
- [ ] Verify user data anonymized in Firestore after deletion

**Evidence Path:**
- Updated file: `source/apps/mobile-customer/lib/screens/settings/settings_screen.dart`
- Test log: `local-ci/verification/gdpr_delete_account_test.log`

---

### Task 3.6: Implement GDPR Data Export UI
**Status:** NOT_STARTED  
**Priority:** P1 (Legal Compliance)  
**Requirement IDs:** CUST-GDPR-002  
**Estimated Effort:** 2-3 hours

**Description:**
Add "Export My Data" button to customer settings screen with backend callable integration.

**Acceptance Criteria:**
- [ ] Update `source/apps/mobile-customer/lib/screens/settings/settings_screen.dart`:
  - Add "Export My Data" button
  - Call `exportUserData` callable on tap
  - Show loading spinner during export
  - Display download link or "Export sent to your email" message
  - Handle errors
- [ ] Test export flow end-to-end
- [ ] Verify JSON export contains all user data (profile, transactions, redemptions, favorites)

**Evidence Path:**
- Updated file: `source/apps/mobile-customer/lib/screens/settings/settings_screen.dart`
- Test log: `local-ci/verification/gdpr_export_data_test.log`

---

### Task 3.7: Implement Customer Redemption Confirmation Screen
**Status:** NOT_STARTED  
**Priority:** P1  
**Requirement IDs:** CUST-REDEEM-002  
**Estimated Effort:** 3-4 hours

**Description:**
Create redemption confirmation screen for customer app to show redemption success after merchant scans QR.

**Acceptance Criteria:**
- [ ] Create `source/apps/mobile-customer/lib/screens/redemption/redemption_confirmation_screen.dart`
  - Display success icon/animation
  - Show offer name, merchant name, points redeemed, timestamp
  - Add "Back to Home" button
- [ ] Implement notification listener or polling mechanism to detect redemption completion
- [ ] Navigate to RedemptionConfirmationScreen when redemption detected
- [ ] Test flow: customer generates QR → merchant scans → customer sees confirmation

**Evidence Path:**
- New file: `source/apps/mobile-customer/lib/screens/redemption/redemption_confirmation_screen.dart`
- Test log: `local-ci/verification/redemption_confirmation_test.log`

---

## PHASE 4: ADMIN WEB OPERATIONAL COVERAGE

### Task 4.1: Implement Push Campaign Management (Create Campaign)
**Status:** NOT_STARTED  
**Priority:** P1  
**Requirement IDs:** ADMIN-CAMPAIGN-001  
**Estimated Effort:** 4-5 hours

**Description:**
Create admin web pages for push campaign creation.

**Acceptance Criteria:**
- [ ] Create `source/apps/web-admin/pages/campaigns/index.tsx` (list campaigns)
  - Fetch campaigns from Firestore `campaigns` collection
  - Display table with campaign name, status, created date, sent date, target count
  - Add "Create Campaign" button
- [ ] Create `source/apps/web-admin/pages/campaigns/create.tsx` (compose form)
  - Form fields: title, message, target audience (all/customers/merchants/tier), schedule (now/later)
  - Call `createCampaignCallable` on submit
  - Redirect to campaigns list on success
- [ ] Add navigation link in admin sidebar: "Campaigns"
- [ ] Test campaign creation end-to-end

**Evidence Path:**
- New files: `source/apps/web-admin/pages/campaigns/index.tsx`, `source/apps/web-admin/pages/campaigns/create.tsx`
- Updated sidebar component
- Test log: `local-ci/verification/admin_campaigns_create_test.log`

---

### Task 4.2: Implement Push Campaign Management (Send Campaign)
**Status:** NOT_STARTED  
**Priority:** P1  
**Requirement IDs:** ADMIN-CAMPAIGN-002  
**Estimated Effort:** 2-3 hours  
**Depends On:** Task 4.1

**Description:**
Add campaign send functionality to admin web.

**Acceptance Criteria:**
- [ ] Update `source/apps/web-admin/pages/campaigns/index.tsx`:
  - Add "Send" button for campaigns with status='draft'
  - Call `sendCampaignCallable` on button click
  - Show confirmation dialog before sending
  - Update campaign status to 'sent' after success
- [ ] Test campaign send end-to-end
- [ ] Verify notifications delivered to target users

**Evidence Path:**
- Updated file: `source/apps/web-admin/pages/campaigns/index.tsx`
- Test log: `local-ci/verification/admin_campaigns_send_test.log`

---

### Task 4.3: Implement Push Campaign Management (Campaign Stats)
**Status:** NOT_STARTED  
**Priority:** P1  
**Requirement IDs:** ADMIN-CAMPAIGN-003  
**Estimated Effort:** 3-4 hours  
**Depends On:** Task 4.1

**Description:**
Create campaign stats dashboard in admin web.

**Acceptance Criteria:**
- [ ] Create `source/apps/web-admin/pages/campaigns/[id].tsx` (campaign detail page)
  - Fetch campaign stats via `getCampaignStatsCallable`
  - Display: total sent, delivered, opened, clicked (if tracked)
  - Display target audience breakdown
  - Display sent timestamp
  - Add chart visualization (e.g., delivery rate over time)
- [ ] Test stats retrieval and display

**Evidence Path:**
- New file: `source/apps/web-admin/pages/campaigns/[id].tsx`
- Test log: `local-ci/verification/admin_campaigns_stats_test.log`

---

### Task 4.4: Implement Fraud Detection Dashboard
**Status:** NOT_STARTED  
**Priority:** P1  
**Requirement IDs:** ADMIN-FRAUD-001, MERCH-REDEEM-005  
**Estimated Effort:** 5-6 hours

**Description:**
Create fraud detection dashboard in admin web and fraud warning UI in merchant app.

**Acceptance Criteria:**
- [ ] Create `source/apps/web-admin/pages/fraud/index.tsx`
  - Call `detectFraudPatternsCallable` or query Firestore for flagged transactions
  - Display table: flagged user, merchant, redemption, fraud score, reason, timestamp
  - Add filters: date range, fraud type, score threshold
  - Add action buttons: "Review", "Ban User", "Disable Offer"
- [ ] Update merchant redemption flow:
  - Check fraud score in redemption response
  - If score > threshold, show warning banner: "This redemption has been flagged for review. Proceed with caution."
  - Merchant can still confirm but warning is logged
- [ ] Add navigation link in admin sidebar: "Fraud Detection"
- [ ] Test fraud detection end-to-end

**Evidence Path:**
- New file: `source/apps/web-admin/pages/fraud/index.tsx`
- Updated merchant redemption files
- Test log: `local-ci/verification/fraud_detection_test.log`

---

### Task 4.5: Implement Admin Points Management UI
**Status:** NOT_STARTED  
**Priority:** P2  
**Requirement IDs:** ADMIN-POINTS-001, ADMIN-POINTS-002, ADMIN-POINTS-003  
**Estimated Effort:** 4-5 hours

**Description:**
Create admin UI for manual points adjustment, transfer, and expiration.

**Acceptance Criteria:**
- [ ] Create `source/apps/web-admin/pages/points/manage.tsx`
  - Tab 1: Manual Adjustment
    - Form: userId, amount (+ or -), reason
    - Call `adjustPointsManual` callable
  - Tab 2: User-to-User Transfer
    - Form: fromUserId, toUserId, amount, reason
    - Call `transferPointsCallable` callable
  - Tab 3: Manual Expiration
    - Form: userId, amount, reason
    - Call `expirePointsManual` callable
  - Show confirmation dialog before each action
  - Log actions to admin audit log
- [ ] Add navigation link in admin sidebar: "Points Management"
- [ ] Test all three operations end-to-end

**Evidence Path:**
- New file: `source/apps/web-admin/pages/points/manage.tsx`
- Test log: `local-ci/verification/admin_points_management_test.log`

---

### Task 4.6: Fix Mock Data in Analytics
**Status:** NOT_STARTED  
**Priority:** P1  
**Requirement IDs:** BACKEND-DATA-001, ADMIN-ANALYTICS-001  
**Estimated Effort:** 3-4 hours

**Description:**
Replace placeholder/mock data in `calculateDailyStats` with real aggregation queries.

**Acceptance Criteria:**
- [ ] Update `source/backend/firebase-functions/src/analytics.ts:calculateDailyStats`
  - Remove mock data constants
  - Implement real Firestore aggregation queries:
    - Daily redemptions count: query `redemptions` collection with timestamp filter
    - Daily signups count: query `users` collection with createdAt filter
    - Active offers count: query `offers` collection with status='active'
  - Return real data
- [ ] OR if real aggregation too expensive:
  - Document function as "sample data for demo only"
  - Create `docs/BLOCKER_ANALYTICS.md`
  - Mark ADMIN-ANALYTICS-001 as BLOCKED or PARTIAL
- [ ] Test admin dashboard with real data
- [ ] Verify dashboard displays accurate numbers

**Evidence Path:**
- Updated file: `source/backend/firebase-functions/src/analytics.ts`
- Test log: `local-ci/verification/analytics_real_data_test.log` OR blocker doc: `docs/BLOCKER_ANALYTICS.md`

---

## PHASE 5: MEDIUM-PRIORITY ENHANCEMENTS

### Task 5.1: Implement Favorites List Screen
**Status:** NOT_STARTED  
**Priority:** P2  
**Requirement IDs:** CUST-OFFER-005  
**Estimated Effort:** 2-3 hours

**Description:**
Create dedicated favorites list screen in customer app.

**Acceptance Criteria:**
- [ ] Create `source/apps/mobile-customer/lib/screens/offers/favorites_screen.dart`
  - Fetch favorites from Firestore `users/{uid}/favorites` subcollection
  - Display offer cards (same as OffersScreen)
  - Add "Remove from Favorites" button
  - Handle empty state: "No favorites yet. Tap ❤️ on offers to save them here."
- [ ] Add route in `main.dart`: `/favorites`
- [ ] Add navigation button in OffersScreen or app bar: "Favorites" icon
- [ ] Test favorites flow end-to-end

**Evidence Path:**
- New file: `source/apps/mobile-customer/lib/screens/offers/favorites_screen.dart`
- Updated navigation
- Test log: `local-ci/verification/favorites_screen_test.log`

---

### Task 5.2: Enhance Redemption History (Customer App)
**Status:** NOT_STARTED  
**Priority:** P2  
**Requirement IDs:** CUST-REDEEM-003  
**Estimated Effort:** 3-4 hours

**Description:**
Create dedicated redemption history screen with detailed view.

**Acceptance Criteria:**
- [ ] Create `source/apps/mobile-customer/lib/screens/redemption/redemption_history_screen.dart`
  - Fetch redemptions from Firestore `redemptions` collection filtered by userId
  - Display list with: offer name, merchant name, points redeemed, timestamp, redemption ID
  - Add tap to view detailed view with: full offer details, merchant contact, redemption status, QR token (if applicable)
  - Add filters: date range (last 7 days, last 30 days, all time)
- [ ] Add route in `main.dart`: `/redemption_history`
- [ ] Add navigation button in WalletScreen or profile menu
- [ ] Test redemption history view

**Evidence Path:**
- New file: `source/apps/mobile-customer/lib/screens/redemption/redemption_history_screen.dart`
- Updated navigation
- Test log: `local-ci/verification/redemption_history_customer_test.log`

---

### Task 5.3: Enhance Redemption History (Merchant App)
**Status:** NOT_STARTED  
**Priority:** P2  
**Requirement IDs:** MERCH-REDEEM-004  
**Estimated Effort:** 3-4 hours

**Description:**
Enhance merchant redemption history with filters and detailed view.

**Acceptance Criteria:**
- [ ] Update `source/apps/mobile-merchant/lib/screens/redemption/redemption_history_screen.dart`
  - Add filters: date range, offer, customer
  - Add CSV export button (generate CSV and share via email/file)
  - Add detailed view: customer info, offer info, timestamp, points redeemed, fraud score (if flagged)
- [ ] Test filters and export

**Evidence Path:**
- Updated file: `source/apps/mobile-merchant/lib/screens/redemption/redemption_history_screen.dart`
- Test log: `local-ci/verification/redemption_history_merchant_test.log`

---

### Task 5.4: Implement Media Upload (Offer Images)
**Status:** NOT_STARTED  
**Priority:** P2  
**Requirement IDs:** MERCH-OFFER-006  
**Estimated Effort:** 4-5 hours

**Description:**
Add image upload UI to merchant offer create/edit screens.

**Acceptance Criteria:**
- [ ] Add `image_picker` package to `source/apps/mobile-merchant/pubspec.yaml`
- [ ] Update `source/apps/mobile-merchant/lib/screens/offers/create_offer_screen.dart`:
  - Add "Upload Image" button
  - On tap, show image picker (camera or gallery)
  - Upload selected image to Firebase Storage: `offers/{offerId}/image.jpg`
  - Store download URL in Firestore offer document `imageUrl` field
  - Show image preview in form
- [ ] Mirror changes in `edit_offer_screen.dart`
- [ ] Test image upload end-to-end
- [ ] Verify image displayed in customer app offer detail screen

**Evidence Path:**
- Updated files: `source/apps/mobile-merchant/lib/screens/offers/create_offer_screen.dart`, `edit_offer_screen.dart`
- Test log: `local-ci/verification/media_upload_offers_test.log`

---

### Task 5.5: Implement Media Upload (Store Logo/Banner)
**Status:** NOT_STARTED  
**Priority:** P2  
**Requirement IDs:** MERCH-PROFILE-001  
**Estimated Effort:** 2-3 hours  
**Depends On:** Task 5.4 (reuse upload logic)

**Description:**
Add logo and banner upload UI to merchant profile screen.

**Acceptance Criteria:**
- [ ] Update `source/apps/mobile-merchant/lib/screens/profile/merchant_profile_screen.dart`:
  - Add "Upload Logo" button
  - Add "Upload Banner" button
  - Upload to Firebase Storage: `merchants/{merchantId}/logo.jpg`, `merchants/{merchantId}/banner.jpg`
  - Store download URLs in Firestore merchant document
- [ ] Test upload end-to-end
- [ ] Verify logo/banner displayed in customer app merchant info

**Evidence Path:**
- Updated file: `source/apps/mobile-merchant/lib/screens/profile/merchant_profile_screen.dart`
- Test log: `local-ci/verification/media_upload_profile_test.log`

---

### Task 5.6: Enhance Admin User Search
**Status:** NOT_STARTED  
**Priority:** P3  
**Requirement IDs:** ADMIN-USER-001  
**Estimated Effort:** 3-4 hours OR document as client-side only

**Description:**
Upgrade admin user search from client-side filtering to backend search.

**Acceptance Criteria (Option A - Full Implementation):**
- [ ] Integrate Algolia Search:
  - Add Algolia account and index
  - Sync Firestore users to Algolia (via Cloud Functions trigger)
  - Update `source/apps/web-admin/pages/users/index.tsx` to call Algolia API
- [ ] OR create backend search endpoint in REST API
- [ ] Test search with large user dataset (1000+ users)

**Acceptance Criteria (Option B - Document Limitation):**
- [ ] Add note to `docs/CTO_GAP_AUDIT.md`: "Admin user search is client-side only. Admins must load more pages manually. For full-text search, integrate Algolia or backend search endpoint."
- [ ] Mark ADMIN-USER-001 as PARTIAL with note

**Evidence Path:**
- Option A: Updated admin web files, Algolia config, test log
- Option B: Updated audit doc

---

## PHASE 6: BACKEND CLEANUP

### Task 6.1: Resolve Orphan Backend Functions
**Status:** NOT_STARTED  
**Priority:** P2  
**Requirement IDs:** BACKEND-ORPHAN-001  
**Estimated Effort:** 4-6 hours

**Description:**
Audit 47 orphan backend functions and either integrate with UI, deprecate, or document as admin-only.

**Acceptance Criteria:**
- [ ] Audit each orphan function (see CTO_GAP_AUDIT.md list)
- [ ] For each function, decide:
  - **Integrate:** Implement UI (already covered in tasks above for WhatsApp, GDPR, campaigns, points, fraud)
  - **Deprecate:** Remove function export if truly unnecessary, update tests
  - **Document:** Add JSDoc comment marking as "Admin-only" or "Internal utility", create admin CLI script if needed
- [ ] Update `spec/requirements.yaml` to reflect decisions
- [ ] Create summary document: `local-ci/verification/orphan_functions_resolution.md`

**Evidence Path:**
- Updated backend files (removed exports or added docs)
- Resolution summary: `local-ci/verification/orphan_functions_resolution.md`

---

## PHASE 7: FINAL GATES & VERIFICATION

### Task 7.1: Create cto_verify.py Gate Script
**Status:** NOT_STARTED  
**Priority:** P0 (Required by master file)  
**Estimated Effort:** 3-4 hours

**Description:**
Create Python verification script that enforces completion criteria.

**Acceptance Criteria:**
- [ ] Create `tools/gates/cto_verify.py`
- [ ] Script must:
  - Parse `spec/requirements.yaml`
  - FAIL if any requirement is not READY (except BLOCKED with matching `docs/BLOCKER_*.md`)
  - Verify each requirement has non-empty anchors
  - Verify routes exist for UI-marked features (parse Flutter/Next.js route files)
  - Verify backend exports referenced by clients exist
  - Verify no TODO/mock/placeholder in critical modules (configurable allowlist)
  - Verify test commands were executed and logs exist in `local-ci/verification/`
  - Generate `local-ci/verification/cto_verify_report.json` with PASS/FAIL status and details
  - Exit 0 if all checks pass, exit 1 if any check fails
- [ ] Add requirements: `pyyaml`, `jsonschema` (if needed)
- [ ] Test script with current codebase (should FAIL initially)

**Evidence Path:**
- New file: `tools/gates/cto_verify.py`
- Report: `local-ci/verification/cto_verify_report.json`

---

### Task 7.2: Run All Required Commands and Capture Logs
**Status:** NOT_STARTED  
**Priority:** P0  
**Estimated Effort:** 1-2 hours

**Description:**
Execute all build/test commands per master file STEP 5 and capture outputs.

**Acceptance Criteria:**
- [ ] Customer app:
  - `cd source/apps/mobile-customer && flutter --version > ../../local-ci/verification/customer_flutter_version.log`
  - `flutter pub get > ../../local-ci/verification/customer_pub_get.log 2>&1`
  - `flutter analyze > ../../local-ci/verification/customer_analyze.log 2>&1`
  - `flutter test > ../../local-ci/verification/customer_test.log 2>&1`
- [ ] Merchant app:
  - Same commands, output to `merchant_*.log`
- [ ] Admin web:
  - `cd source/apps/web-admin && npm ci > ../../local-ci/verification/web_admin_npm_ci.log 2>&1`
  - `npm run build > ../../local-ci/verification/web_admin_build.log 2>&1`
  - `npm test > ../../local-ci/verification/web_admin_test.log 2>&1`
- [ ] Backend functions:
  - `cd source/backend/firebase-functions && npm ci > ../../../local-ci/verification/backend_functions_npm_ci.log 2>&1`
  - `npm run build > ../../../local-ci/verification/backend_functions_build.log 2>&1`
  - `npm test > ../../../local-ci/verification/backend_functions_test.log 2>&1`
- [ ] Backend REST:
  - `cd source/backend/rest-api && npm ci > ../../../local-ci/verification/backend_rest_npm_ci.log 2>&1`
  - `npm run build > ../../../local-ci/verification/backend_rest_build.log 2>&1` (if build script exists)
- [ ] All commands must exit 0 (success)
- [ ] If any command fails: Fix errors, re-run, keep logs

**Evidence Path:**
- Logs: `local-ci/verification/*_version.log`, `*_pub_get.log`, `*_npm_ci.log`, `*_analyze.log`, `*_build.log`, `*_test.log`

---

### Task 7.3: Run cto_verify.py Until PASS
**Status:** NOT_STARTED  
**Priority:** P0  
**Estimated Effort:** Variable (depends on failures)

**Description:**
Execute `tools/gates/cto_verify.py` repeatedly, fixing failures until it exits 0.

**Acceptance Criteria:**
- [ ] Run `python3 tools/gates/cto_verify.py > local-ci/verification/gate_run.log 2>&1`
- [ ] If exit code != 0:
  - Read `local-ci/verification/cto_verify_report.json`
  - Identify failing checks
  - Fix issues (update requirements.yaml, add missing files, fix anchors, etc.)
  - Re-run gate
- [ ] Repeat until exit code == 0
- [ ] Final `cto_verify_report.json` must show status: PASS

**Evidence Path:**
- Final logs: `local-ci/verification/gate_run.log`, `local-ci/verification/cto_verify_report.json`

---

## OPTIONAL: NICE-TO-HAVE (If Time Permits)

### Task 8.1: Implement Stripe Integration Pages
**Status:** NOT_STARTED  
**Priority:** P3 (OR mark as BLOCKED if no Stripe account)  
**Requirement IDs:** ADMIN-PAYMENT-004  
**Estimated Effort:** 4-6 hours

**Description:**
Create admin pages for Stripe transaction management.

**Acceptance Criteria:**
- [ ] Create `source/apps/web-admin/pages/payments/stripe/index.tsx` (transactions list)
- [ ] Create `source/apps/web-admin/pages/payments/stripe/[id].tsx` (transaction detail)
- [ ] Integrate with Stripe API to fetch transactions
- [ ] Add refund/dispute management UI
- [ ] If Stripe credentials unavailable: Create `docs/BLOCKER_STRIPE.md` and mark ADMIN-PAYMENT-004 as BLOCKED

**Evidence Path:**
- New files or blocker doc

---

### Task 8.2: Implement Merchant Staff Management
**Status:** NOT_STARTED  
**Priority:** P3 (OR remove from requirements if not needed)  
**Requirement IDs:** MERCH-STAFF-001  
**Estimated Effort:** 8-12 hours (significant backend + frontend work)

**Description:**
Implement multi-user merchant accounts with staff management.

**Decision Required:**
- If multi-user needed: Requires new backend role system (staff, owner), invite/management UI
- If not needed: Remove requirement from `spec/requirements.yaml` and document as "single owner only"

**Evidence Path:**
- TBD based on decision

---

## Execution Notes

- **Total Estimated Effort:** ~80-100 hours (2-3 weeks for single developer)
- **Critical Path:** Phase 1 (tests) → Phase 2 (security) → Phase 3 (high-impact features) → Phase 7 (gates)
- **Parallel Work Opportunities:**
  - Phase 3 tasks (WhatsApp, deep links, GDPR, redemption) can be done in parallel if multiple developers
  - Phase 4 tasks (admin web pages) can be done in parallel
- **Blockers to Watch:**
  - Twilio WhatsApp credentials (affects Tasks 3.1, 3.2)
  - Stripe credentials (affects Task 8.1)
  - Firebase deploy permissions (not covered in backlog, may require `docs/BLOCKER_FIREBASE_DEPLOY.md`)

---

**Backlog End**
