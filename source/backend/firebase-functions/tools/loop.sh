#!/usr/bin/env bash
set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
ROOT="/home/user/urbanpoints-lebanon-complete-ecosystem/backend/firebase-functions"
ART="/home/user/ARTIFACTS"
LOG="$ART/COMMAND_LOGS"
mkdir -p "$LOG" "$ART/COVERAGE"

cd "$ROOT"

echo "TS=$TS" | tee "$LOG/${TS}_meta.log"

# Run tests+coverage (using existing emulator setup in tests)
TESTLOG="$LOG/${TS}_tests.log"
COVLOG="$LOG/${TS}_coverage.log"
npm test -- --coverage --runInBand 2>&1 | tee "$TESTLOG"

# Copy coverage folder snapshot
if [ -d "$ROOT/coverage" ]; then
  cp -R "$ROOT/coverage" "$ART/COVERAGE/$TS" 2>&1 | tee "$LOG/${TS}_coverage_copy.log" || true
fi

# Dump coverage totals
node - <<'NODE' 2>&1 | tee "$COVLOG"
const fs=require('fs');
const p='./coverage/coverage-summary.json';
if (fs.existsSync(p)) {
  const s=JSON.parse(fs.readFileSync(p,'utf8')).total;
  console.log(JSON.stringify(s,null,2));
  process.exit(0);
}
console.log("NO coverage-summary.json found; relying on jest stdout in tests log.");
NODE

# Save diff evidence
git status --porcelain 2>&1 | tee "$LOG/${TS}_git_status.log" || true
git diff 2>&1 | tee "$LOG/${TS}_git_diff.patch" || true

echo "LOOP COMPLETE: TS=$TS" | tee -a "$LOG/${TS}_meta.log"
