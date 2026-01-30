#!/usr/bin/env bash
# Wrapper to run stripe_client_gate_hard.sh in background-safe mode

set -euo pipefail

GATE_SCRIPT="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/tools/stripe_client_gate_hard.sh"
DEADLINE_SECONDS=900
POLL_INTERVAL=2
EVIDENCE_ROOT="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/docs/evidence/production_gate"

"${GATE_SCRIPT}" > /dev/null 2>&1 &
GATE_PID=$!

START_TIME=$(date +%s)
VERDICT_FILE=""

echo "Running stripe client gate (PID: ${GATE_PID})"

while true; do
  CURRENT_TIME=$(date +%s)
  if (( CURRENT_TIME - START_TIME > DEADLINE_SECONDS )); then
    echo "Deadline exceeded (${DEADLINE_SECONDS}s). Killing gate." && kill -9 ${GATE_PID} 2>/dev/null || true
    exit 1
  fi

  VERDICT_FILE=$(find "${EVIDENCE_ROOT}" -name "FINAL_STRIPE_CLIENT_GATE.md" -mmin -5 2>/dev/null | sort | tail -1)
  if [[ -n "${VERDICT_FILE}" ]]; then
    echo "Verdict file found: ${VERDICT_FILE}"
    head -20 "${VERDICT_FILE}"
    exit 0
  fi

  if ! kill -0 ${GATE_PID} 2>/dev/null; then
    # process ended without verdict
    VERDICT_FILE=$(find "${EVIDENCE_ROOT}" -name "FINAL_STRIPE_CLIENT_GATE.md" 2>/dev/null | sort | tail -1)
    if [[ -n "${VERDICT_FILE}" ]]; then
      head -20 "${VERDICT_FILE}"
      exit 0
    fi
    echo "Gate process ended but verdict file missing." && exit 1
  fi

  sleep ${POLL_INTERVAL}
done
