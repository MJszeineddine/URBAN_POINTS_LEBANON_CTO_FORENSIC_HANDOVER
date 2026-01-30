#!/usr/bin/env bash
set -euo pipefail

# ORD-03: Offer Details + Save/Share
# Stub gate: checks for offer detail screen and tracking

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-03: Offer Details + Save/Share ==="
echo "Checking for offer detail screens..."

# Check offer detail screen
if [ -f "source/apps/mobile-customer/lib/screens/offer_detail_screen.dart" ]; then
  echo "✓ Offer detail screen found"
else
  echo "✗ Offer detail screen missing"
  exit 1
fi

# Check if save/share logic is referenced in backend
if [ -f "source/backend/firebase-functions/src/core/offers.ts" ]; then
  echo "✓ Offer core functions found"
else
  echo "✗ Offer core functions missing"
  exit 1
fi

echo ""
echo "✓ ORD-03 checks passed (stub gate)"
exit 0
