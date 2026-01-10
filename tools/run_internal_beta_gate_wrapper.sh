#!/usr/bin/env bash
# Wrapper to run INTERNAL_BETA_GATE non-PTY and poll for verdict
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
EVIDENCE_ROOT="$REPO_ROOT/docs/evidence/internal_beta_gate"
GATE="$REPO_ROOT/tools/internal_beta_gate_hard.sh"

OUT="$REPO_ROOT/.internal_beta_gate.out"
ERR="$REPO_ROOT/.internal_beta_gate.err"
MARKER="$(mktemp)"
trap 'rm -f "$MARKER"' EXIT

touch "$MARKER"
"$GATE" >"$OUT" 2>"$ERR" &
PID=$!

deadline=$((SECONDS + 180))
final_file=""
exit_code=0

while [ $SECONDS -lt $deadline ]; do
  found=$(find "$EVIDENCE_ROOT" -type f \( -name "FINAL_INTERNAL_BETA_GATE.md" -o -name "NO_GO_*.md" \) -newer "$MARKER" 2>/dev/null | sort | tail -n 1)
  if [ -n "$found" ]; then final_file="$found"; break; fi
  sleep 2
  if ! kill -0 "$PID" 2>/dev/null; then break; fi
done

wait "$PID" || exit_code=$?

if [ -z "$final_file" ]; then
  final_file=$(find "$EVIDENCE_ROOT" -type f \( -name "FINAL_INTERNAL_BETA_GATE.md" -o -name "NO_GO_*.md" \) 2>/dev/null | sort | tail -n 1 || true)
fi

if [ -n "$final_file" ]; then
  evidence_dir="$(cd "$(dirname "$final_file")" && pwd)"
  verdict_line=$(grep -m1 "VERDICT" "$final_file" || true)
  echo "Evidence folder: $evidence_dir"
  [ -n "$verdict_line" ] && echo "$verdict_line"
else
  echo "FINAL/NO_GO verdict not found within timeout" >&2
  exit_code=2
fi

exit "$exit_code"
