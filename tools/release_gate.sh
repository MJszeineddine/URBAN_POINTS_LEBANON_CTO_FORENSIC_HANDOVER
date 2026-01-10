#!/usr/bin/env bash
# Unified Release Gate - Deterministic execution with evidence

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/source/backend/firebase-functions"

TS="$(date +%Y%m%d_%H%M%S)"
EDIR_TMP="/tmp/urbanpoints_release/${TS}"
EDIR_REPO="${PROJECT_ROOT}/docs/parity/evidence/release/${TS}"
mkdir -p "${EDIR_TMP}" "${EDIR_REPO}"

log_pair() {
  local name="$1"; shift
  echo "[${name}] START $(date -Iseconds)" | tee -a "${EDIR_TMP}/${name}.log" | tee -a "${EDIR_REPO}/${name}.log"
  set +e
  if command -v script >/dev/null 2>&1; then
    script -q /dev/null bash -lc "$*" 2>&1 | tee -a "${EDIR_TMP}/${name}.log" | tee -a "${EDIR_REPO}/${name}.log"
  else
    bash -lc "$*" 2>&1 | tee -a "${EDIR_TMP}/${name}.log" | tee -a "${EDIR_REPO}/${name}.log"
  fi
  local status=${PIPESTATUS[0]}
  set -e
  echo "[${name}] END   $(date -Iseconds) (status=${status})" | tee -a "${EDIR_TMP}/${name}.log" | tee -a "${EDIR_REPO}/${name}.log"
  return ${status}
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
  # Check 1: GOOGLE_APPLICATION_CREDENTIALS file
  if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
    return 0
  fi
  # Check 2: gcloud ADC
  if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    return 0
  fi
  # Check 3: firebase projects:list (tests firebase auth)
  if (cd "${PROJECT_ROOT}/source" && (command -v firebase >/dev/null 2>&1 && firebase projects:list || npx -y firebase-tools projects:list) >/dev/null 2>&1); then
    return 0
  fi
  return 1
}

env_status=0
gate_status=0
build_status=0
tests_status=0
deploy_status=0

echo "==== RELEASE GATE ===="
echo "Timestamp: ${TS}"
echo "Evidence: ${EDIR_REPO}"

# 1) ENV_GATE
log_pair env "bash '${PROJECT_ROOT}/tools/env_gate.sh'" || env_status=$?
if [ "${env_status}" -ne 0 ]; then
  echo "NO-GO (ENV_BLOCKER) (env_exit=${env_status})" | tee "${EDIR_TMP}/status.txt" | tee "${EDIR_REPO}/status.txt"
  exit 1
fi

# 2) PHASE 3 Gate
log_pair gate "bash '${PROJECT_ROOT}/tools/phase3_gate.sh'" || gate_status=$?
if [ "${gate_status}" -ne 0 ]; then
  echo "NO-GO (GATE_BLOCKER) (gate_exit=${gate_status})" | tee "${EDIR_TMP}/status.txt" | tee "${EDIR_REPO}/status.txt"
  exit 1
fi

# 3) Backend build
log_pair build "cd '${BACKEND_DIR}' && npm run build" || build_status=$?
if [ "${build_status}" -ne 0 ]; then
  echo "NO-GO (BUILD_BLOCKER) (build_exit=${build_status})" | tee "${EDIR_TMP}/status.txt" | tee "${EDIR_REPO}/status.txt"
  exit 1
fi

# 4) Full tests
log_pair tests "cd '${BACKEND_DIR}' && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=urbangenspark-test GOOGLE_CLOUD_PROJECT=urbangenspark-test npm run test:ci" || tests_status=$?
if [ "${tests_status}" -ne 0 ]; then
  echo "NO-GO (TEST_BLOCKER) (tests_exit=${tests_status})" | tee "${EDIR_TMP}/status.txt" | tee "${EDIR_REPO}/status.txt"
  exit 1
fi

# 5) Deploy dry-run (optional, skipped if no cloud credentials)
deploy_mode="NORMAL"
if detect_credentials; then
  log_pair deploy "cd '${PROJECT_ROOT}/source' && (command -v firebase >/dev/null 2>&1 && firebase deploy --only functions --config firebase.json --dry-run || npx -y firebase-tools deploy --only functions --config firebase.json --dry-run)" || deploy_status=$?
  if [ "${deploy_status}" -ne 0 ]; then
    echo "NO-GO (DEPLOY_BLOCKER) (deploy_exit=${deploy_status})" | tee "${EDIR_TMP}/status.txt" | tee "${EDIR_REPO}/status.txt"
    # Continue to produce meta.json
  fi

  # Semantic deploy check for auth/perm blockers (even if exit 0)
  deploy_blocker_line=""
  if [ -f "${EDIR_TMP}/deploy.log" ]; then
    if ! deploy_semantic_fail "${EDIR_TMP}/deploy.log"; then
      deploy_status=97
      deploy_blocker_line=$(grep "BLOCKER_DEPLOY_AUTH" "${EDIR_TMP}/deploy.log" | head -n 1 || true)
      # mirror blocker line into repo copy
      if [ -n "${deploy_blocker_line}" ]; then
        echo "${deploy_blocker_line}" | tee -a "${EDIR_REPO}/deploy.log" >/dev/null
      fi
    fi
  fi
else
  # No cloud credentials detected - skip deploy gracefully
  deploy_mode="SKIPPED"
  deploy_status=0
  {
    echo "[deploy] START $(date -Iseconds)" | tee -a "${EDIR_TMP}/deploy.log" | tee -a "${EDIR_REPO}/deploy.log"
    echo "DEPLOY_MODE=SKIPPED" | tee -a "${EDIR_TMP}/deploy.log" | tee -a "${EDIR_REPO}/deploy.log"
    echo "DEPLOY_SKIPPED_NO_CREDENTIALS: Local/CI mode" | tee -a "${EDIR_TMP}/deploy.log" | tee -a "${EDIR_REPO}/deploy.log"
    echo "[deploy] END   $(date -Iseconds) (status=0)" | tee -a "${EDIR_TMP}/deploy.log" | tee -a "${EDIR_REPO}/deploy.log"
  } >/dev/null
fi

# Status & meta
final_status="GO"
if [ "${deploy_status}" -eq 97 ]; then
  final_status="NO-GO (DEPLOY_AUTH_BLOCKER)"
elif [ "${deploy_status}" -ne 0 ]; then
  final_status="NO-GO (DEPLOY_BLOCKER)"
fi

echo "${final_status} (env_exit=${env_status} gate_exit=${gate_status} build_exit=${build_status} tests_exit=${tests_status} deploy_exit=${deploy_status} deploy_mode=${deploy_mode})" | tee "${EDIR_TMP}/status.txt" | tee "${EDIR_REPO}/status.txt"

{
  echo "{"
  echo "  \"timestamp\": \"$(date -Iseconds)\"," 
  echo "  \"pwd\": \"$(pwd)\"," 
  echo "  \"git_sha\": \"$(git rev-parse HEAD 2>/dev/null || echo NOGIT)\"," 
  echo "  \"node\": \"$(node -v)\"," 
  echo "  \"npm\": \"$(npm -v)\"," 
  echo "  \"java\": \"$(java -version 2>&1 | head -n 1)\"," 
  echo "  \"env_exit\": ${env_status},"
  echo "  \"gate_exit\": ${gate_status},"
  echo "  \"build_exit\": ${build_status},"
  echo "  \"tests_exit\": ${tests_status},"
  echo "  \"deploy_exit\": ${deploy_status},"
  echo "  \"deploy_mode\": \"${deploy_mode}\""
  echo "}"
} | tee "${EDIR_TMP}/meta.json" | tee "${EDIR_REPO}/meta.json"

echo "==== RELEASE GATE DONE ===="
echo "Evidence: ${EDIR_REPO}"
echo "Status: ${final_status}"

if [[ "${final_status}" == GO* ]]; then
  exit 0
else
  exit 1
fi
