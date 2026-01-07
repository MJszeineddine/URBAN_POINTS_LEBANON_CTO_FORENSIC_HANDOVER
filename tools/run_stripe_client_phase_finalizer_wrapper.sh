#!/usr/bin/env bash
# Wrapper to run stripe_client_phase_finalizer.sh in background-safe mode

set -euo pipefail

PROJECT_ROOT="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER"
SCRIPT_PATH="$PROJECT_ROOT/tools/stripe_client_phase_finalizer.sh"
EVIDENCE_ROOT="$PROJECT_ROOT/docs/evidence/production_gate"
DEADLINE_SECONDS=900
POLL_INTERVAL=2

chmod +x "$SCRIPT_PATH" 2>/dev/null || true

"$SCRIPT_PATH" > /dev/null 2>&1 &
PID=$!

START=$(date +%s)
FOUND=""

echo "Running stripe client phase finalizer (PID: ${PID})"

while true; do
  NOW=$(date +%s)
  if (( NOW - START > DEADLINE_SECONDS )); then
    echo "Deadline exceeded (${DEADLINE_SECONDS}s). Killing finalizer." && kill -9 ${PID} 2>/dev/null || true
    exit 1
  fi

  FOUND=$(find "$EVIDENCE_ROOT" -type f -name 'FINAL_STRIPE_CLIENT_PHASE.md' -mmin -5 2>/dev/null | sort | tail -1)
  if [[ -n "$FOUND" ]]; then
    echo "Final report found: ${FOUND}"
    head -40 "$FOUND"
    if grep -q "VERDICT: GO" "$FOUND"; then
      exit 0
    else
      exit 2
    fi
  fi

  if ! kill -0 ${PID} 2>/dev/null; then
    # Process ended; try to find any report
    FOUND=$(find "$EVIDENCE_ROOT" -type f -name 'FINAL_STRIPE_CLIENT_PHASE.md' 2>/dev/null | sort | tail -1)
    if [[ -n "$FOUND" ]]; then
      echo "Final report found: ${FOUND}"
      head -40 "$FOUND"
      if grep -q "VERDICT: GO" "$FOUND"; then
        exit 0
      else
        exit 2
      fi
    fi
    echo "Finalizer ended but report missing." && exit 1
  fi

  sleep ${POLL_INTERVAL}
done
