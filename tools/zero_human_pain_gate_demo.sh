#!/usr/bin/env bash
# ZERO_HUMAN_PAIN_GATE_DEMO - NOT FOR PRODUCTION
# 
# This is a DEMO ONLY script:
# - Does NOT connect to Firebase Emulator or real project
# - Simulates test results deterministically
# - Outputs "DEMO_ONLY ✅" verdict (NOT "GO")
# - Perfect for CI/CD smoke testing and training
# - NEVER should be mistaken for production gate

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TS="$(date -u +"%Y%m%dT%H%M%SZ")"
EVIDENCE_ROOT="$REPO_ROOT/docs/evidence/zero_human_pain_gate"
EVIDENCE_DIR="$EVIDENCE_ROOT/$TS"

mkdir -p "$EVIDENCE_DIR"

log_file="$EVIDENCE_DIR/demo_orchestrator.log"
exec 1> >(tee -a "$log_file")
exec 2>&1

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        ZERO_HUMAN_PAIN_GATE_DEMO (NOT PRODUCTION)           ║"
echo "║         This is a deterministic simulation only.            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Timestamp: $TS"
echo "Evidence: $EVIDENCE_DIR"
echo ""

# Simulate backend pain test
{
  echo "Running simulated backend pain test..."
  sleep 0.5
  
  echo "✅ User creation: 145ms"
  echo "✅ Offer creation: 312ms"
  echo "✅ QR token generation (30s delay): 1250ms"
  echo "✅ QR token generation (60s delay): 1180ms"
  echo "✅ QR token generation (90s delay): 1220ms"
  echo "✅ Redemption validation: 890ms"
  echo "✅ Balance verification: 210ms"
  echo ""
  echo "Backend Result: PASS ✅"
} > "$EVIDENCE_DIR/backend_pain_test_demo.log"

# Simulate mobile customer app test
{
  echo "Running simulated customer app pain test..."
  sleep 0.3
  
  echo "✅ App startup: 1245ms"
  echo "✅ Navigation to offers: 890ms"
  echo "✅ Offer list load: 1050ms"
  echo "✅ Offer detail load: 450ms"
  echo "✅ QR generation: 2100ms"
  echo "✅ All screens < 10s: PASS ✅"
  echo ""
  echo "Customer App Result: PASS ✅"
} > "$EVIDENCE_DIR/flutter_customer_pain_test_demo.log"

# Simulate mobile merchant app test
{
  echo "Running simulated merchant app pain test..."
  sleep 0.3
  
  echo "✅ App startup: 1180ms"
  echo "✅ Navigation to offers: 750ms"
  echo "✅ Create offer form: 620ms"
  echo "✅ Offer submission: 1840ms"
  echo "✅ QR scanner: 890ms"
  echo "✅ Analytics dashboard: 1540ms"
  echo "✅ All screens < 10s: PASS ✅"
  echo ""
  echo "Merchant App Result: PASS ✅"
} > "$EVIDENCE_DIR/flutter_merchant_pain_test_demo.log"

# Collect metrics
{
  echo "{"
  echo "  \"demo_mode\": true,"
  echo "  \"backend\": {"
  echo "    \"user_creation_ms\": 145,"
  echo "    \"offer_creation_ms\": 312,"
  echo "    \"qr_token_30s_ms\": 1250,"
  echo "    \"qr_token_60s_ms\": 1180,"
  echo "    \"qr_token_90s_ms\": 1220,"
  echo "    \"redemption_validation_ms\": 890,"
  echo "    \"balance_check_ms\": 210"
  echo "  },"
  echo "  \"mobile_customer\": {"
  echo "    \"startup_ms\": 1245,"
  echo "    \"offers_nav_ms\": 890,"
  echo "    \"list_load_ms\": 1050,"
  echo "    \"detail_load_ms\": 450,"
  echo "    \"qr_gen_ms\": 2100"
  echo "  },"
  echo "  \"mobile_merchant\": {"
  echo "    \"startup_ms\": 1180,"
  echo "    \"offers_nav_ms\": 750,"
  echo "    \"form_ms\": 620,"
  echo "    \"submit_ms\": 1840,"
  echo "    \"scanner_ms\": 890,"
  echo "    \"analytics_ms\": 1540"
  echo "  }"
  echo "}"
} > "$EVIDENCE_DIR/metrics_demo.json"

# Final verdict: DEMO_ONLY (NOT GO)
{
  echo "# ZERO_HUMAN_PAIN_GATE Demo Verdict"
  echo ""
  echo "**VERDICT: DEMO_ONLY ✅**"
  echo ""
  echo "> This is a DEMO ONLY verdict. It does not represent production readiness."
  echo "> No Firebase Emulator or real project was involved."
  echo "> Results are simulated and deterministic."
  echo ""
  echo "Timestamp: $TS"
  echo ""
  echo "## Simulated Test Results"
  echo ""
  echo "✅ Backend pain test: PASS (simulated)"
  echo "✅ Customer app pain test: PASS (simulated)"
  echo "✅ Merchant app pain test: PASS (simulated)"
  echo ""
  echo "## To run PRODUCTION gate:"
  echo ""
  echo "**With Firebase Emulator (Recommended):**"
  echo "\`\`\`bash"
  echo "firebase emulators:start --only firestore,functions,auth"
  echo "# In another terminal:"
  echo "bash tools/run_zero_human_pain_gate_wrapper.sh"
  echo "\`\`\`"
  echo ""
  echo "**With Real Firebase (CI/CD):**"
  echo "\`\`\`bash"
  echo "export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json"
  echo "bash tools/run_zero_human_pain_gate_wrapper.sh"
  echo "\`\`\`"
  echo ""
} > "$EVIDENCE_DIR/VERDICT_DEMO.md"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    DEMO VERDICT                            ║"
echo "║                  DEMO_ONLY ✅                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# SHA256SUMS
echo "Generating SHA256SUMS..."
(
  cd "$EVIDENCE_DIR" || exit
  find . -type f ! -name SHA256SUMS.txt -print0 | sort -z | xargs -0 shasum -a 256 > SHA256SUMS.txt
  echo "✅ SHA256SUMS generated"
)

echo ""
echo "Evidence folder: $EVIDENCE_DIR"
echo "Verdict file: VERDICT_DEMO.md"
echo ""
echo "⚠️  This demo verdict is NOT for production decisions."
echo "    Run production gate with Firebase Emulator or real auth."
echo ""

exit 0

echo "▶ PHASE 1: Backend Pain Test"
echo "✅ PASS"
echo ""

echo "▶ PHASE 2: Mobile Pain Test - Customer App"
echo "✅ PASS"
echo ""

echo "▶ PHASE 3: Mobile Pain Test - Merchant App"
echo "✅ PASS"
echo ""

echo "▶ PHASE 4: Analyzing Results"
echo "✅ All tests PASS"
echo ""

# SHA256SUMS
(
  cd "$EVIDENCE_DIR" || exit
  find . -type f -print0 | sort -z | xargs -0 shasum -a 256 > SHA256SUMS.txt
)

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    FINAL VERDICT                           ║"
echo "║                  $VERDICT ✅                                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "Evidence folder: $EVIDENCE_DIR"
echo ""
grep "VERDICT:" "$EVIDENCE_DIR/ZERO_HUMAN_PAIN_GATE_VERDICT.md"
echo ""

exit "$EXIT_CODE"
