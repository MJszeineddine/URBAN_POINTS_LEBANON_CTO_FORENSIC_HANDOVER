#!/usr/bin/env bash
# Unified Fullstack Gate - deterministic run with evidence and optional SKIPs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BACKEND_FN_DIR="${PROJECT_ROOT}/source/backend/firebase-functions"
REST_API_DIR="${PROJECT_ROOT}/source/backend/rest-api"
WEB_ADMIN_DIR="${PROJECT_ROOT}/source/apps/web-admin"
FLUTTER_APPS=(
  "${PROJECT_ROOT}/source/apps/mobile-admin"
  "${PROJECT_ROOT}/source/apps/mobile-customer"
  "${PROJECT_ROOT}/source/apps/mobile-merchant"
)

TS="$(date +%Y%m%d_%H%M%S)"
EDIR_TMP="/tmp/urbanpoints_fullstack/${TS}"
EDIR_REPO="${PROJECT_ROOT}/docs/parity/evidence/fullstack/${TS}"
mkdir -p "${EDIR_TMP}" "${EDIR_REPO}"

COMMAND_TIMEOUT_DEFAULT=600

with_timeout() {
  local seconds="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "${seconds}" "$@"
  elif command -v perl >/dev/null 2>&1; then
    perl -e 'alarm shift; exec @ARGV' "${seconds}" "$@"
  else
    local pycmd="python"
    if command -v python3 >/dev/null 2>&1; then
      pycmd="python3"
    fi
    ${pycmd} - "${seconds}" "$@" <<'PY'
import os, subprocess, sys, signal
secs = int(sys.argv[1]); cmd = sys.argv[2:]
proc = subprocess.Popen(cmd)
try:
    proc.wait(timeout=secs)
    sys.exit(proc.returncode)
except subprocess.TimeoutExpired:
    proc.send_signal(signal.SIGKILL)
    proc.wait()
    sys.exit(124)
PY
  fi
}

run_logged() {
  local name="$1"; shift
  local timeout_secs="$1"; shift
  local log_tmp="${EDIR_TMP}/${name}.log"
  local log_repo="${EDIR_REPO}/${name}.log"

  mkdir -p "$(dirname "${log_tmp}")" "$(dirname "${log_repo}")"
  echo "[${name}] START $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "${log_tmp}" | tee -a "${log_repo}"

  local cmd_str
  cmd_str="$(printf '%q ' "$@")"
  local runner
  if command -v script >/dev/null 2>&1; then
    runner=(script -q /dev/null bash -lc "${cmd_str}")
  elif command -v stdbuf >/dev/null 2>&1; then
    runner=(stdbuf -oL -eL bash -lc "${cmd_str}")
  else
    runner=(bash -lc "${cmd_str}")
  fi

  set +e
  with_timeout "${timeout_secs}" "${runner[@]}" 2>&1 | tee -a "${log_tmp}" | tee -a "${log_repo}"
  local status=${PIPESTATUS[0]}
  set -e

  echo "[${name}] END   $(date -u +%Y-%m-%dT%H:%M:%SZ) (status=${status})" | tee -a "${log_tmp}" | tee -a "${log_repo}"
  return "${status}"
}

deploy_semantic_fail() {
  local log_path="$1"
  local hits
  hits=$(LC_ALL=C grep -i -n -E '(Could not load the default credentials|Default credentials|PERMISSION_DENIED|permission denied|Unauthenticated|unauthorized|Missing or insufficient permissions|Error:.*googleauth|Error:.*authentication|Request had insufficient authentication scopes|gcloud auth)' "${log_path}" 2>/dev/null | grep -vi -E 'outdated version of firebase-functions|breaking changes|Dry run complete!' || true)
  if [ -n "${hits}" ]; then
    local first_hit
    first_hit="$(echo "${hits}" | head -n 1)"
    echo "BLOCKER_DEPLOY_AUTH: ${first_hit}" | tee -a "${log_path}" >/dev/null
    return 1
  fi
  return 0
}

detect_credentials() {
  if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
    return 0
  fi
  if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    return 0
  fi
  if (cd "${PROJECT_ROOT}/source" && (command -v firebase >/dev/null 2>&1 && firebase projects:list || npx -y firebase-tools projects:list) >/dev/null 2>&1); then
    return 0
  fi
  return 1
}

echo "==== FULLSTACK GATE ===="
echo "Timestamp: ${TS}"
echo "Evidence: ${EDIR_REPO}"

env_exit=0
gate_exit=0
fn_build_exit=0
fn_tests_exit=0
rest_build_exit=0
rest_tests_exit=0
web_build_exit=0
web_lint_exit=0
flutter_admin_exit=0
flutter_customer_exit=0
flutter_merchant_exit=0
deploy_exit=0
deploy_mode="NORMAL"

# 1) ENV GATE
run_logged env 60 bash "${PROJECT_ROOT}/tools/env_gate.sh" || env_exit=$?
if [ "${env_exit}" -ne 0 ]; then
  echo "NO-GO (ENV_BLOCKER) (env_exit=${env_exit})" | tee "${EDIR_TMP}/status.txt" | tee "${EDIR_REPO}/status.txt"
  exit 1
fi

# 2) PHASE3 GATE
run_logged gate 300 bash "${PROJECT_ROOT}/tools/phase3_gate.sh" || gate_exit=$?
if [ "${gate_exit}" -ne 0 ]; then
  echo "NO-GO (GATE_BLOCKER) (gate_exit=${gate_exit})" | tee "${EDIR_TMP}/status.txt" | tee "${EDIR_REPO}/status.txt"
  exit 1
fi

# 3) Backend Functions build + tests
run_logged backend_functions_build ${COMMAND_TIMEOUT_DEFAULT} bash -lc "cd '${BACKEND_FN_DIR}' && npm run build" || fn_build_exit=$?
run_logged backend_functions_tests ${COMMAND_TIMEOUT_DEFAULT} bash -lc "cd '${BACKEND_FN_DIR}' && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=urbangenspark-test GOOGLE_CLOUD_PROJECT=urbangenspark-test npm run test:ci" || fn_tests_exit=$?

# 4) REST API build + tests
run_logged rest_api_build ${COMMAND_TIMEOUT_DEFAULT} bash -lc "cd '${REST_API_DIR}' && npm run build" || rest_build_exit=$?
run_logged rest_api_tests ${COMMAND_TIMEOUT_DEFAULT} bash -lc "cd '${REST_API_DIR}' && npm test" || rest_tests_exit=$?

# 5) Web Admin build + lint
if [ -f "${WEB_ADMIN_DIR}/package.json" ]; then
  run_logged web_admin_build ${COMMAND_TIMEOUT_DEFAULT} bash -lc "cd '${WEB_ADMIN_DIR}' && npm run build" || web_build_exit=$?
  run_logged web_admin_lint ${COMMAND_TIMEOUT_DEFAULT} bash -lc "cd '${WEB_ADMIN_DIR}' && npm run lint" || web_lint_exit=$?
else
  {
    echo "[web_admin_build] START $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "SKIPPED: package.json missing"; echo "[web_admin_build] END   $(date -u +%Y-%m-%dT%H:%M:%SZ) (status=0)"
  } | tee -a "${EDIR_TMP}/web_admin_build.log" | tee -a "${EDIR_REPO}/web_admin_build.log" >/dev/null
  {
    echo "[web_admin_lint] START $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "SKIPPED: package.json missing"; echo "[web_admin_lint] END   $(date -u +%Y-%m-%dT%H:%M:%SZ) (status=0)"
  } | tee -a "${EDIR_TMP}/web_admin_lint.log" | tee -a "${EDIR_REPO}/web_admin_lint.log" >/dev/null
fi

# 6) Flutter apps analyze + tests (skip gracefully if flutter missing)
run_flutter_suite() {
  local app_path="$1"; local name="$2"; local out_name="$3"
  if command -v flutter >/dev/null 2>&1; then
    run_logged "${out_name}_analyze" ${COMMAND_TIMEOUT_DEFAULT} bash -lc "cd '${app_path}' && flutter pub get && flutter analyze" || return $? 
    run_logged "${out_name}_tests" ${COMMAND_TIMEOUT_DEFAULT} bash -lc "cd '${app_path}' && flutter test" || return $?
    return 0
  else
    {
      echo "[${out_name}] START $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "FLUTTER_MODE=SKIPPED"; echo "FLUTTER_SKIPPED_NO_SDK: Local/CI mode"; echo "[${out_name}] END   $(date -u +%Y-%m-%dT%H:%M:%SZ) (status=0)"
    } | tee -a "${EDIR_TMP}/${out_name}.log" | tee -a "${EDIR_REPO}/${out_name}.log" >/dev/null
    return 0
  fi
}

run_flutter_suite "${FLUTTER_APPS[0]}" "mobile-admin" "flutter_admin" || flutter_admin_exit=$?
run_flutter_suite "${FLUTTER_APPS[1]}" "mobile-customer" "flutter_customer" || flutter_customer_exit=$?
run_flutter_suite "${FLUTTER_APPS[2]}" "mobile-merchant" "flutter_merchant" || flutter_merchant_exit=$?

# 7) Deploy dry-run (optional; SKIPPED when no credentials)
if detect_credentials; then
  run_logged deploy ${COMMAND_TIMEOUT_DEFAULT} bash -lc "cd '${PROJECT_ROOT}/source' && (command -v firebase >/dev/null 2>&1 && firebase deploy --only functions --config firebase.json --dry-run || npx -y firebase-tools deploy --only functions --config firebase.json --dry-run)" || deploy_exit=$?
  # semantic check
  if [ -f "${EDIR_TMP}/deploy.log" ]; then
    if ! deploy_semantic_fail "${EDIR_TMP}/deploy.log"; then
      deploy_exit=97
      blocker_line=$(grep "BLOCKER_DEPLOY_AUTH" "${EDIR_TMP}/deploy.log" | head -n 1 || true)
      if [ -n "${blocker_line:-}" ]; then echo "${blocker_line}" | tee -a "${EDIR_REPO}/deploy.log" >/dev/null; fi
    fi
  fi
else
  deploy_mode="SKIPPED"
  deploy_exit=0
  {
    echo "[deploy] START $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "${EDIR_TMP}/deploy.log" | tee -a "${EDIR_REPO}/deploy.log"
    echo "DEPLOY_MODE=SKIPPED" | tee -a "${EDIR_TMP}/deploy.log" | tee -a "${EDIR_REPO}/deploy.log"
    echo "DEPLOY_SKIPPED_NO_CREDENTIALS: Local/CI mode" | tee -a "${EDIR_TMP}/deploy.log" | tee -a "${EDIR_REPO}/deploy.log"
    echo "[deploy] END   $(date -u +%Y-%m-%dT%H:%M:%SZ) (status=0)" | tee -a "${EDIR_TMP}/deploy.log" | tee -a "${EDIR_REPO}/deploy.log"
  } >/dev/null
fi

# Final status determination
final_status="GO"
if [ "${fn_build_exit}" -ne 0 ] || [ "${rest_build_exit}" -ne 0 ] || [ "${web_build_exit}" -ne 0 ]; then
  final_status="NO-GO (BUILD_BLOCKER)"
elif [ "${fn_tests_exit}" -ne 0 ] || [ "${rest_tests_exit}" -ne 0 ]; then
  final_status="NO-GO (TEST_BLOCKER)"
elif [ "${deploy_exit}" -eq 97 ]; then
  final_status="NO-GO (DEPLOY_AUTH_BLOCKER)"
elif [ "${deploy_exit}" -ne 0 ]; then
  final_status="NO-GO (DEPLOY_BLOCKER)"
fi

echo "${final_status} (env_exit=${env_exit} gate_exit=${gate_exit} fn_build_exit=${fn_build_exit} fn_tests_exit=${fn_tests_exit} rest_build_exit=${rest_build_exit} rest_tests_exit=${rest_tests_exit} web_build_exit=${web_build_exit} web_lint_exit=${web_lint_exit} flutter_admin_exit=${flutter_admin_exit} flutter_customer_exit=${flutter_customer_exit} flutter_merchant_exit=${flutter_merchant_exit} deploy_exit=${deploy_exit} deploy_mode=${deploy_mode})" | tee "${EDIR_TMP}/status.txt" | tee "${EDIR_REPO}/status.txt"

{
  echo "{"
  echo "  \"timestamp\": \"$(date -Iseconds)\"," 
  echo "  \"pwd\": \"$(pwd)\"," 
  echo "  \"git_sha\": \"$(git rev-parse HEAD 2>/dev/null || echo NOGIT)\"," 
  echo "  \"node\": \"$(node -v)\"," 
  echo "  \"npm\": \"$(npm -v)\"," 
  echo "  \"java\": \"$(java -version 2>&1 | head -n 1)\"," 
  echo "  \"env_exit\": ${env_exit},"
  echo "  \"gate_exit\": ${gate_exit},"
  echo "  \"fn_build_exit\": ${fn_build_exit},"
  echo "  \"fn_tests_exit\": ${fn_tests_exit},"
  echo "  \"rest_build_exit\": ${rest_build_exit},"
  echo "  \"rest_tests_exit\": ${rest_tests_exit},"
  echo "  \"web_build_exit\": ${web_build_exit},"
  echo "  \"web_lint_exit\": ${web_lint_exit},"
  echo "  \"flutter_admin_exit\": ${flutter_admin_exit},"
  echo "  \"flutter_customer_exit\": ${flutter_customer_exit},"
  echo "  \"flutter_merchant_exit\": ${flutter_merchant_exit},"
  echo "  \"deploy_exit\": ${deploy_exit},"
  echo "  \"deploy_mode\": \"${deploy_mode}\""
  echo "}"
} | tee "${EDIR_TMP}/meta.json" | tee "${EDIR_REPO}/meta.json"

echo "==== FULLSTACK GATE DONE ===="
echo "Evidence: ${EDIR_REPO}"
echo "Status: ${final_status}"

if [[ "${final_status}" == GO* ]]; then
  exit 0
else
  exit 1
fi
