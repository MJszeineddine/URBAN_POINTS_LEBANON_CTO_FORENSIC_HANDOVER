#!/usr/bin/env bash
# Stripe Phase Deployment Gate - Hard Timeout Edition
# Non-PTY, file-only output, hard timeouts, polling-based execution
# Based on proven prod_deploy_gate_hard.sh pattern

set -euo pipefail

# Change to Firebase Functions directory
cd /Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/backend/firebase-functions

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT="urbangenspark"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
GATE_NAME="stripe_phase_gate"
EVIDENCE_DIR="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/docs/evidence/production_gate/${TIMESTAMP}/${GATE_NAME}"

mkdir -p "${EVIDENCE_DIR}"

EXECUTION_LOG="${EVIDENCE_DIR}/EXECUTION_LOG.md"
VERDICT_FILE="${EVIDENCE_DIR}/FINAL_STRIPE_GATE.md"

# ============================================================================
# HARD TIMEOUT IMPLEMENTATION
# ============================================================================

# Usage: hard_timeout <seconds> <log_prefix> <command> <args...>
# Spawns command as background process, launches kill job, waits for result
hard_timeout() {
  local timeout_seconds=$1
  if [ "$timeout_seconds" -lt 120 ]; then
    timeout_seconds=120
  fi
  shift
  local log_prefix=$1
  shift
  
  local out_log="${EVIDENCE_DIR}/${log_prefix}.out.log"
  local err_log="${EVIDENCE_DIR}/${log_prefix}.err.log"
  local exit_code_file="${EVIDENCE_DIR}/${log_prefix}.exitcode"
  
  # Run command in background, capture output
  (
    "$@" > "${out_log}" 2> "${err_log}"
    echo $? > "${exit_code_file}"
  ) &
  
  local cmd_pid=$!
  
  # Spawn killer process
  (
    sleep "${timeout_seconds}"
    if kill -0 "${cmd_pid}" 2>/dev/null; then
      echo "TIMEOUT_KILL after ${timeout_seconds}s" >> "${err_log}"
      kill -9 "${cmd_pid}" 2>/dev/null || true
      echo "124" > "${exit_code_file}"  # Timeout exit code
    fi
  ) &
  
  local killer_pid=$!
  
  # Wait for command to finish
  wait "${cmd_pid}" 2>/dev/null || true
  
  # Kill the killer if command finished early
  kill -9 "${killer_pid}" 2>/dev/null || true
  
  # Read exit code
  if [[ -f "${exit_code_file}" ]]; then
    return $(cat "${exit_code_file}")
  else
    return 1
  fi
}

# ============================================================================
# EXECUTION LOG HEADER
# ============================================================================

cat > "${EXECUTION_LOG}" <<EOF
# Stripe Phase Deployment Gate - Execution Log

**Project**: ${PROJECT}
**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}
**Evidence Directory**: ${EVIDENCE_DIR}

## Commands Executed

EOF

# ============================================================================
# STEP 1: FIREBASE VERSION CHECK
# ============================================================================

echo "### 1. Firebase CLI Version" >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"
echo '```bash' >> "${EXECUTION_LOG}"
echo "firebase --version" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"

if hard_timeout 10 "firebase_version" firebase --version; then
  echo "**Status**: ✅ SUCCESS (exit code 0)" >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/firebase_version.out.log" | head -3 >> "${EXECUTION_LOG}"
else
  echo "**Status**: ❌ FAILED (exit code $?)" >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/firebase_version.err.log" | head -10 >> "${EXECUTION_LOG}"
fi
echo "" >> "${EXECUTION_LOG}"

# ============================================================================
# STEP 2: SET PROJECT
# ============================================================================

echo "### 2. Set Firebase Project" >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"
echo '```bash' >> "${EXECUTION_LOG}"
echo "firebase use ${PROJECT}" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"

if hard_timeout 10 "firebase_use" firebase use "${PROJECT}"; then
  echo "**Status**: ✅ SUCCESS" >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/firebase_use.out.log" | head -5 >> "${EXECUTION_LOG}"
else
  echo "**Status**: ❌ FAILED" >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/firebase_use.err.log" | head -10 >> "${EXECUTION_LOG}"
fi
echo "" >> "${EXECUTION_LOG}"

# ============================================================================
# STEP 3: PRE-DEPLOY FUNCTIONS LIST
# ============================================================================

echo "### 3. Pre-Deploy Functions Inventory" >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"
echo '```bash' >> "${EXECUTION_LOG}"
echo "firebase functions:list --project ${PROJECT}" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"

if hard_timeout 30 "firebase_functions_list_pre" firebase functions:list --project "${PROJECT}"; then
  echo "**Status**: ✅ SUCCESS" >> "${EXECUTION_LOG}"
  echo "" >> "${EXECUTION_LOG}"
  echo '```' >> "${EXECUTION_LOG}"
  grep -E "stripe|Stripe" "${EVIDENCE_DIR}/firebase_functions_list_pre.out.log" || echo "(No Stripe functions found)" >> "${EXECUTION_LOG}"
  echo '```' >> "${EXECUTION_LOG}"
else
  echo "**Status**: ❌ FAILED" >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/firebase_functions_list_pre.err.log" | head -10 >> "${EXECUTION_LOG}"
fi
echo "" >> "${EXECUTION_LOG}"

# ============================================================================
# STEP 4: DEPLOY STRIPE FUNCTIONS (CRITICAL)
# ============================================================================

echo "### 4. Deploy Stripe Functions" >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"
echo '```bash' >> "${EXECUTION_LOG}"
echo "firebase deploy --only functions:stripeWebhook,functions:initiatePaymentCallable,functions:createCheckoutSession,functions:createBillingPortalSession --project ${PROJECT}" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"

DEPLOY_EXIT_CODE=0
if hard_timeout 300 "firebase_deploy_stripe" firebase deploy \
  --only functions:stripeWebhook,functions:initiatePaymentCallable,functions:createCheckoutSession,functions:createBillingPortalSession \
  --project "${PROJECT}"; then
  echo "**Status**: ✅ SUCCESS (exit code 0)" >> "${EXECUTION_LOG}"
  echo "" >> "${EXECUTION_LOG}"
  echo "**Smoking Gun Lines**:" >> "${EXECUTION_LOG}"
  echo '```' >> "${EXECUTION_LOG}"
  grep -E "Deploy complete|Successful|functions\[" "${EVIDENCE_DIR}/firebase_deploy_stripe.out.log" | tail -20 >> "${EXECUTION_LOG}"
  echo '```' >> "${EXECUTION_LOG}"
else
  DEPLOY_EXIT_CODE=$?
  echo "**Status**: ❌ FAILED (exit code ${DEPLOY_EXIT_CODE})" >> "${EXECUTION_LOG}"
  echo "" >> "${EXECUTION_LOG}"
  echo "**Error Output**:" >> "${EXECUTION_LOG}"
  echo '```' >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/firebase_deploy_stripe.err.log" | tail -30 >> "${EXECUTION_LOG}"
  echo '```' >> "${EXECUTION_LOG}"
fi
echo "" >> "${EXECUTION_LOG}"

# ============================================================================
# STEP 5: POST-DEPLOY FUNCTIONS LIST
# ============================================================================

echo "### 5. Post-Deploy Functions Verification" >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"
echo '```bash' >> "${EXECUTION_LOG}"
echo "firebase functions:list --project ${PROJECT}" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"

if hard_timeout 30 "firebase_functions_list_post" firebase functions:list --project "${PROJECT}"; then
  echo "**Status**: ✅ SUCCESS" >> "${EXECUTION_LOG}"
  echo "" >> "${EXECUTION_LOG}"
  echo "**Stripe Functions Inventory**:" >> "${EXECUTION_LOG}"
  echo '```' >> "${EXECUTION_LOG}"
  grep -E "stripe|initiate|checkout|billing|Webhook" "${EVIDENCE_DIR}/firebase_functions_list_post.out.log" || echo "(No matches found)" >> "${EXECUTION_LOG}"
  echo '```' >> "${EXECUTION_LOG}"
  
  # Count Stripe functions
  STRIPE_FUNCTION_COUNT=$(grep -E "stripeWebhook|initiatePaymentCallable|createCheckoutSession|createBillingPortalSession" "${EVIDENCE_DIR}/firebase_functions_list_post.out.log" | wc -l | xargs)
  echo "" >> "${EXECUTION_LOG}"
  echo "**Stripe Functions Count**: ${STRIPE_FUNCTION_COUNT}/4" >> "${EXECUTION_LOG}"
else
  echo "**Status**: ❌ FAILED" >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/firebase_functions_list_post.err.log" | head -10 >> "${EXECUTION_LOG}"
  STRIPE_FUNCTION_COUNT=0
fi
echo "" >> "${EXECUTION_LOG}"

# ============================================================================
# STEP 6: GENERATE SHA256SUMS
# ============================================================================

echo "### 6. Evidence Integrity" >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"

cd "${EVIDENCE_DIR}"
find . -type f -name "*.log" -o -name "*.exitcode" | sort | xargs shasum -a 256 > SHA256SUMS.txt

echo "**SHA256SUMS.txt generated**:" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
cat SHA256SUMS.txt >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
echo "" >> "${EXECUTION_LOG}"

# ============================================================================
# VERDICT GENERATION
# ============================================================================

cat > "${VERDICT_FILE}" <<EOF
# Stripe Phase Deployment Gate - FINAL VERDICT

**Project**: ${PROJECT}
**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}

---

## Deployment Summary

EOF

if [[ ${DEPLOY_EXIT_CODE} -eq 0 ]] && [[ ${STRIPE_FUNCTION_COUNT} -ge 4 ]]; then
  cat >> "${VERDICT_FILE}" <<EOF
### ✅ VERDICT: GO

**Deploy Status**: SUCCESS (exit code 0)  
**Stripe Functions Deployed**: ${STRIPE_FUNCTION_COUNT}/4  
**Evidence Directory**: ${EVIDENCE_DIR}

## Deployed Functions

EOF

  grep -E "stripeWebhook|initiatePaymentCallable|createCheckoutSession|createBillingPortalSession" "${EVIDENCE_DIR}/firebase_functions_list_post.out.log" | while read -r line; do
    echo "- ${line}" >> "${VERDICT_FILE}"
  done

  cat >> "${VERDICT_FILE}" <<EOF

## Smoking Gun Evidence

\`\`\`
EOF
  grep -E "Deploy complete|Successful" "${EVIDENCE_DIR}/firebase_deploy_stripe.out.log" | head -5 >> "${VERDICT_FILE}"
  echo '```' >> "${VERDICT_FILE}"
  
  cat >> "${VERDICT_FILE}" <<EOF

## Next Steps

1. ✅ Stripe functions deployed successfully
2. 🔐 Configure secrets: See docs/STRIPE_SECRETS_SETUP.md
3. 🌐 Register webhook endpoint in Stripe Dashboard: https://us-central1-urbangenspark.cloudfunctions.net/stripeWebhook
4. 🧪 Test checkout flow: Call createCheckoutSession from client app
5. 📊 Monitor webhook logs: firebase functions:log --only stripeWebhook

---

**Deployment Gate Passed**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

else
  cat >> "${VERDICT_FILE}" <<EOF
### ❌ VERDICT: NO GO

**Deploy Status**: ${DEPLOY_EXIT_CODE}  
**Stripe Functions Found**: ${STRIPE_FUNCTION_COUNT}/4  
**Evidence Directory**: ${EVIDENCE_DIR}

## Failure Analysis

EOF

  if [[ ${DEPLOY_EXIT_CODE} -ne 0 ]]; then
    echo "**Deploy Command Failed**: Exit code ${DEPLOY_EXIT_CODE}" >> "${VERDICT_FILE}"
    echo "" >> "${VERDICT_FILE}"
    echo '```' >> "${VERDICT_FILE}"
    tail -20 "${EVIDENCE_DIR}/firebase_deploy_stripe.err.log" >> "${VERDICT_FILE}"
    echo '```' >> "${VERDICT_FILE}"
  fi
  
  if [[ ${STRIPE_FUNCTION_COUNT} -lt 4 ]]; then
    echo "" >> "${VERDICT_FILE}"
    echo "**Missing Functions**: Expected 4 Stripe functions, found ${STRIPE_FUNCTION_COUNT}" >> "${VERDICT_FILE}"
    echo "" >> "${VERDICT_FILE}"
    echo "Expected functions:" >> "${VERDICT_FILE}"
    echo "- stripeWebhook" >> "${VERDICT_FILE}"
    echo "- initiatePaymentCallable" >> "${VERDICT_FILE}"
    echo "- createCheckoutSession" >> "${VERDICT_FILE}"
    echo "- createBillingPortalSession" >> "${VERDICT_FILE}"
  fi

  cat >> "${VERDICT_FILE}" <<EOF

---

**Deployment Gate Failed**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

fi

# ============================================================================
# FINAL OUTPUT
# ============================================================================

echo ""
echo "============================================================================"
echo "STRIPE PHASE DEPLOYMENT GATE - EXECUTION COMPLETE"
echo "============================================================================"
echo ""
echo "Evidence Directory: ${EVIDENCE_DIR}"
echo "Execution Log: ${EXECUTION_LOG}"
echo "Final Verdict: ${VERDICT_FILE}"
echo ""

if [[ -f "${VERDICT_FILE}" ]]; then
  echo "--- VERDICT (First 15 lines) ---"
  head -15 "${VERDICT_FILE}"
fi

exit 0
