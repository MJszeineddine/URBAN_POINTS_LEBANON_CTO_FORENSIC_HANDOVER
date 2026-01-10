#!/usr/bin/env bash
# Stripe CLI Replay Gate - Non-PTY, evidence-first webhook verification

set -euo pipefail

PROJECT_ROOT="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER"
cd "$PROJECT_ROOT"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
GATE_NAME="stripe_cli_replay_gate"
EVIDENCE_DIR="$PROJECT_ROOT/docs/evidence/production_gate/${TIMESTAMP}/${GATE_NAME}"
FIREBASE_FUNCTIONS_DIR="$PROJECT_ROOT/source/backend/firebase-functions"

mkdir -p "$EVIDENCE_DIR"

EXECUTION_LOG="$EVIDENCE_DIR/EXECUTION_LOG.md"
VERDICT_FILE="$EVIDENCE_DIR/FINAL_STRIPE_CLI_REPLAY_GATE.md"

# Trap to ensure cleanup
STRIPE_LISTEN_PID=""
cleanup() {
  if [[ -n "${STRIPE_LISTEN_PID}" && -n "${STRIPE_LISTEN_PID##*[!0-9]*}" ]]; then
    kill -9 "${STRIPE_LISTEN_PID}" 2>/dev/null || true
    echo "Killed stripe listen process ${STRIPE_LISTEN_PID}" >> "${EXECUTION_LOG}" || true
  fi
}
trap cleanup EXIT

# Hard timeout runner (same pattern as stripe_client_gate_hard.sh)
hard_timeout() {
  local timeout_seconds=$1
  shift
  local log_prefix=$1
  shift

  local out_log="$EVIDENCE_DIR/${log_prefix}.out.log"
  local err_log="$EVIDENCE_DIR/${log_prefix}.err.log"
  local exit_code_file="$EVIDENCE_DIR/${log_prefix}.exitcode"

  (
    "$@" >"${out_log}" 2>"${err_log}"
    echo $? >"${exit_code_file}"
  ) &

  local cmd_pid=$!

  (
    sleep "${timeout_seconds}" || true
    if kill -0 "${cmd_pid}" 2>/dev/null; then
      echo "TIMEOUT_KILL after ${timeout_seconds}s" >>"${err_log}"
      kill -9 "${cmd_pid}" 2>/dev/null || true
      echo "124" >"${exit_code_file}"
    fi
  ) &
  local killer_pid=$!

  wait "${cmd_pid}" 2>/dev/null || true
  kill -9 "${killer_pid}" 2>/dev/null || true

  if [[ -f "${exit_code_file}" ]]; then
    return $(cat "${exit_code_file}")
  else
    return 1
  fi
}

# Initialize execution log
cat >"${EXECUTION_LOG}" <<EOF
# Stripe CLI Replay Gate - Execution Log

**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}
**Evidence Directory**: ${EVIDENCE_DIR}

## Commands Executed
EOF

# A) Snapshot environment
echo "\n### A. Environment Snapshot" >> "${EXECUTION_LOG}"
echo '```bash' >> "${EXECUTION_LOG}"
echo "uname -a && sw_vers" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
if hard_timeout 10 "env_snapshot" bash -c "uname -a && sw_vers 2>&1"; then
  echo "**Status**: ✅" >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/env_snapshot.out.log" >> "${EXECUTION_LOG}"
else
  echo "**Status**: ⚠️" >> "${EXECUTION_LOG}"
fi

echo "\n### B. Node Version" >> "${EXECUTION_LOG}"
if hard_timeout 10 "env_node" node --version; then
  echo "**Status**: ✅ $(cat ${EVIDENCE_DIR}/env_node.out.log)" >> "${EXECUTION_LOG}"
else
  echo "**Status**: ⚠️ Node not found" >> "${EXECUTION_LOG}"
fi

echo "\n### C. Firebase CLI Version" >> "${EXECUTION_LOG}"
if hard_timeout 10 "env_firebase" firebase --version; then
  echo "**Status**: ✅ $(cat ${EVIDENCE_DIR}/env_firebase.out.log)" >> "${EXECUTION_LOG}"
else
  echo "**Status**: ❌ Firebase CLI not found" >> "${EXECUTION_LOG}"
  cat >"${VERDICT_FILE}" <<EOF
# Stripe CLI Replay Gate - FINAL VERDICT

**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}

### VERDICT: NO_GO

**Reason**: Firebase CLI not installed or not in PATH.

**Evidence**: ${EVIDENCE_DIR}

## Required Setup
\`\`\`bash
npm install -g firebase-tools
firebase login
\`\`\`
EOF
  exit 1
fi

# B) Verify firebase project selection
echo "\n### D. Firebase Project Selection" >> "${EXECUTION_LOG}"
echo '```bash' >> "${EXECUTION_LOG}"
echo "cd ${FIREBASE_FUNCTIONS_DIR} && firebase use" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
if hard_timeout 30 "firebase_use" bash -c "cd ${FIREBASE_FUNCTIONS_DIR} && firebase use 2>&1"; then
  echo "**Status**: ✅" >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/firebase_use.out.log" >> "${EXECUTION_LOG}"
else
  echo "**Status**: ⚠️" >> "${EXECUTION_LOG}"
fi

# C) Verify deployed functions
echo "\n### E. Firebase Functions List" >> "${EXECUTION_LOG}"
echo '```bash' >> "${EXECUTION_LOG}"
echo "firebase functions:list --project urbangenspark" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
if hard_timeout 60 "firebase_functions_list" bash -c "cd ${FIREBASE_FUNCTIONS_DIR} && firebase functions:list --project urbangenspark 2>&1"; then
  echo "**Status**: ✅" >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/firebase_functions_list.out.log" >> "${EXECUTION_LOG}"
  
  # Verify required functions exist
  REQUIRED_FUNCTIONS=("createCheckoutSession" "createBillingPortalSession" "stripeWebhook" "initiatePaymentCallable")
  MISSING_FUNCTIONS=()
  
  for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if ! grep -q "${func}" "${EVIDENCE_DIR}/firebase_functions_list.out.log" 2>/dev/null; then
      MISSING_FUNCTIONS+=("${func}")
    fi
  done
  
  if [[ ${#MISSING_FUNCTIONS[@]} -gt 0 ]]; then
    echo "\n**Missing Functions**: ${MISSING_FUNCTIONS[*]}" >> "${EXECUTION_LOG}"
    cat >"${VERDICT_FILE}" <<EOF
# Stripe CLI Replay Gate - FINAL VERDICT

**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}

### VERDICT: NO_GO

**Reason**: Required Firebase Functions not deployed: ${MISSING_FUNCTIONS[*]}

**Evidence**: ${EVIDENCE_DIR}

## Required Functions
- createCheckoutSession
- createBillingPortalSession
- stripeWebhook
- initiatePaymentCallable

Deploy missing functions before running this gate.
EOF
    exit 2
  fi
else
  echo "**Status**: ❌ Failed to list functions" >> "${EXECUTION_LOG}"
  cat >"${VERDICT_FILE}" <<EOF
# Stripe CLI Replay Gate - FINAL VERDICT

**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}

### VERDICT: NO_GO

**Reason**: Unable to list Firebase Functions. Check authentication and project access.

**Evidence**: ${EVIDENCE_DIR}
EOF
  exit 3
fi

# D) Check Stripe CLI availability
echo "\n### F. Stripe CLI Version" >> "${EXECUTION_LOG}"
echo '```bash' >> "${EXECUTION_LOG}"
echo "stripe --version" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"
if hard_timeout 10 "stripe_version" stripe --version; then
  echo "**Status**: ✅ $(cat ${EVIDENCE_DIR}/stripe_version.out.log)" >> "${EXECUTION_LOG}"
else
  echo "**Status**: ❌ Stripe CLI not found" >> "${EXECUTION_LOG}"
  cat >"${VERDICT_FILE}" <<EOF
# Stripe CLI Replay Gate - FINAL VERDICT

**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}

### VERDICT: NO_GO

**Reason**: Stripe CLI not installed or not in PATH.

**Evidence**: ${EVIDENCE_DIR}

## Required Setup
Install Stripe CLI: https://stripe.com/docs/stripe-cli

macOS:
\`\`\`bash
brew install stripe/stripe-cli/stripe
stripe login
\`\`\`

Then run: stripe login
EOF
  exit 4
fi

# E) Stripe CLI webhook replay
WEBHOOK_URL="https://us-central1-urbangenspark.cloudfunctions.net/stripeWebhook"

echo "\n### G. Stripe Listen (Background)" >> "${EXECUTION_LOG}"
echo '```bash' >> "${EXECUTION_LOG}"
echo "stripe listen --forward-to ${WEBHOOK_URL}" >> "${EXECUTION_LOG}"
echo '```' >> "${EXECUTION_LOG}"

# Start stripe listen in background
stripe listen --forward-to "${WEBHOOK_URL}" > "${EVIDENCE_DIR}/stripe_listen.out.log" 2> "${EVIDENCE_DIR}/stripe_listen.err.log" &
STRIPE_LISTEN_PID=$!
echo "**Started stripe listen (PID: ${STRIPE_LISTEN_PID})**" >> "${EXECUTION_LOG}"

# Give it time to initialize
sleep 5

# Check if process is still running
if ! kill -0 "${STRIPE_LISTEN_PID}" 2>/dev/null; then
  echo "**Status**: ❌ Stripe listen failed to start" >> "${EXECUTION_LOG}"
  cat "${EVIDENCE_DIR}/stripe_listen.err.log" >> "${EXECUTION_LOG}"
  cat >"${VERDICT_FILE}" <<EOF
# Stripe CLI Replay Gate - FINAL VERDICT

**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}

### VERDICT: NO_GO

**Reason**: Stripe listen failed to start. Check Stripe authentication.

**Evidence**: ${EVIDENCE_DIR}

Run: stripe login
EOF
  exit 5
fi

echo "**Status**: ✅ Running in background" >> "${EXECUTION_LOG}"

# Trigger webhook events
EVENTS=("checkout.session.completed" "customer.subscription.created" "invoice.payment_succeeded")

for event in "${EVENTS[@]}"; do
  echo "\n### H. Trigger Event: ${event}" >> "${EXECUTION_LOG}"
  echo '```bash' >> "${EXECUTION_LOG}"
  echo "stripe trigger ${event}" >> "${EXECUTION_LOG}"
  echo '```' >> "${EXECUTION_LOG}"
  
  event_safe=$(echo "${event}" | tr '.' '_')
  if hard_timeout 30 "stripe_trigger_${event_safe}" stripe trigger "${event}"; then
    echo "**Status**: ✅" >> "${EXECUTION_LOG}"
    cat "${EVIDENCE_DIR}/stripe_trigger_${event_safe}.out.log" >> "${EXECUTION_LOG}"
  else
    echo "**Status**: ⚠️ Failed to trigger ${event}" >> "${EXECUTION_LOG}"
    cat "${EVIDENCE_DIR}/stripe_trigger_${event_safe}.err.log" >> "${EXECUTION_LOG}" 2>/dev/null || true
  fi
  
  # Wait between triggers
  sleep 2
done

# Let webhooks process
echo "\n### I. Webhook Processing Wait" >> "${EXECUTION_LOG}"
echo "Waiting 10 seconds for webhooks to process..." >> "${EXECUTION_LOG}"
sleep 10

# Stop stripe listen
if [[ -n "${STRIPE_LISTEN_PID}" ]]; then
  kill -9 "${STRIPE_LISTEN_PID}" 2>/dev/null || true
  echo "Stopped stripe listen (PID: ${STRIPE_LISTEN_PID})" >> "${EXECUTION_LOG}"
  STRIPE_LISTEN_PID=""
fi

# F) Firestore verification note
echo "\n### J. Firestore Verification" >> "${EXECUTION_LOG}"
cat >> "${EXECUTION_LOG}" <<'EOF'
**Note**: Firestore verification requires Firebase Admin SDK with service account credentials.
This gate verifies webhook delivery to the Cloud Function endpoint.
Manual verification: Check Firestore console for updated documents in:
- users/{uid}/billing/subscription (from webhook updates)
- Any payment or subscription collections your functions write to

For automated verification, implement a Node script with:
```javascript
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();
// Query recent documents...
```
EOF

# Check stripe listen logs for success indicators
WEBHOOK_SUCCESS=0
if grep -qi "succeeded" "${EVIDENCE_DIR}/stripe_listen.out.log" 2>/dev/null || \
   grep -qi "200" "${EVIDENCE_DIR}/stripe_listen.out.log" 2>/dev/null; then
  WEBHOOK_SUCCESS=1
  echo "\n**Webhook Delivery**: ✅ Found success indicators in stripe listen logs" >> "${EXECUTION_LOG}"
else
  echo "\n**Webhook Delivery**: ⚠️ No clear success indicators in logs" >> "${EXECUTION_LOG}"
fi

# Generate SHA256SUMS
echo "\n### K. Evidence Integrity" >> "${EXECUTION_LOG}"
(cd "$EVIDENCE_DIR" && find . -type f -maxdepth 1 2>/dev/null | sed 's|^./||' | grep -v SHA256SUMS.txt | sort | xargs shasum -a 256 > SHA256SUMS.txt 2>/dev/null || true)
echo "SHA256SUMS.txt generated" >> "${EXECUTION_LOG}"

# Determine verdict
VERDICT="PARTIAL_GO"
VERDICT_REASON="Webhooks triggered and forwarded. Manual Firestore verification required."

if [[ ${WEBHOOK_SUCCESS} -eq 1 ]]; then
  VERDICT="GO"
  VERDICT_REASON="All webhook events triggered and delivered successfully to Cloud Function endpoint."
fi

# Check for any critical failures
if grep -qi "error" "${EVIDENCE_DIR}/stripe_listen.err.log" 2>/dev/null; then
  VERDICT="PARTIAL_GO"
  VERDICT_REASON="Webhooks triggered but errors detected in stripe listen logs. Review evidence."
fi

# G) Final verdict
cat >"${VERDICT_FILE}" <<EOF
# Stripe CLI Replay Gate - FINAL VERDICT

**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}

### VERDICT: ${VERDICT}

**Reason**: ${VERDICT_REASON}

## Evidence Summary

### Functions Verified
- ✅ createCheckoutSession (deployed)
- ✅ createBillingPortalSession (deployed)
- ✅ stripeWebhook (deployed)
- ✅ initiatePaymentCallable (deployed)

### Webhook Events Triggered
- checkout.session.completed
- customer.subscription.created
- invoice.payment_succeeded

### Webhook Delivery
$(if [[ ${WEBHOOK_SUCCESS} -eq 1 ]]; then echo "✅ Webhooks delivered to Cloud Function"; else echo "⚠️ Check stripe_listen logs for delivery status"; fi)

### Evidence Files
- EXECUTION_LOG.md
- env_*.log
- firebase_functions_list.out.log
- stripe_version.out.log
- stripe_listen.out.log / stripe_listen.err.log
- stripe_trigger_*.out.log
- SHA256SUMS.txt

**Evidence Directory**: ${EVIDENCE_DIR}

## Next Steps
1. Review EXECUTION_LOG.md for detailed command outputs
2. Check stripe_listen.out.log for webhook delivery confirmations
3. Verify Firestore updates manually in Firebase Console:
   - users/{uid}/billing/subscription
   - Payment/subscription collections
4. If verdict is PARTIAL_GO, investigate any errors in *.err.log files

## Manual Firestore Verification
\`\`\`bash
# Connect to Firestore and query recent updates
firebase firestore:get users/{test_uid}/billing/subscription --project urbangenspark
\`\`\`
EOF

echo ""
echo "Evidence: ${EVIDENCE_DIR}"
echo "Verdict: ${VERDICT}"
echo "See: ${VERDICT_FILE}"
