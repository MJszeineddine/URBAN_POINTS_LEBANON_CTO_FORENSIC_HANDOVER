#!/usr/bin/env bash
set -euo pipefail

# ORD-09: Notifications (Push/In-app)
# Stub gate: checks for FCM and notification logic

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-09: Notifications (Push/In-app) ==="
echo "Checking for notification infrastructure..."

# Check FCM service
if [ -f "source/backend/firebase-functions/src/phase3Notifications.ts" ]; then
  echo "✓ Notification backend found"
else
  echo "✗ Notification backend missing"
  exit 1
fi

# Check mobile customer FCM
if [ -f "source/apps/mobile-customer/lib/services/fcm_service.dart" ]; then
  echo "✓ Customer FCM service found"
else
  echo "✗ Customer FCM service missing"
  exit 1
fi

echo ""
echo "✓ ORD-09 checks passed (stub gate)"
exit 0
