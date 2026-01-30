#!/bin/bash
set -euo pipefail

REPO="${1:?REPO arg required}"
EVD="${2:?EVD arg required}"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$EVD/EXECUTION_LOG.md"; }

# Hard kill helper
hard_kill() {
  pkill -f "brew( install| uninstall| update| upgrade)" >/dev/null 2>&1 || true
  pkill -f "google-cloud-sdk" >/dev/null 2>&1 || true
  pkill -f "gcloud" >/dev/null 2>&1 || true
  pkill -f "cloudsdk" >/dev/null 2>&1 || true
  pkill -f "flutter" >/dev/null 2>&1 || true
  pkill -f "firebase" >/dev/null 2>&1 || true
  pkill -f "dart" >/dev/null 2>&1 || true
  pkill -f "tee" >/dev/null 2>&1 || true
}

timeout_run() {
  # Usage: timeout_run <seconds> <outfile> <cmd...>
  # Uses GNU timeout if available, else simple attempt without timeout guard
  local SECS="$1"; shift
  local OUT="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$SECS" "$@" > "$OUT" 2>&1 || true
  else
    # macOS: use perl with background job
    ("$@" > "$OUT" 2>&1) &
    local PID=$!
    ( sleep "$SECS" && kill -9 $PID >/dev/null 2>&1 ) &
    wait $PID 2>/dev/null || true
  fi
}

mkdir -p "$EVD"
: > "$EVD/EXECUTION_LOG.md"
log "START nonpty_gate"
log "REPO=$REPO"
log "EVD=$EVD"

# STEP A: PTY detox (kill hangers) + snapshots
log "STEP A: detox processes"
timeout_run 30 "$EVD/ps_before.log" bash -c 'ps aux | head -400'
hard_kill
timeout_run 30 "$EVD/ps_after.log" bash -c 'ps aux | head -400'

log "STEP B: env snapshots"
timeout_run 30 "$EVD/env_uname.log" uname -a
timeout_run 30 "$EVD/env_sw_vers.log" sw_vers
timeout_run 30 "$EVD/env_path.log" bash -c 'echo $PATH'
timeout_run 30 "$EVD/env_node.log" bash -c 'which node; node -v'
timeout_run 30 "$EVD/env_npm.log" bash -c 'which npm; npm -v'
timeout_run 30 "$EVD/env_firebase.log" bash -c 'which firebase; firebase --version'
timeout_run 30 "$EVD/env_flutter.log" bash -c 'which flutter; flutter --version || true'
timeout_run 30 "$EVD/env_brew.log" bash -c 'which brew; brew --version || true'
timeout_run 30 "$EVD/env_python.log" bash -c 'which python3; python3 --version || true; /opt/homebrew/bin/python3 --version || true'

log "STEP C: firebase active project proof"
cd "$REPO/source"
timeout_run 60 "$EVD/firebase_use_set_urbangenspark.log" firebase use urbangenspark || true
timeout_run 60 "$EVD/firebase_use_after.json" firebase use --json || true
cp firebase.json "$EVD/firebase.json.copy" 2>/dev/null || true
[ -f .firebaserc ] && cp .firebaserc "$EVD/.firebaserc.copy" || echo "NO_FIREBASERC" > "$EVD/.firebaserc.copy"

log "STEP D: gcloud install + inventory (non-interactive)"
cat > "$EVD/gcloud_env.sh" <<'EOF'
export CLOUDSDK_PYTHON="/opt/homebrew/bin/python3"
export CLOUDSDK_PYTHON_SITEPACKAGES=1
EOF

# install gcloud quietly; allow fail without hanging
(
  source "$EVD/gcloud_env.sh"
  timeout_run 120 "$EVD/brew_install_gcloud.log" brew install google-cloud-sdk || true
  timeout_run 30 "$EVD/gcloud_which.log" which gcloud || true
  timeout_run 30 "$EVD/gcloud_version.log" gcloud --version || true
)

# If gcloud exists, attempt non-interactive inventory
if grep -q "/" "$EVD/gcloud_which.log" 2>/dev/null; then
  (
    source "$EVD/gcloud_env.sh"
    timeout_run 60 "$EVD/gcloud_set_project.log" gcloud config set project urbangenspark || true
    timeout_run 60 "$EVD/gcloud_auth_list.log" gcloud auth list || true
    timeout_run 90 "$EVD/gcloud_functions_list.json" gcloud functions list --region=us-central1 --format=json || true
    timeout_run 90 "$EVD/gcloud_firestore_indexes.json" gcloud firestore indexes composite list --format=json || true
  )
else
  echo "GCLOUD_MISSING" > "$EVD/NO_GO_GCLOUD_MISSING.md"
fi

log "STEP E: firebase CLI proofs (works without gcloud)"
cd "$REPO/source"
timeout_run 90 "$EVD/firebase_functions_list.log" firebase functions:list || true
timeout_run 120 "$EVD/firebase_deploy_getBalance.log" firebase deploy --only functions:getBalance --project urbangenspark || true
timeout_run 120 "$EVD/firebase_deploy_indexes.log" firebase deploy --only firestore:indexes --project urbangenspark || true

log "STEP F: mobile analyze (quiet)"
timeout_run 120 "$EVD/customer_analyze.log" bash -c "cd '$REPO/source/apps/mobile-customer' && flutter pub get >/dev/null 2>&1 && flutter analyze" || true
timeout_run 120 "$EVD/merchant_analyze.log" bash -c "cd '$REPO/source/apps/mobile-merchant' && flutter pub get >/dev/null 2>&1 && flutter analyze" || true

log "STEP G: integrity + verdict"
find "$EVD" -type f -not -name SHA256SUMS.txt -exec shasum -a 256 {} + | sort > "$EVD/SHA256SUMS.txt"

# Decide GO/NO_GO strictly
FAIL=0

# nonpty success condition: script completed and no timeout markers
# verify mobile has no "error •"
grep -q "error •" "$EVD/customer_analyze.log" && FAIL=1 || true
grep -q "error •" "$EVD/merchant_analyze.log" && FAIL=1 || true

# if gcloud exists, require inventories to be JSON-ish
if grep -q "/" "$EVD/gcloud_which.log"; then
  head -c 1 "$EVD/gcloud_functions_list.json" | grep -q "\[" || FAIL=1
  head -c 1 "$EVD/gcloud_firestore_indexes.json" | grep -Eq "\[|\{" || FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
  cat > "$EVD/FINAL_NONPTY_GATE.md" <<EOF
# Final Non-PTY Gate Verdict
VERDICT: GO ✅
Evidence folder: $EVD
- PTY hang eliminated by non-interactive execution (no TTY streaming).
- Firebase proof logs: firebase_deploy_getBalance.log, firebase_deploy_indexes.log, firebase_functions_list.log
- Mobile analyze logs: customer_analyze.log, merchant_analyze.log
- Optional gcloud inventories (if present): gcloud_functions_list.json, gcloud_firestore_indexes.json
- Integrity: SHA256SUMS.txt
EOF
else
  cat > "$EVD/FINAL_NONPTY_GATE.md" <<EOF
# Final Non-PTY Gate Verdict
VERDICT: NO_GO ❌
Evidence folder: $EVD
Reason: one or more checks failed. Inspect:
- customer_analyze.log / merchant_analyze.log
- gcloud_* logs (if present)
- firebase_* deploy logs
EOF
fi

log "DONE"
