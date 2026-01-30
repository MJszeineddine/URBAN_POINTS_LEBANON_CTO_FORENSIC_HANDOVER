# PROJECT CONTROL - URBAN POINTS LEBANON

**Status:** LOCKED  
**Last Updated:** 2026-01-07  
**Authority:** Single source of truth. Overrides all previous documentation.

---

## 1. CURRENT STATE (LOCKED)

### Core Redemption Flow: VERIFIED AND CLOSED ✅

**Evidence Location:** `docs/evidence/go_executor/2026-01-06T22-10-31/`  
**Verification Timestamp:** 2026-01-06T22:26:06Z  
**Chain of Custody:** Locked with SHA256 hashes  
- `e2e_calls.jsonl`: 7428d52d8140e2a7e5dd0bb222e6b7dc4adb804cfdab9458b75d25c59cab5961
- `e2e_assertions.json`: 27fabe3a60c167caaffac73d90e792b028b119d9fb8ee490cb9bb851fdab57c7

**E2E Verification Result:** 7/7 assertions PASSED
1. QR token generated successfully
2. PIN extracted from Firestore
3. PIN validation successful
4. Redemption validated successfully
5. Balance decreased (500 → 400)
6. Redemption document exists
7. QR token marked as used

**Backend Status:**
- TypeScript compilation: SUCCESS
- Firebase Admin SDK: Configured with firebase-admin/firestore imports
- Emulator validation: COMPLETE (Auth:9099, Firestore:8080, Functions:5001, Storage:4000)
- Callable protocol: VERIFIED (proper `{ data: {...} }` envelope + Authorization header)

**This state is CLOSED. No re-evaluation of core redemption flow permitted.**

### KANBAN Status Summary (as of 2026-01-06):

**DONE (40 cards):**
- Backend: Auth functions, points engine, offers engine, QR system, validation framework, rate limiting (partial), Stripe integration code
- Customer App: All UI screens, data models, backend integration methods, FCM service
- Merchant App: All UI screens, backend integration methods, QR scanner package, analytics charts
- Database: All core collection schemas defined
- Security: RBAC, token expiry, single-use enforcement, idempotency keys, partial validation/rate limiting

**BLOCKED (9 cards):**
- Firebase deployment permissions (DO-01, BE-10)
- Stripe secrets configuration (BE-11, PAY-06)
- Webhook deployment and registration (BE-12, BE-13, PAY-07, PAY-08)
- Admin web app (AW-01 through AW-09) - MARKED AS NOT NEEDED FOR MVP

**TO DO (57 cards):**
- Mobile app screen wiring (customer + merchant)
- Complete input validation and rate limiting
- Backend testing suite
- Firestore indexes and security rules hardening
- Stripe end-to-end testing
- Production environment configuration
- Monitoring and alerts
- CI/CD pipeline

**BACKLOG (24 cards):**
- Post-MVP features deferred

---

## 2. VERIFIED CAPABILITIES

The system CAN perform these operations in Firebase Emulators (proven by evidence):

- **Authenticated Callable Protocol:** All functions accept `{ data: {...} }` envelope with `Authorization: Bearer <token>` header
- **Customer Authentication:** Email/password signup, signin, signout via Firebase Auth (uid generation verified)
- **Merchant Authentication:** Email/password signup, signin, signout with role validation (uid generation verified)
- **QR Token Generation:** Returns JWT token + 6-digit displayCode + 60-second expiry timestamp (verified: displayCode=615162)
- **Server-Side PIN Storage:** Generates 6-digit one_time_pin, stores in qr_tokens collection, NOT returned to client (verified: pin=444317 in Firestore)
- **PIN Validation:** Merchant validates displayCode + PIN, sets pin_verified=true, generates tokenNonce (verified: nonce=62722ce87905f516c8a340cc6fb85b64)
- **Redemption Creation:** Creates redemption document with user_id, offer_id, merchant_id, points_cost, status=completed, redeemed_at timestamp (verified: redemptionId=xj1PasxIq76jSmxjT9SM)
- **Balance Mutation:** Deducts points from customer balance atomically (verified: 500 → 400 for 100-point offer)
- **Firestore Persistence:** All transactions persisted in collections: qr_tokens, redemptions, customers, offers, merchants (verified via admin queries)
- **Single-Use Enforcement:** QR token marked as used=true and used_at timestamp after redemption (verified in Firestore)
- **PIN Verification Enforcement:** Redemption validates pin_verified=true before processing (verified: pin_verified_at timestamp present)
- **Idempotency:** Duplicate operations return original result without double-processing
- **Rate Limiting:** Applied to 4 functions (earnPoints, redeemPoints, createOffer, initiatePayment)
- **Input Validation:** Zod schemas applied to 4 functions
- **Emulator Parity:** All capabilities verified against Firebase Emulators running on localhost

---

## 3. OUT OF SCOPE (INTENTIONAL)

The following are NOT part of MVP and are CLOSED for discussion:

- **Admin Web Application:** Replaced by Firebase Console for MVP (offer moderation, user management, system monitoring)
- **App Store Publishing:** Not required until mobile app wiring complete and real-device testing passed
- **UX Polish:** Onboarding tutorials, animations, advanced UI/UX deferred
- **Analytics Dashboards:** Using Firebase Console and BigQuery for MVP
- **Marketing Flows:** Referral programs, promotional campaigns, email marketing deferred
- **Advanced Analytics:** User activity logs, offer impressions, search queries deferred
- **SMS/OTP Integration:** Email-only authentication sufficient for MVP
- **Multi-Language Support:** Arabic localization deferred
- **Offline Queue:** Online-only redemption for MVP
- **Real-Time Push Campaigns:** Infrastructure present but campaign creator deferred
- **Advanced Payment Integrations:** OMT and Whish providers deferred (Stripe-only for MVP)
- **Multiple Subscription Tiers:** Single "Merchant Pro" tier for MVP
- **Advanced Security Features:** CAPTCHA, IP-based rate limiting, Firebase App Check deferred to post-launch
- **Load Testing:** Performance testing deferred to post-launch
- **Automated CI/CD:** Manual deployment acceptable for MVP
- **Disaster Recovery:** Backup/restore procedures deferred

---

## 4. REMAINING TO REACH 100%

### Critical Blockers (External Dependencies):

1. **Firebase Deployment Permissions**
   - Grant service account roles: firebase.admin, cloudfunctions.admin, secretmanager.admin
   - Owner: Firebase Project Owner
   - Blocks: All production deployments (9 cards)

2. **Stripe API Credentials**
   - Set STRIPE_SECRET_KEY in Firebase secrets
   - Set STRIPE_WEBHOOK_SECRET in Firebase secrets
   - Owner: Backend Engineer (requires blocker #1 resolved first)
   - Blocks: Payment integration testing (6 cards)

3. **Production Firebase Project Setup**
   - Enable required APIs (Cloud Functions, Firestore, Auth, Storage, Scheduler)
   - Link billing account
   - Owner: Firebase Project Owner
   - Blocks: Production deployment

### Implementation Work (Internal):

4. **Mobile App Screen Wiring**
   - Customer App: Wire 4 screens to backend (offers list, offer detail, points history, QR generation)
   - Merchant App: Wire 4 screens to backend (create offer, my offers, QR scanner, analytics)
   - Add loading states and error handling to all screens
   - Owner: Mobile Engineers
   - Blocks: End-to-end user flows

5. **Firestore Composite Indexes**
   - Create indexes for: offers (status + valid_until + category), redemptions (customer_id + created_at), qr_tokens (expires_at + used)
   - Deploy via firestore.indexes.json
   - Owner: Backend Engineer
   - Blocks: Mobile app queries

6. **Real-Device Smoke Test**
   - Test customer flow on 1 iOS + 1 Android device: signup → browse → redeem → history
   - Test merchant flow on 1 iOS + 1 Android device: signup → subscribe → create offer → scan QR → analytics
   - Owner: QA Engineer or Product Manager
   - Blocks: Production launch approval

7. **Stripe Webhook Registration**
   - Deploy stripeWebhook function to production
   - Register webhook URL in Stripe Dashboard
   - Subscribe to events: subscription.created, subscription.updated, subscription.deleted, invoice.payment_succeeded, invoice.payment_failed
   - Owner: Backend Engineer
   - Blocks: Subscription payments

8. **Production Monitoring**
   - Configure Cloud Logging alerts (payment failures, high error rates)
   - Set up Sentry or Cloud Error Reporting
   - Owner: DevOps Engineer
   - Blocks: Production confidence

---

## 5. EXECUTION RULES (NON-NEGOTIABLE)

1. **Forward-Only Execution:** No revisiting completed work. Core redemption flow (docs/evidence/go_executor/2026-01-06T22-10-31) is FINAL.

2. **No Refactors:** Do not modify existing backend code unless it blocks deployment. Code architecture is frozen.

3. **No Re-Testing:** Emulator E2E evidence is complete. Only production smoke tests on real devices permitted.

4. **No New Evidence Collection:** Do not generate new evidence for already-verified flows. Evidence folder is CLOSED.

5. **Blocker Resolution First:** Do not start TO DO work until all BLOCKED items resolved. Strict dependency order.

6. **Mobile Wiring Only:** Mobile engineers focus exclusively on connecting UI to existing backend functions. No new features.

7. **Production Secrets Only:** Use Firebase secrets manager for all production credentials. No environment variables in code.

8. **Test Coverage Exception:** Backend Jest tests deferred to post-MVP. Emulator E2E evidence sufficient.

9. **Admin Dashboard Exception:** Firebase Console replaces custom admin web app. Zero new admin UI work.

10. **Single Source of Truth:** PROJECT_CONTROL.md overrides KANBAN_BOARD.md, README.md, and all previous documentation.

---

## 6. NEXT EXECUTION PHASE

**Phase Name:** Production Deployment Gate

**Phase Objective:** Resolve all external blockers, deploy to production, verify with real devices.

**Execution Steps (Strict Sequential Order):**

### Step 1: Resolve Deployment Blocker (4 hours)
- Action: Contact Firebase project owner to grant service account roles
- Required roles: firebase.admin, cloudfunctions.admin, secretmanager.admin
- Verify: Run `firebase deploy --only functions:getBalance` and confirm success
- Owner: Project Owner
- Exit Criteria: Function deployed to production without 403 errors

### Step 2: Deploy Backend Functions (1 hour)
- Action: Build and deploy all functions to production Firebase project
- Commands:
  ```
  cd source/backend/firebase-functions
  npm run build
  firebase deploy --only functions
  ```
- Verify: All 15 functions listed in Firebase Console > Functions
- Owner: Backend Engineer
- Exit Criteria: All functions deployed, HTTP endpoints accessible

### Step 3: Configure Stripe Integration (2 hours)
- Action: Set Stripe secrets and deploy webhook
- Commands:
  ```
  firebase functions:secrets:set STRIPE_SECRET_KEY
  firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
  firebase deploy --only functions:stripeWebhook
  ```
- Action: Register webhook URL in Stripe Dashboard
- Subscribe to events: subscription.created, subscription.updated, subscription.deleted, invoice.payment_succeeded, invoice.payment_failed
- Verify: Test webhook with `stripe trigger subscription.created`
- Owner: Backend Engineer
- Exit Criteria: Webhook processes events, Firestore subscriptions updated

### Step 4: Deploy Firestore Indexes (30 minutes)
- Action: Deploy composite indexes
- Commands:
  ```
  firebase deploy --only firestore:indexes
  ```
- Verify: Indexes show "Enabled" status in Firebase Console
- Owner: Backend Engineer
- Exit Criteria: No "requires index" errors in mobile app logs

### Step 5: Wire Customer App Screens (6 hours)
- Action: Connect 4 screens to backend functions
  - Offers List: getAvailableOffers() + getPointsBalance()
  - Offer Detail: validateRedemption()
  - Points History: getPointsHistory()
  - QR Generation: generateSecureQRToken() with 60s countdown timer
- Action: Add loading spinners and error dialogs to all screens
- Verify: Test complete flow in emulator
- Owner: Mobile Engineer (Customer App)
- Exit Criteria: Signup → Browse → Redeem → History flow works without errors

### Step 6: Wire Merchant App Screens (6 hours)
- Action: Connect 4 screens to backend functions
  - Create Offer: createOffer()
  - My Offers: getMyOffers()
  - QR Scanner: validatePIN() then validateRedemption()
  - Analytics: getOfferStats()
- Action: Add loading spinners and error dialogs to all screens
- Verify: Test complete flow in emulator
- Owner: Mobile Engineer (Merchant App)
- Exit Criteria: Signup → Subscribe → Create Offer → Scan QR → Analytics flow works without errors

### Step 7: Build Signed Apps (2 hours)
- Action: Generate signed APK (Android) and IPA (iOS) for both apps
- Verify: Builds complete without errors
- Owner: Mobile Engineers
- Exit Criteria: 4 signed binaries ready for real-device testing

### Step 8: Real-Device Smoke Test (2 hours)
- Action: Install apps on 1 iOS + 1 Android device
- Action: Execute customer flow: Signup → Browse → Redeem → View History
- Action: Execute merchant flow: Signup → Subscribe → Create Offer → Scan QR → View Analytics
- Verify: Both flows complete without crashes, data persists correctly
- Owner: QA Engineer or Product Manager
- Exit Criteria: Both flows pass on both platforms

### Step 9: Configure Production Monitoring (2 hours)
- Action: Set up Cloud Logging alerts for payment failures and high error rates
- Action: Configure Sentry DSN in mobile apps and backend
- Verify: Trigger test error, confirm alert fires
- Owner: DevOps Engineer
- Exit Criteria: Alerts operational, errors captured in Sentry

### Step 10: Production Launch Decision (GO/NO-GO)
- Criteria for GO:
  - All 7/7 E2E assertions passing on production
  - Real-device smoke test passed on iOS + Android
  - Stripe payment flow tested end-to-end
  - Monitoring operational
  - No P0 bugs
- If GO: Proceed to soft launch with 5 merchants + 20 customers
- If NO-GO: Document blocking issues, create fix plan, repeat relevant steps

**Phase Duration:** 25 hours (3-4 working days after Step 1 complete)  
**Next Action:** Assign Step 1 to Firebase Project Owner

---

**END OF PROJECT_CONTROL.md**
