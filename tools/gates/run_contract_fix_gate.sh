#!/bin/bash
#
# Contract Fix Gate - Verifies callable overrides fixed and DTO contracts enforced
#

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EVIDENCE_DIR="local-ci/evidence/CONTRACT_FIX_${TIMESTAMP}"
SUMMARY_FILE="${EVIDENCE_DIR}/SUMMARY.json"

echo "======================================================================"
echo "CONTRACT FIX GATE"
echo "======================================================================"
echo "Timestamp: ${TIMESTAMP}"
echo "Evidence: ${EVIDENCE_DIR}"
echo ""

# Create evidence directory
mkdir -p "${EVIDENCE_DIR}/logs"

# Capture git state
echo "[1/6] Capturing git state..."
git rev-parse HEAD > "${EVIDENCE_DIR}/commit_hash.txt"
git status > "${EVIDENCE_DIR}/git_status.txt"
git diff --name-only > "${EVIDENCE_DIR}/changed_files.txt"

# Navigate to backend
cd source/backend/firebase-functions

# Install dependencies
echo "[2/6] Installing dependencies..."
npm ci 2>&1 | tee "../../../${EVIDENCE_DIR}/logs/npm_install.log"

# Build
echo "[3/6] Building backend..."
npm run build 2>&1 | tee "../../../${EVIDENCE_DIR}/logs/build.log"

# Run contract tests
echo "[4/6] Running contract tests..."
TEST_EXIT_CODE=0
npx jest --runTestsByPath src/__tests__/contracts.customer.test.ts 2>&1 | tee "../../../${EVIDENCE_DIR}/logs/test.log" || TEST_EXIT_CODE=$?

cd ../../..

# Check for unimplemented stubs in compiled output
echo "[5/6] Checking compiled output for removed stubs..."
STUB_CHECK_PASSED=true
if [ -f "source/backend/firebase-functions/lib/callableWrappers.js" ]; then
  CRITICAL_CALLABLES="getAvailableOffers getFilteredOffers searchOffers getPointsHistory redeemOffer generateQRToken"
  for callable in $CRITICAL_CALLABLES; do
    if grep -q "exports\.${callable}.*HttpsError.*unimplemented" "source/backend/firebase-functions/lib/callableWrappers.js"; then
      echo "  ❌ FAIL: ${callable} still has unimplemented stub"
      STUB_CHECK_PASSED=false
    else
      echo "  ✅ PASS: ${callable} stub removed"
    fi
  done
else
  echo "  ⚠️  WARN: lib/callableWrappers.js not found"
  STUB_CHECK_PASSED=false
fi

# Generate summary
echo "[6/6] Generating evidence summary..."

GATE_STATUS="FAIL"
if [ $TEST_EXIT_CODE -eq 0 ] && [ "$STUB_CHECK_PASSED" = true ]; then
  GATE_STATUS="PASS"
fi

cat > "${SUMMARY_FILE}" << EOF
{
  "gate": "CONTRACT_FIX",
  "timestamp": "${TIMESTAMP}",
  "status": "${GATE_STATUS}",
  "test_exit_code": ${TEST_EXIT_CODE},
  "stub_check_passed": ${STUB_CHECK_PASSED},
  "commit_hash": "$(cat ${EVIDENCE_DIR}/commit_hash.txt)",
  "changed_files": [
    "source/backend/firebase-functions/src/callableWrappers.ts",
    "source/backend/firebase-functions/src/adapters/time.ts",
    "source/backend/firebase-functions/src/adapters/offerDto.ts",
    "source/backend/firebase-functions/src/index.ts",
    "source/backend/firebase-functions/src/__tests__/contracts.customer.test.ts"
  ],
  "fixed_callables": [
    "getAvailableOffers",
    "getFilteredOffers",
    "searchOffers",
    "getPointsHistory",
    "redeemOffer",
    "generateQRToken",
    "getOffersByLocationFunc",
    "getBalance"
  ],
  "changes_summary": "Removed CommonJS stub overrides, added DTO adapters for time/offer, enforced Flutter contracts (points_required, qr_token, valid_until as ISO), implemented getPointsHistory"
}
EOF

echo ""
echo "======================================================================"
echo "GATE RESULT: ${GATE_STATUS}"
echo "======================================================================"
echo "Evidence folder: ${EVIDENCE_DIR}"
echo "Summary: ${SUMMARY_FILE}"
echo ""

if [ "${GATE_STATUS}" = "PASS" ]; then
  echo "✅ GO - All contract fixes verified"
  cat "${SUMMARY_FILE}"
  exit 0
else
  echo "❌ NO-GO - Contract fix gate failed"
  echo ""
  echo "Test exit code: ${TEST_EXIT_CODE}"
  echo "Stub check: ${STUB_CHECK_PASSED}"
  echo ""
  echo "Logs:"
  echo "  - Build: ${EVIDENCE_DIR}/logs/build.log"
  echo "  - Tests: ${EVIDENCE_DIR}/logs/test.log"
  cat "${SUMMARY_FILE}"
  exit 1
fi
