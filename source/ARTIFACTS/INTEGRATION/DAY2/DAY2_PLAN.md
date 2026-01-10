# DAY 2 EXECUTION PLAN

**Generated**: 2026-01-03T16:30:00+00:00  
**Mission**: Wire Mobile Customer + Mobile Merchant apps to Firebase Auth + Cloud Functions

---

## DISCOVERY FINDINGS

### Customer App (/apps/mobile-customer)
✅ Auth screens exist: login_screen.dart, signup_screen.dart  
✅ Auth service exists: services/auth_service.dart  
✅ Firebase options configured: firebase_options.dart (project: urbangenspark)  
✅ FirebaseFunctions already in use: qr_generation_screen.dart  
⚠️ **ISSUE**: Auth service creates docs in `customers` collection, but backend expects `users`  
⚠️ **ISSUE**: No custom claims reading  
⚠️ **ISSUE**: No role-based routing

### Merchant App (/apps/mobile-merchant)
✅ Auth screens exist: login_screen.dart, signup_screen.dart  
✅ Auth service exists: services/auth_service.dart  
✅ Firebase options configured: firebase_options.dart (project: urbangenspark)  
✅ FirebaseFunctions already in use: validate_redemption_screen.dart  
⚠️ **ISSUE**: Auth service creates docs in `merchants` collection, but backend expects `users`  
⚠️ **ISSUE**: No custom claims reading  
⚠️ **ISSUE**: No role-based routing

###Configuration Status
✅ Firebase project: urbangenspark (correct)  
✅ Firebase options: Properly configured for web, android, ios  
❌ google-services.json: Not found in android/app/ (may cause issues)  
✅ FirebaseFunctions dependency: Already present in both apps

---

## EXECUTION STRATEGY

### STEP 1: Update Auth Services (BOTH APPS)
**Changes to make**:
1. **Remove client-side Firestore doc creation** from signUp methods
   - The backend `onUserCreate` trigger automatically creates `/users/{uid}` doc
   - Keep only Firebase Auth user creation
   - Remove manual `customers`/`merchants` collection writes

2. **Add custom claims reading**:
   - `forceRefreshIdToken()` - Force token refresh
   - `getIdTokenResult()` - Read custom claims from token
   - `getUserRole()` - Extract role from custom claims

3. **Add Firestore user doc reading**:
   - `fetchUserProfile()` - Read from `/users/{uid}` (not customers/merchants)
   - `ensureUserDocExists()` - Verify user doc exists, wait if needed

4. **Add callable function support**:
   - `callGetUserProfile()` - Call deployed `getUserProfile` function
   - Fallback to Firestore direct read if callable fails

### STEP 2: Implement Role-Based Routing (BOTH APPS)
**New files to create**:
1. `lib/screens/auth/role_blocked_screen.dart` - Shows blocking message for wrong role
2. `lib/utils/role_validator.dart` - Centralized role validation logic

**Integration points**:
1. Update `main.dart` to check role after Firebase initialization
2. Update login/signup flows to validate role after authentication
3. Redirect to `role_blocked_screen` if role mismatch

**Validation rules**:
- **Customer app**: Allow roles `customer`, `user` only
- **Merchant app**: Allow role `merchant` only
- **Both**: Block if `isActive == false`

### STEP 3: Update Main Entry Points (BOTH APPS)
**Changes to `main.dart`**:
1. After Firebase init, check if user is logged in
2. If logged in:
   - Refresh ID token
   - Read custom claims role
   - Read Firestore user doc
   - Validate role matches app
   - Route to home or role_blocked_screen

### STEP 4: Update Login/Signup Screens (BOTH APPS)
**Minimal changes** to existing screens:
1. After successful auth, call new role validation
2. If role valid → navigate to home
3. If role invalid → navigate to role_blocked_screen
4. Show loading indicator during validation

### STEP 5: Create E2E Sanity Scripts (BOTH APPS)
**New files**:
- `tool/auth_sanity.dart` (customer)
- `tool/auth_sanity.dart` (merchant)

**Capabilities**:
- Print Firebase initialization status
- Print current user (if any)
- If TEST_EMAIL + TEST_PASSWORD env vars exist:
  - Attempt sign-in
  - Print uid, custom claims role, Firestore role
  - Print PASS/FAIL with reason

### STEP 6: Run Gates & Build APKs
**For each app**:
1. `flutter pub get`
2. `flutter analyze` (must pass with 0 errors)
3. `flutter test` (if tests exist)
4. `flutter build apk --release`

**Rollback plan** if gates fail:
- Revert all code changes
- Output NO-GO with exact blockers

---

## KEY DESIGN DECISIONS

### 1. Rely on Backend `onUserCreate` Trigger
**Decision**: Do NOT create Firestore user docs from client apps  
**Rationale**: Backend `onUserCreate` trigger automatically creates `/users/{uid}` with correct schema  
**Impact**: Simpler client code, consistent data model

### 2. Custom Claims as Primary Role Source
**Decision**: Read role from custom claims first, Firestore as fallback  
**Rationale**: Custom claims are in ID token (no extra network call), faster validation  
**Impact**: Better performance, works offline after initial load

### 3. Minimal UI Changes
**Decision**: Keep existing UI flows, add role validation layer  
**Rationale**: Non-negotiable rule: avoid breaking existing functionality  
**Impact**: Users see familiar UI, role validation happens transparently

### 4. No New Dependencies
**Decision**: Use existing firebase_auth, cloud_firestore, cloud_functions  
**Rationale**: Apps already have these dependencies  
**Impact**: No dependency conflicts, faster implementation

---

## EXPECTED OUTCOMES

### Success Criteria
✅ Both apps successfully build APKs  
✅ Auth services updated to work with Day 1 backend  
✅ Custom claims reading implemented  
✅ Role-based routing functional  
✅ User docs read from `/users/{uid}` collection  
✅ No breaking changes to existing UI  
✅ All gates pass (pub get, analyze, build)

### Artifacts to Produce
1. DAY2_PLAN.md (this document)
2. DAY2_EXECUTION_LOG.md (command outputs)
3. DAY2_DIFF_SUMMARY.md (file-by-file changes)
4. gate_customer_day2.log
5. gate_merchant_day2.log
6. auth_e2e_customer.log
7. auth_e2e_merchant.log

---

## RISK MITIGATION

### Risk 1: Backend Trigger Not Creating User Docs
**Mitigation**: Add `ensureUserDocExists()` with retry logic (max 10s wait)  
**Fallback**: Log warning but allow app to continue

### Risk 2: Custom Claims Not Set Immediately
**Mitigation**: Force token refresh after sign-up, retry if claims missing  
**Fallback**: Read role from Firestore user doc

### Risk 3: Existing Screens Break with New Auth Flow
**Mitigation**: Minimal changes to existing code, add new validation layer  
**Fallback**: Rollback all changes if gates fail

### Risk 4: google-services.json Missing
**Mitigation**: Apps may work with firebase_options.dart alone for basic auth  
**Fallback**: Document missing file, but proceed if possible

---

## TIMELINE ESTIMATE

**Total Duration**: ~2-3 hours

- Discovery & Planning: ✅ COMPLETE (30 min)
- Auth Service Updates: 45 min
- Role Validation Implementation: 30 min
- Main Entry Point Updates: 30 min
- Login/Signup Screen Updates: 20 min
- E2E Sanity Scripts: 15 min
- Gate Execution & APK Builds: 30 min
- Documentation & Artifacts: 20 min

---

**Status**: READY TO EXECUTE  
**Next Step**: Update Customer App auth service  
**Blocking Issues**: None
