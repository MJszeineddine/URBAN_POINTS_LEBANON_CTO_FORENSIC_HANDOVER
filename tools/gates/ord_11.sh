#!/usr/bin/env bash
set -euo pipefail

# ORD-11: Payments (Stripe test mode) + Webhooks
# Stub gate: checks for payment webhook handling

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-11: Payments (Stripe test mode) + Webhooks ==="
echo "Checking for payment webhooks..."

# Check payment webhooks
if [ -f "source/backend/firebase-functions/src/paymentWebhooks.ts" ]; then
  echo "✓ Payment webhooks module found"
else
  echo "✗ Payment webhooks module missing"
  exit 1
fi

# Check stripe integration
if [ -f "source/backend/firebase-functions/src/stripe.ts" ]; then
  if grep -q "stripe\|STRIPE_KEY" "source/backend/firebase-functions/src/stripe.ts"; then
    echo "✓ Stripe configuration found"
  else
    echo "✗ Stripe configuration missing"
    exit 1
  fi
else
  echo "✗ Stripe module missing"
  exit 1
fi

echo ""
echo "✓ ORD-11 checks passed (stub gate)"
exit 0
