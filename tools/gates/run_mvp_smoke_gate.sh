#!/bin/bash
#
# MVP Smoke Gate - End-to-end callable tests on Firebase emulators
#

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EVIDENCE_DIR="local-ci/evidence/MVP_SMOKE_${TIMESTAMP}"

echo "======================================================================"
echo "MVP SMOKE GATE - Firebase Emulator E2E Tests"
echo "======================================================================"
echo "Timestamp: ${TIMESTAMP}"
echo "Evidence: ${EVIDENCE_DIR}"
echo ""

# Create evidence directory
mkdir -p "${EVIDENCE_DIR}/logs"

# Step 1: Capture git state
echo "[1/5] Capturing git state..."
git rev-parse HEAD > "${EVIDENCE_DIR}/commit_hash.txt"
git status --porcelain > "${EVIDENCE_DIR}/git_status.txt"

# Step 2: Build functions
echo "[2/5] Building functions..."
cd source/backend/firebase-functions
npm ci 2>&1 | tee "../../../${EVIDENCE_DIR}/logs/npm_install_functions.log"
npm run build 2>&1 | tee "../../../${EVIDENCE_DIR}/logs/build.log"
cd ../../..

# Step 3: Install smoke dependencies
echo "[3/5] Installing smoke dependencies..."
cd tools/smoke
npm install 2>&1 | tee "../../${EVIDENCE_DIR}/logs/npm_install_smoke.log"
cd ../..

# Step 4: Run emulators with smoke script
echo "[4/5] Running emulators with MVP smoke tests..."
echo "  This will start emulators, run tests, and shut down automatically..."

cd tools/smoke
npx firebase emulators:exec \
  --project demo-mvp \
  --only auth,firestore,functions \
  "node mvp_smoke.mjs --evidence ../../${EVIDENCE_DIR}" \
  2>&1 | tee "../../${EVIDENCE_DIR}/logs/EMULATORS_EXEC.log"

SMOKE_EXIT=$?
cd ../..

# Step 5: Determine verdict
echo "[5/5] Determining gate verdict..."

if [ -f "${EVIDENCE_DIR}/SUMMARY.json" ]; then
  STATUS=$(grep -o '"status": *"[^"]*"' "${EVIDENCE_DIR}/SUMMARY.json" | cut -d'"' -f4)
  
  if [ "$STATUS" = "PASS" ] && [ $SMOKE_EXIT -eq 0 ]; then
    echo ""
    echo "======================================================================"
    echo "MVP SMOKE GATE: GO ✅"
    echo "======================================================================"
    echo "Evidence: ${EVIDENCE_DIR}"
    echo ""
    echo "Summary:"
    cat "${EVIDENCE_DIR}/SUMMARY.json"
    echo ""
    exit 0
  fi
fi

echo ""
echo "======================================================================"
echo "MVP SMOKE GATE: NO-GO ❌"
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
echo "  - ${EVIDENCE_DIR}/logs/EMULATORS_EXEC.log"
echo "  - ${EVIDENCE_DIR}/SMOKE_LOG.txt"
echo ""
exit 1
