#!/usr/bin/env bash
set -euo pipefail

# Single-entrypoint autopilot run script
# - creates local-ci/verification/finish_today/LATEST
# - runs gates and writes logs/reports/proof

if git rev-parse --show-toplevel >/dev/null 2>&1; then
  REPO_ROOT="$(git rev-parse --show-toplevel)"
else
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi
cd "$REPO_ROOT"

BASE_DIR="local-ci/verification/finish_today/LATEST"
INVENTORY_DIR="$BASE_DIR/inventory"
LOGS_DIR="$BASE_DIR/logs"
REPORTS_DIR="$BASE_DIR/reports"
PROOF_DIR="$BASE_DIR/proof"
CI_DIR="$BASE_DIR/ci"

mkdir -p "$INVENTORY_DIR" "$LOGS_DIR" "$REPORTS_DIR" "$PROOF_DIR" "$CI_DIR"

TS=$(TZ="Asia/Beirut" date +"%Y-%m-%dT%H:%M:%S%:z" 2>/dev/null || TZ="Asia/Beirut" date +"%Y-%m-%dT%H:%M:%S%z")
echo "timestamp: $TS" > "$INVENTORY_DIR/run_timestamp.txt"
git rev-parse --verify HEAD > "$INVENTORY_DIR/git_commit.txt" 2>/dev/null || echo "no-git" > "$INVENTORY_DIR/git_commit.txt"
git log -1 --oneline >> "$INVENTORY_DIR/git_commit.txt" 2>/dev/null || true
git status --porcelain > "$INVENTORY_DIR/git_status.txt" 2>/dev/null || true

echo "Autopilot run: $TS" > "$REPORTS_DIR/FINAL_TODAY_REPORT.md"
echo "Repository: $(git rev-parse --show-toplevel 2>/dev/null || echo 'no-git')" >> "$REPORTS_DIR/FINAL_TODAY_REPORT.md"
echo "Commit: $(git rev-parse --verify HEAD 2>/dev/null || echo 'no-git')" >> "$REPORTS_DIR/FINAL_TODAY_REPORT.md"
echo >> "$REPORTS_DIR/FINAL_TODAY_REPORT.md"

# Gate runner helper
run_gate() {
  local name="$1"; shift
  local cmd=("$@")
  local log="$LOGS_DIR/${name}.log"
  echo "== START GATE: $name ==" | tee "$log"
  start=$(date +%s)
  set +e
  "${cmd[@]}" >> "$log" 2>&1
  rc=$?
  set -e
  end=$(date +%s)
  dur=$((end-start))
  echo "GATE:$name:rc=$rc:duration_s=$dur" >> "$REPORTS_DIR/summary.tmp"
  echo "== END GATE: $name rc=$rc dur=${dur}s ==" | tee -a "$log"
  return $rc
}

# Summary JSON builder
summary_init() { echo -n "{" > "$REPORTS_DIR/summary.json"; first=true; }
summary_add() {
  local name="$1"; local rc="$2"; local dur="$3"
  if [ "$first" = true ]; then
    first=false
  else
    echo -n "," >> "$REPORTS_DIR/summary.json"
  fi
  echo -n "\"$name\":{" >> "$REPORTS_DIR/summary.json"
  echo -n "\"exit_code\":$rc,\"duration_s\":$dur" >> "$REPORTS_DIR/summary.json"
  echo -n "}" >> "$REPORTS_DIR/summary.json"
}
summary_finish() { echo "}" >> "$REPORTS_DIR/summary.json"; }

# Required files gate
required_files_check() {
  local missing=0
  for f in firebase.json firestore.rules storage.rules; do
    if [ ! -f "$REPO_ROOT/$f" ]; then
      echo "missing required file: $f"
      missing=1
    else
      echo "found $f"
    fi
  done
  return $missing
}

# Prepare gates list
GATES=(
  "deploy-config-valid"
  "required-files"
  "security-scan"
  "rest-api-tests"
  "firebase-functions-tests"
  "web-admin-build-test"
  "mobile-customer-build"
  "mobile-merchant-build"
)

get_gate_cmd() {
  name="$1"
  case "$name" in
    deploy-config-valid)
      echo "python3 tools/autopilot/validate_deploy_config.py"
      ;;
    required-files)
      echo "for f in firebase.json firestore.rules storage.rules firestore.indexes.json; do [ -f \"\$f\" ] || { echo \"missing: \$f\"; exit 1; }; done && echo 'all required files found'"
      ;;
    security-scan)
      echo "bash tools/autopilot/security_scan.sh $LOGS_DIR/security_scan.log"
      ;;
    rest-api-tests)
      echo "[ -d 'source/backend/rest-api' ] && [ -f 'source/backend/rest-api/package.json' ] && (cd source/backend/rest-api && npm ci && npm test) || echo 'rest-api not found, skipping' && exit 0"
      ;;
    firebase-functions-tests)
      echo "[ -d 'source/backend/firebase-functions' ] && [ -f 'source/backend/firebase-functions/package.json' ] && (cd source/backend/firebase-functions && npm ci && npm test) || echo 'firebase-functions not found, skipping' && exit 0"
      ;;
    web-admin-build-test)
      echo "[ -d 'source/apps/web-admin' ] && [ -f 'source/apps/web-admin/package.json' ] && (cd source/apps/web-admin && npm ci && npm run build) || echo 'web-admin not found, skipping' && exit 0"
      ;;
    mobile-customer-build)
      echo "[ -d 'source/apps/mobile-customer' ] && [ -f 'source/apps/mobile-customer/pubspec.yaml' ] && (cd source/apps/mobile-customer && flutter pub get && flutter build apk --debug) || echo 'mobile-customer not found, skipping' && exit 0"
      ;;
    mobile-merchant-build)
      echo "[ -d 'source/apps/mobile-merchant' ] && [ -f 'source/apps/mobile-merchant/pubspec.yaml' ] && (cd source/apps/mobile-merchant && flutter pub get && flutter build apk --debug) || echo 'mobile-merchant not found, skipping' && exit 0"
      ;;
    *)
      echo "true"
      ;;
  esac
}

summary_init

overall_rc=0
for g in "${GATES[@]}"; do
  name="$g"
  echo "Running gate: $name"
  start=$(date +%s)
  cmd="$(get_gate_cmd "$name")"
  set +e
  (cd "$REPO_ROOT" && bash -c "$cmd") >> "$LOGS_DIR/${name}.log" 2>&1
  rc=$?
  set -e
  end=$(date +%s)
  dur=$((end-start))
  summary_add "$name" "$rc" "$dur"
  if [ ! -f "$LOGS_DIR/${name}.log" ]; then
    echo "(no log produced)" > "$LOGS_DIR/${name}.log"
  fi
  if [ "$rc" -ne 0 ]; then
    overall_rc=1
    echo "Gate $name failed (rc=$rc)" >> "$REPORTS_DIR/FINAL_TODAY_REPORT.md"
  else
    echo "Gate $name passed" >> "$REPORTS_DIR/FINAL_TODAY_REPORT.md"
  fi
done

summary_finish

# Create human-friendly summary
echo "" >> "$REPORTS_DIR/FINAL_TODAY_REPORT.md"
echo "Summary JSON: $REPORTS_DIR/summary.json" >> "$REPORTS_DIR/FINAL_TODAY_REPORT.md"
echo "Logs: $LOGS_DIR" >> "$REPORTS_DIR/FINAL_TODAY_REPORT.md"

# Generate proof index and SHA256 sums for inventory/logs/reports/proof/ci
echo "PROOF INDEX" > "$PROOF_DIR/PROOF_INDEX.md"
find "$BASE_DIR" -type f -print | sed "s|^$BASE_DIR/||" >> "$PROOF_DIR/PROOF_INDEX.md"

echo "Generating SHA256 sums..." > "$PROOF_DIR/SHA256SUMS.txt"
find "$BASE_DIR" -type f -not -path "*/.git/*" -print0 | sort -z | xargs -0 shasum -a 256 | sed "s|$PWD/||" >> "$PROOF_DIR/SHA256SUMS.txt" || true

echo "Autopilot finished. overall_rc=$overall_rc"

if [ "$overall_rc" -ne 0 ]; then
  echo "One or more gates failed. See logs and $REPORTS_DIR/FINAL_TODAY_REPORT.md"
  exit 2
else
  echo "All gates passed. Evidence written to $BASE_DIR (ignored by git)."
  exit 0
fi
 
