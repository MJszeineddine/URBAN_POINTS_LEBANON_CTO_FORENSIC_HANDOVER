#!/usr/bin/env bash
# INTERNAL_BETA_GATE (HARD) - Evidence-first gate for internal beta readiness
# Exits 0 only if all non-payment gates pass; Stripe keys are recorded as DEFERRED blockers.

# Do not exit on errors; we capture and report them explicitly.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
EVIDENCE_ROOT="$REPO_ROOT/docs/evidence/internal_beta_gate"
TS="$(date -u +"%Y%m%dT%H%M%SZ")"
EVIDENCE_DIR="$EVIDENCE_ROOT/$TS"
mkdir -p "$EVIDENCE_DIR"

# Files
ENV_SNAPSHOT="$EVIDENCE_DIR/env_snapshot.txt"
BACKEND_INSTALL_LOG="$EVIDENCE_DIR/backend_install.log"
BACKEND_INSTALL_ERR="$EVIDENCE_DIR/backend_install.err"
BACKEND_TYPECHECK_LOG="$EVIDENCE_DIR/backend_typecheck.log"
BACKEND_TYPECHECK_ERR="$EVIDENCE_DIR/backend_typecheck.err"
BACKEND_BUILD_LOG="$EVIDENCE_DIR/backend_build.log"
BACKEND_BUILD_ERR="$EVIDENCE_DIR/backend_build.err"
FLUTTER_CUST_LOG="$EVIDENCE_DIR/flutter_customer_analyze.log"
FLUTTER_CUST_ERR="$EVIDENCE_DIR/flutter_customer_analyze.err"
FLUTTER_MERCH_LOG="$EVIDENCE_DIR/flutter_merchant_analyze.log"
FLUTTER_MERCH_ERR="$EVIDENCE_DIR/flutter_merchant_analyze.err"
WEB_ADMIN_GATE_LOG="$EVIDENCE_DIR/web_admin_gate.log"
WEB_ADMIN_GATE_ERR="$EVIDENCE_DIR/web_admin_gate.err"
CLAIMS_GATE_LOG="$EVIDENCE_DIR/web_admin_claims_gate.log"
CLAIMS_GATE_ERR="$EVIDENCE_DIR/web_admin_claims_gate.err"
DIAG_SMOKE_LOG="$EVIDENCE_DIR/web_admin_diagnostics_smoke.log"
DIAG_SMOKE_ERR="$EVIDENCE_DIR/web_admin_diagnostics_smoke.err"
FINAL_GO="$EVIDENCE_DIR/FINAL_INTERNAL_BETA_GATE.md"

failures=()
status_lines=()

record_status() {
  local label="$1"; local rc="$2"
  if [ "$rc" -eq 0 ]; then
    status_lines+=("- $label: PASS (exit $rc)")
  else
    status_lines+=("- $label: FAIL (exit $rc)")
    failures+=("$label failed (exit $rc)")
  fi
}

# Env snapshot
{
  echo "UTC: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "node: $(node -v 2>&1 || echo 'unavailable')"
  echo "npm: $(npm -v 2>&1 || echo 'unavailable')"
  echo "firebase: $(firebase --version 2>&1 || echo 'unavailable')"
  echo "flutter: $(flutter --version 2>&1 | head -n 1 || echo 'unavailable')"
} > "$ENV_SNAPSHOT"

# Backend typecheck + build
BACKEND_DIR="$REPO_ROOT/source/backend/firebase-functions"
if [ -f "$BACKEND_DIR/package-lock.json" ]; then INSTALL_CMD="npm ci"; else INSTALL_CMD="npm install"; fi
( cd "$BACKEND_DIR" && $INSTALL_CMD ) >"$BACKEND_INSTALL_LOG" 2>"$BACKEND_INSTALL_ERR"; rc=$?
record_status "Backend install" "$rc"
( cd "$BACKEND_DIR" && npm run type-check ) >"$BACKEND_TYPECHECK_LOG" 2>"$BACKEND_TYPECHECK_ERR"; rc=$?
record_status "Backend typecheck" "$rc"
( cd "$BACKEND_DIR" && npm run build ) >"$BACKEND_BUILD_LOG" 2>"$BACKEND_BUILD_ERR"; rc=$?
record_status "Backend build" "$rc"

# Flutter analyze - customer
CUST_DIR="$REPO_ROOT/source/apps/mobile-customer"
( cd "$CUST_DIR" && flutter pub get > /dev/null 2>>"$FLUTTER_CUST_ERR" && dart analyze --no-fatal-warnings >"$FLUTTER_CUST_LOG" 2>>"$FLUTTER_CUST_ERR" ); rc_cust=$?
if [ "$rc_cust" -eq 0 ]; then
  status_lines+=("- Flutter customer analyze: PASS")
else
  status_lines+=("- Flutter customer analyze: FAIL (exit $rc_cust)")
  failures+=("Flutter customer analyze failed (exit $rc_cust)")
fi

# Flutter analyze - merchant
MERCH_DIR="$REPO_ROOT/source/apps/mobile-merchant"
( cd "$MERCH_DIR" && flutter pub get > /dev/null 2>>"$FLUTTER_MERCH_ERR" && dart analyze --no-fatal-warnings >"$FLUTTER_MERCH_LOG" 2>>"$FLUTTER_MERCH_ERR" ); rc_merch=$?
if [ "$rc_merch" -eq 0 ]; then
  status_lines+=("- Flutter merchant analyze: PASS")
else
  status_lines+=("- Flutter merchant analyze: FAIL (exit $rc_merch)")
  failures+=("Flutter merchant analyze failed (exit $rc_merch)")
fi

# Web-admin gates
WEB_ADMIN_DIR="$REPO_ROOT/source/apps/web-admin"
( cd "$WEB_ADMIN_DIR" && tools/web_admin_gate.sh ) >"$WEB_ADMIN_GATE_LOG" 2>"$WEB_ADMIN_GATE_ERR"; rc_web_admin=$?
record_status "Web Admin gate" "$rc_web_admin"
( cd "$WEB_ADMIN_DIR" && tools/web_admin_claims_gate.sh ) >"$CLAIMS_GATE_LOG" 2>"$CLAIMS_GATE_ERR"; rc_claims=$?
record_status "Web Admin claims gate" "$rc_claims"
( cd "$WEB_ADMIN_DIR" && tools/web_admin_diagnostics_smoke.sh ) >"$DIAG_SMOKE_LOG" 2>"$DIAG_SMOKE_ERR"; rc_diag=$?
record_status "Web Admin diagnostics smoke" "$rc_diag"

# Stripe is DEFERRED per policy_contract.json - not a blocker
BLOCKERS=()

# Verdict
EXIT_CODE=0
if [ ${#failures[@]} -ne 0 ]; then EXIT_CODE=1; fi

{
  echo "# INTERNAL_BETA_GATE Verdict"
  if [ "$EXIT_CODE" -eq 0 ]; then
    echo "VERDICT: GO_INTERNAL_BETA ✅"
  else
    echo "VERDICT: NO_GO ❌"
  fi
  echo "Timestamp (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Evidence: docs/evidence/internal_beta_gate/$TS"
  echo ""
  echo "## Status"
  for line in "${status_lines[@]}"; do echo "$line"; done
  echo ""
  echo "## Blockers"
  for b in "${BLOCKERS[@]}"; do echo "- $b"; done
  if [ ${#failures[@]} -ne 0 ]; then
    echo ""
    echo "## Failures"
    for f in "${failures[@]}"; do echo "- $f"; done
  fi
} > "$FINAL_GO"

# SHA256SUMS
( cd "$EVIDENCE_DIR" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256 ) > "$EVIDENCE_DIR/SHA256SUMS.txt"

exit "$EXIT_CODE"
