#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_ADMIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$WEB_ADMIN_DIR/../../.." && pwd)"
EVIDENCE_ROOT="$REPO_ROOT/docs/evidence/web_admin_gate"
TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
EVIDENCE_DIR="$EVIDENCE_ROOT/$TIMESTAMP"

mkdir -p "$EVIDENCE_DIR"

LOG="$EVIDENCE_DIR/EXECUTION_LOG.md"
ENV_SNAPSHOT="$EVIDENCE_DIR/env_snapshot.txt"
BUILD_LOG="$EVIDENCE_DIR/build.log"
BUILD_ERR="$EVIDENCE_DIR/build.err"
LINT_LOG="$EVIDENCE_DIR/lint.log"
LINT_ERR="$EVIDENCE_DIR/lint.err"
TYPECHECK_LOG="$EVIDENCE_DIR/typecheck.log"
TYPECHECK_ERR="$EVIDENCE_DIR/typecheck.err"
READONLY_SCAN="$EVIDENCE_DIR/readonly_scan.txt"
GUARD_SCAN="$EVIDENCE_DIR/guard_scan.txt"
FINAL_FILE="$EVIDENCE_DIR/FINAL_WEB_ADMIN_GATE.md"
INSTALL_LOG="$EVIDENCE_DIR/install.log"
INSTALL_ERR="$EVIDENCE_DIR/install.err"

failures=()
status_lines=()

append_log() {
  echo "$1" >> "$LOG"
}

has_npm_script() {
  node -e "const p=require('./package.json');process.exit(p.scripts && p.scripts['$1'] ? 0 : 1);" >/dev/null 2>&1
}

run_cmd() {
  local desc="$1"
  local cmd="$2"
  local out="$3"
  local err="$4"
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

printf '# Web Admin Gate Execution Log\n' > "$LOG"
append_log "timestamp_utc: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
append_log "repo_root: $REPO_ROOT"
append_log "web_admin_dir: $WEB_ADMIN_DIR"
append_log "evidence_dir: $EVIDENCE_DIR"
append_log ""

{
  echo "UTC: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "node: $(node -v 2>&1 || echo 'node not available')"
  echo "npm: $(npm -v 2>&1 || echo 'npm not available')"
  git -C "$REPO_ROOT" rev-parse HEAD 2>&1 || echo "git hash unavailable"
} > "$ENV_SNAPSHOT"

INSTALL_CMD="npm ci"
if [ ! -f "$WEB_ADMIN_DIR/package-lock.json" ]; then
  INSTALL_CMD="npm install"
fi
append_log "Install command: $INSTALL_CMD"
run_cmd "Install dependencies" "$INSTALL_CMD" "$INSTALL_LOG" "$INSTALL_ERR"

if has_npm_script lint; then
  if [ -f "$WEB_ADMIN_DIR/node_modules/next/dist/cli/next-lint.js" ]; then
    run_cmd "Lint" "npm run lint" "$LINT_LOG" "$LINT_ERR"
  else
    echo "next lint command unavailable in installed Next.js; skipped" >"$LINT_LOG"
    : >"$LINT_ERR"
    status_lines+=("- Lint: SKIPPED (next lint command unavailable)")
  fi
else
  echo "lint script not found; skipped" >"$LINT_LOG"
  : >"$LINT_ERR"
  status_lines+=("- Lint: SKIPPED (script missing)")
fi

typecheck_command=""
if has_npm_script typecheck; then
  typecheck_command="npm run typecheck"
else
  typecheck_command="npx tsc -p tsconfig.json --noEmit"
fi
run_cmd "Typecheck" "$typecheck_command" "$TYPECHECK_LOG" "$TYPECHECK_ERR"

run_cmd "Build" "npm run build" "$BUILD_LOG" "$BUILD_ERR"

find "$WEB_ADMIN_DIR" \( -path "$WEB_ADMIN_DIR/node_modules" -o -path "$WEB_ADMIN_DIR/.next" \) -prune -false -o -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) -print0 \
  | xargs -0 grep -nE 'addDoc\(|setDoc\(|updateDoc\(|deleteDoc\(|writeBatch\(|runTransaction\(' 2>/dev/null > "$READONLY_SCAN" || true
if [ ! -s "$READONLY_SCAN" ]; then
  echo "none" > "$READONLY_SCAN"
  status_lines+=("- Read-only scan: PASS (no mutations)")
else
  failures+=("Read-only violation detected (see readonly_scan.txt)")
  status_lines+=("- Read-only scan: FAIL (mutations found)")
fi

missing_guard=0
> "$GUARD_SCAN"
if [ -d "$WEB_ADMIN_DIR/pages/admin" ]; then
  admin_pages=()
  while IFS= read -r page; do
    admin_pages+=("$page")
  done < <(find "$WEB_ADMIN_DIR/pages/admin" -maxdepth 1 -type f -name "*.tsx" | sort)
  if [ ${#admin_pages[@]} -eq 0 ]; then
    echo "No admin pages found" >> "$GUARD_SCAN"
    failures+=("No admin pages found for guard verification")
    missing_guard=1
  else
    for page in "${admin_pages[@]}"; do
      base="$(basename "$page")"
      if [ "$base" = "login.tsx" ]; then
        echo "$base: skipped (login page remains unguarded by design)" >> "$GUARD_SCAN"
        continue
      fi
      if grep -q "AdminGuard" "$page"; then
        echo "$base: AdminGuard present" >> "$GUARD_SCAN"
      else
        echo "$base: AdminGuard MISSING" >> "$GUARD_SCAN"
        missing_guard=1
      fi
    done
  fi
else
  echo "pages/admin directory missing" >> "$GUARD_SCAN"
  failures+=("pages/admin directory missing")
  missing_guard=1
fi

if [ $missing_guard -eq 0 ]; then
  status_lines+=("- AdminGuard coverage: PASS")
else
  status_lines+=("- AdminGuard coverage: FAIL (see guard_scan.txt)")
  failures+=("AdminGuard coverage incomplete")
fi

verdict="GO ✅"
exit_code=0
if [ ${#failures[@]} -ne 0 ]; then
  verdict="NO_GO ❌"
  exit_code=1
fi

{
  echo "# Web Admin Gate Verdict"
  echo "VERDICT: $verdict"
  echo "Timestamp (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Evidence: docs/evidence/web_admin_gate/$TIMESTAMP"
  echo ""
  echo "## Status"
  for line in "${status_lines[@]}"; do
    echo "$line"
  done
  if [ ${#failures[@]} -ne 0 ]; then
    echo ""
    echo "## Failures"
    for f in "${failures[@]}"; do
      echo "- $f"
    done
  fi
} > "$FINAL_FILE"

( cd "$EVIDENCE_DIR" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256 ) > "$EVIDENCE_DIR/SHA256SUMS.txt"

exit $exit_code
