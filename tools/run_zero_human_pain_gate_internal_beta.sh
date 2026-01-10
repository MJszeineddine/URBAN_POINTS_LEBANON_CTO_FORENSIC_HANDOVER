#!/usr/bin/env bash
# ZERO_HUMAN_PAIN_GATE - Internal Beta Runner (PATH A)
# Fully automated + headless + deterministic + zero manual steps
# Exit codes: 0 (GO), 1 (NO_GO), 2 (timeout)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TS="$(date -u +"%Y%m%dT%H%M%SZ")"
EVIDENCE_ROOT="$REPO_ROOT/docs/evidence/zero_human_pain_gate"
EVIDENCE_DIR="$EVIDENCE_ROOT/$TS"

mkdir -p "$EVIDENCE_DIR"

EMULATOR_LOG="$EVIDENCE_DIR/firebase_emulator.log"
WRAPPER_LOG="$EVIDENCE_DIR/internal_beta_wrapper_output.log"
EMULATOR_PID_FILE="$REPO_ROOT/.firebase_emulator.pid"

cleanup() {
  echo ""
  echo "▶ Cleanup: Stopping Firebase Emulator..."
  if [ -f "$EMULATOR_PID_FILE" ]; then
    EMULATOR_PID=$(cat "$EMULATOR_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$EMULATOR_PID" ]; then
      kill "$EMULATOR_PID" 2>/dev/null || true
      sleep 1
      kill -9 "$EMULATOR_PID" 2>/dev/null || true
    fi
    rm -f "$EMULATOR_PID_FILE"
  fi
  pkill -f "firebase emulators:start" 2>/dev/null || true
  for port in 8080 9099 4400; do
    lsof -ti:$port 2>/dev/null | xargs kill -9 2>/dev/null || true
  done
}

trap cleanup EXIT

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║      ZERO_HUMAN_PAIN_GATE - Internal Beta (PATH A: Headless + Auto)       ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Timestamp: $TS"
echo "Evidence: $EVIDENCE_DIR"
echo ""

echo "▶ PREFLIGHT: Checking Firebase CLI..."
if ! command -v firebase &> /dev/null; then
  echo "❌ Firebase CLI not found"
  { echo "# NO_GO: Firebase CLI Missing"; echo ""; echo "**VERDICT: NO_GO ❌**"; } > "$EVIDENCE_DIR/NO_GO_FIREBASE_CLI_MISSING.md"
  (cd "$EVIDENCE_DIR" && find . -type f ! -name SHA256SUMS.txt -exec shasum -a 256 {} \; | sort > SHA256SUMS.txt)
  exit 1
fi
echo "✅ Firebase CLI found: $(firebase --version 2>/dev/null)"
echo ""

echo "▶ Cleaning ports..."
pkill -f "firebase emulators:start" 2>/dev/null || true
for port in 8080 9099 4400; do
  lsof -ti:$port 2>/dev/null | xargs kill -9 2>/dev/null || true
done
sleep 2
echo "✅ Ports cleared"
echo ""

echo "▶ Starting Firebase Emulator..."
echo "   Services: firestore, auth"
echo "   Log: $EMULATOR_LOG"
cd "$REPO_ROOT"
firebase emulators:start --only firestore,auth --project demo-zero-human-pain > "$EMULATOR_LOG" 2>&1 &
EMULATOR_PID=$!
echo "$EMULATOR_PID" > "$EMULATOR_PID_FILE"
echo "   PID: $EMULATOR_PID"
echo ""

echo "▶ Waiting for emulator (max 120s)..."
TIMEOUT=120
ELAPSED=0
emulator_ready=false
while [ $ELAPSED -lt $TIMEOUT ]; do
  if grep -q "All emulators ready" "$EMULATOR_LOG" 2>/dev/null; then
    emulator_ready=true
    echo "✅ Emulator ready after ${ELAPSED}s"
    grep -A 5 "Host:Port" "$EMULATOR_LOG" 2>/dev/null | grep -E "(Firestore|Auth)" || true
    if nc -z -w 2 localhost 8080 2>/dev/null && nc -z -w 2 localhost 9099 2>/dev/null; then
      echo "✅ Confirmed ports: 8080 (Firestore), 9099 (Auth)"
    fi
    break
  fi
  if ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
    echo "❌ Emulator died"
    break
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  [ $((ELAPSED % 10)) -eq 0 ] && echo "   Waiting... ($ELAPSED/$TIMEOUT)"
done

if [ "$emulator_ready" = false ]; then
  echo "❌ Emulator timeout"
  { echo "# NO_GO: Emulator Timeout"; echo ""; echo "**VERDICT: NO_GO ❌**"; echo ""; echo "## Emulator Start Timeout"; echo ""; echo "\`\`\`"; tail -50 "$EMULATOR_LOG" 2>/dev/null; echo "\`\`\`"; } > "$EVIDENCE_DIR/NO_GO_EMULATOR_START_TIMEOUT.md"
  (cd "$EVIDENCE_DIR" && find . -type f ! -name SHA256SUMS.txt -exec shasum -a 256 {} \; | sort > SHA256SUMS.txt)
  exit 1
fi

echo ""
echo "▶ Running wrapper..."
sleep 3
GATE_EXIT_CODE=0
bash "$REPO_ROOT/tools/run_zero_human_pain_gate_wrapper.sh" > "$WRAPPER_LOG" 2>&1 || GATE_EXIT_CODE=$?
echo "   Exit code: $GATE_EXIT_CODE"
echo ""

echo "▶ Results:"
LATEST=$(find "$EVIDENCE_ROOT" -maxdepth 1 -type d -name "202*" 2>/dev/null | sort | tail -n 1)
if [ -n "$LATEST" ]; then
  echo "Evidence: $LATEST"
  ls -lh "$LATEST/" 2>/dev/null || true
  echo ""
  VERDICT=$(find "$LATEST" -maxdepth 1 -name "*.md" -type f 2>/dev/null | head -1)
  if [ -n "$VERDICT" ]; then
    echo "═══ VERDICT: $(basename "$VERDICT") ═══"
    cat "$VERDICT"
    echo "═══════════════════════════════════════"
  fi
fi

(cd "$EVIDENCE_DIR" && find . -type f ! -name SHA256SUMS.txt -exec shasum -a 256 {} \; | sort > SHA256SUMS.txt)
echo ""
echo "Exit Code: $GATE_EXIT_CODE"
exit "$GATE_EXIT_CODE"
