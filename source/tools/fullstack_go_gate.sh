#!/bin/bash
# Full-Stack GO Gate Script
# Phase 6 Consolidation
# Runs all critical gates and produces final verdict

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ROOT="/home/user/urbanpoints-lebanon-complete-ecosystem"
ARTIFACTS="/home/user/ARTIFACTS/FS_GO"
LOG_FILE="$ARTIFACTS/logs/${TIMESTAMP}_fullstack_go_gate.log"

echo "=== FULL-STACK GO GATE ===" | tee -a "$LOG_FILE"
echo "Timestamp: $(date -Iseconds)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Track results
RESULTS=()

# GATE 1: Backend Tests + Coverage
echo "[1/4] Backend Tests + Coverage..." | tee -a "$LOG_FILE"
cd "$ROOT/backend/firebase-functions"
if npm test -- --coverage --runInBand >> "$LOG_FILE" 2>&1; then
  RESULTS+=("backend:PASS")
  echo "✅ Backend PASS" | tee -a "$LOG_FILE"
else
  RESULTS+=("backend:FAIL")
  echo "❌ Backend FAIL" | tee -a "$LOG_FILE"
fi

# GATE 2: Flutter Customer
echo "[2/4] Flutter Customer..." | tee -a "$LOG_FILE"
cd "$ROOT/apps/mobile-customer"
flutter analyze >> "$LOG_FILE" 2>&1 || true  # Warnings OK
if flutter test >> "$LOG_FILE" 2>&1; then
  RESULTS+=("flutter_customer:PASS")
  echo "✅ Flutter Customer PASS" | tee -a "$LOG_FILE"
else
  RESULTS+=("flutter_customer:FAIL")
  echo "❌ Flutter Customer FAIL" | tee -a "$LOG_FILE"
fi

# GATE 3: Flutter Merchant
echo "[3/4] Flutter Merchant..." | tee -a "$LOG_FILE"
cd "$ROOT/apps/mobile-merchant"
flutter analyze >> "$LOG_FILE" 2>&1 || true  # Warnings OK
if flutter test >> "$LOG_FILE" 2>&1; then
  RESULTS+=("flutter_merchant:PASS")
  echo "✅ Flutter Merchant PASS" | tee -a "$LOG_FILE"
else
  RESULTS+=("flutter_merchant:FAIL")
  echo "❌ Flutter Merchant FAIL" | tee -a "$LOG_FILE"
fi

# GATE 4: Web Admin Build (optional)
echo "[4/4] Web Admin Build..." | tee -a "$LOG_FILE"
cd "$ROOT/apps/web-admin"
if [ -d "pages" ] || [ -d "app" ]; then
  if npm run build >> "$LOG_FILE" 2>&1; then
    RESULTS+=("web_admin:PASS")
    echo "✅ Web Admin PASS" | tee -a "$LOG_FILE"
  else
    RESULTS+=("web_admin:FAIL")
    echo "❌ Web Admin FAIL" | tee -a "$LOG_FILE"
  fi
else
  RESULTS+=("web_admin:SKIP")
  echo "⏭️  Web Admin SKIP (no pages/app dir)" | tee -a "$LOG_FILE"
fi

# Summary
echo "" | tee -a "$LOG_FILE"
echo "=== RESULTS ===" | tee -a "$LOG_FILE"
for result in "${RESULTS[@]}"; do
  echo "$result" | tee -a "$LOG_FILE"
done

# Check overall status
if echo "${RESULTS[@]}" | grep -q "FAIL"; then
  echo "" | tee -a "$LOG_FILE"
  echo "VERDICT: NO-GO" | tee -a "$LOG_FILE"
  exit 1
else
  echo "" | tee -a "$LOG_FILE"
  echo "VERDICT: GO" | tee -a "$LOG_FILE"
  exit 0
fi
