#!/usr/bin/env bash
# Stripe Client Phase Gate - Non-PTY, hard timeout evidence collector

set -euo pipefail

# Change to repo root
cd /Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER

PROJECT_ROOT="$PWD"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
GATE_NAME="stripe_client_phase_gate"
EVIDENCE_DIR="$PROJECT_ROOT/docs/evidence/production_gate/${TIMESTAMP}/${GATE_NAME}"

mkdir -p "$EVIDENCE_DIR"

EXECUTION_LOG="$EVIDENCE_DIR/EXECUTION_LOG.md"
VERDICT_FILE="$EVIDENCE_DIR/FINAL_STRIPE_CLIENT_GATE.md"

# Apps
CUSTOMER_APP="$PROJECT_ROOT/source/apps/mobile-customer"
MERCHANT_APP="$PROJECT_ROOT/source/apps/mobile-merchant"

# Hard timeout runner
# Usage: hard_timeout <seconds> <log_prefix> <command ...>
hard_timeout() {
  local timeout_seconds=$1
  shift
  local log_prefix=$1
  shift

  local out_log="$EVIDENCE_DIR/${log_prefix}.out.log"
  local err_log="$EVIDENCE_DIR/${log_prefix}.err.log"
  local exit_code_file="$EVIDENCE_DIR/${log_prefix}.exitcode"

  (
    "$@" >"${out_log}" 2>"${err_log}"
    echo $? >"${exit_code_file}"
  ) &

  local cmd_pid=$!

  (
    sleep "${timeout_seconds}" || true
    if kill -0 "${cmd_pid}" 2>/dev/null; then
      echo "TIMEOUT_KILL after ${timeout_seconds}s" >>"${err_log}"
      kill -9 "${cmd_pid}" 2>/dev/null || true
      echo "124" >"${exit_code_file}"
    fi
  ) &
  local killer_pid=$!

  wait "${cmd_pid}" 2>/dev/null || true
  kill -9 "${killer_pid}" 2>/dev/null || true

  if [[ -f "${exit_code_file}" ]]; then
    return $(cat "${exit_code_file}")
  else
    return 1
  fi
}

# Header
cat >"${EXECUTION_LOG}" <<EOF
# Stripe Client Phase Gate - Execution Log

**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}
**Evidence Directory**: ${EVIDENCE_DIR}

## Commands Executed
EOF

# 1) Flutter version
{
  echo "\n### 1. Flutter Version" >>"${EXECUTION_LOG}"
  echo '```bash' >>"${EXECUTION_LOG}"
  echo "flutter --version" >>"${EXECUTION_LOG}"
  echo '```' >>"${EXECUTION_LOG}"
  if hard_timeout 60 "flutter_version" flutter --version; then
    echo "**Status**: ✅" >>"${EXECUTION_LOG}"
    cat "${EVIDENCE_DIR}/flutter_version.out.log" >>"${EXECUTION_LOG}"
  else
    echo "**Status**: ❌" >>"${EXECUTION_LOG}"
    cat "${EVIDENCE_DIR}/flutter_version.err.log" >>"${EXECUTION_LOG}"
  fi
} >>"${EXECUTION_LOG}"

# 2) Git head (best effort)
{
  echo "\n### 2. Git HEAD" >>"${EXECUTION_LOG}"
  echo '```bash' >>"${EXECUTION_LOG}"
  echo "git rev-parse HEAD" >>"${EXECUTION_LOG}"
  echo '```' >>"${EXECUTION_LOG}"
  if hard_timeout 10 "git_head" git rev-parse HEAD; then
    echo "**Status**: ✅" >>"${EXECUTION_LOG}"
    cat "${EVIDENCE_DIR}/git_head.out.log" >>"${EXECUTION_LOG}"
  else
    echo "**Status**: ⚠️ (git not available)" >>"${EXECUTION_LOG}"
    cat "${EVIDENCE_DIR}/git_head.err.log" >>"${EXECUTION_LOG}"
  fi
} >>"${EXECUTION_LOG}"

run_flutter_steps() {
  local app_path=$1
  local app_name=$2

  echo "\n### ${app_name}: flutter pub get" >>"${EXECUTION_LOG}"
  echo '```bash' >>"${EXECUTION_LOG}"
  echo "(cd ${app_path} && flutter pub get)" >>"${EXECUTION_LOG}"
  echo '```' >>"${EXECUTION_LOG}"
  if hard_timeout 300 "${app_name}_pub_get" bash -c "cd ${app_path} && flutter pub get"; then
    echo "**Status**: ✅" >>"${EXECUTION_LOG}"
  else
    echo "**Status**: ❌" >>"${EXECUTION_LOG}"
    cat "${EVIDENCE_DIR}/${app_name}_pub_get.err.log" >>"${EXECUTION_LOG}"
  fi

  echo "\n### ${app_name}: flutter analyze" >>"${EXECUTION_LOG}"
  echo '```bash' >>"${EXECUTION_LOG}"
  echo "(cd ${app_path} && flutter analyze --no-fatal-infos --no-fatal-warnings)" >>"${EXECUTION_LOG}"
  echo '```' >>"${EXECUTION_LOG}"
  if hard_timeout 300 "${app_name}_analyze" bash -c "cd ${app_path} && flutter analyze --no-fatal-infos --no-fatal-warnings"; then
    echo "**Status**: ✅" >>"${EXECUTION_LOG}"
  else
    echo "**Status**: ❌" >>"${EXECUTION_LOG}"
    cat "${EVIDENCE_DIR}/${app_name}_analyze.err.log" >>"${EXECUTION_LOG}"
  fi
}

run_flutter_steps "$CUSTOMER_APP" "customer"
run_flutter_steps "$MERCHANT_APP" "merchant"

# SHA256 sums
(
  cd "$EVIDENCE_DIR"
  find . -type f | sort | xargs shasum -a 256 >SHA256SUMS.txt
)

echo "\n### Evidence Integrity" >>"${EXECUTION_LOG}"
echo "SHA256SUMS.txt generated" >>"${EXECUTION_LOG}"

# Verdict
customer_analyze_errors=$(grep -c "error •" "${EVIDENCE_DIR}/customer_analyze.out.log" 2>/dev/null || true)
merchant_analyze_errors=$(grep -c "error •" "${EVIDENCE_DIR}/merchant_analyze.out.log" 2>/dev/null || true)
customer_analyze_exit=$(cat "${EVIDENCE_DIR}/customer_analyze.exitcode" 2>/dev/null || echo 1)
merchant_analyze_exit=$(cat "${EVIDENCE_DIR}/merchant_analyze.exitcode" 2>/dev/null || echo 1)
customer_pub_exit=$(cat "${EVIDENCE_DIR}/customer_pub_get.exitcode" 2>/dev/null || echo 1)
merchant_pub_exit=$(cat "${EVIDENCE_DIR}/merchant_pub_get.exitcode" 2>/dev/null || echo 1)

pass_conditions=(
  "$customer_analyze_errors" = "0"
  "$merchant_analyze_errors" = "0"
  "$customer_analyze_exit" = "0"
  "$merchant_analyze_exit" = "0"
  "$customer_pub_exit" = "0"
  "$merchant_pub_exit" = "0"
)

verdict="NO GO"
if [[ ${customer_analyze_errors} -eq 0 && ${merchant_analyze_errors} -eq 0 \
  && ${customer_analyze_exit} -eq 0 && ${merchant_analyze_exit} -eq 0 \
  && ${customer_pub_exit} -eq 0 && ${merchant_pub_exit} -eq 0 ]]; then
  verdict="GO"
fi

cat >"${VERDICT_FILE}" <<EOF
# Stripe Client Phase Gate - FINAL VERDICT

**Timestamp**: ${TIMESTAMP}
**Gate**: ${GATE_NAME}

### VERDICT: ${verdict}

- Flutter version: $(head -1 "${EVIDENCE_DIR}/flutter_version.out.log" 2>/dev/null || echo 'unknown')
- customer flutter analyze errors: ${customer_analyze_errors}
- merchant flutter analyze errors: ${merchant_analyze_errors}
- Evidence: ${EVIDENCE_DIR}

## Next Steps
- Inspect flutter analyze logs for warnings; ensure no "error •" entries.
- If verdict is NO GO, fix issues and rerun gate.
EOF

echo ""
echo "Evidence: ${EVIDENCE_DIR}"
echo "Verdict: ${verdict}"
echo "Log: ${EXECUTION_LOG}"
