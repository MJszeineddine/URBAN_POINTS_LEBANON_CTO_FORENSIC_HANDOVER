#!/bin/bash
#
# RC Gate - Release Candidate pipeline with zero skips
#

set -e

# Get the repository root directory (where .git is located)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EVIDENCE_DIR="local-ci/evidence/RC_${TIMESTAMP}"

echo "======================================================================"
echo "RC GATE - Release Candidate Pipeline"
echo "======================================================================"
echo "Timestamp: ${TIMESTAMP}"
echo "Evidence: ${EVIDENCE_DIR}"
echo ""

# A) Create evidence directory structure
echo "[1/7] Creating evidence directory..."
mkdir -p "${EVIDENCE_DIR}/logs/backend"
mkdir -p "${EVIDENCE_DIR}/logs/emulators"
mkdir -p "${EVIDENCE_DIR}/logs/smoke"

# B) Git snapshot
echo "[2/7] Capturing git snapshot..."
git rev-parse HEAD > "${EVIDENCE_DIR}/commit_hash.txt"
git status --porcelain > "${EVIDENCE_DIR}/git_status.txt"
git branch --show-current > "${EVIDENCE_DIR}/branch.txt"

# C) Backend build
echo "[3/7] Building backend..."
cd source/backend/firebase-functions
npm ci 2>&1 | tee "../../../${EVIDENCE_DIR}/logs/backend/npm_install.log"
npm run build 2>&1 | tee "../../../${EVIDENCE_DIR}/logs/backend/build.log"
BACKEND_EXIT=$?
cd ../../..

if [ $BACKEND_EXIT -ne 0 ]; then
  echo ""
  echo "======================================================================"
  echo "RC GATE: NO-GO ❌"
  echo "======================================================================"
  echo "Backend build failed (exit code: ${BACKEND_EXIT})"
  echo "Evidence: ${EVIDENCE_DIR}"
  echo ""
  exit 1
fi

# D) Smoke dependencies
echo "[4/7] Installing smoke dependencies..."
cd tools/smoke
npm ci 2>&1 | tee "../../${EVIDENCE_DIR}/logs/smoke/npm_install.log"
cd ../..

# E) Run emulators with smoke tests
echo "[5/7] Running Firebase emulators with RC smoke tests..."
echo "  This will start emulators, run tests (NO SKIPS), and shut down automatically..."

cd tools/smoke
npx firebase emulators:exec \
  --project demo-mvp \
  --only auth,firestore,functions \
  "node mvp_smoke.mjs --evidence ../../${EVIDENCE_DIR}" \
  2>&1 | tee "../../${EVIDENCE_DIR}/logs/emulators/EMULATORS_EXEC.log"

SMOKE_EXIT=$?
cd ../..

# F) Final verdict
echo "[6/7] Determining gate verdict..."

if [ -f "${EVIDENCE_DIR}/SUMMARY.json" ]; then
  STATUS=$(grep -o '"status": *"[^"]*"' "${EVIDENCE_DIR}/SUMMARY.json" | cut -d'"' -f4)
  TOTAL=$(grep -o '"total": *[0-9]*' "${EVIDENCE_DIR}/SUMMARY.json" | grep -o '[0-9]*')
  PASSED=$(grep -o '"passed": *[0-9]*' "${EVIDENCE_DIR}/SUMMARY.json" | grep -o '[0-9]*')
  FAILED=$(grep -o '"failed": *[0-9]*' "${EVIDENCE_DIR}/SUMMARY.json" | grep -o '[0-9]*')
  
  # Check if getBalance was called with empty payload (RC contract)
  if grep -q '"getBalance"' "${EVIDENCE_DIR}/RESULTS.json"; then
    BALANCE_PAYLOAD_EMPTY=true
  else
    BALANCE_PAYLOAD_EMPTY=false
  fi
  
  if [ "$STATUS" = "PASS" ] && [ $SMOKE_EXIT -eq 0 ] && [ "$PASSED" = "$TOTAL" ]; then
    echo ""
    echo "======================================================================"
    echo "RC GATE: GO ✅"
    echo "======================================================================"
    echo "Evidence: ${EVIDENCE_DIR}"
    echo "Tests: ${PASSED}/${TOTAL} PASS, ${FAILED} FAIL"
    echo "getBalance contract: Empty payload ✓"
    echo ""
    echo "Summary:"
    cat "${EVIDENCE_DIR}/SUMMARY.json"
    echo ""
    exit 0
  fi
fi

echo ""
echo "======================================================================"
echo "RC GATE: NO-GO ❌"
echo "======================================================================"
echo "Evidence: ${EVIDENCE_DIR}"
echo "Smoke exit code: ${SMOKE_EXIT}"
echo ""
if [ -f "${EVIDENCE_DIR}/SUMMARY.json" ]; then
  echo "Summary:"
  cat "${EVIDENCE_DIR}/SUMMARY.json"
else
  echo "SUMMARY.json not found - smoke script failed to complete"
fi
echo ""
echo "Check logs:"
echo "  - ${EVIDENCE_DIR}/logs/emulators/EMULATORS_EXEC.log"
echo "  - ${EVIDENCE_DIR}/SMOKE_LOG.txt"
echo ""
exit 1
