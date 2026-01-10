#!/usr/bin/env bash
set -euo pipefail

# ORD-05: Wallet / Points / Transactions
# Stub gate: checks for points balance and transaction history

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-05: Wallet / Points / Transactions ==="
echo "Checking for points and wallet functionality..."

# Check points backend
if [ -f "source/backend/firebase-functions/src/core/points.ts" ]; then
  if grep -q "getPointsBalance\|processRedemption" "source/backend/firebase-functions/src/core/points.ts"; then
    echo "✓ Points backend functions found"
  else
    echo "✗ Points backend functions missing"
    exit 1
  fi
else
  echo "✗ Points module missing"
  exit 1
fi

# Check customer points screens
if [ -f "source/apps/mobile-customer/lib/screens/points_history_screen.dart" ] || [ -f "source/apps/mobile-customer/lib/screens/points_history_screen_v2.dart" ]; then
  echo "✓ Points history screen found"
else
  echo "✗ Points history screen missing"
  exit 1
fi

echo ""
echo "✓ ORD-05 checks passed (stub gate)"
exit 0
