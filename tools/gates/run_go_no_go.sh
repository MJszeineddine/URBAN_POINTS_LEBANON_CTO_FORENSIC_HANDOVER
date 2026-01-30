#!/bin/bash
#
# GO/NO-GO Wrapper Gate - Evidence-only verification
# Creates evidence bundle, runs best available inner gate, validates
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_ID="GO_NO_GO_${TIMESTAMP}"
EVIDENCE_DIR="local-ci/evidence/${RUN_ID}"

echo "======================================================================"
echo "GO/NO-GO WRAPPER GATE"
echo "======================================================================"
echo "Run ID: ${RUN_ID}"
echo "Evidence: ${EVIDENCE_DIR}"
echo ""

# Create evidence structure
mkdir -p "${EVIDENCE_DIR}/logs"

# Save environment snapshot
echo "[1/6] Capturing environment..."
git rev-parse HEAD > "${EVIDENCE_DIR}/commit_hash.txt" 2>&1 || echo "not-a-git-repo" > "${EVIDENCE_DIR}/commit_hash.txt"
git status --porcelain > "${EVIDENCE_DIR}/git_status.txt" 2>&1 || echo "not-a-git-repo" > "${EVIDENCE_DIR}/git_status.txt"

{
  echo "=== Node ==="
  node -v 2>&1 || echo "node: not found"
  echo ""
  echo "=== NPM ==="
  npm -v 2>&1 || echo "npm: not found"
  echo ""
  echo "=== Python ==="
  python3 --version 2>&1 || echo "python3: not found"
  echo ""
  echo "=== Java ==="
  java -version 2>&1 || echo "java: not found"
} > "${EVIDENCE_DIR}/ENV.txt"

# Discover best inner gate (preference order)
INNER_GATE=""
if [ -f "tools/gates/run_rc_strict_gate.sh" ]; then
  INNER_GATE="tools/gates/run_rc_strict_gate.sh"
  echo "[2/6] Using inner gate: run_rc_strict_gate.sh"
elif [ -f "tools/gates/run_rc_gate.sh" ]; then
  INNER_GATE="tools/gates/run_rc_gate.sh"
  echo "[2/6] Using inner gate: run_rc_gate.sh"
elif [ -f "tools/gates/run_mvp_smoke_gate.sh" ]; then
  INNER_GATE="tools/gates/run_mvp_smoke_gate.sh"
  echo "[2/6] Using inner gate: run_mvp_smoke_gate.sh"
else
  echo "[2/6] No inner gate found - using minimal smoke"
  INNER_GATE=""
fi

# Run inner gate or fallback
echo "[3/6] Running tests..."

if [ -n "$INNER_GATE" ]; then
  # Run discovered inner gate
  bash "$INNER_GATE" > "${EVIDENCE_DIR}/logs/INNER_GATE.log" 2>&1 || {
    INNER_EXIT=$?
    echo "  Inner gate exited with code: $INNER_EXIT"
  }
  
  # Find latest evidence folder created by inner gate
  INNER_EVIDENCE=$(find local-ci/evidence -maxdepth 1 -type d -name "RC_STRICT_*" -o -name "RC_*" | sort | tail -1)
  
  if [ -n "$INNER_EVIDENCE" ] && [ -d "$INNER_EVIDENCE" ]; then
    echo "[4/6] Copying evidence from inner gate: $INNER_EVIDENCE"
    # Copy/merge evidence files to wrapper evidence folder
    cp -r "$INNER_EVIDENCE"/* "${EVIDENCE_DIR}/" 2>/dev/null || true
  else
    echo "[4/6] Warning: No inner evidence folder found"
  fi
else
  # Minimal fallback smoke (not implemented - mark as blocker)
  cat > "${EVIDENCE_DIR}/SUMMARY.json" <<EOF
{
  "status": "FAIL",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tests": {"total": 0, "passed": 0, "failed": 0, "skipped": 0},
  "blocker": "No inner gate found and minimal smoke not implemented"
}
EOF
  
  cat > "${EVIDENCE_DIR}/SMOKE_LOG.txt" <<EOF
[$(date -u +%Y-%m-%dT%H:%M:%SZ)] NO-GO: No inner gate found
[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Blocker: Missing test infrastructure
EOF
fi

# Ensure required evidence files exist
echo "[5/6] Validating evidence..."

if [ ! -f "${EVIDENCE_DIR}/SUMMARY.json" ]; then
  echo "  Warning: SUMMARY.json missing - creating FAIL placeholder"
  cat > "${EVIDENCE_DIR}/SUMMARY.json" <<EOF
{
  "status": "FAIL",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tests": {"total": 0, "passed": 0, "failed": 0, "skipped": 0},
  "error": "SUMMARY.json not created by inner gate"
}
EOF
fi

if [ ! -f "${EVIDENCE_DIR}/SMOKE_LOG.txt" ]; then
  touch "${EVIDENCE_DIR}/SMOKE_LOG.txt"
fi

# Run validator
echo "[6/6] Running validator..."
python3 tools/validate/go_no_go_validator.py --evidence "${EVIDENCE_DIR}"
VALIDATOR_EXIT=$?

echo ""
echo "======================================================================"
if [ $VALIDATOR_EXIT -eq 0 ]; then
  echo "GO/NO-GO VERDICT: GO ✅"
else
  echo "GO/NO-GO VERDICT: NO-GO ❌"
fi
echo "======================================================================"
echo "Evidence: ${EVIDENCE_DIR}"
echo ""

if [ -f "${EVIDENCE_DIR}/VALIDATION.json" ]; then
  cat "${EVIDENCE_DIR}/VALIDATION.json"
fi

exit $VALIDATOR_EXIT
