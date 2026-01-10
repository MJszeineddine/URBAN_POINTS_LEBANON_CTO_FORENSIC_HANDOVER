#!/usr/bin/env bash
# Stripe Phase Gate Wrapper - Polling Executor
# Runs stripe_phase_gate_hard.sh in background, polls for verdict file
# Based on proven run_prod_gate_wrapper.sh pattern

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

GATE_SCRIPT="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/tools/stripe_phase_gate_hard.sh"
DEADLINE_SECONDS=720  # 12 minutes (Stripe deploy should be faster than full functions deploy)
POLL_INTERVAL=2       # Check every 2 seconds

# ============================================================================
# EXECUTION
# ============================================================================

echo "============================================================================"
echo "STRIPE PHASE DEPLOYMENT GATE - WRAPPER START"
echo "============================================================================"
echo ""
echo "Gate Script: ${GATE_SCRIPT}"
echo "Deadline: ${DEADLINE_SECONDS}s"
echo "Poll Interval: ${POLL_INTERVAL}s"
echo ""

# Launch gate script in background with full output redirection
"${GATE_SCRIPT}" > /dev/null 2>&1 &
GATE_PID=$!

echo "Gate PID: ${GATE_PID}"
echo "Polling for verdict file..."
echo ""

# Poll for verdict file
START_TIME=$(date +%s)
VERDICT_FOUND=0

while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  
  if [[ ${ELAPSED} -ge ${DEADLINE_SECONDS} ]]; then
    echo "⏰ DEADLINE EXCEEDED (${DEADLINE_SECONDS}s)"
    echo "Killing gate process ${GATE_PID}..."
    kill -9 ${GATE_PID} 2>/dev/null || true
    echo ""
    echo "❌ Gate did not complete within deadline"
    exit 1
  fi
  
  # Look for verdict file in evidence directory
  VERDICT_FILE=$(find /Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/docs/evidence/production_gate -name "FINAL_STRIPE_GATE.md" -type f 2>/dev/null | head -1)
  
  if [[ -n "${VERDICT_FILE}" ]] && [[ -f "${VERDICT_FILE}" ]]; then
    VERDICT_FOUND=1
    break
  fi
  
  # Check if gate process still running
  if ! kill -0 ${GATE_PID} 2>/dev/null; then
    # Process finished, but no verdict file found (should not happen)
    echo "⚠️  Gate process finished but no verdict file found"
    sleep 2  # Wait a moment for file system sync
    VERDICT_FILE=$(find /Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/docs/evidence/production_gate -name "FINAL_STRIPE_GATE.md" -type f 2>/dev/null | head -1)
    if [[ -n "${VERDICT_FILE}" ]] && [[ -f "${VERDICT_FILE}" ]]; then
      VERDICT_FOUND=1
      break
    else
      echo "❌ Gate completed but no verdict file generated"
      exit 1
    fi
  fi
  
  sleep ${POLL_INTERVAL}
done

# ============================================================================
# VERDICT DISPLAY
# ============================================================================

if [[ ${VERDICT_FOUND} -eq 1 ]]; then
  echo "✅ Verdict file found: ${VERDICT_FILE}"
  echo ""
  echo "--- VERDICT (First 20 lines) ---"
  head -20 "${VERDICT_FILE}"
  echo ""
  echo "--- VERDICT (Last 5 lines) ---"
  tail -5 "${VERDICT_FILE}"
  echo ""
  
  # Determine pass/fail
  if grep -q "VERDICT: GO" "${VERDICT_FILE}"; then
    echo "============================================================================"
    echo "✅ STRIPE PHASE DEPLOYMENT GATE: PASSED"
    echo "============================================================================"
    exit 0
  else
    echo "============================================================================"
    echo "❌ STRIPE PHASE DEPLOYMENT GATE: FAILED"
    echo "============================================================================"
    exit 1
  fi
else
  echo "❌ No verdict file found"
  exit 1
fi
