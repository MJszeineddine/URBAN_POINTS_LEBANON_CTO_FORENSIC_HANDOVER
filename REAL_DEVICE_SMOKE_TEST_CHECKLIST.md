# REAL-DEVICE SMOKE TEST CHECKLIST

**Project:** Urban Points Lebanon MVP  
**Test Date:** TBD (After signed apps built)  
**Tester:** QA Engineer / Product Manager  
**Devices Required:** 1 iOS device + 1 Android device  

**IMPORTANT:** Do NOT re-test emulator flows. This checklist tests ONLY production deployment on real hardware.

---

## PRE-TEST SETUP

### Prerequisites
- [ ] Backend functions deployed to production (verify: https://console.firebase.google.com/project/urbangenspark/functions)
- [ ] Firestore indexes deployed and enabled (verify: https://console.firebase.google.com/project/urbangenspark/firestore/indexes)
- [ ] Signed customer app APK + IPA available
- [ ] Signed merchant app APK + IPA available
- [ ] Test devices have internet connectivity (Wi-Fi or cellular)
- [ ] Test accounts prepared:
  - 1 customer test account (email + password)
  - 1 merchant test account (email + password)

### Installation
- [ ] Install customer app on iOS device
- [ ] Install customer app on Android device
- [ ] Install merchant app on iOS device
- [ ] Install merchant app on Android device

---

## CUSTOMER APP - IOS DEVICE

### Test Flow: Signup → Browse → Redeem → History

#### 1. Signup Flow
- [ ] Launch customer app
- [ ] Tap "Sign Up"
- [ ] Enter email, password, confirm password
- [ ] Submit form
- [ ] **PASS CRITERIA:** User redirected to offers list screen, no crash

#### 2. Browse Offers
- [ ] Offers list displays (may be empty if no offers created yet)
- [ ] Points balance visible in app bar (default: 0)
- [ ] Pull to refresh works
- [ ] **PASS CRITERIA:** Screen renders without crash, balance loads

#### 3. Create Test Offer (Temporary Step)
- [ ] Switch to merchant app
- [ ] Sign in with merchant test account
- [ ] Create 1 test offer (title: "Smoke Test Offer", points: 100)
- [ ] Switch back to customer app
- [ ] Pull to refresh offers list
- [ ] **PASS CRITERIA:** Test offer appears in list

#### 4. Attempt Redemption (Expected Failure)
- [ ] Tap on test offer
- [ ] Tap "Redeem" button
- [ ] **EXPECTED:** Error dialog "Insufficient Points" (customer has 0 balance)
- [ ] Dismiss dialog
- [ ] **PASS CRITERIA:** App handles error gracefully, no crash

#### 5. Add Test Points (Backend Console)
- [ ] Open Firebase Console: https://console.firebase.google.com/project/urbangenspark/firestore
- [ ] Navigate to `customers` collection
- [ ] Find customer document (by email or UID)
- [ ] Edit `points_balance` field → set to 500
- [ ] Save changes

#### 6. Redeem Offer
- [ ] Return to customer app
- [ ] Pull to refresh offers list
- [ ] Verify balance updated to 500 in app bar
- [ ] Tap on test offer
- [ ] Tap "Redeem" button
- [ ] **PASS CRITERIA:** QR generation screen appears

#### 7. QR Token Generation
- [ ] Verify 6-digit display code shown
- [ ] Verify QR code visible
- [ ] Verify countdown timer starts at 60 seconds
- [ ] Observe timer decrementing
- [ ] **PASS CRITERIA:** QR code displays, timer counts down, no crash

#### 8. Points History
- [ ] Navigate back to offers list
- [ ] Tap "History" or "Profile" tab (check app navigation)
- [ ] Verify points history loads
- [ ] **PASS CRITERIA:** History screen renders, shows transactions (may be empty)

#### iOS Customer App Result
- [ ] **PASS** (all criteria met)
- [ ] **FAIL** (record failures below)

**iOS Customer App Failures:**
```
(Record any failures here)
```

---

## CUSTOMER APP - ANDROID DEVICE

### Test Flow: Signup → Browse → Redeem → History

**NOTE:** If using same test account, skip signup step. If different account, follow full flow.

#### 1. Signup Flow
- [ ] Launch customer app
- [ ] Tap "Sign Up" or sign in if account exists
- [ ] Enter credentials
- [ ] Submit form
- [ ] **PASS CRITERIA:** User redirected to offers list screen, no crash

#### 2. Browse Offers
- [ ] Offers list displays
- [ ] Points balance visible in app bar
- [ ] Pull to refresh works
- [ ] **PASS CRITERIA:** Screen renders without crash, balance loads

#### 3. Redeem Offer
- [ ] Tap on test offer (created earlier)
- [ ] Tap "Redeem" button
- [ ] **PASS CRITERIA:** QR generation screen appears

#### 4. QR Token Generation
- [ ] Verify 6-digit display code shown
- [ ] Verify QR code visible
- [ ] Verify countdown timer starts at 60 seconds
- [ ] Observe timer decrementing
- [ ] **PASS CRITERIA:** QR code displays, timer counts down, no crash

#### 5. Points History
- [ ] Navigate back to offers list
- [ ] Tap "History" or "Profile" tab
- [ ] Verify points history loads
- [ ] **PASS CRITERIA:** History screen renders

#### Android Customer App Result
- [ ] **PASS** (all criteria met)
- [ ] **FAIL** (record failures below)

**Android Customer App Failures:**
```
(Record any failures here)
```

---

## MERCHANT APP - IOS DEVICE

### Test Flow: Signup → Create Offer → Scan QR → View Analytics

#### 1. Signup Flow
- [ ] Launch merchant app
- [ ] Tap "Sign Up" or sign in if account exists
- [ ] Enter credentials
- [ ] Submit form
- [ ] **PASS CRITERIA:** User redirected to merchant home screen, no crash

#### 2. Create Offer
- [ ] Tap "Create Offer" or "+" button
- [ ] Fill form:
  - Title: "iOS Smoke Test Offer"
  - Description: "Test offer for smoke testing"
  - Category: Any
  - Points Cost: 100
  - (Optional fields: leave empty or fill as desired)
- [ ] Tap "Create Offer" button
- [ ] **EXPECTED:** Loading spinner appears
- [ ] **PASS CRITERIA:** Success message shown, redirected to offers list, offer appears

#### 3. My Offers Screen
- [ ] Navigate to "My Offers" tab
- [ ] Verify newly created offer appears in list
- [ ] Verify offer details correct (title, points, category)
- [ ] Pull to refresh works
- [ ] **PASS CRITERIA:** Offers load without crash

#### 4. Scan QR Code
- [ ] Have customer app ready with QR code displayed (from earlier test)
- [ ] Tap "Scan QR" button in merchant app
- [ ] Grant camera permissions if prompted
- [ ] Point camera at customer QR code
- [ ] **EXPECTED:** QR detected, PIN entry screen appears

#### 5. Enter PIN
- [ ] Retrieve PIN from Firebase Console (check earlier documentation for method)
  - Alternative: Use backend logs if PIN visible
  - Alternative: If PIN retrieval blocked, document as "PIN retrieval issue" and skip to analytics
- [ ] Enter 6-digit PIN
- [ ] Tap "Verify PIN" button
- [ ] **EXPECTED:** Redemption confirmation screen appears
- [ ] **PASS CRITERIA:** PIN validation succeeds (or fails gracefully with clear error)

#### 6. Complete Redemption
- [ ] Review redemption details (offer, customer, points)
- [ ] Tap "Complete Redemption" button
- [ ] **EXPECTED:** Success message shown
- [ ] **PASS CRITERIA:** Redemption completes, merchant app returns to home screen

#### 7. View Analytics
- [ ] Navigate to "Analytics" tab
- [ ] Verify statistics load:
  - Total Offers
  - Active Offers
  - Total Redemptions
  - Total Points Earned
- [ ] **PASS CRITERIA:** Analytics screen renders with data, no crash

#### iOS Merchant App Result
- [ ] **PASS** (all criteria met)
- [ ] **FAIL** (record failures below)

**iOS Merchant App Failures:**
```
(Record any failures here)
```

---

## MERCHANT APP - ANDROID DEVICE

### Test Flow: Signup → Create Offer → Scan QR → View Analytics

#### 1. Signup Flow
- [ ] Launch merchant app
- [ ] Tap "Sign Up" or sign in if account exists
- [ ] Enter credentials
- [ ] Submit form
- [ ] **PASS CRITERIA:** User redirected to merchant home screen, no crash

#### 2. Create Offer
- [ ] Tap "Create Offer" or "+" button
- [ ] Fill form:
  - Title: "Android Smoke Test Offer"
  - Description: "Test offer for Android smoke testing"
  - Category: Any
  - Points Cost: 100
- [ ] Tap "Create Offer" button
- [ ] **EXPECTED:** Loading spinner appears
- [ ] **PASS CRITERIA:** Success message shown, offer appears in list

#### 3. My Offers Screen
- [ ] Navigate to "My Offers" tab
- [ ] Verify newly created offer appears
- [ ] Pull to refresh works
- [ ] **PASS CRITERIA:** Offers load without crash

#### 4. Scan QR Code
- [ ] Have customer app ready with QR code displayed
- [ ] Tap "Scan QR" button in merchant app
- [ ] Grant camera permissions if prompted
- [ ] Point camera at customer QR code
- [ ] **EXPECTED:** QR detected, PIN entry screen appears

#### 5. Enter PIN
- [ ] Retrieve PIN from Firebase Console or backend logs
- [ ] Enter 6-digit PIN
- [ ] Tap "Verify PIN" button
- [ ] **EXPECTED:** Redemption confirmation screen appears
- [ ] **PASS CRITERIA:** PIN validation succeeds

#### 6. Complete Redemption
- [ ] Review redemption details
- [ ] Tap "Complete Redemption" button
- [ ] **EXPECTED:** Success message shown
- [ ] **PASS CRITERIA:** Redemption completes successfully

#### 7. View Analytics
- [ ] Navigate to "Analytics" tab
- [ ] Verify statistics load
- [ ] **PASS CRITERIA:** Analytics screen renders with updated redemption count

#### Android Merchant App Result
- [ ] **PASS** (all criteria met)
- [ ] **FAIL** (record failures below)

**Android Merchant App Failures:**
```
(Record any failures here)
```

---

## CROSS-PLATFORM CONSISTENCY CHECKS

### Data Consistency
- [ ] Customer balance decreased by correct amount on both platforms
- [ ] Redemption appears in customer history on both platforms
- [ ] Merchant analytics updated on both platforms
- [ ] Offer redemption count incremented

### Backend Verification (Firebase Console)
- [ ] Check `redemptions` collection: New redemption documents exist
- [ ] Check `qr_tokens` collection: Tokens marked as `used: true`
- [ ] Check `customers` collection: Balance decreased correctly
- [ ] Check `offers` collection: Redemption count incremented

---

## PERFORMANCE OBSERVATIONS

### Load Times (Record approximate times)
- Customer app launch: _____ seconds
- Offers list load: _____ seconds
- QR generation: _____ seconds
- Merchant app launch: _____ seconds
- Analytics load: _____ seconds

### Issues Observed
- [ ] Any crashes (if yes, record below)
- [ ] Any UI rendering issues
- [ ] Any network errors
- [ ] Any data inconsistencies

**Performance Issues:**
```
(Record any performance issues here)
```

---

## FINAL VERDICT

### Overall Result
- [ ] **GO** - All critical flows passed on both platforms
- [ ] **CONDITIONAL GO** - Minor issues found, document and proceed
- [ ] **NO-GO** - Critical failures found, deployment blocked

### Critical Failures (P0)
```
(List any critical failures that block production launch)
```

### Minor Issues (P1/P2)
```
(List any minor issues that can be addressed post-launch)
```

---

## SIGN-OFF

**Tester Name:** ___________________________  
**Tester Signature:** ___________________________  
**Test Date:** ___________________________  
**Test Duration:** ___________________________  

**Approved for Production Launch:**
- [ ] YES - Proceed with soft launch
- [ ] NO - Address failures and re-test

**CTO/Product Owner Signature:** ___________________________  
**Date:** ___________________________
