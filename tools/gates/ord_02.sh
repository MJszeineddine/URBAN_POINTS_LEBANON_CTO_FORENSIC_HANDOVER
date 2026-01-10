#!/usr/bin/env bash
set -euo pipefail

# ORD-02: Customer Core Navigation + Home Feed
# Stub gate: checks for customer app home/navigation screens

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-02: Customer Core Navigation ==="
echo "Checking for home feed and navigation screens..."

# Check mobile customer home/feed screens
if [ -f "source/apps/mobile-customer/lib/screens/home_screen.dart" ] || [ -f "source/apps/mobile-customer/lib/screens/offers_list_screen.dart" ]; then
  echo "✓ Customer home/offers screen found"
else
  echo "✗ Customer home/offers screen missing"
  exit 1
fi

# Check navigation routing
if [ -f "source/apps/mobile-customer/lib/main.dart" ]; then
  echo "✓ Main app file found"
else
  echo "✗ Main app file missing"
  exit 1
fi

echo ""
echo "✓ ORD-02 checks passed (stub gate)"
exit 0
