# SPRINT 1: EXECUTION MODE

---

## 1️⃣ STRIPE KEYS READINESS

### Firebase Configuration Commands

Once Stripe live keys are provided (sk_live_* and whsec_live_*), execute in order:

```bash
# Set Stripe Secret Key
firebase functions:config:set stripe.secret_key="sk_live_YOUR_ACTUAL_KEY"

# Set Stripe Webhook Secret
firebase functions:config:set stripe.webhook_secret="whsec_live_YOUR_ACTUAL_WEBHOOK_SECRET"

# Deploy functions to pick up new config
firebase deploy --only functions

# Verify config was set
firebase functions:config:get stripe
```

### Expected Output After Deploy
```
✓ functions[initiatePayment(us-central1)] Successful update operation.
✓ functions[stripeWebhook(us-central1)] Successful update operation.
...
✓ Deploy complete!
```

### Verification Command (Run After Deploy)
```bash
curl -X POST https://us-central1-urbangenspark.cloudfunctions.net/initiatePayment \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"customerId":"test","amount":100}' \
  2>&1 | grep -E "success|error"
```

Expected: Either `"success": true` or error message with config-related detail (not "STRIPE_SECRET_KEY not configured")

---

## 2️⃣ REAL-DEVICE SMOKE TEST PLAN

### Prerequisites (Before Testing)
- [ ] iPhone 12+ device with iOS 15+ and developer mode enabled
- [ ] Android 10+ device
- [ ] Both devices connected to same WiFi as tester laptop
- [ ] Test Firebase project configured (or staging project)
- [ ] Tester has sudo/admin access to install apps
- [ ] Tester has test customer/merchant email addresses prepared

### Test Duration: 30-45 minutes

---

## CUSTOMER APP SMOKE TEST

### Part A: Installation & Launch (5 minutes)

**Step 1: Build & Install**
```bash
cd source/apps/mobile-customer
flutter clean
flutter pub get
flutter build apk --release
# Transfer to Android device via USB
adb install build/app/outputs/flutter-apk/app-release.apk
```
- [ ] APK installs without error
- [ ] App icon appears on home screen

**Step 2: Launch App**
- [ ] Tap app icon
- [ ] Splash screen appears
- [ ] No crash dialog
- [ ] Onboarding screen loads (Welcome message visible)

---

### Part B: Authentication Flow (10 minutes)

**Step 3: Create Account**
- [ ] Tap "Sign Up" button
- [ ] Email field accepts input: `test-customer-001@example.com`
- [ ] Password field accepts input: `TestPass123!`
- [ ] Tap "Create Account"
- [ ] **Wait 10 seconds** (Firebase Auth + user doc creation)
- [ ] Home screen appears (not onboarding)
- [ ] No error dialogs
- [ ] **Check phone log**: Open logcat → No RED ERROR lines

**Step 4: Logout & Login**
- [ ] Tap profile icon (top-left or bottom nav)
- [ ] Tap "Logout"
- [ ] Auth screen appears
- [ ] Tap "Already have an account? Log in"
- [ ] Enter same email & password
- [ ] Tap "Login"
- [ ] **Wait 5 seconds**
- [ ] Home screen appears (previously data retained)
- [ ] No crashes

---

### Part C: Core App Flow (20 minutes)

**Step 5: Browse Offers**
- [ ] Home screen shows "Offers" list or "Loading..."
- [ ] **Wait 10 seconds** for data to load
- [ ] At least 1 offer appears (or "No offers available" message)
- [ ] Tap first offer
- [ ] Offer detail screen loads with title, description, points value
- [ ] No null pointer exceptions

**Step 6: Generate QR Code**
- [ ] Tap "Generate QR Code" button (or "Redeem" button)
- [ ] QR code appears on screen with countdown timer (60, 59, 58...)
- [ ] **Wait 5 seconds** (countdown continues)
- [ ] Tap screen to close or wait until timer hits 0
- [ ] No crashes during countdown

**Step 7: Navigate Back**
- [ ] Press back or tap back button
- [ ] Return to offers list
- [ ] Previous scroll position preserved (or list at top)
- [ ] No crashes

**Step 8: Check Points History**
- [ ] Tap "History" tab (or icon at bottom)
- [ ] History screen loads
- [ ] Shows "No transactions" or previous transactions
- [ ] Tap a transaction (if any)
- [ ] Transaction detail shows
- [ ] No null pointer exceptions

**Step 9: Profile Screen**
- [ ] Tap "Profile" tab
- [ ] Profile info loads (email, points balance, membership status)
- [ ] No null pointer exceptions
- [ ] Tap "Billing" or "Subscription" button
- [ ] External browser opens to Stripe checkout (or test form)
- [ ] **Do NOT complete purchase**
- [ ] Browser closes or press back
- [ ] App still running (no crash after browser return)

**Step 10: Background/Resume Test**
- [ ] App is open on home screen
- [ ] Press home button (send app to background)
- [ ] Wait 3 seconds
- [ ] Tap app icon to return
- [ ] App resumes to same screen
- [ ] No crash on resume

---

### Part D: Final Checks (5 minutes)

**Step 11: Crashlytics Verification**
- [ ] Open Firebase Console on laptop: https://console.firebase.google.com/project/urbangenspark/crashlytics
- [ ] Select "mobile-customer" app
- [ ] Verify: **No crash reports** for this session
- [ ] Timestamp matches current time (last 5 minutes)

**Step 12: Network Resilience**
- [ ] Turn OFF WiFi on device (airplane mode on)
- [ ] Tap "Refresh" or navigate to offers list
- [ ] See error message or "No connection" state (no crash)
- [ ] Turn WiFi back ON
- [ ] Data reloads
- [ ] No crash

---

## MERCHANT APP SMOKE TEST

### Part A: Installation & Launch (5 minutes)

**Step 1: Build & Install**
```bash
cd source/apps/mobile-merchant
flutter clean
flutter pub get
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```
- [ ] APK installs
- [ ] App icon appears
- [ ] App launches without crash

---

### Part B: Authentication (10 minutes)

**Step 2: Create Merchant Account**
- [ ] Tap "Sign Up"
- [ ] Email: `test-merchant-001@example.com`
- [ ] Password: `TestPass123!`
- [ ] Tap "Create Account"
- [ ] **Wait 10 seconds**
- [ ] Home screen appears
- [ ] Role indicator shows "Merchant" (if visible)

**Step 3: Logout & Login**
- [ ] Logout
- [ ] Login with same credentials
- [ ] Home screen appears

---

### Part C: Merchant Core Flow (20 minutes)

**Step 4: Create Offer**
- [ ] Tap "Create Offer" button
- [ ] Form loads with fields: Title, Description, Points Cost
- [ ] Enter: Title = "Test Offer", Description = "Test", Points = "100"
- [ ] Tap "Create"
- [ ] **Wait 5 seconds** (Cloud Function call)
- [ ] Success message appears
- [ ] Return to "My Offers" screen
- [ ] New offer appears in list

**Step 5: Edit Offer**
- [ ] Tap newly created offer
- [ ] Tap "Edit" button
- [ ] Form reappears with populated data
- [ ] Change title to "Test Offer Updated"
- [ ] Tap "Save"
- [ ] **Wait 5 seconds**
- [ ] Success message
- [ ] Offer title updated in list

**Step 6: QR Scanner Setup**
- [ ] Tap "Validate Redemption" or "QR Scanner"
- [ ] Permission popup: "Camera Permission"
- [ ] Tap "Allow"
- [ ] Camera view opens (live feed from device camera visible)
- [ ] No crashes

**Step 7: Test QR Scan (with Customer QR from earlier)**
- [ ] Point customer phone at merchant phone camera (both devices side-by-side)
- [ ] Hold 3 seconds
- [ ] If QR scans: Validation screen appears (do NOT complete redemption)
- [ ] If QR doesn't scan: Press back (no crash)

**Step 8: Analytics Screen**
- [ ] Tap "Analytics"
- [ ] Screen loads with charts/data or "No data yet" message
- [ ] No null pointer exceptions
- [ ] Back to home

**Step 9: Billing Screen**
- [ ] Tap "Subscription & Billing"
- [ ] Screen loads with subscription info
- [ ] Tap "Manage Billing"
- [ ] Browser opens
- [ ] **Do NOT complete**
- [ ] Close browser
- [ ] App resumes (no crash)

---

### Part D: Final Checks (5 minutes)

**Step 10: Crashlytics Check**
- [ ] Firebase Console → mobile-merchant → Crashlytics
- [ ] **Verify: No crash reports** for this session

**Step 11: Network Resilience**
- [ ] Airplane mode ON
- [ ] Tap refresh/navigate
- [ ] Error or "no connection" (no crash)
- [ ] Airplane mode OFF
- [ ] Data reloads

---

## PASS CRITERIA

### Customer App
- [ ] All 12 steps completed without app crash
- [ ] No red error lines in logcat
- [ ] No crash reports in Firebase Crashlytics for this session
- [ ] Navigation smooth (no freezes >3 seconds)
- [ ] Network error handled gracefully (no crash)

### Merchant App
- [ ] All 11 steps completed without crash
- [ ] No red error lines in logcat
- [ ] No crash reports in Firebase Crashlytics
- [ ] Camera permission working
- [ ] Navigation smooth
- [ ] Network error handled gracefully

### Overall
- [ ] Both apps complete without crashes
- [ ] Firestore reads/writes work (offers visible, data persists)
- [ ] Cloud Functions callable (offers created successfully)
- [ ] Firebase Crashlytics receives session data (sessions visible in console)

---

## FAIL CRITERIA (Any of these = BLOCK internal beta)

- ❌ App crashes on launch
- ❌ App crashes during any step 1-11
- ❌ RED error lines in logcat (Java exceptions, null pointers)
- ❌ "Application Not Responding" (ANR) dialog appears
- ❌ Firestore data never loads (timeout >15 seconds)
- ❌ Cloud Function fails with error (offer creation fails)
- ❌ Navigation back causes crash
- ❌ Network error causes crash (not handled gracefully)
- ❌ Permission denial causes crash (camera permission)
- ❌ Crash reports visible in Firebase Crashlytics (any red critical error)

---

## 3️⃣ INTERNAL BETA GO / NO-GO GATE

### 5 Pass/Fail Conditions

**Condition 1: Real-Device Smoke Test**
- **Status**: PASS if customer app + merchant app complete all steps with zero crashes
- **Failure Criteria**: Any crash, ANR, or unhandled exception during test
- **Evidence**: Crashlytics report shows 0 critical errors + tester sign-off
- **GO/NO-GO**: ✅ GO only if PASS

---

**Condition 2: Stripe Test Keys Configured**
- **Status**: PASS if `STRIPE_SECRET_KEY` (sk_test_*) and `STRIPE_WEBHOOK_SECRET` are set in Firebase Functions config
- **Failure Criteria**: Keys not set, deployment fails, or config:get returns empty
- **Verification Command**:
  ```bash
  firebase functions:config:get stripe | grep -E "secret_key|webhook_secret"
  ```
  Expected output: Both keys present (values obscured is OK)
- **GO/NO-GO**: ✅ GO only if PASS

---

**Condition 3: Webhook Endpoint Reachable**
- **Status**: PASS if Stripe webhook function responds to HTTP requests with 200 or 401 (not 503/404)
- **Failure Criteria**: Function not deployed, returns 5xx error, or times out
- **Verification Command**:
  ```bash
  curl -s -o /dev/null -w "%{http_code}" \
    https://us-central1-urbangenspark.cloudfunctions.net/stripeWebhook \
    -X POST -H "Content-Type: application/json" -d '{}'
  ```
  Expected: 200, 400, or 401 (not 503/404)
- **GO/NO-GO**: ✅ GO only if PASS

---

**Condition 4: Firebase Crashlytics Active**
- **Status**: PASS if both apps have Crashlytics configured and reporting sessions to Firebase Console
- **Failure Criteria**: No sessions visible in Crashlytics console, SDK not initialized, or error during initialization
- **Verification**: Open Firebase Console → Crashlytics → Both apps show "Active" with session count > 0
- **GO/NO-GO**: ✅ GO only if PASS

---

**Condition 5: Firebase Functions Deployed & Live**
- **Status**: PASS if all 14 core functions (initiatePayment, stripeWebhook, getBalance, generateSecureQRToken, validateRedemption, etc.) are deployed to urbangenspark project
- **Failure Criteria**: Any function shows "Offline" or deployment had errors
- **Verification Command**:
  ```bash
  firebase functions:list
  ```
  Expected: 14 functions, all showing "✓" status
- **GO/NO-GO**: ✅ GO only if PASS

---

## GO / NO-GO VERDICT

### INTERNAL BETA GO ✅

**Requirements:**
- [ ] Condition 1: PASS (all smoke test steps complete, 0 crashes)
- [ ] Condition 2: PASS (Stripe test keys configured)
- [ ] Condition 3: PASS (webhook endpoint reachable)
- [ ] Condition 4: PASS (Crashlytics active and reporting)
- [ ] Condition 5: PASS (Firebase Functions deployed)

**If all 5 conditions PASS:**
```
✅ VERDICT: GO INTERNAL BETA
Next action: Distribute test APKs/IPAs to beta testers (Firebase App Distribution)
```

---

### INTERNAL BETA NO-GO ❌

**If ANY condition FAILS:**
```
❌ VERDICT: BLOCK INTERNAL BETA
Action: Fix failed condition(s), re-run verification, then resubmit
```

**Typical blockers:**
- Smoke test crashes → Fix app bugs, rebuild, retest
- Stripe keys missing → Get keys from Finance, set config, redeploy
- Webhook unreachable → Verify function deployed (firebase deploy --only functions), test again
- Crashlytics inactive → Check function initialization, rebuild, test again
- Functions offline → Run `firebase deploy`, check for errors, retry

---

## EXECUTION CHECKLIST

**Pre-Execution:**
- [ ] Stripe keys obtained from Finance
- [ ] Testing devices available (iPhone + Android)
- [ ] Firebase CLI authenticated (`firebase login`)
- [ ] Source code checked out locally
- [ ] Flutter environment verified (`flutter doctor`)

**Execution Order:**
1. Run Task 1: Set Stripe keys via `firebase functions:config:set`
2. Run Task 2: Smoke test on real devices (30-45 min)
3. Run Task 3: Verify 5 GO/NO-GO conditions
4. Document results in SPRINT_1_EXECUTION_RESULTS.md

**Timeline:**
- Stripe config: 10 minutes
- Real-device smoke test: 45 minutes
- GO/NO-GO verification: 10 minutes
- **Total: ~1 hour**

---

**END OF EXECUTION COMMANDS**
