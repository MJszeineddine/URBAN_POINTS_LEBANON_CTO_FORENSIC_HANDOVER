#!/bin/bash
set -euo pipefail

REPO="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER"
cd "$REPO"

TS=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
EVD="$REPO/docs/evidence/production_gate/$TS/prod_deploy_gate_hard"
mkdir -p "$EVD"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$EVD/EXECUTION_LOG.md"
}

hard_timeout() {
  local TIMEOUT=$1
  local OUTFILE=$2
  local ERRFILE=$3
  local EXITFILE=$4
  shift 4
  
  # Use perl alarm for macOS compatibility
  set +e
  ( "$@" ) > "$OUTFILE" 2> "$ERRFILE" &
  local PID=$!
  
  ( sleep "$TIMEOUT" && kill -9 "$PID" 2>/dev/null ) &
  local KILLER_PID=$!
  
  wait "$PID"
  local EXIT=$?
  kill -9 "$KILLER_PID" 2>/dev/null || true
  
  echo "$EXIT" > "$EXITFILE"
  set -e
  return "$EXIT"
}

{
  echo "# PRODUCTION DEPLOY GATE EXECUTION LOG"
  echo ""
  echo "Start Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "PWD: $(pwd)"
  echo "Node: $(node -v 2>&1)"
  echo "NPM: $(npm -v 2>&1)"
  echo ""
} > "$EVD/EXECUTION_LOG.md"

cd "$REPO/source"

# Step A: Firebase version
log "STEP A: firebase --version"
if ! hard_timeout 30 "$EVD/firebase_version.out.log" "$EVD/firebase_version.err.log" "$EVD/firebase_version.exitcode" firebase --version; then
  log "FAIL: firebase version check"
  {
    echo "# NO_GO: FIREBASE_VERSION_FAIL"
    echo ""
    echo "Firebase CLI version check failed or timed out."
    echo ""
    echo "## stderr (last 80 lines)"
    tail -n 80 "$EVD/firebase_version.err.log"
  } > "$EVD/NO_GO_TIMEOUT_version.md"
  exit 1
fi
log "OK: firebase version"

# Step B: Use project
log "STEP B: firebase use urbangenspark"
if ! hard_timeout 45 "$EVD/firebase_use.out.log" "$EVD/firebase_use.err.log" "$EVD/firebase_use.exitcode" firebase use urbangenspark; then
  log "FAIL: firebase use"
  {
    echo "# NO_GO: FIREBASE_USE_FAIL"
    echo ""
    echo "firebase use urbangenspark failed or timed out."
    echo ""
    echo "## stderr (last 80 lines)"
    tail -n 80 "$EVD/firebase_use.err.log"
  } > "$EVD/NO_GO_TIMEOUT_use.md"
  exit 2
fi
log "OK: firebase use"

# Check for auth errors
if grep -qiE "not logged in|authentication|login required|permission denied|403" "$EVD/firebase_use.err.log" 2>/dev/null; then
  log "FAIL: authentication missing"
  {
    echo "# NO_GO: AUTH_MISSING"
    echo ""
    echo "Firebase CLI not authenticated."
    echo ""
    echo "## Remediation"
    echo "Run: firebase login --no-localhost"
    echo ""
    echo "## Error log"
    cat "$EVD/firebase_use.err.log"
  } > "$EVD/NO_GO_AUTH.md"
  exit 3
fi

# Step C: Pre-deploy inventory
log "STEP C: firebase functions:list (pre-deploy)"
if ! hard_timeout 45 "$EVD/firebase_functions_list_pre.out.log" "$EVD/firebase_functions_list_pre.err.log" "$EVD/firebase_functions_list_pre.exitcode" firebase functions:list --project urbangenspark; then
  log "WARN: pre-deploy functions:list failed (non-fatal)"
fi
log "OK: pre-deploy inventory"

# Step D: Deploy functions
log "STEP D: firebase deploy --only functions (600s timeout)"
if ! hard_timeout 600 "$EVD/firebase_deploy_functions.out.log" "$EVD/firebase_deploy_functions.err.log" "$EVD/firebase_deploy_functions.exitcode" firebase deploy --only functions --project urbangenspark; then
  EXITCODE=$(cat "$EVD/firebase_deploy_functions.exitcode")
  log "FAIL: functions deploy (exit=$EXITCODE)"
  {
    echo "# NO_GO: DEPLOY_FUNCTIONS_FAIL"
    echo ""
    echo "firebase deploy --only functions failed or timed out."
    echo "Exit code: $EXITCODE"
    echo ""
    echo "## stdout (last 80 lines)"
    tail -n 80 "$EVD/firebase_deploy_functions.out.log"
    echo ""
    echo "## stderr (last 80 lines)"
    tail -n 80 "$EVD/firebase_deploy_functions.err.log"
  } > "$EVD/NO_GO_TIMEOUT_deploy_functions.md"
  exit 4
fi
log "OK: functions deploy"

# Step E: Deploy indexes
log "STEP E: firebase deploy --only firestore:indexes (300s timeout)"
if ! hard_timeout 300 "$EVD/firebase_deploy_indexes.out.log" "$EVD/firebase_deploy_indexes.err.log" "$EVD/firebase_deploy_indexes.exitcode" firebase deploy --only firestore:indexes --project urbangenspark; then
  EXITCODE=$(cat "$EVD/firebase_deploy_indexes.exitcode")
  log "FAIL: indexes deploy (exit=$EXITCODE)"
  {
    echo "# NO_GO: DEPLOY_INDEXES_FAIL"
    echo ""
    echo "firebase deploy --only firestore:indexes failed or timed out."
    echo "Exit code: $EXITCODE"
    echo ""
    echo "## stdout (last 80 lines)"
    tail -n 80 "$EVD/firebase_deploy_indexes.out.log"
    echo ""
    echo "## stderr (last 80 lines)"
    tail -n 80 "$EVD/firebase_deploy_indexes.err.log"
  } > "$EVD/NO_GO_TIMEOUT_deploy_indexes.md"
  exit 5
fi
log "OK: indexes deploy"

# Step F: Post-deploy inventory
log "STEP F: firebase functions:list (post-deploy)"
if ! hard_timeout 45 "$EVD/firebase_functions_list_post.out.log" "$EVD/firebase_functions_list_post.err.log" "$EVD/firebase_functions_list_post.exitcode" firebase functions:list --project urbangenspark; then
  log "FAIL: post-deploy functions:list"
  {
    echo "# NO_GO: POST_DEPLOY_LIST_FAIL"
    echo ""
    echo "Post-deploy functions:list failed."
    echo ""
    echo "## stderr"
    cat "$EVD/firebase_functions_list_post.err.log"
  } > "$EVD/NO_GO_TIMEOUT_list_post.md"
  exit 6
fi
log "OK: post-deploy inventory"

cd "$REPO"

# Verdict logic
FAIL=0

if ! grep -q "Deploy complete!" "$EVD/firebase_deploy_functions.out.log" 2>/dev/null; then
  log "VERDICT: NO_GO (functions deploy did not complete)"
  FAIL=1
fi

if ! grep -qE "deployed indexes|indexes are up to date" "$EVD/firebase_deploy_indexes.out.log" 2>/dev/null; then
  log "VERDICT: NO_GO (indexes deploy did not complete)"
  FAIL=1
fi

if [ ! -s "$EVD/firebase_functions_list_post.out.log" ]; then
  log "VERDICT: NO_GO (post-deploy inventory empty)"
  FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
  VERDICT="GO ✅"
  log "VERDICT: GO"
  
  {
    echo "# FINAL PRODUCTION DEPLOYMENT GATE"
    echo ""
    echo "**VERDICT: $VERDICT**"
    echo ""
    echo "**Project:** urbangenspark"
    echo "**Timestamp:** $TS"
    echo "**Evidence:** $EVD"
    echo ""
    echo "## Success Evidence"
    echo ""
    echo "### Functions Deploy (Smoking Gun)"
    echo '```'
    grep -E "Deploy complete!|Successful.*operation" "$EVD/firebase_deploy_functions.out.log" | head -10
    echo '```'
    echo ""
    echo "### Indexes Deploy (Smoking Gun)"
    echo '```'
    grep -E "deployed indexes|indexes are up to date|Deploy complete" "$EVD/firebase_deploy_indexes.out.log" | head -5
    echo '```'
    echo ""
    echo "### Post-Deploy Inventory"
    echo '```'
    head -20 "$EVD/firebase_functions_list_post.out.log"
    echo '```'
    echo ""
    echo "## Log Files"
    echo "- firebase_deploy_functions.out.log"
    echo "- firebase_deploy_indexes.out.log"
    echo "- firebase_functions_list_post.out.log"
    echo "- EXECUTION_LOG.md"
    echo "- SHA256SUMS.txt"
  } > "$EVD/FINAL_PROD_DEPLOY_GATE.md"
else
  VERDICT="NO_GO ❌"
  log "VERDICT: NO_GO"
  
  {
    echo "# FINAL PRODUCTION DEPLOYMENT GATE"
    echo ""
    echo "**VERDICT: $VERDICT**"
    echo ""
    echo "One or more steps failed. Check:"
    echo "- firebase_deploy_functions.out.log"
    echo "- firebase_deploy_indexes.out.log"
    echo "- NO_GO_*.md files"
  } > "$EVD/FINAL_PROD_DEPLOY_GATE.md"
fi

# Integrity
find "$EVD" -type f ! -name SHA256SUMS.txt -exec shasum -a 256 {} + | sort > "$EVD/SHA256SUMS.txt"

log "DONE: $VERDICT"
echo "$VERDICT" > "$EVD/VERDICT.txt"
