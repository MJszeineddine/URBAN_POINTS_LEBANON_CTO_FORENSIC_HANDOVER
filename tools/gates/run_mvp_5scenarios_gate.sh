#!/bin/bash
#
# MVP 5 Scenarios Gate - Run 5 end-to-end scenarios and validate
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_ID="MVP_5SCENARIOS_${TIMESTAMP}"
EVIDENCE_DIR="local-ci/evidence/${RUN_ID}"

echo "======================================================================"
echo "MVP 5 SCENARIOS GATE"
echo "======================================================================"
echo "Run ID: ${RUN_ID}"
echo "Evidence: ${EVIDENCE_DIR}"
echo ""

mkdir -p "${EVIDENCE_DIR}/logs"

# Capture git snapshot
git rev-parse HEAD > "${EVIDENCE_DIR}/git_commit.txt" 2>&1 || echo "not-a-git-repo" > "${EVIDENCE_DIR}/git_commit.txt"
git status --porcelain > "${EVIDENCE_DIR}/git_status.txt" 2>&1 || echo "not-a-git-repo" > "${EVIDENCE_DIR}/git_status.txt"

# Step 1: Install backend dependencies
echo "[1/4] Installing backend dependencies..."
cd source/backend
npm install --silent > "${REPO_ROOT}/${EVIDENCE_DIR}/logs/backend_npm_install.log" 2>&1 || {
  echo "Backend npm install failed"
  exit 1
}
cd "$REPO_ROOT"
echo "✓ Backend dependencies installed"

# Step 2: Install smoke test dependencies  
echo "[2/4] Installing smoke test dependencies..."
cd tools/smoke
npm install --silent > "${REPO_ROOT}/${EVIDENCE_DIR}/logs/smoke_npm_install.log" 2>&1 || {
  echo "Smoke npm install failed"
  exit 1
}
cd "$REPO_ROOT"
echo "✓ Smoke dependencies installed"

# Step 3: Start emulators and run tests
echo "[3/4] Starting Firebase emulators and running tests..."
EMULATOR_LOG="${EVIDENCE_DIR}/logs/emulators.log"
cd source/backend
npx firebase emulators:exec \
  --only auth,firestore,functions \
  --project demo-mvp \
  "cd ../../tools/smoke && node mvp_5scenarios.mjs --evidence ../../${EVIDENCE_DIR}" \
  > "${REPO_ROOT}/$EMULATOR_LOG" 2>&1

EMULATOR_EXIT=$?
cd "$REPO_ROOT"

if [ $EMULATOR_EXIT -ne 0 ]; then
  echo "✗ Emulators/tests failed (exit $EMULATOR_EXIT)"
  echo "See: $EMULATOR_LOG"
fi

# Step 4: Validate evidence
echo "[4/4] Validating evidence..."
python3 tools/validate/mvp_5scenarios_validator.py --evidence "${EVIDENCE_DIR}"
VALIDATOR_EXIT=$?

# Print verdict
echo ""
echo "======================================================================"
if [ $VALIDATOR_EXIT -eq 0 ]; then
  echo "MVP 5 SCENARIOS: PASS ✅"
else
  echo "MVP 5 SCENARIOS: FAIL ❌"
fi
echo "======================================================================"
echo "Evidence: ${EVIDENCE_DIR}"
echo ""

if [ -f "${EVIDENCE_DIR}/VALIDATION.json" ]; then
  cat "${EVIDENCE_DIR}/VALIDATION.json"
fi

exit $VALIDATOR_EXIT
