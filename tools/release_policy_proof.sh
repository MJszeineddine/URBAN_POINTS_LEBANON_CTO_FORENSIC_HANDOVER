#!/usr/bin/env bash
# RELEASE_POLICY_PROOF - Unified proof that release policy is enforced
# Runs all gates in order and produces final verdict
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${REPO_ROOT}/tools"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
PROOF_EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/policy_resolution/${TS}"
mkdir -p "${PROOF_EVIDENCE_DIR}"

LOG="${PROOF_EVIDENCE_DIR}/proof_orchestrator.log"

{
  echo "RELEASE_POLICY_PROOF - Started"
  echo "Timestamp: ${TS}"
  echo "Repository: ${REPO_ROOT}"
  echo ""
  echo "Policy Contract: tools/policy_contract.json"
  echo "Policy: Stripe DEFERRED (not required for release)"
  echo ""
  echo "Gates to execute:"
  echo "  1. stripe_deferred_gate.sh"
  echo "  2. final_gap_scan_gate.sh"
  echo "  3. external_dependency_gate.sh"
  echo "  4. final_release_gate.sh"
  echo ""
} | tee "${LOG}"

all_passed=true

# ============================================================================
# GATE 1: STRIPE_DEFERRED_GATE
# ============================================================================
echo "▶ GATE 1: stripe_deferred_gate.sh" | tee -a "${LOG}"
if bash "${TOOLS_DIR}/stripe_deferred_gate.sh" >>"${LOG}" 2>&1; then
  stripe_evidence=$(find "${REPO_ROOT}/docs/evidence/stripe_deferred_gate" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${stripe_evidence}/VERDICT.md" ]; then
    cp "${stripe_evidence}/VERDICT.md" "${PROOF_EVIDENCE_DIR}/stripe_deferred_verdict.md"
    echo "  ✅ PASS" | tee -a "${LOG}"
  else
    echo "  ❌ FAIL (no verdict)" | tee -a "${LOG}"
    all_passed=false
  fi
else
  stripe_evidence=$(find "${REPO_ROOT}/docs/evidence/stripe_deferred_gate" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${stripe_evidence}/NO_GO_STRIPE_DEFERRED_CONTRACT_BROKEN.md" ]; then
    cp "${stripe_evidence}/NO_GO_STRIPE_DEFERRED_CONTRACT_BROKEN.md" "${PROOF_EVIDENCE_DIR}/"
  fi
  echo "  ❌ FAIL" | tee -a "${LOG}"
  all_passed=false
fi

# ============================================================================
# GATE 2: FINAL_GAP_SCAN_GATE
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ GATE 2: final_gap_scan_gate.sh" | tee -a "${LOG}"
if bash "${TOOLS_DIR}/final_gap_scan_gate.sh" >>"${LOG}" 2>&1; then
  gap_evidence=$(find "${REPO_ROOT}/docs/evidence/final_gap_scan" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${gap_evidence}/VERDICT.md" ] || [ -f "${gap_evidence}/VERDICT_FINAL_GAPS_CLEAR.md" ]; then
    [ -f "${gap_evidence}/VERDICT.md" ] && cp "${gap_evidence}/VERDICT.md" "${PROOF_EVIDENCE_DIR}/final_gap_scan_verdict.md"
    [ -f "${gap_evidence}/VERDICT_FINAL_GAPS_CLEAR.md" ] && cp "${gap_evidence}/VERDICT_FINAL_GAPS_CLEAR.md" "${PROOF_EVIDENCE_DIR}/final_gap_scan_verdict.md"
    echo "  ✅ PASS" | tee -a "${LOG}"
  else
    echo "  ❌ FAIL (no verdict)" | tee -a "${LOG}"
    all_passed=false
  fi
else
  gap_evidence=$(find "${REPO_ROOT}/docs/evidence/final_gap_scan" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${gap_evidence}/NO_GO_FINAL_GAPS_FOUND.md" ]; then
    cp "${gap_evidence}/NO_GO_FINAL_GAPS_FOUND.md" "${PROOF_EVIDENCE_DIR}/"
  fi
  echo "  ❌ FAIL" | tee -a "${LOG}"
  all_passed=false
fi

# ============================================================================
# GATE 3: EXTERNAL_DEPENDENCY_GATE
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ GATE 3: external_dependency_gate.sh" | tee -a "${LOG}"
if bash "${TOOLS_DIR}/external_dependency_gate.sh" >>"${LOG}" 2>&1; then
  ext_evidence=$(find "${REPO_ROOT}/docs/evidence/external_dependency_check" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${ext_evidence}/VERDICT.md" ]; then
    cp "${ext_evidence}/VERDICT.md" "${PROOF_EVIDENCE_DIR}/external_dependency_verdict.md"
    echo "  ✅ PASS" | tee -a "${LOG}"
  else
    echo "  ❌ FAIL (no verdict)" | tee -a "${LOG}"
    all_passed=false
  fi
else
  ext_evidence=$(find "${REPO_ROOT}/docs/evidence/external_dependency_check" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${ext_evidence}/NO_GO_EXTERNAL_DEPENDENCIES.md" ]; then
    cp "${ext_evidence}/NO_GO_EXTERNAL_DEPENDENCIES.md" "${PROOF_EVIDENCE_DIR}/"
  fi
  echo "  ❌ FAIL" | tee -a "${LOG}"
  all_passed=false
fi

# ============================================================================
# GATE 4: FINAL_RELEASE_GATE
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ GATE 4: final_release_gate.sh" | tee -a "${LOG}"
if bash "${TOOLS_DIR}/final_release_gate.sh" >>"${LOG}" 2>&1; then
  release_evidence=$(find "${REPO_ROOT}/docs/evidence/final_release_gate" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${release_evidence}/VERDICT.md" ]; then
    cp "${release_evidence}/VERDICT.md" "${PROOF_EVIDENCE_DIR}/final_release_verdict.md"
    echo "  ✅ PASS" | tee -a "${LOG}"
  else
    echo "  ❌ FAIL (no verdict)" | tee -a "${LOG}"
    all_passed=false
  fi
else
  release_evidence=$(find "${REPO_ROOT}/docs/evidence/final_release_gate" -maxdepth 1 -type d | sort -r | head -1)
  if [ -f "${release_evidence}/NO_GO_RELEASE_GATE_FAILED.md" ]; then
    cp "${release_evidence}/NO_GO_RELEASE_GATE_FAILED.md" "${PROOF_EVIDENCE_DIR}/"
  fi
  echo "  ❌ FAIL" | tee -a "${LOG}"
  all_passed=false
fi

# ============================================================================
# FINAL VERDICT
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ FINAL VERDICT" | tee -a "${LOG}"

if [ "${all_passed}" = true ]; then
  {
    echo "# RELEASE_POLICY_PROOF Verdict"
    echo ""
    echo "**VERDICT: GO ✅**"
    echo ""
    echo "## Policy Enforcement Complete"
    echo ""
    echo "**Policy:** Stripe DEFERRED (not required for release)"
    echo ""
    echo "**Contract:** tools/policy_contract.json"
    echo ""
    echo "## All Gates Passed"
    echo ""
    echo "- ✅ stripe_deferred_gate.sh: Stripe contract verified"
    echo "- ✅ final_gap_scan_gate.sh: No non-deferred gaps"
    echo "- ✅ external_dependency_gate.sh: All non-deferred deps satisfied"
    echo "- ✅ final_release_gate.sh: Orchestrator passed"
    echo ""
    echo "## Timestamps"
    echo ""
    echo "- Proof run: ${TS}"
    echo "- Evidence: ${PROOF_EVIDENCE_DIR}"
    echo ""
    echo "## Policy Consistency Verified"
    echo ""
    echo "All gates are consistent with DEFERRED policy:"
    echo "- STRIPE_ENABLED defaults to 0"
    echo "- No test keys in repository"
    echo "- All Stripe functions guarded"
    echo "- Gates do not require Stripe keys/accounts"
    echo ""
    echo "**Status:** Project ready for production release with Stripe deferred."
  } > "${PROOF_EVIDENCE_DIR}/VERDICT.md"
  echo "✅ ALL GATES PASSED - Policy enforced" | tee -a "${LOG}"
  exit_code=0
else
  {
    echo "# RELEASE_POLICY_PROOF Verdict"
    echo ""
    echo "**VERDICT: NO_GO ❌**"
    echo ""
    echo "## Policy Enforcement Failed"
    echo ""
    echo "One or more gates failed. See evidence folder for details."
    echo ""
    echo "Evidence location: ${PROOF_EVIDENCE_DIR}"
  } > "${PROOF_EVIDENCE_DIR}/NO_GO_POLICY_ENFORCEMENT_FAILED.md"
  echo "❌ POLICY ENFORCEMENT FAILED" | tee -a "${LOG}"
  exit_code=1
fi

# Generate SHA256SUMS
cd "${PROOF_EVIDENCE_DIR}"
find . -type f ! -name SHA256SUMS.txt -exec shasum -a 256 {} \; | sort > SHA256SUMS.txt

echo "" | tee -a "${LOG}"
echo "Evidence: ${PROOF_EVIDENCE_DIR}" | tee -a "${LOG}"
echo "Files: $(ls -1 ${PROOF_EVIDENCE_DIR} | tr '\n' ' ')" | tee -a "${LOG}"

exit ${exit_code}
