#!/usr/bin/env bash
# Web Admin Diagnostics Smoke Test (ZERO-INTERACTION)
# Validates /admin/diagnostics invariants, guard enforcement, and build quality.

set -euo pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_ADMIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$WEB_ADMIN_DIR/../../.." && pwd)"
EVIDENCE_ROOT="$REPO_ROOT/docs/evidence/web_admin_diagnostics_smoke"
ISO_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EVIDENCE_DIR="$EVIDENCE_ROOT/$ISO_TS"

# Evidence files
ENV_SNAPSHOT="$EVIDENCE_DIR/env_snapshot.txt"
DIAG_SCAN="$EVIDENCE_DIR/diagnostics_scan.txt"
GUARD_SCAN="$EVIDENCE_DIR/guard_scan.txt"
INSTALL_LOG="$EVIDENCE_DIR/install.log"
INSTALL_ERR="$EVIDENCE_DIR/install.err"
TYPECHECK_LOG="$EVIDENCE_DIR/typecheck.log"
TYPECHECK_ERR="$EVIDENCE_DIR/typecheck.err"
BUILD_LOG="$EVIDENCE_DIR/build.log"
BUILD_ERR="$EVIDENCE_DIR/build.err"
FINAL_GO="$EVIDENCE_DIR/FINAL_WEB_ADMIN_DIAGNOSTICS_SMOKE.md"

mkdir -p "$EVIDENCE_DIR"

# Helpers
failures=()
status_lines=()

has_npm_script() {
  node -e "const p=require('./package.json');process.exit(p.scripts && p.scripts['$1'] ? 0 : 1);" >/dev/null 2>&1
}

run_cmd() {
  local desc="$1"; shift
  local cmd="$1"; shift
  local out="$1"; shift
  local err="$1"; shift
  (cd "$WEB_ADMIN_DIR" && eval "$cmd") >"$out" 2>"$err" || {
    status_lines+=("- $desc: FAIL")
    failures+=("$desc failed")
    return 1
  }
  status_lines+=("- $desc: PASS")
}

# Env snapshot
{
  echo "UTC: $ISO_TS"
  echo "node: $(node -v 2>&1 || echo 'not available')"
  echo "npm: $(npm -v 2>&1 || echo 'not available')"
  echo "next: $(node -p "require('next/package.json').version" 2>&1 || echo 'unknown')"
  echo "typescript: $(node -p "require('typescript/package.json').version" 2>&1 || echo 'unknown')"
} > "$ENV_SNAPSHOT"

# Install
INSTALL_CMD="npm ci"
if [ ! -f "$WEB_ADMIN_DIR/package-lock.json" ]; then INSTALL_CMD="npm install"; fi
run_cmd "Install dependencies" "$INSTALL_CMD" "$INSTALL_LOG" "$INSTALL_ERR"

# Typecheck
if has_npm_script typecheck; then
  run_cmd "Typecheck" "npm run typecheck" "$TYPECHECK_LOG" "$TYPECHECK_ERR"
else
  run_cmd "Typecheck" "npx tsc --noEmit" "$TYPECHECK_LOG" "$TYPECHECK_ERR"
fi

# Build
run_cmd "Build" "npm run build" "$BUILD_LOG" "$BUILD_ERR"

# Diagnostics checks
DIAG_PAGE="$WEB_ADMIN_DIR/pages/admin/diagnostics.tsx"
> "$DIAG_SCAN"
if [ -f "$DIAG_PAGE" ]; then
  echo "diagnostics.tsx: present" >> "$DIAG_SCAN"
else
  echo "diagnostics.tsx: MISSING" >> "$DIAG_SCAN"
  failures+=("Diagnostics page missing")
fi

if [ -f "$DIAG_PAGE" ]; then
  if grep -q "AdminGuard" "$DIAG_PAGE"; then
    echo "AdminGuard import: present" >> "$DIAG_SCAN"
  else
    echo "AdminGuard import: MISSING" >> "$DIAG_SCAN"; failures+=("Diagnostics missing AdminGuard import")
  fi
  if grep -q "<AdminGuard>" "$DIAG_PAGE"; then
    echo "AdminGuard wrapper: present" >> "$DIAG_SCAN"
  else
    echo "AdminGuard wrapper: MISSING" >> "$DIAG_SCAN"; failures+=("Diagnostics not wrapped with AdminGuard")
  fi
  if grep -q "getIdTokenResult" "$DIAG_PAGE"; then
    echo "getIdTokenResult usage: present" >> "$DIAG_SCAN"
  else
    echo "getIdTokenResult usage: MISSING" >> "$DIAG_SCAN"; failures+=("Diagnostics missing getIdTokenResult usage")
  fi
  if grep -q "isAdmin" "$DIAG_PAGE" && (grep -q "role === 'admin'" "$DIAG_PAGE" || grep -q "admin === true" "$DIAG_PAGE"); then
    echo "isAdmin computation: present" >> "$DIAG_SCAN"
  else
    echo "isAdmin computation: MISSING" >> "$DIAG_SCAN"; failures+=("Diagnostics missing isAdmin computation")
  fi
  if (grep -nE 'addDoc\(|setDoc\(|updateDoc\(|deleteDoc\(|writeBatch\(|runTransaction\(' "$DIAG_PAGE" || true) | grep -q .; then
    echo "Mutations found in diagnostics.tsx" >> "$DIAG_SCAN"; failures+=("Read-only violation: Firestore mutation in diagnostics.tsx")
  else
    echo "No mutations detected in diagnostics.tsx" >> "$DIAG_SCAN"
  fi
  if grep -q "role" "$DIAG_PAGE" || grep -q "admin" "$DIAG_PAGE"; then
    echo "Claims read: present (role/admin)" >> "$DIAG_SCAN"
  else
    echo "Claims read: MISSING" >> "$DIAG_SCAN"; failures+=("Diagnostics missing claims read")
  fi
fi

# Guard enforcement (diagnostics must be guarded; login excluded)
> "$GUARD_SCAN"
LOGIN_PAGE="$WEB_ADMIN_DIR/pages/admin/login.tsx"
if [ -f "$DIAG_PAGE" ]; then
  if grep -q "<AdminGuard>" "$DIAG_PAGE"; then
    echo "diagnostics.tsx: guarded by AdminGuard" >> "$GUARD_SCAN"
  else
    echo "diagnostics.tsx: NOT guarded" >> "$GUARD_SCAN"; failures+=("Diagnostics not guarded by AdminGuard")
  fi
else
  echo "diagnostics.tsx: missing, cannot verify guard" >> "$GUARD_SCAN"
fi
if [ -f "$LOGIN_PAGE" ]; then
  echo "login.tsx: excluded from guard checks" >> "$GUARD_SCAN"
fi

# Verdict
EXIT_CODE=0
REASON=""
if [ ${#failures[@]} -ne 0 ]; then
  EXIT_CODE=1
  REASON="$(printf '%s' "${failures[0]}" | tr ' ' '_' | tr -cd '[:alnum:]_')"
  NO_GO_FILE="$EVIDENCE_DIR/NO_GO_${REASON}.md"
  {
    echo "# Web Admin Diagnostics Smoke Verdict"
    echo "VERDICT: NO_GO ❌"
    echo "Timestamp (UTC): $ISO_TS"
    echo "Evidence: docs/evidence/web_admin_diagnostics_smoke/$ISO_TS"
    echo ""
    echo "## Failures"
    for f in "${failures[@]}"; do echo "- $f"; done
  } > "$NO_GO_FILE"
else
  {
    echo "# Web Admin Diagnostics Smoke Verdict"
    echo "VERDICT: GO ✅"
    echo "Timestamp (UTC): $ISO_TS"
    echo "Evidence: docs/evidence/web_admin_diagnostics_smoke/$ISO_TS"
    echo ""
    echo "## Summary"
    for line in "${status_lines[@]}"; do echo "$line"; done
    echo "- Diagnostics checks: PASS (AdminGuard, getIdTokenResult, claims, isAdmin)"
    echo "- No mutations detected. Read-only admin diagnostics."
  } > "$FINAL_GO"
fi

# SHA256 sums
( cd "$EVIDENCE_DIR" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256 ) > "$EVIDENCE_DIR/SHA256SUMS.txt"

exit $EXIT_CODE
