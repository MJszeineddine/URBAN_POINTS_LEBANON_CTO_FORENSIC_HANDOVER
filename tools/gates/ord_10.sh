#!/usr/bin/env bash
set -euo pipefail

# ORD-10: Subscriptions + Entitlements
# Stub gate: checks for subscription logic

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-10: Subscriptions + Entitlements ==="
echo "Checking for subscription infrastructure..."

# Check subscription automation
if [ -f "source/backend/firebase-functions/src/subscriptionAutomation.ts" ]; then
  echo "✓ Subscription automation found"
else
  echo "✗ Subscription automation missing"
  exit 1
fi

# Check stripe integration
if [ -f "source/backend/firebase-functions/src/stripe.ts" ]; then
  echo "✓ Stripe integration found"
else
  echo "✗ Stripe integration missing"
  exit 1
fi

echo ""
echo "✓ ORD-10 checks passed (stub gate)"
exit 0
