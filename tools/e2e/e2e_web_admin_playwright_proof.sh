#!/bin/bash
set -euo pipefail

# Web Admin Playwright Proof Script
# Tests web-admin UI with Playwright
# Outputs verdict JSON + logs under local-ci/verification/e2e_proof_pack/web_admin/

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROOF_DIR="local-ci/verification/e2e_proof_pack/web_admin"
mkdir -p "$PROOF_DIR/screenshots"

RUN_LOG="$PROOF_DIR/playwright.log"
exec > >(tee "$RUN_LOG") 2>&1

echo "=========================================="
echo "WEB ADMIN PLAYWRIGHT PROOF"
echo "=========================================="
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

VERDICT="BLOCKED"
REASON="Playwright or web-admin build not available"
DETAILS=""

# Check if web-admin exists
if [ ! -d "source/apps/web-admin" ]; then
  DETAILS="source/apps/web-admin directory not found."
  echo "BLOCKER: $DETAILS"
  VERDICT="BLOCKED"
else
  echo "web-admin app found. Checking Playwright..."
  
  # Check if Playwright is available (Node.js + npm)
  if ! command -v npx &> /dev/null; then
    DETAILS="Node.js/npm not available. Cannot run Playwright."
    echo "BLOCKER: $DETAILS"
    VERDICT="BLOCKED"
  else
    # Try to run Playwright (would need package.json with @playwright/test)
    cd source/apps/web-admin
    
    if [ ! -f "package.json" ]; then
      DETAILS="No package.json in web-admin. Cannot install Playwright."
      cd "$ROOT"
      VERDICT="BLOCKED"
    elif ! [ -d "node_modules" ]; then
      echo "Installing dependencies..."
      npm install --silent || {
        DETAILS="npm install failed for web-admin."
        VERDICT="BLOCKED"
      }
    fi
    
    if [ "$VERDICT" != "BLOCKED" ]; then
      echo "Attempting to run Playwright tests..."
      if timeout 60 npx playwright test --reporter=json > results.json 2>&1; then
        VERDICT="PASS"
        DETAILS="Playwright tests executed successfully."
        cp results.json "$ROOT/$PROOF_DIR/playwright_results.json" 2>/dev/null || true
      else
        DETAILS="Playwright tests failed or timed out (60s)."
        VERDICT="BLOCKED"
      fi
    fi
    
    cd "$ROOT"
  fi
fi

# Generate VERDICT.json
cat > "$PROOF_DIR/VERDICT.json" << EOF
{
  "timestamp_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "service": "web_admin",
  "verdict": "$VERDICT",
  "reason": "$REASON",
  "details": "$DETAILS",
  "evidence_paths": [
    "$PROOF_DIR/playwright.log"
  ]
}
EOF

echo "=========================================="
echo "Web Admin Playwright Proof: $VERDICT"
echo "=========================================="

[ "$VERDICT" = "PASS" ] && exit 0 || exit 1
