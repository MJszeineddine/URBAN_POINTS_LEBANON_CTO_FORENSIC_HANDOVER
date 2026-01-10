#!/usr/bin/env bash
# Wrapper to run stripe_cli_replay_gate_hard.sh in background-safe mode

set -euo pipefail

PROJECT_ROOT="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER"
GATE_SCRIPT="${PROJECT_ROOT}/tools/stripe_cli_replay_gate_hard.sh"
EVIDENCE_ROOT="${PROJECT_ROOT}/docs/evidence/production_gate"
DEADLINE_SECONDS=600  # 10 minutes
POLL_INTERVAL=3

chmod +x "$GATE_SCRIPT" 2>/dev/null || true

"${GATE_SCRIPT}" > /dev/null 2>&1 &
GATE_PID=$!

START_TIME=$(date +%s)
VERDICT_FILE=""

echo "Running Stripe CLI replay gate (PID: ${GATE_PID})"

while true; do
  CURRENT_TIME=$(date +%s)
  if (( CURRENT_TIME - START_TIME > DEADLINE_SECONDS )); then
    echo "Deadline exceeded (${DEADLINE_SECONDS}s). Killing gate." && kill -9 ${GATE_PID} 2>/dev/null || true
    exit 1
  fi

  VERDICT_FILE=$(find "${EVIDENCE_ROOT}" -name "FINAL_STRIPE_CLI_REPLAY_GATE.md" -mmin -5 2>/dev/null | sort | tail -1)
  if [[ -n "${VERDICT_FILE}" ]]; then
    echo ""
    echo "==================================================================="
    echo "Verdict file found: ${VERDICT_FILE}"
    echo "==================================================================="
    echo ""
    head -60 "${VERDICT_FILE}"
    echo ""
    echo "==================================================================="
    
    if grep -q "VERDICT: GO" "${VERDICT_FILE}"; then
      echo "✅ VERDICT: GO"
      exit 0
    elif grep -q "VERDICT: PARTIAL_GO" "${VERDICT_FILE}"; then
      echo "⚠️  VERDICT: PARTIAL_GO (manual verification required)"
      exit 0
    else
      echo "❌ VERDICT: NO_GO"
      exit 2
    fi
  fi

  if ! kill -0 ${GATE_PID} 2>/dev/null; then
    # Process ended without verdict
    VERDICT_FILE=$(find "${EVIDENCE_ROOT}" -name "FINAL_STRIPE_CLI_REPLAY_GATE.md" 2>/dev/null | sort | tail -1)
    if [[ -n "${VERDICT_FILE}" ]]; then
      echo ""
      echo "Verdict file found: ${VERDICT_FILE}"
      head -60 "${VERDICT_FILE}"
      
      if grep -q "VERDICT: GO" "${VERDICT_FILE}"; then
        exit 0
      elif grep -q "VERDICT: PARTIAL_GO" "${VERDICT_FILE}"; then
        exit 0
      else
        exit 2
      fi
    fi
    echo "Gate process ended but verdict file missing." && exit 1
  fi

  sleep ${POLL_INTERVAL}
done
