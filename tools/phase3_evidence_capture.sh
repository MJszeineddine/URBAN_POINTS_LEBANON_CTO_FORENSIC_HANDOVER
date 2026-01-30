#!/usr/bin/env bash
# Phase 3 evidence capture: gate, tests, deploy (streamed, timed, 0-hang)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/source/backend/firebase-functions"
TS="$(date +%Y%m%d_%H%M%S)"
EDIR_TMP="/tmp/phase3/${TS}"
EDIR_REPO="${PROJECT_ROOT}/docs/parity/evidence/phase3/${TS}"

mkdir -p "${EDIR_TMP}" "${EDIR_REPO}"

ENV_LOG_TMP="${EDIR_TMP}/env.log"
GATE_LOG_TMP="${EDIR_TMP}/gate.log"
TEST_LOG_TMP="${EDIR_TMP}/tests.log"
DEPLOY_LOG_TMP="${EDIR_TMP}/deploy.log"
EMULATOR_LOG_TMP="${EDIR_TMP}/emulator.log"
STATUS_TXT_TMP="${EDIR_TMP}/status.txt"
OUTPUT_MD_TMP="${EDIR_TMP}/OUTPUT.md"
META_JSON_TMP="${EDIR_TMP}/meta.json"

ENV_LOG_REPO="${EDIR_REPO}/env.log"
GATE_LOG_REPO="${EDIR_REPO}/gate.log"
TEST_LOG_REPO="${EDIR_REPO}/tests.log"
DEPLOY_LOG_REPO="${EDIR_REPO}/deploy.log"
EMULATOR_LOG_REPO="${EDIR_REPO}/emulator.log"
STATUS_TXT_REPO="${EDIR_REPO}/status.txt"
OUTPUT_MD_REPO="${EDIR_REPO}/OUTPUT.md"
META_JSON_REPO="${EDIR_REPO}/meta.json"

COMMAND_TIMEOUT_DEFAULT=600
COMMAND_TIMEOUT_GATE=300
COMMAND_TIMEOUT_TESTS=600
COMMAND_TIMEOUT_DEPLOY=600
EMULATOR_TIMEOUT=60

PORTS_TO_KILL=(8080 9150 4400 4000 9099 4500)

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
    ${pycmd} - "$seconds" "$@" <<'PY'
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
  with_timeout "${timeout_secs}" "${runner[@]}" \
    2>&1 | tee -a "${log_tmp}" | tee -a "${log_repo}"
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

kill_ports() {
  for port in "${PORTS_TO_KILL[@]}"; do
    local pids
    pids="$(lsof -ti tcp:"${port}" 2>/dev/null || true)"
    if [ -n "${pids}" ]; then
      echo "[emulator] Killing processes on port ${port}: ${pids}" | tee -a "${EMULATOR_LOG_TMP}" | tee -a "${EMULATOR_LOG_REPO}"
      echo "${pids}" | xargs kill -9 >/dev/null 2>&1 || true
    fi
  done
}

find_firebase_cmd() {
  if command -v firebase >/dev/null 2>&1; then
    echo "firebase"
  else
    echo "npx -y firebase-tools"
  fi
}

start_emulator() {
  export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
  export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
  export GCLOUD_PROJECT=urbangenspark-test
  export GOOGLE_CLOUD_PROJECT=urbangenspark-test

  kill_ports

  local firebase_cmd
  firebase_cmd="$(find_firebase_cmd)"

  echo "[emulator] Starting Firestore emulator via: ${firebase_cmd}" | tee -a "${EMULATOR_LOG_TMP}" | tee -a "${EMULATOR_LOG_REPO}"

  set +e
  (cd "${PROJECT_ROOT}/source" && nohup ${firebase_cmd} emulators:start --only firestore --project urbangenspark-test --config firebase.json >"${EMULATOR_LOG_TMP}" 2>&1 & echo $! >"${EDIR_TMP}/emulator.pid")
  set -e

  if [ ! -f "${EDIR_TMP}/emulator.pid" ]; then
    echo "[emulator] Failed to start emulator (missing pid)" | tee -a "${EMULATOR_LOG_TMP}" | tee -a "${EMULATOR_LOG_REPO}"
    return 1
  fi

  local pid
  pid="$(cat "${EDIR_TMP}/emulator.pid")"

  local waited=0
  while ! nc -z 127.0.0.1 8080 >/dev/null 2>&1; do
    sleep 1
    waited=$((waited + 1))
    if [ "${waited}" -ge "${EMULATOR_TIMEOUT}" ]; then
      echo "[emulator] Timeout waiting for Firestore emulator (pid=${pid})" | tee -a "${EMULATOR_LOG_TMP}" | tee -a "${EMULATOR_LOG_REPO}"
      cat "${EMULATOR_LOG_TMP}" | tee -a "${EMULATOR_LOG_REPO}" || true
      return 1
    fi
  done
  echo "[emulator] Ready after ${waited}s (pid=${pid})" | tee -a "${EMULATOR_LOG_TMP}" | tee -a "${EMULATOR_LOG_REPO}"
}

cleanup() {
  if [ -f "${EDIR_TMP}/emulator.pid" ]; then
    local pid
    pid="$(cat "${EDIR_TMP}/emulator.pid")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      kill "${pid}" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "${pid}" >/dev/null 2>&1 || true
    fi
  fi
  kill_ports || true
}

trap cleanup EXIT

main() {
  echo "=========================================="
  echo "PHASE 3 EVIDENCE CAPTURE"
  echo "Timestamp: ${TS}"
  echo "Evidence: ${EDIR_REPO}"
  echo "=========================================="
  echo ""

  # STEP 1: ENV_GATE
  echo "STEP 1: ENV_GATE"
  local env_status=0
  run_logged env 30 bash "${PROJECT_ROOT}/tools/env_gate.sh" || env_status=$?
  
  if [ "${env_status}" -ne 0 ]; then
    echo "NO-GO (ENV_BLOCKER) (env_exit=${env_status})" | tee "${STATUS_TXT_TMP}" | tee "${STATUS_TXT_REPO}"
    cp "${ENV_LOG_TMP}" "${ENV_LOG_REPO}" >/dev/null 2>&1 || true
    
    # Extract blocker line
    local blocker_line
    blocker_line="$(grep 'BLOCKER_ENV_GATE:' "${ENV_LOG_TMP}" || echo 'Unknown blocker')"
    
    cat > "${OUTPUT_MD_TMP}" <<EOF
# PHASE 3 EXECUTION REPORT

**Timestamp:** $(date "+%Y-%m-%d %H:%M:%S")
**Evidence Dir:** ${EDIR_REPO}

---

## FINAL STATUS

Result: **NO-GO (ENV_BLOCKER)**
Reason: ${blocker_line}

---

## ENV_GATE LOG

\`\`\`
$(cat "${ENV_LOG_TMP}")
\`\`\`

---

Evidence incomplete - execution stopped at ENV_GATE.
EOF
    
    cp "${OUTPUT_MD_TMP}" "${OUTPUT_MD_REPO}"
    
    echo ""
    echo "===== ENV_GATE_LOG ====="
    cat "${ENV_LOG_TMP}"
    echo ""
    echo "BLOCKER: ${blocker_line}"
    exit 1
  fi
  
  echo "ENV_GATE: PASS ✅"
  echo ""

  # STEP 2: Start Emulator
  echo "STEP 2: EMULATOR"
  start_emulator

  # STEP 3: GATE
  echo ""
  echo "STEP 3: PHASE3_GATE"
  local gate_status=0
  run_logged gate "${COMMAND_TIMEOUT_GATE}" bash "${PROJECT_ROOT}/tools/phase3_gate.sh" || gate_status=$?

  # STEP 4: TESTS
  echo ""
  echo "STEP 4: TESTS"
  local tests_status=0
  run_logged tests "${COMMAND_TIMEOUT_TESTS}" bash -lc "cd '${BACKEND_DIR}' && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=urbangenspark-test GOOGLE_CLOUD_PROJECT=urbangenspark-test npm run test:ci" || tests_status=$?

  # STEP 5: DEPLOY DRY-RUN
  echo ""
  echo "STEP 5: DEPLOY DRY-RUN"
  local deploy_status=0
  local deploy_mode="NORMAL"
  
  if detect_credentials; then
    run_logged deploy "${COMMAND_TIMEOUT_DEPLOY}" bash -lc "cd '${PROJECT_ROOT}/source' && $(find_firebase_cmd) deploy --only functions --config firebase.json --dry-run" || deploy_status=$?
    
    # Semantic deploy auth/perm check even if exit code was 0
    local deploy_blocker_line=""
    if [ -f "${DEPLOY_LOG_TMP}" ]; then
      if ! deploy_semantic_fail "${DEPLOY_LOG_TMP}"; then
        deploy_status=97
        deploy_blocker_line=$(grep "BLOCKER_DEPLOY_AUTH" "${DEPLOY_LOG_TMP}" | head -n 1 || true)
        if [ -n "${deploy_blocker_line}" ]; then
          echo "${deploy_blocker_line}" | tee -a "${DEPLOY_LOG_REPO}" >/dev/null
        fi
      fi
    fi
  else
    # No cloud credentials detected - skip deploy gracefully
    deploy_mode="SKIPPED"
    deploy_status=0
    {
      echo "[deploy] START $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "${DEPLOY_LOG_TMP}" | tee -a "${DEPLOY_LOG_REPO}"
      echo "DEPLOY_MODE=SKIPPED" | tee -a "${DEPLOY_LOG_TMP}" | tee -a "${DEPLOY_LOG_REPO}"
      echo "DEPLOY_SKIPPED_NO_CREDENTIALS: Local/CI mode" | tee -a "${DEPLOY_LOG_TMP}" | tee -a "${DEPLOY_LOG_REPO}"
      echo "[deploy] END   $(date -u +%Y-%m-%dT%H:%M:%SZ) (status=0)" | tee -a "${DEPLOY_LOG_TMP}" | tee -a "${DEPLOY_LOG_REPO}"
    } >/dev/null
  fi

  cp "${EMULATOR_LOG_TMP}" "${EMULATOR_LOG_REPO}" >/dev/null 2>&1 || true

  # Generate OUTPUT.md
  local final_status
  local final_reason=""
  
  if [ "${gate_status}" -ne 0 ]; then
    final_status="NO-GO (GATE_BLOCKER)"
    final_reason="Gate checks failed (exit ${gate_status})"
  elif [ "${tests_status}" -ne 0 ]; then
    final_status="NO-GO (TEST_BLOCKER)"
    final_reason="Tests failed (exit ${tests_status})"
  elif [ "${deploy_status}" -eq 97 ]; then
    final_status="NO-GO (DEPLOY_AUTH_BLOCKER)"
    if [ -n "${deploy_blocker_line}" ]; then
      final_reason="Deploy auth blocker: ${deploy_blocker_line}"
    else
      final_reason="Deploy auth blocker detected"
    fi
  elif [ "${deploy_status}" -ne 0 ]; then
    final_status="NO-GO (DEPLOY_BLOCKER)"
    final_reason="Deploy dry-run failed (exit ${deploy_status})"
  else
    final_status="GO"
    final_reason="All checks passed"
  fi

  echo "${final_status} (env_exit=${env_status} gate_exit=${gate_status} tests_exit=${tests_status} deploy_exit=${deploy_status})" | tee "${STATUS_TXT_TMP}" | tee "${STATUS_TXT_REPO}"

  # Write meta.json
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
    echo "  \"tests_exit\": ${tests_status},"
    echo "  \"deploy_exit\": ${deploy_status},"
    echo "  \"deploy_mode\": \"${deploy_mode}\""
    echo "}"
  } | tee "${META_JSON_TMP}" | tee "${META_JSON_REPO}"

  # Extract test results
  local test_summary
  test_summary="$(grep -E 'Test Suites:|Tests:' "${TEST_LOG_TMP}" | tail -2 | tr '\n' ' ' || echo 'N/A')"

  cat > "${OUTPUT_MD_TMP}" <<EOF
# PHASE 3 EXECUTION REPORT

**Timestamp:** $(date "+%Y-%m-%d %H:%M:%S")
**Evidence Dir:** ${EDIR_REPO}

---

## FINAL STATUS

Result: **${final_status}**
Reason: ${final_reason}

---

## ENVIRONMENT (ENV_GATE)

\`\`\`
$(tail -20 "${ENV_LOG_TMP}")
\`\`\`

---

## GATE (phase3_gate.sh)

First 80 lines:
\`\`\`
$(sed -n '1,80p' "${GATE_LOG_TMP}")
\`\`\`

Last 40 lines:
\`\`\`
$(tail -40 "${GATE_LOG_TMP}")
\`\`\`

---

## TESTS (npm run test:ci)

${test_summary}

Last 60 lines:
\`\`\`
$(tail -60 "${TEST_LOG_TMP}")
\`\`\`

---

## DEPLOY (dry-run)

Last 60 lines:
\`\`\`
$(tail -60 "${DEPLOY_LOG_TMP}")
\`\`\`

---

## EVIDENCE FILES

- ${ENV_LOG_REPO}
- ${GATE_LOG_REPO}
- ${TEST_LOG_REPO}
- ${DEPLOY_LOG_REPO}
- ${EMULATOR_LOG_REPO}
- ${STATUS_TXT_REPO}
- ${OUTPUT_MD_REPO}

EOF

  cp "${OUTPUT_MD_TMP}" "${OUTPUT_MD_REPO}"

  echo ""
  echo "=========================================="
  echo "EVIDENCE SUMMARY"
  echo "=========================================="
  echo ""
  echo "===== PHASE3_GATE_FIRST_80 ====="
  sed -n '1,80p' "${GATE_LOG_TMP}"
  echo ""
  echo "===== PHASE3_GATE_LAST_40 ====="
  tail -n 40 "${GATE_LOG_TMP}"
  echo ""
  echo "===== PHASE3_TESTS_LAST_60 ====="
  tail -n 60 "${TEST_LOG_TMP}"
  echo ""
  echo "===== PHASE3_DEPLOY_LAST_60 ====="
  tail -n 60 "${DEPLOY_LOG_TMP}"
  echo ""
  echo "=========================================="
  echo "FINAL STATUS: ${final_status}"
  echo "=========================================="
  echo "Evidence directory: ${EDIR_REPO}"
  echo "OUTPUT.md: ${OUTPUT_MD_REPO}"
  echo "META: ${META_JSON_REPO}"
  echo ""

  if [ "${final_status}" = "GO" ]; then
    exit 0
  else
    exit 1
  fi
}

main "$@"
