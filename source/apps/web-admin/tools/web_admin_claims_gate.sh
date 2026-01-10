#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_ADMIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$WEB_ADMIN_DIR/../../.." && pwd)"
EVIDENCE_ROOT="$REPO_ROOT/docs/evidence/web_admin_claims_gate"
TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
EVIDENCE_DIR="$EVIDENCE_ROOT/$TIMESTAMP"

mkdir -p "$EVIDENCE_DIR"

LOG="$EVIDENCE_DIR/EXECUTION_LOG.md"
ENV_SNAPSHOT="$EVIDENCE_DIR/env_snapshot.txt"
INSTALL_LOG="$EVIDENCE_DIR/install.log"
INSTALL_ERR="$EVIDENCE_DIR/install.err"
TYPECHECK_LOG="$EVIDENCE_DIR/typecheck.log"
TYPECHECK_ERR="$EVIDENCE_DIR/typecheck.err"
BUILD_LOG="$EVIDENCE_DIR/build.log"
BUILD_ERR="$EVIDENCE_DIR/build.err"
DIAG_SCAN="$EVIDENCE_DIR/diagnostics_scan.txt"
FINAL_FILE="$EVIDENCE_DIR/FINAL_WEB_ADMIN_CLAIMS_GATE.md"

failures=()
status_lines=()

append_log() { echo "$1" >> "$LOG"; }

has_npm_script() {
  node -e "const p=require('./package.json');process.exit(p.scripts && p.scripts['$1'] ? 0 : 1);" >/dev/null 2>&1
}

run_cmd() {
  local desc="$1" cmd="$2" out="$3" err="$4"
  append_log "### $desc"
  append_log "Command: $cmd"
  (cd "$WEB_ADMIN_DIR" && eval "$cmd") >"$out" 2>"$err"
  local rc=$?
  append_log "Exit Code: $rc"
  if [ $rc -eq 0 ]; then
    status_lines+=("- $desc: PASS (exit $rc)")
  else
    status_lines+=("- $desc: FAIL (exit $rc)")
    failures+=("$desc failed (exit $rc)")
  fi
}

printf '# Web Admin Claims Gate Execution Log\n' > "$LOG"
append_log "timestamp_utc: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
append_log "repo_root: $REPO_ROOT"
append_log "web_admin_dir: $WEB_ADMIN_DIR"
append_log "evidence_dir: $EVIDENCE_DIR"
append_log ""

{
  echo "UTC: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "node: $(node -v 2>&1 || echo 'node not available')"
  echo "npm: $(npm -v 2>&1 || echo 'npm not available')"
  echo "next: $(node -p "require('next/package.json').version" 2>&1 || echo 'unknown')"
  echo "tsc: $(node -p "require('typescript/package.json').version" 2>&1 || echo 'unknown')"
} > "$ENV_SNAPSHOT"

INSTALL_CMD="npm ci"
if [ ! -f "$WEB_ADMIN_DIR/package-lock.json" ]; then INSTALL_CMD="npm install"; fi
append_log "Install command: $INSTALL_CMD"
run_cmd "Install dependencies" "$INSTALL_CMD" "$INSTALL_LOG" "$INSTALL_ERR"

if has_npm_script typecheck; then
  run_cmd "Typecheck" "npm run typecheck" "$TYPECHECK_LOG" "$TYPECHECK_ERR"
else
  run_cmd "Typecheck" "npx tsc --noEmit" "$TYPECHECK_LOG" "$TYPECHECK_ERR"
fi

run_cmd "Build" "npm run build" "$BUILD_LOG" "$BUILD_ERR"

DIAG_PAGE="$WEB_ADMIN_DIR/pages/admin/diagnostics.tsx"
> "$DIAG_SCAN"
if [ -f "$DIAG_PAGE" ]; then
  echo "diagnostics.tsx: present" >> "$DIAG_SCAN"
  grep -n "AdminGuard" "$DIAG_PAGE" >> "$DIAG_SCAN" || true
  if grep -q "<AdminGuard>" "$DIAG_PAGE"; then
    echo "AdminGuard wrapper: present" >> "$DIAG_SCAN"
  else
    echo "AdminGuard wrapper: MISSING" >> "$DIAG_SCAN"; failures+=("Diagnostics missing AdminGuard wrapper")
  fi
  if grep -q "getIdTokenResult" "$DIAG_PAGE"; then
    echo "getIdTokenResult usage: present" >> "$DIAG_SCAN"
  else
    echo "getIdTokenResult usage: MISSING" >> "$DIAG_SCAN"; failures+=("Diagnostics missing getIdTokenResult usage")
  fi
  if grep -q "claims" "$DIAG_PAGE"; then
    echo "claims read: present" >> "$DIAG_SCAN"
  else
    echo "claims read: MISSING" >> "$DIAG_SCAN"; failures+=("Diagnostics missing claims read")
  fi
  if grep -q "isAdmin" "$DIAG_PAGE" && (grep -q "role === 'admin'" "$DIAG_PAGE" || grep -q "claims.*admin" "$DIAG_PAGE"); then
    echo "isAdmin computation: present" >> "$DIAG_SCAN"
  else
    echo "isAdmin computation: MISSING" >> "$DIAG_SCAN"; failures+=("Diagnostics missing isAdmin computation")
  fi
else
  echo "diagnostics.tsx: MISSING" >> "$DIAG_SCAN"
  failures+=("Diagnostics page missing")
fi

verdict="GO ✅"; exit_code=0
if [ ${#failures[@]} -ne 0 ]; then verdict="NO_GO ❌"; exit_code=1; fi

{
  echo "# Web Admin Claims Gate Verdict"
  echo "VERDICT: $verdict"
  echo "Timestamp (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Evidence: docs/evidence/web_admin_claims_gate/$TIMESTAMP"
  echo ""
  echo "## Status"
  for line in "${status_lines[@]}"; do echo "$line"; done
  echo ""
  echo "## Diagnostics Grep Results"
  cat "$DIAG_SCAN"
  if [ ${#failures[@]} -ne 0 ]; then
    echo ""
    echo "## Failures"; for f in "${failures[@]}"; do echo "- $f"; done
  fi
} > "$FINAL_FILE"

( cd "$EVIDENCE_DIR" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256 ) > "$EVIDENCE_DIR/SHA256SUMS.txt"

exit $exit_code
