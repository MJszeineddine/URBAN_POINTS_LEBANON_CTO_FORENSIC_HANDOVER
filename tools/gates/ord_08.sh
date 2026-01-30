#!/usr/bin/env bash
set -euo pipefail

# ORD-08: Web Admin Moderation Console (Scope-defined)
# Stub gate: checks for web admin pages

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-08: Web Admin Moderation Console ==="
echo "Checking for web admin pages..."

# Check web admin offers page
if [ -f "source/apps/web-admin/pages/admin/offers.tsx" ]; then
  echo "✓ Web admin offers page found"
else
  echo "✗ Web admin offers page missing"
  exit 1
fi

# Check web admin users page
if [ -f "source/apps/web-admin/pages/admin/users.tsx" ]; then
  echo "✓ Web admin users page found"
else
  echo "✗ Web admin users page missing"
  exit 1
fi

# Check web admin merchants page
if [ -f "source/apps/web-admin/pages/admin/merchants.tsx" ]; then
  echo "✓ Web admin merchants page found"
else
  echo "✗ Web admin merchants page missing"
  exit 1
fi

echo ""
echo "✓ ORD-08 checks passed (stub gate)"
exit 0
