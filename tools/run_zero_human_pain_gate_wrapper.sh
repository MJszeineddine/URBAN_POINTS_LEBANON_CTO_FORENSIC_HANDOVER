#!/usr/bin/env bash
# Wrapper to run ZERO_HUMAN_PAIN_GATE (production gate only) non-PTY and poll for verdict
# This wrapper:
# 1. Runs the production gate (NOT the demo)
# 2. Waits for VERDICT.md to be written (10 min deadline)
# 3. Mirrors the exit code from the gate
# 4. Outputs evidence folder path

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
EVIDENCE_ROOT="$REPO_ROOT/docs/evidence/zero_human_pain_gate"
GATE="$REPO_ROOT/tools/zero_human_pain_gate_hard.sh"

OUT="$REPO_ROOT/.zero_human_pain_gate.out"
ERR="$REPO_ROOT/.zero_human_pain_gate.err"
MARKER="$(mktemp)"
trap 'rm -f "$MARKER"' EXIT

echo "Starting ZERO_HUMAN_PAIN_GATE (production)..."
echo ""

touch "$MARKER"
"$GATE" >"$OUT" 2>"$ERR" &
PID=$!

deadline=$((SECONDS + 600)) # 10 min timeout
final_file=""
no_go_file=""
exit_code=0

# Poll for VERDICT.md or NO_GO_*.md
while [ $SECONDS -lt $deadline ]; do
  # Check for real verdict
  found=$(find "$EVIDENCE_ROOT" -type f -name "VERDICT.md" -newer "$MARKER" 2>/dev/null | sort | tail -n 1 || true)
  if [ -n "$found" ]; then 
    final_file="$found"
    break
  fi
  
  # Check for NO_GO verdicts (preflight failures)
  no_go=$(find "$EVIDENCE_ROOT" -type f -name "NO_GO_*.md" -newer "$MARKER" 2>/dev/null | sort | tail -n 1 || true)
  if [ -n "$no_go" ]; then
    no_go_file="$no_go"
    break
  fi
  
  sleep 2
  if ! kill -0 "$PID" 2>/dev/null; then 
    break
  fi
done

# Wait for process to finish and capture exit code
wait "$PID" 2>/dev/null || exit_code=$?

# Fallback: if no new file found, look for any recent verdict
if [ -z "$final_file" ] && [ -z "$no_go_file" ]; then
  final_file=$(find "$EVIDENCE_ROOT" -type f -name "VERDICT.md" 2>/dev/null | sort | tail -n 1 || true)
  if [ -z "$final_file" ]; then
    no_go_file=$(find "$EVIDENCE_ROOT" -type f -name "NO_GO_*.md" 2>/dev/null | sort | tail -n 1 || true)
  fi
fi

# Output results
if [ -n "$no_go_file" ]; then
  evidence_dir="$(cd "$(dirname "$no_go_file")" && pwd)"
  echo "Evidence folder: $evidence_dir"
  echo ""
  cat "$no_go_file"
  echo ""
  exit 1
elif [ -n "$final_file" ]; then
  evidence_dir="$(cd "$(dirname "$final_file")" && pwd)"
  echo "Evidence folder: $evidence_dir"
  echo ""
  cat "$final_file"
  exit "$exit_code"
else
  echo "ERROR: No VERDICT.md or NO_GO_*.md found within 10m timeout" >&2
  exit 2
fi
