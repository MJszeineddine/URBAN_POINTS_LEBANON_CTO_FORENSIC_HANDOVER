#!/usr/bin/env bash
# Stripe Client Phase Finalizer - Non-PTY, evidence-first

set -euo pipefail

# Repo root
PROJECT_ROOT="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER"
cd "$PROJECT_ROOT"

UTC_TS=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
FINAL_REPORT_DIR="$PROJECT_ROOT/docs/evidence/production_gate/${UTC_TS}/stripe_client_phase_final_report"
mkdir -p "$FINAL_REPORT_DIR"

FINAL_SUMMARY_MD="$FINAL_REPORT_DIR/FINAL_STRIPE_CLIENT_PHASE.md"

# Locate latest gate evidence (stripe_client_phase_gate)
LATEST_FINAL=$(ls -1dt "$PROJECT_ROOT"/docs/evidence/production_gate/*/stripe_client_phase_gate/FINAL_STRIPE_CLIENT_GATE.md 2>/dev/null | head -1 || true)

if [[ -z "${LATEST_FINAL}" || ! -f "${LATEST_FINAL}" ]]; then
  cat >"$FINAL_SUMMARY_MD" <<EOF
# Stripe Client Phase - Final Report

**Timestamp**: ${UTC_TS}
**Gate**: stripe_client_phase_final_report

### VERDICT: NO GO

- Reason: No prior stripe_client_phase_gate evidence found.
- Evidence directory: ${FINAL_REPORT_DIR}
EOF
  # integrity
  (cd "$FINAL_REPORT_DIR" && shasum -a 256 * > SHA256SUMS.txt 2>/dev/null || true)
  exit 1
fi

LATEST_GATE_DIR=$(dirname "${LATEST_FINAL}")
LATEST_PARENT_DIR=$(dirname "${LATEST_GATE_DIR}")

# Verify latest gate has GO
if ! grep -q "^### VERDICT: GO" "${LATEST_FINAL}"; then
  cat >"$FINAL_SUMMARY_MD" <<EOF
# Stripe Client Phase - Final Report

**Timestamp**: ${UTC_TS}
**Gate**: stripe_client_phase_final_report

### VERDICT: NO GO

- Reason: Latest gate verdict is not GO.
- Latest gate: ${LATEST_GATE_DIR}
- Evidence directory: ${FINAL_REPORT_DIR}
EOF
  # Copy primary files for reference
  cp -f "${LATEST_GATE_DIR}/FINAL_STRIPE_CLIENT_GATE.md" "$FINAL_REPORT_DIR/" 2>/dev/null || true
  cp -f "${LATEST_GATE_DIR}/EXECUTION_LOG.md" "$FINAL_REPORT_DIR/" 2>/dev/null || true
  (cd "$FINAL_REPORT_DIR" && shasum -a 256 * > SHA256SUMS.txt 2>/dev/null || true)
  exit 2
fi

# Extract quotes
VERDICT_QUOTES=$(grep -E 'VERDICT:|customer flutter analyze errors|merchant flutter analyze errors' "${LATEST_FINAL}" || true)
CUST_ERRORS_TAIL=$(tail -n 50 "${LATEST_GATE_DIR}/customer_analyze.out.log" 2>/dev/null | grep 'error •' || true)
MERCH_ERRORS_TAIL=$(tail -n 50 "${LATEST_GATE_DIR}/merchant_analyze.out.log" 2>/dev/null | grep 'error •' || true)
LOG_TS=$(grep -E '^\*\*Timestamp\*\*:' "${LATEST_GATE_DIR}/EXECUTION_LOG.md" | head -1 || true)
LOG_FLUTTER=$(grep -E '^Flutter ' "${LATEST_GATE_DIR}/EXECUTION_LOG.md" | head -1 || true)

# Create Manual QA doc
QA_DOC_PATH="$PROJECT_ROOT/docs/STRIPE_CLIENT_MANUAL_QA.md"
cat >"$QA_DOC_PATH" <<'EOF'
# Stripe Client Manual QA

## Preconditions
- Signed in with a valid test user
- Reliable internet connection
- Backend deployed; Stripe products/prices configured and mapped in Functions

## Customer App Flow
- Navigate: Settings → Billing
- Tap: Subscribe
- Expected: External browser opens Stripe Checkout
- Complete the checkout, then return to the app
- App listens to Firestore `users/{uid}/billing/subscription` and updates status automatically

## Merchant App Flow
- Navigate: Profile/Settings → Billing
- Tap: Manage Billing
- Expected: External browser opens Stripe Customer Portal
- Return to the app; billing status updates from Firestore stream

## Success Criteria
- Status shows Active
- Next renewal date appears if available

## Troubleshooting
- If status doesn’t update immediately, wait 30–90s (webhook processing)
- Tap Refresh on the Billing screen to re-pull state
EOF

# Determine quick locate paths (static paths; line numbers best-effort from repository state)
CUST_ROUTE_PATH="source/apps/mobile-customer/lib/main.dart#L66"
CUST_SETTINGS_ENTRY="source/apps/mobile-customer/lib/screens/settings_screen.dart#L97"
MERCH_ROUTE_PATH="source/apps/mobile-merchant/lib/main.dart#L64"
MERCH_PROFILE_ENTRY="source/apps/mobile-merchant/lib/main.dart#L1137"

# Create root proof report
ROOT_PROOF_PATH="$PROJECT_ROOT/PROOF_STRIPE_CLIENT_PHASE.md"
cat >"$ROOT_PROOF_PATH" <<EOF
# Stripe Client Phase — Final Proof

**Verdict**: GO ✅
**Latest Gate Evidence**: ${LATEST_GATE_DIR}

## Quotes

> From FINAL_STRIPE_CLIENT_GATE.md

${VERDICT_QUOTES}

> From customer_analyze.out.log (tail | grep 'error •')

${CUST_ERRORS_TAIL:-"<no matches>"}

> From merchant_analyze.out.log (tail | grep 'error •')

${MERCH_ERRORS_TAIL:-"<no matches>"}

> From EXECUTION_LOG.md

${LOG_TS}
${LOG_FLUTTER}

## Client Deliverables Shipped
- services: source/apps/mobile-customer/lib/services/stripe_client.dart
- services: source/apps/mobile-customer/lib/services/billing_state.dart
- screen:   source/apps/mobile-customer/lib/screens/billing/billing_screen.dart
- services: source/apps/mobile-merchant/lib/services/stripe_client.dart
- services: source/apps/mobile-merchant/lib/services/billing_state.dart
- screen:   source/apps/mobile-merchant/lib/screens/billing/billing_screen.dart
- deps:     url_launcher declared in both apps' pubspec.yaml
- tools:    tools/stripe_client_gate_hard.sh and tools/run_stripe_client_gate_wrapper.sh

## Quick Locate (Entry Points)
- Customer route: [${CUST_ROUTE_PATH}](${CUST_ROUTE_PATH})
- Customer settings → Billing: [${CUST_SETTINGS_ENTRY}](${CUST_SETTINGS_ENTRY})
- Merchant route: [${MERCH_ROUTE_PATH}](${MERCH_ROUTE_PATH})
- Merchant profile → Billing: [${MERCH_PROFILE_ENTRY}](${MERCH_PROFILE_ENTRY})

## How To Test
- See docs/STRIPE_CLIENT_MANUAL_QA.md for the manual QA checklist.

EOF

# Copy prior evidence into new folder
cp -f "${LATEST_GATE_DIR}/FINAL_STRIPE_CLIENT_GATE.md" "$FINAL_REPORT_DIR/" 2>/dev/null || true
cp -f "${LATEST_GATE_DIR}/EXECUTION_LOG.md" "$FINAL_REPORT_DIR/" 2>/dev/null || true
cp -f "${LATEST_GATE_DIR}/customer_analyze.out.log" "$FINAL_REPORT_DIR/" 2>/dev/null || true
cp -f "${LATEST_GATE_DIR}/merchant_analyze.out.log" "$FINAL_REPORT_DIR/" 2>/dev/null || true
cp -f "${LATEST_GATE_DIR}/SHA256SUMS.txt" "$FINAL_REPORT_DIR/" 2>/dev/null || true

# Copy new docs into evidence
cp -f "$QA_DOC_PATH" "$FINAL_REPORT_DIR/" 2>/dev/null || true
cp -f "$ROOT_PROOF_PATH" "$FINAL_REPORT_DIR/" 2>/dev/null || true

# Write final summary with GO
cat >"$FINAL_SUMMARY_MD" <<EOF
# Stripe Client Phase - Final Report

**Timestamp**: ${UTC_TS}
**Gate**: stripe_client_phase_final_report

### VERDICT: GO ✅

- Prior gate: ${LATEST_GATE_DIR}
- Finalizer evidence: ${FINAL_REPORT_DIR}

#### Key Quotes

${VERDICT_QUOTES}

customer (tail | grep 'error •'):
${CUST_ERRORS_TAIL:-"<no matches>"}

merchant (tail | grep 'error •'):
${MERCH_ERRORS_TAIL:-"<no matches>"}

${LOG_TS}
${LOG_FLUTTER}
EOF

# Integrity for final report folder
(cd "$FINAL_REPORT_DIR" && find . -type f -maxdepth 1 2>/dev/null | sed 's|^./||' | sort | xargs shasum -a 256 > SHA256SUMS.txt)

exit 0
