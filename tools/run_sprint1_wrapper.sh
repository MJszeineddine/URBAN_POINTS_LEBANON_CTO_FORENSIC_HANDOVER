#!/bin/bash

###############################################################################
# SPRINT 1: RUNNER WRAPPER
#
# Non-interactive wrapper that:
# 1. Runs sprint1_runner_hard.sh in background
# 2. Polls for completion (FINAL_SPRINT1_GATE.md or NO_GO*.md)
# 3. Displays result and exits with appropriate code
#
# Usage: run_sprint1_wrapper.sh [REPO_ROOT]
###############################################################################

set -o pipefail

REPO_ROOT="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== SPRINT 1 RUNNER WRAPPER ==="
echo "Repo root: ${REPO_ROOT}"
echo "Time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

# Create logs directory
mkdir -p "${REPO_ROOT}/docs/evidence/sprint1" 2>/dev/null || {
  echo "ERROR: Cannot create evidence directory" >&2
  exit 1
}

# Run runner in background with output redirected
echo "Starting sprint1_runner_hard.sh in background..."
"${SCRIPT_DIR}/sprint1_runner_hard.sh" "${REPO_ROOT}" > /dev/null 2>&1 &
RUNNER_PID=$!
echo "Runner PID: ${RUNNER_PID}"
echo ""

# Get the latest evidence directory
get_latest_evidence_dir() {
  ls -td "${REPO_ROOT}"/docs/evidence/sprint1/*/ 2>/dev/null | head -1 | tr -d '/'
}

# Poll for completion (max 120 seconds)
MAX_WAIT=120
ELAPSED=0
POLL_INTERVAL=2

echo "Waiting for sprint1_runner_hard.sh to complete..."
echo "Polling every ${POLL_INTERVAL}s (timeout: ${MAX_WAIT}s)..."
echo ""

while [ ${ELAPSED} -lt ${MAX_WAIT} ]; do
  EVIDENCE_DIR=$(get_latest_evidence_dir)
  
  if [ -z "${EVIDENCE_DIR}" ]; then
    sleep ${POLL_INTERVAL}
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
    continue
  fi
  
  # Check for completion files
  if [ -f "${EVIDENCE_DIR}/FINAL_SPRINT1_GATE.md" ]; then
    echo "✓ Final gate found"
    echo ""
    cat "${EVIDENCE_DIR}/FINAL_SPRINT1_GATE.md"
    echo ""
    echo "Evidence location: ${EVIDENCE_DIR}"
    exit 0
  fi
  
  # Check for NO_GO files
  NO_GO_FILES=$(find "${EVIDENCE_DIR}" -maxdepth 1 -name "NO_GO_*.md" 2>/dev/null)
  if [ -n "${NO_GO_FILES}" ]; then
    echo "✗ Blocker detected"
    echo ""
    for file in ${NO_GO_FILES}; do
      cat "${file}"
      echo ""
    done
    echo "Evidence location: ${EVIDENCE_DIR}"
    exit 1
  fi
  
  sleep ${POLL_INTERVAL}
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# Timeout
echo "ERROR: Timeout waiting for runner to complete (${MAX_WAIT}s exceeded)" >&2
echo "Check logs: ${EVIDENCE_DIR}/sprint1_runner.log"
exit 2
