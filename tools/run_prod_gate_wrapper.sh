#!/bin/bash
set -euo pipefail

REPO="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER"
cd "$REPO"

echo "Starting prod_deploy_gate_hard.sh in background (non-PTY)..."

# Make executable
chmod +x tools/prod_deploy_gate_hard.sh

# Run in background with full redirection
/bin/bash tools/prod_deploy_gate_hard.sh > /dev/null 2>&1 &
GATE_PID=$!

echo "Gate PID: $GATE_PID"

# Poll for verdict file (max 12 minutes = 720 seconds)
DEADLINE=$(($(date +%s) + 720))
EVD_PATTERN="docs/evidence/production_gate/2026-*/prod_deploy_gate_hard"

while [ $(date +%s) -lt $DEADLINE ]; do
  # Find the most recent evidence folder
  EVD=$(find docs/evidence/production_gate -type d -name "prod_deploy_gate_hard" 2>/dev/null | sort -r | head -1 || echo "")
  
  if [ -n "$EVD" ] && [ -f "$EVD/FINAL_PROD_DEPLOY_GATE.md" ]; then
    echo ""
    echo "================================================"
    echo "Evidence: $EVD"
    echo "================================================"
    echo ""
    head -10 "$EVD/FINAL_PROD_DEPLOY_GATE.md"
    echo ""
    echo "Full report: $EVD/FINAL_PROD_DEPLOY_GATE.md"
    echo "================================================"
    exit 0
  fi
  
  # Check if process is still running
  if ! kill -0 "$GATE_PID" 2>/dev/null; then
    echo "Gate process terminated. Checking for evidence..."
    sleep 2
    EVD=$(find docs/evidence/production_gate -type d -name "prod_deploy_gate_hard" 2>/dev/null | sort -r | head -1 || echo "")
    if [ -n "$EVD" ] && [ -f "$EVD/FINAL_PROD_DEPLOY_GATE.md" ]; then
      echo "Evidence: $EVD"
      head -10 "$EVD/FINAL_PROD_DEPLOY_GATE.md"
      exit 0
    else
      echo "ERROR: Gate script terminated but no verdict file found."
      exit 1
    fi
  fi
  
  sleep 2
done

# Timeout - script stuck
echo "ERROR: Script timed out after 12 minutes"
kill -9 "$GATE_PID" 2>/dev/null || true

EVD=$(find docs/evidence/production_gate -type d -name "prod_deploy_gate_hard" 2>/dev/null | sort -r | head -1 || echo "")
if [ -n "$EVD" ]; then
  {
    echo "# NO_GO: SCRIPT_STUCK"
    echo ""
    echo "Gate script did not complete within 12 minutes."
    echo "Evidence folder: $EVD"
    echo ""
    echo "Check EXECUTION_LOG.md for last known step."
  } > "$EVD/NO_GO_SCRIPT_STUCK.md"
  echo "Partial evidence: $EVD/NO_GO_SCRIPT_STUCK.md"
fi

exit 1
