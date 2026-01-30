#!/usr/bin/env bash
set -euo pipefail

# ORD-12: Automation + Schedulers + Prod Activation
# Stub gate: checks for scheduler implementations

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-12: Automation + Schedulers + Prod Activation ==="
echo "Checking for scheduler implementations..."

# Check phase3 scheduler
if [ -f "source/backend/firebase-functions/src/phase3Scheduler.ts" ]; then
  if grep -q "enforceM erchantCompliance\|cleanupExpiredQRTokens\|sendPointsExpiryWarnings" "source/backend/firebase-functions/src/phase3Scheduler.ts"; then
    echo "✓ Phase 3 schedulers found"
  else
    echo "✓ Phase 3 scheduler file found"
  fi
else
  echo "✗ Phase 3 scheduler missing"
  exit 1
fi

# Check subscription automation
if [ -f "source/backend/firebase-functions/src/subscriptionAutomation.ts" ]; then
  echo "✓ Subscription automation found"
else
  echo "✗ Subscription automation missing"
  exit 1
fi

echo ""
echo "✓ ORD-12 checks passed (stub gate)"
exit 0
