#!/bin/bash
#
# RC_STRICT Gate - Zero-tolerance Release Candidate validation
# Machine-verifiable GO/NO-GO with strict acceptance criteria
#

set -e

# Get the repository root directory (where .git is located)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EVIDENCE_DIR="local-ci/evidence/RC_STRICT_${TIMESTAMP}"

echo "======================================================================"
echo "RC_STRICT GATE"
echo "======================================================================"
echo "Timestamp: ${TIMESTAMP}"
echo "Evidence: ${EVIDENCE_DIR}"
echo ""

# [1/8] Create evidence directory structure
echo "[1/8] Creating evidence directory..."
mkdir -p "${EVIDENCE_DIR}/logs/backend"
mkdir -p "${EVIDENCE_DIR}/logs/emulators"
mkdir -p "${EVIDENCE_DIR}/logs/smoke"

# [2/8] Git snapshot
echo "[2/8] Capturing git snapshot..."
git rev-parse HEAD > "${EVIDENCE_DIR}/commit_hash.txt"
git status --porcelain > "${EVIDENCE_DIR}/git_status.txt"
git branch --show-current > "${EVIDENCE_DIR}/branch.txt"

# [3/8] Backend build
echo "[3/8] Building backend..."
cd source/backend/firebase-functions
npm ci 2>&1 | tee "../../../${EVIDENCE_DIR}/logs/backend/npm_install.log"
npm run build 2>&1 | tee "../../../${EVIDENCE_DIR}/logs/backend/build.log"
BACKEND_EXIT=$?
cd ../../..

if [ $BACKEND_EXIT -ne 0 ]; then
  echo ""
  echo "======================================================================"
  echo "RC_STRICT GATE: NO-GO ❌"
  echo "======================================================================"
  echo "Backend build failed (exit code: ${BACKEND_EXIT})"
  echo "Evidence: ${EVIDENCE_DIR}"
  echo ""
  exit 1
fi

echo "  ✓ Backend build successful"

# [4/8] Install smoke dependencies
echo "[4/8] Installing smoke dependencies..."
cd tools/smoke
npm ci 2>&1 | tee "../../${EVIDENCE_DIR}/logs/smoke/npm_install.log"
cd ../..

# [5/8] Run Firebase emulators with smoke tests
echo "[5/8] Running Firebase emulators with RC_STRICT smoke tests..."
cd tools/smoke

# Run emulators with smoke script
npx firebase emulators:exec \
  --only auth,firestore,functions \
  --project demo-mvp \
  "node mvp_smoke.mjs --evidence ../../${EVIDENCE_DIR}" \
  2>&1 | tee "../../${EVIDENCE_DIR}/logs/emulators/EMULATORS_EXEC.log"

EMULATOR_EXIT=$?
cd ../..

if [ $EMULATOR_EXIT -ne 0 ]; then
  echo ""
  echo "======================================================================"
  echo "RC_STRICT GATE: NO-GO ❌"
  echo "======================================================================"
  echo "Emulator tests failed (exit code: ${EMULATOR_EXIT})"
  echo "Evidence: ${EVIDENCE_DIR}"
  echo ""
  exit 1
fi

# [6/8] Run RC_STRICT validator
echo "[6/8] Running RC_STRICT validator..."

if [ ! -f "tools/validate/rc_strict_validator.py" ]; then
  echo "ERROR: rc_strict_validator.py not found"
  exit 1
fi

python3 tools/validate/rc_strict_validator.py --evidence "${EVIDENCE_DIR}"
VALIDATOR_EXIT=$?

if [ $VALIDATOR_EXIT -ne 0 ]; then
  echo ""
  echo "======================================================================"
  echo "RC_STRICT GATE: NO-GO ❌"
  echo "======================================================================"
  echo "Validation failed - see VALIDATION.json for details"
  echo "Evidence: ${EVIDENCE_DIR}"
  echo ""
  
  if [ -f "${EVIDENCE_DIR}/VALIDATION.json" ]; then
    echo "VALIDATION.json:"
    cat "${EVIDENCE_DIR}/VALIDATION.json"
    echo ""
  fi
  
  exit $VALIDATOR_EXIT
fi

# [7/8] Print success verdict
echo ""
echo "======================================================================"
echo "RC_STRICT GATE: GO ✅"
echo "======================================================================"
echo "Evidence: ${EVIDENCE_DIR}"
echo ""

# [8/8] Print evidence summary
echo "[8/8] Evidence artifacts:"
echo ""

if [ -f "${EVIDENCE_DIR}/SUMMARY.json" ]; then
  echo "SUMMARY.json:"
  cat "${EVIDENCE_DIR}/SUMMARY.json"
  echo ""
fi

if [ -f "${EVIDENCE_DIR}/VALIDATION.json" ]; then
  echo "VALIDATION.json:"
  cat "${EVIDENCE_DIR}/VALIDATION.json"
  echo ""
fi

echo "======================================================================"
exit 0
