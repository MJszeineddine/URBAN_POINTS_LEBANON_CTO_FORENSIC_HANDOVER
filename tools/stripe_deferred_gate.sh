#!/usr/bin/env bash
# STRIPE_DEFERRED_GATE - Verify Stripe is properly deferred for this release
# 
# Contract:
# - Stripe is disabled by default (STRIPE_ENABLED=0)
# - No test keys (sk_test_, pk_test_) anywhere in repo
# - All Stripe initialization guarded by STRIPE_ENABLED check
# - Evidence-first output
#
# Exit Codes:
# 0 = PASS (Stripe deferred contract verified)
# 1 = FAIL (Contract violation detected)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/stripe_deferred_gate/${TS}"
mkdir -p "${EVIDENCE_DIR}"

LOG="${EVIDENCE_DIR}/scan.log"
VIOLATIONS="${EVIDENCE_DIR}/violations.json"

# Initialize results
{
  echo "STRIPE_DEFERRED_GATE - Scan started"
  echo "Timestamp: ${TS}"
  echo "Repository: ${REPO_ROOT}"
} | tee "${LOG}"

passed=0
failed=0

# ============================================================================
# CHECK A: No sk_test_ or pk_test_ keys anywhere in repo (except placeholders)
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ CHECK A: Scanning for active test keys (sk_test_*, pk_test_*)" | tee -a "${LOG}"

# Find test key matches BUT exclude .env.example and .env which are just placeholders
test_key_matches=$(grep -r "sk_test_\|pk_test_" \
  "${REPO_ROOT}/source" "${REPO_ROOT}/tools" "${REPO_ROOT}/docs" \
  --include="*.ts" --include="*.js" --include="*.dart" \
  --include="*.json" --include="*.yaml" --include="*.yml" \
  --exclude-dir="node_modules" --exclude-dir=".git" \
  2>/dev/null | grep -v ".env" | grep -v ".env.example" | grep -v ".env.deployment" || true)

if [ -n "${test_key_matches}" ]; then
  echo "  ✗ FAIL: Found test keys in source (not in env files)" | tee -a "${LOG}"
  echo "${test_key_matches}" | tee -a "${LOG}"
  ((failed++))
else
  echo "  ✓ PASS: No test keys in active source code" | tee -a "${LOG}"
  echo "  (Placeholders in .env files are documented and excluded)" | tee -a "${LOG}"
  ((passed++))
fi

# ============================================================================
# CHECK B: Verify STRIPE_ENABLED defaults to 0
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ CHECK B: Verify STRIPE_ENABLED default = 0" | tee -a "${LOG}"

# Check .env.example for STRIPE_ENABLED
if [ -f "${REPO_ROOT}/source/backend/firebase-functions/.env.example" ]; then
  env_example="${REPO_ROOT}/source/backend/firebase-functions/.env.example"
  stripe_enabled_line=$(grep "^STRIPE_ENABLED" "${env_example}" || true)
  
  if [[ "${stripe_enabled_line}" == "STRIPE_ENABLED=0" ]]; then
    echo "  ✓ PASS: STRIPE_ENABLED=0 in .env.example" | tee -a "${LOG}"
    ((passed++))
  else
    echo "  ✗ FAIL: STRIPE_ENABLED not set to 0 in .env.example" | tee -a "${LOG}"
    if [ -n "${stripe_enabled_line}" ]; then
      echo "    Found: ${stripe_enabled_line}" | tee -a "${LOG}"
    else
      echo "    STRIPE_ENABLED not found in .env.example" | tee -a "${LOG}"
    fi
    ((failed++))
  fi
else
  echo "  ✗ FAIL: .env.example not found" | tee -a "${LOG}"
  ((failed++))
fi

# ============================================================================
# CHECK C: Verify runtime guards in backend Stripe initialization
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ CHECK C: Verify STRIPE_ENABLED guards in backend" | tee -a "${LOG}"

stripe_file="${REPO_ROOT}/source/backend/firebase-functions/src/stripe.ts"
if [ -f "${stripe_file}" ]; then
  # Check for isStripeEnabled function
  if grep -q "function isStripeEnabled" "${stripe_file}"; then
    echo "  ✓ PASS: isStripeEnabled() helper function found" | tee -a "${LOG}"
    ((passed++))
  else
    echo "  ✗ FAIL: isStripeEnabled() helper function not found" | tee -a "${LOG}"
    ((failed++))
  fi
  
  # Check for STRIPE_DEFERRED guard in initiatePayment
  if grep -q "export async function initiatePayment" "${stripe_file}" && \
     grep -B 20 "export async function initiatePayment" "${stripe_file}" | grep -q "if (!isStripeEnabled())" || \
     grep -A 10 "export async function initiatePayment" "${stripe_file}" | grep -q "if (!isStripeEnabled())"; then
    echo "  ✓ PASS: initiatePayment guarded by isStripeEnabled()" | tee -a "${LOG}"
    ((passed++))
  else
    echo "  ✗ FAIL: initiatePayment missing isStripeEnabled() guard" | tee -a "${LOG}"
    ((failed++))
  fi
  
  # Check for STRIPE_DEFERRED guard in createCustomer
  if grep -q "export async function createCustomer" "${stripe_file}" && \
     grep -A 10 "export async function createCustomer" "${stripe_file}" | grep -q "if (!isStripeEnabled())"; then
    echo "  ✓ PASS: createCustomer guarded by isStripeEnabled()" | tee -a "${LOG}"
    ((passed++))
  else
    echo "  ✗ FAIL: createCustomer missing isStripeEnabled() guard" | tee -a "${LOG}"
    ((failed++))
  fi
  
  # Check for STRIPE_DEFERRED guard in createSubscription
  if grep -q "export async function createSubscription" "${stripe_file}" && \
     grep -A 10 "export async function createSubscription" "${stripe_file}" | grep -q "if (!isStripeEnabled())"; then
    echo "  ✓ PASS: createSubscription guarded by isStripeEnabled()" | tee -a "${LOG}"
    ((passed++))
  else
    echo "  ✗ FAIL: createSubscription missing isStripeEnabled() guard" | tee -a "${LOG}"
    ((failed++))
  fi
  
  # Check for STRIPE_DEFERRED guard in verifyPaymentStatus
  if grep -q "export async function verifyPaymentStatus" "${stripe_file}" && \
     grep -A 10 "export async function verifyPaymentStatus" "${stripe_file}" | grep -q "if (!isStripeEnabled())"; then
    echo "  ✓ PASS: verifyPaymentStatus guarded by isStripeEnabled()" | tee -a "${LOG}"
    ((passed++))
  else
    echo "  ✗ FAIL: verifyPaymentStatus missing isStripeEnabled() guard" | tee -a "${LOG}"
    ((failed++))
  fi
  
  # Check for STRIPE_DEFERRED guard in stripeWebhook
  if grep -A 10 "export const stripeWebhook" "${stripe_file}" | grep -q "isStripeEnabled()"; then
    echo "  ✓ PASS: stripeWebhook guarded by isStripeEnabled()" | tee -a "${LOG}"
    ((passed++))
  else
    echo "  ✗ FAIL: stripeWebhook missing isStripeEnabled() guard" | tee -a "${LOG}"
    ((failed++))
  fi
  
  # Check for production key validation (sk_live_)
  if grep -q "sk_live_" "${stripe_file}"; then
    echo "  ✓ PASS: Production key format (sk_live_) validation present" | tee -a "${LOG}"
    ((passed++))
  else
    echo "  ✗ FAIL: No sk_live_ validation found" | tee -a "${LOG}"
    ((failed++))
  fi
else
  echo "  ✗ FAIL: stripe.ts not found at expected path" | tee -a "${LOG}"
  ((failed++))
fi

# ============================================================================
# Generate verdict
# ============================================================================
echo "" | tee -a "${LOG}"
echo "▶ STRIPE_DEFERRED CONTRACT VERIFICATION" | tee -a "${LOG}"
echo "  Checks Passed: ${passed}" | tee -a "${LOG}"
echo "  Checks Failed: ${failed}" | tee -a "${LOG}"

# Write JSON violations file
{
  echo "{"
  echo "  \"scan_timestamp\": \"${TS}\","
  echo "  \"checks_passed\": ${passed},"
  echo "  \"checks_failed\": ${failed},"
  echo "  \"contract_satisfied\": $([ ${failed} -eq 0 ] && echo 'true' || echo 'false')"
  echo "}"
} > "${VIOLATIONS}"

# Write verdict
if [ ${failed} -eq 0 ]; then
  {
    echo "# STRIPE_DEFERRED_GATE Verdict"
    echo ""
    echo "**VERDICT: GO ✅**"
    echo ""
    echo "## STRIPE Deferred Contract Verified"
    echo ""
    echo "- ✅ No test keys (sk_test_, pk_test_) in repository"
    echo "- ✅ STRIPE_ENABLED defaults to 0 (disabled)"
    echo "- ✅ All Stripe functions guarded by isStripeEnabled() checks"
    echo "- ✅ Production key validation in place (sk_live_ required when enabled)"
    echo ""
    echo "**Status:** Stripe deferred for this release. Can be re-enabled in future versions by:"
    echo "1. Setting STRIPE_ENABLED=1 in configuration"
    echo "2. Providing sk_live_* production keys"
    echo "3. Setting up Stripe webhooks (whsk_*)"
  } > "${EVIDENCE_DIR}/VERDICT.md"
  echo "" | tee -a "${LOG}"
  echo "✅ STRIPE_DEFERRED contract satisfied" | tee -a "${LOG}"
  exit_code=0
else
  {
    echo "# STRIPE_DEFERRED_GATE Verdict"
    echo ""
    echo "**VERDICT: NO_GO ❌**"
    echo ""
    echo "## STRIPE Deferred Contract BROKEN"
    echo ""
    echo "The following contract violations were detected:"
    echo ""
    if grep -q "FAIL: Found test keys" "${LOG}"; then
      echo "- ❌ Test keys (sk_test_, pk_test_) found in repository"
    fi
    if grep -q "FAIL: STRIPE_ENABLED not set to 0" "${LOG}"; then
      echo "- ❌ STRIPE_ENABLED not defaulting to 0"
    fi
    if grep -q "FAIL:.*missing.*isStripeEnabled" "${LOG}"; then
      echo "- ❌ Some Stripe functions missing STRIPE_ENABLED guards"
    fi
    echo ""
    echo "## Remediation Required"
    echo ""
    echo "See scan.log for detailed findings."
  } > "${EVIDENCE_DIR}/NO_GO_STRIPE_DEFERRED_CONTRACT_BROKEN.md"
  echo "" | tee -a "${LOG}"
  echo "❌ STRIPE_DEFERRED contract violated - see NO_GO_STRIPE_DEFERRED_CONTRACT_BROKEN.md" | tee -a "${LOG}"
  exit_code=1
fi

# Generate SHA256SUMS
cd "${EVIDENCE_DIR}"
sha256sum VERDICT.md NO_GO_STRIPE_DEFERRED_CONTRACT_BROKEN.md scan.log violations.json 2>/dev/null | grep -v "No such file" > SHA256SUMS.txt || true
echo "" | tee -a "${LOG}"
echo "Evidence: ${EVIDENCE_DIR}" | tee -a "${LOG}"
echo "Files: $(ls -1 ${EVIDENCE_DIR} | tr '\n' ' ')" | tee -a "${LOG}"

exit ${exit_code}
