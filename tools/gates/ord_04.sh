#!/usr/bin/env bash
set -euo pipefail

# ORD-04: Redeem QR end-to-end (Customer)
# Stub gate: checks for QR generation and redemption flow

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-04: Redeem QR End-to-End ==="
echo "Checking for QR generation and redemption..."

# Check QR token generation backend
if [ -f "source/backend/firebase-functions/src/core/qr.ts" ]; then
  if grep -q "generateSecureQRToken\|coreGenerateSecureQRToken" "source/backend/firebase-functions/src/core/qr.ts"; then
    echo "✓ QR token generation found"
  else
    echo "✗ QR token generation function missing"
    exit 1
  fi
else
  echo "✗ QR module missing"
  exit 1
fi

# Check redemption backend
if [ -f "source/backend/firebase-functions/src/core/points.ts" ]; then
  if grep -q "processRedemption\|coreValidateRedemption" "source/backend/firebase-functions/src/core/points.ts"; then
    echo "✓ Redemption logic found"
  else
    echo "✗ Redemption logic missing"
    exit 1
  fi
else
  echo "✗ Points module missing"
  exit 1
fi

# Check customer app QR display
if [ -f "source/apps/mobile-customer/lib/screens/offer_detail_screen.dart" ]; then
  echo "✓ Customer QR display screen found"
else
  echo "✗ Customer QR display screen missing"
  exit 1
fi

echo ""
echo "✓ ORD-04 checks passed (stub gate)"
exit 0
