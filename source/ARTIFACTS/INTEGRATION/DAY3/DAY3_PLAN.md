# DAY 3 MISSION PLAN
## UI Integration for Firebase Auth + Role Validation

**Date**: 2026-01-03  
**Objective**: Wire existing UI flows to Day 2 auth layer without redesigning screens  
**Scope**: Customer App + Merchant App

---

## MISSION CONSTRAINTS

### ✅ ALLOWED
- Wire existing UI to auth_service.dart methods
- Add role validation to auth state listeners
- Insert RoleBlockedScreen when role mismatch
- Add minimal loading indicators
- Add error handling (snackbars only)
- Update navigation logic

### ❌ FORBIDDEN
- Redesign any screens
- Change auth_service.dart or backend
- Add Provider or new state management
- Create new UI screens (except using existing role_blocked_screen.dart)
- Change color schemes, layouts, or styling
- Add animations or transitions

---

## PHASE 1: DISCOVERY

### Objectives
1. Locate auth state listeners (StreamBuilder/authStateChanges)
2. Find initial route / splash screen logic
3. Identify login/signup screen implementations
4. Map current navigation flow

### Deliverable
- `ARTIFACTS/INTEGRATION/DAY3/discovery.log`

---

## PHASE 2: AUTH STATE WIRING

### Customer App Changes

**File**: `/apps/mobile-customer/lib/main.dart`

**Current Flow** (assumed):
```dart
authStateChanges → user ? HomeScreen : LoginScreen
```

**Target Flow**:
```dart
authStateChanges → 
  if (user == null) → LoginScreen
  else:
    1. Show loading
    2. await forceRefreshIdToken()
    3. validate role (customer/user)
    4. if valid → HomeScreen
    5. if invalid → RoleBlockedScreen
    6. if error → LoginScreen (with error)
```

**Implementation**:
- Add `_validateAndRoute()` helper method
- Use RoleValidator.validateCustomerRole()
- Handle timeout (5-7s max)
- Show loading spinner during validation

### Merchant App Changes

**File**: `/apps/mobile-merchant/lib/main.dart`

**Target Flow**: Same as customer, but validate for 'merchant' role

---

## PHASE 3: LOGIN/SIGNUP BUTTON WIRING

### Customer App

**Files**:
- `/apps/mobile-customer/lib/screens/auth/login_screen.dart`
- `/apps/mobile-customer/lib/screens/auth/signup_screen.dart`

**Changes**:
1. Verify buttons call `authService.signInWithEmailPassword()`
2. Verify signup calls `authService.signUpWithEmailPassword()`
3. Add loading state (already exists, verify)
4. Add error handling with SnackBar (already exists, verify)
5. NO navigation changes (handled by auth state listener)

### Merchant App

**Files**:
- `/apps/mobile-merchant/lib/screens/auth/login_screen.dart`
- `/apps/mobile-merchant/lib/screens/auth/signup_screen.dart`

**Changes**: Same as customer app

---

## PHASE 4: SAFE UX POLISH

### Loading Indicators

**Add to main.dart auth state handler**:
```dart
if (user != null && _isValidating) {
  return Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Validating account...'),
        ],
      ),
    ),
  );
}
```

### Timeout Handling

```dart
Future<void> _validateAndRoute() async {
  try {
    await Future.timeout(
      Duration(seconds: 7),
      onTimeout: () => throw TimeoutException('Validation timeout'),
    );
    // validation logic
  } catch (e) {
    // show error, sign out
  }
}
```

### Error Messages

- Use existing SnackBar patterns
- No new error screens
- Minimal text changes

---

## PHASE 5: QUALITY GATES

### Both Apps

**Gate 1**: `flutter pub get`
- Should complete without errors
- Log to `gate_customer_day3.log` / `gate_merchant_day3.log`

**Gate 2**: `flutter analyze`
- Should pass or show only existing warnings
- NEW errors = FAIL

**Gate 3**: `flutter test`
- All existing tests must pass
- NEW failures = FAIL

**Gate 4**: `flutter build apk --release`
- Must build successfully
- Build errors = FAIL

### Success Criteria
- All 4 gates pass for both apps
- No new errors introduced
- Existing functionality preserved

---

## ROLLBACK PLAN

### If Any Gate Fails

**Step 1**: Identify failing gate and error
```bash
# Check which gate failed
cat ARTIFACTS/INTEGRATION/DAY3/gate_customer_day3.log | grep -i "error\|fail"
```

**Step 2**: Revert changed files
```bash
# Revert main.dart
git checkout HEAD -- apps/mobile-customer/lib/main.dart
git checkout HEAD -- apps/mobile-merchant/lib/main.dart

# Revert any other changed files
# (listed in DAY3_EXECUTION_LOG.md)
```

**Step 3**: Re-run gates to confirm rollback
```bash
cd apps/mobile-customer && flutter test
cd apps/mobile-merchant && flutter test
```

**Step 4**: Output NO-GO report
- Document exact blocker
- List files that were reverted
- Specify prerequisite to unblock

---

## EXPECTED FILE CHANGES

### Minimal Change Set

**Customer App** (2-3 files):
1. `/apps/mobile-customer/lib/main.dart` - Auth state wiring
2. `/apps/mobile-customer/lib/screens/auth/login_screen.dart` - Verify only
3. `/apps/mobile-customer/lib/screens/auth/signup_screen.dart` - Verify only

**Merchant App** (2-3 files):
1. `/apps/mobile-merchant/lib/main.dart` - Auth state wiring
2. `/apps/mobile-merchant/lib/screens/auth/login_screen.dart` - Verify only
3. `/apps/mobile-merchant/lib/screens/auth/signup_screen.dart` - Verify only

**Total**: 4-6 files (likely only 2 main.dart files need actual changes)

---

## RISK ASSESSMENT

### Low Risk ✅
- main.dart auth state changes (isolated, reversible)
- Adding RoleBlockedScreen route (new feature, doesn't break existing)
- Adding loading indicators (progressive enhancement)

### Medium Risk ⚠️
- Navigation logic changes (could affect routing)
- Timeout handling (needs careful testing)
- Error handling (must not break existing flows)

### High Risk ❌
- None (we're not changing auth_service or backend)

---

## SUCCESS METRICS

| Metric | Target | Measurement |
|--------|--------|-------------|
| Files Changed | ≤6 | Count modified files |
| Lines Added | ≤200 | git diff --stat |
| New Errors | 0 | flutter analyze |
| Test Failures | 0 | flutter test |
| Build Success | 100% | flutter build apk |
| Rollback Time | <5min | Time to revert |

---

## TIMELINE

| Phase | Duration | Status |
|-------|----------|--------|
| Discovery | 10 min | Pending |
| Auth State Wiring | 20 min | Pending |
| Login/Signup Verify | 10 min | Pending |
| UX Polish | 15 min | Pending |
| Gates Execution | 30 min | Pending |
| Documentation | 15 min | Pending |
| **TOTAL** | **100 min** | **Pending** |

---

## DELIVERABLES CHECKLIST

- [ ] `ARTIFACTS/INTEGRATION/DAY3/DAY3_PLAN.md` (this file)
- [ ] `ARTIFACTS/INTEGRATION/DAY3/discovery.log`
- [ ] `ARTIFACTS/INTEGRATION/DAY3/DAY3_EXECUTION_LOG.md`
- [ ] `ARTIFACTS/INTEGRATION/DAY3/DAY3_DIFF_SUMMARY.md`
- [ ] `ARTIFACTS/INTEGRATION/DAY3/gate_customer_day3.log`
- [ ] `ARTIFACTS/INTEGRATION/DAY3/gate_merchant_day3.log`

---

**Prepared**: 2026-01-03T18:00:00+00:00  
**Ready to Execute**: ✅ YES  
**Estimated Completion**: 18:40:00+00:00
