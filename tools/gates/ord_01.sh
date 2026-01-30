#!/usr/bin/env bash
set -euo pipefail

# ORD-01: Auth parity (Login/OTP/Sessions)
# Stub gate: checks for auth-related files and functions
# This is a skeleton that can be replaced with real checks

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-01: Auth Parity Check ==="
echo "Checking for auth-related backend functions..."

# Check if auth service exists
if [ -f "source/backend/firebase-functions/src/auth.ts" ]; then
  echo "✓ Auth service found"
else
  echo "✗ Auth service missing"
  exit 1
fi

# Check mobile customer auth screen
if [ -d "source/apps/mobile-customer/lib/screens/auth" ]; then
  echo "✓ Mobile customer auth screen found"
else
  echo "✗ Mobile customer auth screen missing"
  exit 1
fi

# Check if OTP function exists in backend
if grep -q "verifyOTP\|sendSMS" "source/backend/firebase-functions/src/sms.ts" 2>/dev/null; then
  echo "✓ OTP/SMS functions found"
else
  echo "✗ OTP/SMS functions missing"
  exit 1
fi

echo ""
echo "✓ ORD-01 checks passed (stub gate)"
exit 0
