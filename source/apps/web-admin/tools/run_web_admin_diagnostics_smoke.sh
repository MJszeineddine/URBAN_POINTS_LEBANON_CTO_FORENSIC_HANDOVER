#!/usr/bin/env bash
# Non-PTY Wrapper for Web Admin Diagnostics Smoke Test
# Runs smoke in background, polls for verdict, mirrors exit code.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_ADMIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$WEB_ADMIN_DIR/../../.." && pwd)"
EVIDENCE_ROOT="$REPO_ROOT/docs/evidence/web_admin_diagnostics_smoke"
GATE_SCRIPT="$SCRIPT_DIR/web_admin_diagnostics_smoke.sh"

RUN_OUT="$WEB_ADMIN_DIR/.web_admin_diagnostics_smoke.out"
RUN_ERR="$WEB_ADMIN_DIR/.web_admin_diagnostics_smoke.err"
MARKER="$(mktemp)"
trap 'rm -f "$MARKER"' EXIT

touch "$MARKER"

"$GATE_SCRIPT" >"$RUN_OUT" 2>"$RUN_ERR" &
GATE_PID=$!

deadline=$((SECONDS + 180))
final_file=""
exit_code=0

while [ $SECONDS -lt $deadline ]; do
  found=$(find "$EVIDENCE_ROOT" -type f \( -name "FINAL_WEB_ADMIN_DIAGNOSTICS_SMOKE.md" -o -name "NO_GO_*.md" \) -newer "$MARKER" 2>/dev/null | sort | tail -n 1)
  if [ -n "$found" ]; then
    final_file="$found"
    break
  fi
  sleep 2
  if ! kill -0 "$GATE_PID" 2>/dev/null; then
    break
  fi
done

wait "$GATE_PID" || exit_code=$?

if [ -z "$final_file" ]; then
  # try to find any final after wait
  final_file=$(find "$EVIDENCE_ROOT" -type f \( -name "FINAL_WEB_ADMIN_DIAGNOSTICS_SMOKE.md" -o -name "NO_GO_*.md" \) 2>/dev/null | sort | tail -n 1 || true)
fi

if [ -n "$final_file" ]; then
  evidence_dir="$(cd "$(dirname "$final_file")" && pwd)"
  verdict_line=$(grep -m1 "VERDICT" "$final_file" || true)
  echo "Evidence folder: $evidence_dir"
  [ -n "$verdict_line" ] && echo "$verdict_line"
else
  echo "FINAL/NO_GO verdict not found within 180 seconds" >&2
  exit_code=2
fi

exit "$exit_code"
