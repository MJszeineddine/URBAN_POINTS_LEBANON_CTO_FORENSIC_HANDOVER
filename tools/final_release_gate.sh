#!/usr/bin/env bash
# FINAL_RELEASE_GATE - Unified production release gate
#
# Orchestrates all prerequisite gates:
# 1. Stripe Deferred Contract (STRIPE_ENABLED=0, no test keys, all guards in place)
# 2. External Dependencies (blocks if production credentials missing)
# 3. Final Gaps (production readiness checklist)
#
# Exit Codes:
# 0 = GO (all gates pass)
# 1 = NO_GO (any gate fails)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${REPO_ROOT}/tools"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
GATE_EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/final_release_gate/${TS}"
mkdir -p "${GATE_EVIDENCE_DIR}"

LOG="${GATE_EVIDENCE_DIR}/orchestrator.log"

# Feature completeness mode (optional)
REQUIRE_FEATURE_COMPLETENESS="${REQUIRE_FEATURE_COMPLETENESS:-0}"

# Reality diff mode (optional)
REQUIRE_REALITY_DIFF="${REQUIRE_REALITY_DIFF:-0}"

# Log function
log_gate() {
  local gate_name="$1"
  local status="$2"
  echo "[${gate_name}] ${status} ($(date -Iseconds))" | tee -a "${LOG}"
}

{
  echo "FINAL_RELEASE_GATE - Orchestrator started"
  echo "Timestamp: ${TS}"
  echo "Repository: ${REPO_ROOT}"
  echo "Feature Completeness Required: ${REQUIRE_FEATURE_COMPLETENESS}"
  echo "Reality Diff Required: ${REQUIRE_REALITY_DIFF}"
  echo ""
  echo "Gates to execute:"
  echo "  1. stripe_deferred_gate.sh"
  echo "  2. external_dependency_gate.sh"
  echo "  3. final_gap_scan_gate.sh"
  if [ "${REQUIRE_FEATURE_COMPLETENESS}" = "1" ]; then
    echo "  4. feature_completeness_gate.sh (REQUIRED)"
  fi
  if [ "${REQUIRE_REALITY_DIFF}" = "1" ]; then
    echo "  5. reality_diff_gate.sh (REQUIRED)"
  fi
  echo ""
} | tee "${LOG}"

all_passed=true

# ============================================================================
# GATE 1: STRIPE_DEFERRED_GATE
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ EXECUTING: STRIPE_DEFERRED_GATE" | tee -a "${LOG}"
log_gate "stripe_deferred" "START"

if bash "${TOOLS_DIR}/stripe_deferred_gate.sh" >/dev/null 2>&1; then
  # Find latest evidence folder
  stripe_evidence=$(find "${REPO_ROOT}/docs/evidence/stripe_deferred_gate" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${stripe_evidence}/VERDICT.md" ]; then
    cp "${stripe_evidence}/VERDICT.md" "${GATE_EVIDENCE_DIR}/stripe_deferred_verdict.md"
    log_gate "stripe_deferred" "PASS ✓"
  else
    log_gate "stripe_deferred" "UNKNOWN (no verdict file)"
    all_passed=false
  fi
else
  stripe_evidence=$(find "${REPO_ROOT}/docs/evidence/stripe_deferred_gate" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${stripe_evidence}/NO_GO_STRIPE_DEFERRED_CONTRACT_BROKEN.md" ]; then
    cp "${stripe_evidence}/NO_GO_STRIPE_DEFERRED_CONTRACT_BROKEN.md" "${GATE_EVIDENCE_DIR}/"
  fi
  log_gate "stripe_deferred" "FAIL ✗"
  all_passed=false
fi

# ============================================================================
# GATE 2: EXTERNAL_DEPENDENCY_GATE
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ EXECUTING: EXTERNAL_DEPENDENCY_GATE" | tee -a "${LOG}"
log_gate "external_dependency" "START"

if bash "${TOOLS_DIR}/external_dependency_gate.sh" >/dev/null 2>&1; then
  ext_evidence=$(find "${REPO_ROOT}/docs/evidence/external_dependency_check" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${ext_evidence}/VERDICT.md" ]; then
    cp "${ext_evidence}/VERDICT.md" "${GATE_EVIDENCE_DIR}/external_dependency_verdict.md"
    log_gate "external_dependency" "PASS ✓"
  else
    log_gate "external_dependency" "UNKNOWN (no verdict file)"
    all_passed=false
  fi
else
  ext_evidence=$(find "${REPO_ROOT}/docs/evidence/external_dependency_check" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${ext_evidence}/NO_GO_EXTERNAL_DEPENDENCIES.md" ]; then
    cp "${ext_evidence}/NO_GO_EXTERNAL_DEPENDENCIES.md" "${GATE_EVIDENCE_DIR}/"
  fi
  log_gate "external_dependency" "FAIL ✗"
  all_passed=false
fi

# ============================================================================
# GATE 3: FINAL_GAP_SCAN_GATE
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ EXECUTING: FINAL_GAP_SCAN_GATE" | tee -a "${LOG}"
log_gate "final_gap_scan" "START"

if bash "${TOOLS_DIR}/final_gap_scan_gate.sh" >/dev/null 2>&1; then
  gap_evidence=$(find "${REPO_ROOT}/docs/evidence/final_gap_scan" -maxdepth 1 -type d | sort -r | head -1)
  # Check for either VERDICT.md or VERDICT_FINAL_GAPS_CLEAR.md
  if [ -f "${gap_evidence}/VERDICT.md" ]; then
    cp "${gap_evidence}/VERDICT.md" "${GATE_EVIDENCE_DIR}/final_gap_scan_verdict.md"
    log_gate "final_gap_scan" "PASS ✓"
  elif [ -f "${gap_evidence}/VERDICT_FINAL_GAPS_CLEAR.md" ]; then
    cp "${gap_evidence}/VERDICT_FINAL_GAPS_CLEAR.md" "${GATE_EVIDENCE_DIR}/final_gap_scan_verdict.md"
    log_gate "final_gap_scan" "PASS ✓"
  else
    log_gate "final_gap_scan" "UNKNOWN (no verdict file)"
    all_passed=false
  fi
else
  gap_evidence=$(find "${REPO_ROOT}/docs/evidence/final_gap_scan" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${gap_evidence}/NO_GO_FINAL_GAPS_FOUND.md" ]; then
    cp "${gap_evidence}/NO_GO_FINAL_GAPS_FOUND.md" "${GATE_EVIDENCE_DIR}/"
  fi
  log_gate "final_gap_scan" "FAIL ✗"
  all_passed=false
fi

# ============================================================================
# GATE 4: FEATURE_COMPLETENESS_GATE (Optional)
# ============================================================================
if [ "${REQUIRE_FEATURE_COMPLETENESS}" = "1" ]; then
  echo "" | tee -a "${LOG}"
  echo "▶ EXECUTING: FEATURE_COMPLETENESS_GATE" | tee -a "${LOG}"
  log_gate "feature_completeness" "START"
  
  if bash "${TOOLS_DIR}/feature_completeness_gate.sh" >/dev/null 2>&1; then
    feature_evidence=$(find "${REPO_ROOT}/docs/evidence/feature_completeness" -maxdepth 1 -type d | sort -r | head -1)
    if [ -f "${feature_evidence}/VERDICT.md" ]; then
      cp "${feature_evidence}/VERDICT.md" "${GATE_EVIDENCE_DIR}/feature_completeness_verdict.md"
      log_gate "feature_completeness" "PASS ✓"
    else
      log_gate "feature_completeness" "UNKNOWN (no verdict file)"
      all_passed=false
    fi
  else
    feature_evidence=$(find "${REPO_ROOT}/docs/evidence/feature_completeness" -maxdepth 1 -type d | sort -r | head -1)
    if [ -f "${feature_evidence}/NO_GO_FEATURE_COMPLETENESS.md" ]; then
      cp "${feature_evidence}/NO_GO_FEATURE_COMPLETENESS.md" "${GATE_EVIDENCE_DIR}/"
    fi
    log_gate "feature_completeness" "FAIL ✗"
    all_passed=false
  fi
fi

# ============================================================================
# GATE 5: REALITY_DIFF_GATE (Optional)
# ============================================================================
if [ "${REQUIRE_REALITY_DIFF}" = "1" ]; then
  echo "" | tee -a "${LOG}"
  echo "▶ EXECUTING: REALITY_DIFF_GATE" | tee -a "${LOG}"
  log_gate "reality_diff" "START"
  
  if bash "${TOOLS_DIR}/reality_diff_gate.sh" >/dev/null 2>&1; then
    reality_evidence=$(find "${REPO_ROOT}/docs/evidence/reality_diff" -maxdepth 1 -type d | sort -r | head -1)
    if [ -f "${reality_evidence}/VERDICT.md" ]; then
      cp "${reality_evidence}/VERDICT.md" "${GATE_EVIDENCE_DIR}/reality_diff_verdict.md"
      log_gate "reality_diff" "PASS ✓"
    else
      log_gate "reality_diff" "UNKNOWN (no verdict file)"
      all_passed=false
    fi
  else
    reality_evidence=$(find "${REPO_ROOT}/docs/evidence/reality_diff" -maxdepth 1 -type d | sort -r | head -1)
    if [ -f "${reality_evidence}/NO_GO_REALITY_DIFF.md" ]; then
      cp "${reality_evidence}/NO_GO_REALITY_DIFF.md" "${GATE_EVIDENCE_DIR}/"
    fi
    log_gate "reality_diff" "FAIL ✗"
    all_passed=false
  fi
fi

# ============================================================================
# FINAL VERDICT
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ FINAL VERDICT" | tee -a "${LOG}"

if [ "${all_passed}" = true ]; then
  {
    echo "# FINAL_RELEASE_GATE Verdict"
    echo ""
    echo "**VERDICT: GO ✅**"
    echo ""
    echo "## All Gates Passed"
    echo ""
    echo "- ✅ STRIPE_DEFERRED_GATE: Stripe properly deferred (disabled by default)"
    echo "- ✅ EXTERNAL_DEPENDENCY_GATE: All external dependencies verified"
    echo "- ✅ FINAL_GAP_SCAN_GATE: Production readiness confirmed"
    if [ "${REQUIRE_FEATURE_COMPLETENESS}" = "1" ]; then
      echo "- ✅ FEATURE_COMPLETENESS_GATE: All features implemented and tested"
    fi
    if [ "${REQUIRE_REALITY_DIFF}" = "1" ]; then
      echo "- ✅ REALITY_DIFF_GATE: Zero blockers in reality assessment"
    fi
    echo ""
    echo "**Status:** Project is ready for production release."
  } > "${GATE_EVIDENCE_DIR}/VERDICT.md"
  echo "" | tee -a "${LOG}"
  echo "✅ ALL GATES PASSED - Project ready for release" | tee -a "${LOG}"
  exit_code=0
else
  {
    echo "# FINAL_RELEASE_GATE Verdict"
    echo ""
    echo "**VERDICT: NO_GO ❌**"
    echo ""
    echo "## Gate Failures"
    echo ""
    echo "One or more gates failed. See evidence folder for details:"
    echo "- stripe_deferred_verdict.md (or NO_GO_STRIPE_DEFERRED_CONTRACT_BROKEN.md)"
    echo "- external_dependency_verdict.md (or NO_GO_EXTERNAL_DEPENDENCIES.md)"
    echo "- final_gap_scan_verdict.md (or NO_GO_FINAL_GAPS_FOUND.md)"
    if [ "${REQUIRE_FEATURE_COMPLETENESS}" = "1" ]; then
      echo "- feature_completeness_verdict.md (or NO_GO_FEATURE_COMPLETENESS.md)"
    fi
    if [ "${REQUIRE_REALITY_DIFF}" = "1" ]; then
      echo "- reality_diff_verdict.md (or NO_GO_REALITY_DIFF.md)"
    fi
  } > "${GATE_EVIDENCE_DIR}/NO_GO_RELEASE_GATE_FAILED.md"
  echo "" | tee -a "${LOG}"
  echo "❌ RELEASE GATE FAILED - See evidence for details" | tee -a "${LOG}"
  exit_code=1
fi

# Generate SHA256SUMS
cd "${GATE_EVIDENCE_DIR}"
sha256sum *.md *.log 2>/dev/null | grep -v "No such file" > SHA256SUMS.txt || true

echo "" | tee -a "${LOG}"
echo "Evidence: ${GATE_EVIDENCE_DIR}" | tee -a "${LOG}"
echo "Files: $(ls -1 ${GATE_EVIDENCE_DIR} | tr '\n' ' ')" | tee -a "${LOG}"

exit ${exit_code}
