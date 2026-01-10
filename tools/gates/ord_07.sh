#!/usr/bin/env bash
set -euo pipefail

# ORD-07: Merchant Offer Management (Minimal)
# Stub gate: checks for merchant offer creation screen

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-07: Merchant Offer Management ==="
echo "Checking for merchant offer creation..."

# Check merchant app create offer screen
if [ -f "source/apps/mobile-merchant/lib/screens/create_offer_screen.dart" ]; then
  echo "✓ Merchant create offer screen found"
else
  echo "✗ Merchant create offer screen missing"
  exit 1
fi

# Check offer creation backend
if [ -f "source/backend/firebase-functions/src/core/offers.ts" ]; then
  if grep -q "createOffer" "source/backend/firebase-functions/src/core/offers.ts"; then
    echo "✓ Offer creation backend found"
  else
    echo "✗ Offer creation backend missing"
    exit 1
  fi
else
  echo "✗ Offers module missing"
  exit 1
fi

echo ""
echo "✓ ORD-07 checks passed (stub gate)"
exit 0
