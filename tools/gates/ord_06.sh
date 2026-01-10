#!/usr/bin/env bash
set -euo pipefail

# ORD-06: Merchant Scan + Validate Redeem
# Stub gate: checks for merchant QR scanner and validation

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-06: Merchant Scan + Validate Redeem ==="
echo "Checking for merchant scanner and validation..."

# Check merchant app QR scanner
if [ -f "source/apps/mobile-merchant/lib/screens/qr_scanner_screen.dart" ]; then
  echo "✓ Merchant QR scanner screen found"
else
  echo "✗ Merchant QR scanner screen missing"
  exit 1
fi

# Check PIN validation backend
if [ -f "source/backend/firebase-functions/src/core/qr.ts" ]; then
  if grep -q "coreValidatePIN\|validatePIN" "source/backend/firebase-functions/src/core/qr.ts"; then
    echo "✓ PIN validation logic found"
  else
    echo "✗ PIN validation logic missing"
    exit 1
  fi
else
  echo "✗ QR module missing"
  exit 1
fi

echo ""
echo "✓ ORD-06 checks passed (stub gate)"
exit 0
