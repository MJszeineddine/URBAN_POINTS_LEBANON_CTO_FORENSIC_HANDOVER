#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$ROOT/local-ci/verification/full_stack_gate_run.log"
mkdir -p "$(dirname "$LOG")"

# Stream all output to console and log (append)
exec > >(tee -a "$LOG") 2>&1

echo "=== FULL_STACK_GATE $(date -Iseconds) ==="

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_step() {
  local label="$1"; shift
  echo "--- STEP: ${label}";
  "$@"
  echo "--- STEP DONE: ${label}"
}

install_node_deps() {
  local dir="$1"; local pm=""
  if [ -f "$dir/yarn.lock" ] && has_cmd yarn; then
    pm="yarn"; (cd "$dir" && yarn install --frozen-lockfile --silent)
  elif has_cmd npm; then
    pm="npm"; (cd "$dir" && npm install --silent)
  else
    echo "SKIP install in $dir (no yarn/npm)"; return 1
  fi
}

run_functions_suite() {
  local dir="$ROOT/source/backend/firebase-functions"
  if [ ! -d "$dir" ]; then
    echo "SKIP functions (not found)"; return 0
  fi
  echo "Running Firebase Functions suite"
  install_node_deps "$dir" || return 1
  if [ -f "$dir/package.json" ]; then
    if has_cmd yarn && [ -f "$dir/yarn.lock" ]; then pm_cmd="yarn"; else pm_cmd="npm run"; fi
    (cd "$dir" && ${pm_cmd} lint)
    (cd "$dir" && ${pm_cmd} build)
    (cd "$dir" && ${pm_cmd} test)
  fi
}

run_firestore_rules_check() {
  local config="$ROOT/source/firebase.json"
  local rules="$ROOT/source/infra/firestore.rules"
  if [ ! -f "$config" ] || [ ! -f "$rules" ]; then
    echo "SKIP rules check (missing config/rules)"; return 0
  fi
  if has_cmd firebase; then
    firebase emulators:exec --only firestore --project demo --config "$config" --quiet "echo rules-ok"
  elif has_cmd npx; then
    npx firebase-tools emulators:exec --only firestore --project demo --config "$config" --quiet "echo rules-ok"
  else
    echo "SKIP rules check (no firebase CLI)"
  fi
}

run_web_admin_suite() {
  local dir="$ROOT/source/apps/web-admin"
  if [ ! -d "$dir" ]; then
    echo "SKIP web-admin (not found)"; return 0
  fi
  echo "Running web-admin suite"
  install_node_deps "$dir" || return 1
  if has_cmd yarn && [ -f "$dir/yarn.lock" ]; then pm_cmd="yarn"; else pm_cmd="npm run"; fi
  (cd "$dir" && ${pm_cmd} lint)
  (cd "$dir" && ${pm_cmd} build)
}

run_flutter_suite() {
  local dir="$1"; local name="$2"
  if [ ! -d "$dir" ]; then
    echo "SKIP $name (not found)"; return 0
  fi
  if ! has_cmd flutter; then
    echo "SKIP $name (flutter not installed)"; return 0
  fi
  echo "Running Flutter suite for $name"
  (cd "$dir" && flutter pub get)
  (cd "$dir" && flutter analyze)
  (cd "$dir" && flutter test)
  if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    (cd "$dir" && flutter build apk --debug)
  else
    echo "SKIP $name build (ANDROID_SDK_ROOT not set)"
  fi
}

run_step "firebase_functions" run_functions_suite
run_step "firestore_rules_check" run_firestore_rules_check
run_step "web_admin" run_web_admin_suite
run_step "flutter_customer" run_flutter_suite "$ROOT/source/apps/mobile-customer" "mobile-customer"
run_step "flutter_merchant" run_flutter_suite "$ROOT/source/apps/mobile-merchant" "mobile-merchant"

echo "=== FULL_STACK_GATE END $(date -Iseconds) ==="
