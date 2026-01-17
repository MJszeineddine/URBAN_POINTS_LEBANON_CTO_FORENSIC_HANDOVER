# CTO NEXT FIXES

**Generated:** 2026-01-16  
**Total Failures:** 26  
**Gate Status:** FAIL

---

## Failure Breakdown by Component

- **MERCH-\*:** 7 failures (Merchant App)
- **ADMIN-\*:** 12 failures (Admin Web Portal)
- **BACKEND-\*:** 3 failures (Backend Functions)
- **INFRA-\*:** 2 failures (Infrastructure)
- **TEST-\*:** 3 failures (Test Coverage)

---

## Top 10 Failures to Fix Next (Sorted by Leverage)

### 1. INFRA-RULES-001: BLOCKED but missing blocker doc
**Why Failing:** Status is BLOCKED but no blocker document exists  
**Component:** Infrastructure  
**Leverage:** Unblocks Firestore rules deployment  
**Files to Edit:**
- Create `docs/BLOCKER_FIRESTORE_RULES.md` with blocker rationale

**Validation Command:**
```bash
python3 tools/gates/cto_verify.py
```

**Expected Evidence:**
- `docs/BLOCKER_FIRESTORE_RULES.md` exists
- Gate check passes for INFRA-RULES-001

---

### 2. INFRA-INDEX-001: BLOCKED but missing blocker doc
**Why Failing:** Status is BLOCKED but no blocker document exists  
**Component:** Infrastructure  
**Leverage:** Unblocks Firestore index deployment  
**Files to Edit:**
- Create `docs/BLOCKER_FIRESTORE_INDEXES.md` with blocker rationale

**Validation Command:**
```bash
python3 tools/gates/cto_verify.py
```

**Expected Evidence:**
- `docs/BLOCKER_FIRESTORE_INDEXES.md` exists
- Gate check passes for INFRA-INDEX-001

---

### 3. ADMIN-USER-001: Status is PARTIAL
**Why Failing:** Requirement status is PARTIAL (must be READY or BLOCKED)  
**Component:** Admin Web Portal - User Management  
**Leverage:** Unblocks admin user management features  
**Files to Edit:**
- `spec/requirements.yaml` - Change status from PARTIAL to READY
- Add/verify anchors in admin user management screens
- Ensure implementation is complete

**Validation Command:**
```bash
python3 tools/gates/cto_verify.py
grep -A 5 "ADMIN-USER-001" spec/requirements.yaml
```

**Expected Evidence:**
- `spec/requirements.yaml` shows status: READY
- Anchors verified in web-admin user screens
- Gate check passes

---

### 4. ADMIN-ANALYTICS-001 & ADMIN-ANALYTICS-002: Status is PARTIAL
**Why Failing:** Analytics requirements are PARTIAL (both)  
**Component:** Admin Web Portal - Analytics Dashboard  
**Leverage:** Unblocks analytics and reporting features (2 requirements)  
**Files to Edit:**
- `spec/requirements.yaml` - Update ADMIN-ANALYTICS-001 and ADMIN-ANALYTICS-002 to READY
- Complete analytics dashboard screens
- Add code anchors

**Validation Command:**
```bash
python3 tools/gates/cto_verify.py
grep -A 5 "ADMIN-ANALYTICS" spec/requirements.yaml
```

**Expected Evidence:**
- Both requirements show status: READY
- Analytics screens have proper anchors
- Gate check passes

---

### 5. MERCH-PROFILE-001: Status is PARTIAL
**Why Failing:** Merchant profile requirement is PARTIAL  
**Component:** Merchant App - Profile Management  
**Leverage:** Unblocks merchant profile features  
**Files to Edit:**
- `spec/requirements.yaml` - Update MERCH-PROFILE-001 to READY
- Complete merchant profile screens
- Add code anchors in merchant app

**Validation Command:**
```bash
python3 tools/gates/cto_verify.py
grep -A 5 "MERCH-PROFILE-001" spec/requirements.yaml
```

**Expected Evidence:**
- status: READY in requirements.yaml
- Merchant profile anchors verified
- Gate check passes

---

### 6. MERCH-OFFER-004: Status is PARTIAL
**Why Failing:** Merchant offer management requirement is PARTIAL  
**Component:** Merchant App - Offer Management  
**Leverage:** Unblocks merchant offer creation/editing  
**Files to Edit:**
- `spec/requirements.yaml` - Update MERCH-OFFER-004 to READY
- Complete offer management screens
- Add code anchors

**Validation Command:**
```bash
python3 tools/gates/cto_verify.py
grep -A 5 "MERCH-OFFER-004" spec/requirements.yaml
```

**Expected Evidence:**
- status: READY
- Offer management anchors verified
- Gate check passes

---

### 7. MERCH-REDEEM-004: Status is PARTIAL
**Why Failing:** Merchant redemption requirement is PARTIAL  
**Component:** Merchant App - Redemption Verification  
**Leverage:** Unblocks QR code redemption flow  
**Files to Edit:**
- `spec/requirements.yaml` - Update MERCH-REDEEM-004 to READY
- Complete redemption verification screens
- Add code anchors

**Validation Command:**
```bash
python3 tools/gates/cto_verify.py
grep -A 5 "MERCH-REDEEM-004" spec/requirements.yaml
```

**Expected Evidence:**
- status: READY
- Redemption flow anchors verified
- Gate check passes

---

### 8. MERCH-SUBSCRIPTION-001: Status is PARTIAL
**Why Failing:** Merchant subscription requirement is PARTIAL  
**Component:** Merchant App - Subscription Management  
**Leverage:** Unblocks Stripe integration for merchant billing  
**Files to Edit:**
- `spec/requirements.yaml` - Update MERCH-SUBSCRIPTION-001 to READY
- Complete subscription/billing screens
- Add Stripe integration anchors

**Validation Command:**
```bash
python3 tools/gates/cto_verify.py
grep -A 5 "MERCH-SUBSCRIPTION-001" spec/requirements.yaml
```

**Expected Evidence:**
- status: READY
- Stripe subscription anchors verified
- Gate check passes

---

### 9. TEST-MERCHANT-001: Status is MISSING
**Why Failing:** Merchant app test requirement is MISSING  
**Component:** Test Coverage - Merchant App  
**Leverage:** Unblocks merchant app quality gate  
**Files to Edit:**
- `spec/requirements.yaml` - Add TEST-MERCHANT-001 with status: READY or BLOCKED
- Create merchant app test suite if needed
- Add test file anchors

**Validation Command:**
```bash
python3 tools/gates/cto_verify.py
grep -A 5 "TEST-MERCHANT-001" spec/requirements.yaml
flutter test source/apps/mobile-merchant/
```

**Expected Evidence:**
- Requirement exists in spec/requirements.yaml
- Test logs show passing tests
- Gate check passes

---

### 10. TEST-WEB-001: Status is MISSING
**Why Failing:** Web admin test requirement is MISSING  
**Component:** Test Coverage - Web Admin  
**Leverage:** Unblocks web admin quality gate  
**Files to Edit:**
- `spec/requirements.yaml` - Add TEST-WEB-001 with status: READY or BLOCKED
- Create web admin test suite if needed
- Add test file anchors

**Validation Command:**
```bash
python3 tools/gates/cto_verify.py
grep -A 5 "TEST-WEB-001" spec/requirements.yaml
cd source/apps/web-admin && npm test
```

**Expected Evidence:**
- Requirement exists in spec/requirements.yaml
- Test logs show passing tests
- Gate check passes

---

## Remaining Failures (Not in Top 10)

### MISSING Status (Need to Add Requirements)
- MERCH-OFFER-006
- MERCH-REDEEM-005
- MERCH-STAFF-001
- ADMIN-POINTS-001, 002, 003
- ADMIN-FRAUD-001
- ADMIN-PAYMENT-004
- ADMIN-CAMPAIGN-001, 002, 003
- BACKEND-SECURITY-001
- BACKEND-DATA-001
- BACKEND-ORPHAN-001
- TEST-BACKEND-001

**Action:** Add these requirements to `spec/requirements.yaml` with appropriate status (READY, PARTIAL, or BLOCKED with blocker docs)

---

## Strategic Fix Order

**Phase 1: Quick Wins (Blocker Docs)**
1. INFRA-RULES-001 - Create blocker doc
2. INFRA-INDEX-001 - Create blocker doc

**Phase 2: Convert PARTIAL to READY (Complete Implementation)**
3. ADMIN-USER-001
4. ADMIN-ANALYTICS-001, 002
5. MERCH-PROFILE-001
6. MERCH-OFFER-004
7. MERCH-REDEEM-004
8. MERCH-SUBSCRIPTION-001

**Phase 3: Add Missing Requirements (Spec Updates)**
9. TEST-MERCHANT-001
10. TEST-WEB-001
11. All other MISSING requirements

---

## Gate Re-Run Command

After fixes:
```bash
python3 tools/gates/cto_verify.py
python3 tools/print_gate_failures.py
```

Expected outcome: 26 failures → 0 failures, status: PASS
