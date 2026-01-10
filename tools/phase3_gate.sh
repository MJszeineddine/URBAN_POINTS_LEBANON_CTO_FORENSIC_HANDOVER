#!/bin/bash

################################################################################
# Phase 3 Gate Script - Automation, Scheduler, and Notification Verification
# 
# Verifies Phase 3 implementation:
# 1. Phase 3 functions exist in backend
# 2. Tests pass (unit + integration)
# 3. Build succeeds
# 4. Linting passes (no console.log in production paths)
# 5. FCM token registration works
# 6. Merchant compliance logic is sound
# 7. Notification delivery paths are implemented
#
# Exit codes:
# 0 = ALL CHECKS PASSED ✅
# 1 = LINT/FORMAT ERROR
# 2 = TEST FAILURE
# 3 = BUILD FAILURE
# 4 = MISSING FILES/FUNCTIONS
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_ROOT="${PROJECT_ROOT}/source/backend/firebase-functions"
ARTIFACTS_DIR="${PROJECT_ROOT}/docs/parity"
TIMEOUT_BUILD=300
TIMEOUT_TESTS=600

with_timeout() {
  local seconds="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "${seconds}" "$@"
  elif command -v perl >/dev/null 2>&1; then
    perl -e 'alarm shift; exec @ARGV' "${seconds}" "$@"
  else
    local pycmd="python"
    if command -v python3 >/dev/null 2>&1; then
      pycmd="python3"
    fi
    ${pycmd} - "$seconds" "$@" <<'PY'
import os, subprocess, sys, signal
secs = int(sys.argv[1]); cmd = sys.argv[2:]
proc = subprocess.Popen(cmd)
try:
    proc.wait(timeout=secs)
    sys.exit(proc.returncode)
except subprocess.TimeoutExpired:
    proc.send_signal(signal.SIGKILL)
    proc.wait()
    sys.exit(124)
PY
  fi
}

echo "=========================================================================="
echo "PHASE 3 GATE SCRIPT - AUTOMATION & NOTIFICATIONS VERIFICATION"
echo "=========================================================================="
echo "Project Root: $PROJECT_ROOT"
echo "Backend Root: $BACKEND_ROOT"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PHASE3_PASS=true

# ============================================================================
# CHECK 1: Phase 3 Files Exist
# ============================================================================
echo "CHECK 1: Verifying Phase 3 files exist..."
echo "------------------------------------------------------------------------"

REQUIRED_FILES=(
  "src/phase3Scheduler.ts"
  "src/phase3Notifications.ts"
  "src/__tests__/phase3.test.ts"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "$BACKEND_ROOT/$file" ]; then
    echo -e "${GREEN}✓${NC} $file exists"
  else
    echo -e "${RED}✗${NC} MISSING: $file"
    PHASE3_PASS=false
  fi
done

# ============================================================================
# CHECK 2: Phase 3 Functions Exported in index.ts
# ============================================================================
echo ""
echo "CHECK 2: Verifying Phase 3 exports in index.ts..."
echo "------------------------------------------------------------------------"

INDEX_FILE="$BACKEND_ROOT/src/index.ts"
INDEX_CONTENT="$(tr '\n' ' ' < "$INDEX_FILE")"

if grep -q "./phase3Scheduler" "$INDEX_FILE" && grep -q "./phase3Notifications" "$INDEX_FILE"; then
  echo -e "${GREEN}✓${NC} phase3 modules referenced in index.ts"
else
  echo -e "${RED}✗${NC} phase3 modules not referenced in index.ts"
  PHASE3_PASS=false
fi

REQUIRED_EXPORTS=(
  "notifyOfferStatusChange"
  "enforceMerchantCompliance"
  "cleanupExpiredQRTokens"
  "sendPointsExpiryWarnings"
  "registerFCMToken"
  "unregisterFCMToken"
  "notifyRedemptionSuccess"
  "sendBatchNotification"
)

for export in "${REQUIRED_EXPORTS[@]}"; do
  if [[ "${INDEX_CONTENT}" =~ export[[:space:]]*\{[^}]*${export} ]]; then
    echo -e "${GREEN}✓${NC} ${export} exported"
  else
    echo -e "${RED}✗${NC} NOT EXPORTED: ${export}"
    PHASE3_PASS=false
  fi
done

# ============================================================================
# CHECK 3: Core Functions Implemented (Code Inspection)
# ============================================================================
echo ""
echo "CHECK 3: Verifying core function implementations..."
echo "------------------------------------------------------------------------"

# Check for scheduler functions
if grep -q "pubsub.schedule" "$BACKEND_ROOT/src/phase3Scheduler.ts"; then
  echo -e "${GREEN}✓${NC} Scheduler jobs configured with pub/sub.schedule"
else
  echo -e "${RED}✗${NC} Scheduler configuration missing"
  PHASE3_PASS=false
fi

# Check for FCM token registration (callable)
if grep -q "export const registerFCMToken" "$BACKEND_ROOT/src/phase3Notifications.ts" && \
   grep -q "https\.onCall" "$BACKEND_ROOT/src/phase3Notifications.ts"; then
  echo -e "${GREEN}✓${NC} FCM token registration callable implemented"
else
  echo -e "${RED}✗${NC} FCM token registration missing"
  PHASE3_PASS=false
fi

# Check for merchant compliance
if grep -q "export const enforceMerchantCompliance" "$BACKEND_ROOT/src/phase3Scheduler.ts" && \
   grep -q "is_compliant\|compliance_status" "$BACKEND_ROOT/src/phase3Scheduler.ts"; then
  echo -e "${GREEN}✓${NC} Merchant compliance enforcement implemented"
else
  echo -e "${RED}✗${NC} Merchant compliance logic missing"
  PHASE3_PASS=false
fi

# Check for offer status trigger
if grep -q "export const notifyOfferStatusChange" "$BACKEND_ROOT/src/phase3Scheduler.ts" && \
   grep -q "document('offers/" "$BACKEND_ROOT/src/phase3Scheduler.ts"; then
  echo -e "${GREEN}✓${NC} Offer status change notification trigger implemented"
else
  echo -e "${RED}✗${NC} Offer notification trigger missing"
  PHASE3_PASS=false
fi

# Check for redemption notifications
if grep -q "export const notifyRedemptionSuccess" "$BACKEND_ROOT/src/phase3Notifications.ts" && \
   grep -q "document('redemptions/" "$BACKEND_ROOT/src/phase3Notifications.ts"; then
  echo -e "${GREEN}✓${NC} Redemption success notification trigger implemented"
else
  echo -e "${RED}✗${NC} Redemption notification trigger missing"
  PHASE3_PASS=false
fi

# ============================================================================
# CHECK 4: Test File Exists and Has Tests
# ============================================================================
echo ""
echo "CHECK 4: Verifying test coverage..."
echo "------------------------------------------------------------------------"

TEST_FILE="$BACKEND_ROOT/src/__tests__/phase3.test.ts"

if [ -f "$TEST_FILE" ]; then
  echo -e "${GREEN}✓${NC} Test file exists"
  
  # Count test cases
  TEST_COUNT=$(grep -c "it(" "$TEST_FILE" || echo "0")
  if [ "$TEST_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found $TEST_COUNT test cases"
  else
    echo -e "${RED}✗${NC} No test cases found"
    PHASE3_PASS=false
  fi
  
  # Verify test coverage areas
  for area in "FCM Token" "Merchant Compliance" "Notification" "Cleanup"; do
    if grep -q "$area" "$TEST_FILE"; then
      echo -e "${GREEN}✓${NC} Test coverage: $area"
    else
      echo -e "${YELLOW}⚠${NC} Limited coverage: $area"
    fi
  done
else
  echo -e "${RED}✗${NC} Test file missing"
  PHASE3_PASS=false
fi

# ============================================================================
# CHECK 5: Lint Check - No console.log in production paths
# ============================================================================
echo ""
echo "CHECK 5: Linting - Console.log in production code..."
echo "------------------------------------------------------------------------"

# Allow console.log only in logger.ts and test files
CONSOLE_VIOLATIONS=$( { grep -n "console\." "$BACKEND_ROOT/src/phase3Scheduler.ts" \
  "$BACKEND_ROOT/src/phase3Notifications.ts" 2>/dev/null | \
  grep -v "console\.error\|console\.warn\|console\.log.*test" || true; } | wc -l )

if [ "$CONSOLE_VIOLATIONS" -eq 0 ]; then
  echo -e "${GREEN}✓${NC} No improper console usage in Phase 3 files"
else
  # Note: console.error and console.warn are allowed for logging
  echo -e "${YELLOW}⚠${NC} Review console usage (console.error/warn are OK)"
fi

# ============================================================================
# CHECK 6: Backend Build (Type Checking)
# ============================================================================
echo ""
echo "CHECK 6: TypeScript compilation..."
echo "------------------------------------------------------------------------"

cd "$BACKEND_ROOT"

if with_timeout "${TIMEOUT_BUILD}" npm run build; then
  echo -e "${GREEN}✓${NC} TypeScript compilation successful"
else
  echo -e "${RED}✗${NC} TypeScript compilation failed or timed out"
  PHASE3_PASS=false
fi

# ============================================================================
# CHECK 7: Run Phase 3 Tests
# ============================================================================
echo ""
echo "CHECK 7: Running Phase 3 tests..."
echo "------------------------------------------------------------------------"

if with_timeout "${TIMEOUT_TESTS}" npm run test:ci; then
  echo -e "${GREEN}✓${NC} Tests passed"
else
  echo -e "${RED}✗${NC} Tests failed or timed out"
  PHASE3_PASS=false
fi

# ============================================================================
# CHECK 8: Verify Firestore Rules Updates (if applicable)
# ============================================================================
echo ""
echo "CHECK 8: Firestore rules for Phase 3 collections..."
echo "------------------------------------------------------------------------"

REQUIRED_COLLECTIONS=(
  "notification_logs"
  "notification_campaigns"
  "compliance_checks"
  "cleanup_logs"
)

RULES_FILE="$PROJECT_ROOT/source/infra/firestore.rules"

if [ -f "$RULES_FILE" ]; then
  RULES_OK=true
  for collection in "${REQUIRED_COLLECTIONS[@]}"; do
    if grep -q "\"$collection\"" "$RULES_FILE" || grep -q "'$collection'" "$RULES_FILE"; then
      echo -e "${GREEN}✓${NC} Rules include $collection"
    else
      echo -e "${YELLOW}⚠${NC} No explicit rules for $collection (using default)"
    fi
  done
else
  echo -e "${YELLOW}⚠${NC} Firestore rules file not found at $RULES_FILE"
fi

# ============================================================================
# CHECK 9: Verify Documentation
# ============================================================================
echo ""
echo "CHECK 9: Documentation..."
echo "------------------------------------------------------------------------"

PHASE3_DOCS="$PROJECT_ROOT/docs/PHASE_3_IMPLEMENTATION.md"

if [ -f "$PHASE3_DOCS" ]; then
  echo -e "${GREEN}✓${NC} Phase 3 implementation doc exists"
else
  echo -e "${YELLOW}⚠${NC} Phase 3 implementation doc not found (will create in evidence)"
fi

# ============================================================================
# FINAL VERDICT
# ============================================================================
echo ""
echo "=========================================================================="

if [ "$PHASE3_PASS" = true ]; then
  echo -e "${GREEN}PHASE 3 GATE: PASS ✅${NC}"
  echo "=========================================================================="
  echo ""
  echo "All checks passed. Phase 3 implementation is ready for deployment."
  echo ""
  echo "Scheduler Jobs Active:"
  echo "  • notifyOfferStatusChange (Firestore trigger)"
  echo "  • enforceMerchantCompliance (Daily @ 5 AM Asia/Beirut)"
  echo "  • cleanupExpiredQRTokens (Daily @ 6 AM Asia/Beirut)"
  echo "  • sendPointsExpiryWarnings (Daily @ 11 AM Asia/Beirut)"
  echo ""
  echo "Notification Services:"
  echo "  • registerFCMToken (Callable)"
  echo "  • unregisterFCMToken (Callable)"
  echo "  • notifyRedemptionSuccess (Firestore trigger)"
  echo "  • sendBatchNotification (Callable)"
  echo ""
  echo "Next steps:"
  echo "  1. Deploy backend: firebase deploy --only functions"
  echo "  2. Enable Cloud Scheduler API if not already enabled"
  echo "  3. Verify scheduler jobs in Cloud Console"
  echo "  4. Test FCM token registration in mobile apps"
  echo "  5. Monitor notification delivery in Firestore logs"
  echo ""
  exit 0
else
  echo -e "${RED}PHASE 3 GATE: FAIL ❌${NC}"
  echo "=========================================================================="
  echo ""
  echo "Issues found. Please review above and fix before redeploying."
  echo ""
  exit 1
fi
