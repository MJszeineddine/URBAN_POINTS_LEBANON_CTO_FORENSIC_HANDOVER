#!/usr/bin/env bash
set -euo pipefail

# ORD-13: DevOps Gate Auto (CI/CD + Evidence)
# Stub gate: checks for loop infrastructure and evidence generation

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== ORD-13: DevOps Gate Auto (CI/CD + Evidence) ==="
echo "Checking for loop automation infrastructure..."

# Check loop tools
if [ -f "tools/loop/loop_auto.sh" ]; then
  echo "✓ Loop automation script found"
else
  echo "✗ Loop automation script missing"
  exit 1
fi

# Check Excel update script
if [ -f "tools/excel/update_from_evidence.py" ]; then
  echo "✓ Excel update script found"
else
  echo "✗ Excel update script missing"
  exit 1
fi

# Check next order script
if [ -f "tools/loop/next_order.py" ]; then
  echo "✓ Next order resolver found"
else
  echo "✗ Next order resolver missing"
  exit 1
fi

# Check evidence directory exists
if [ -d "docs/evidence" ]; then
  echo "✓ Evidence collection directory found"
else
  echo "✗ Evidence directory missing"
  exit 1
fi

echo ""
echo "✓ ORD-13 checks passed (stub gate)"
exit 0
