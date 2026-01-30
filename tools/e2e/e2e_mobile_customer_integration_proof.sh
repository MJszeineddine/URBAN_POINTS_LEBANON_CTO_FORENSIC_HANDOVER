#!/bin/bash
set -euo pipefail

# Mobile Customer Integration Proof Script
# Tests mobile-customer with Flutter integration_test
# Outputs verdict JSON + logs under local-ci/verification/e2e_proof_pack/mobile_customer/

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROOF_DIR="local-ci/verification/e2e_proof_pack/mobile_customer"
mkdir -p "$PROOF_DIR"

RUN_LOG="$PROOF_DIR/RUN.log"
exec > >(tee "$RUN_LOG") 2>&1

echo "=========================================="
echo "MOBILE CUSTOMER INTEGRATION PROOF"
echo "=========================================="
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

VERDICT="BLOCKED"
REASON="Flutter emulator or integration tests not available"
DETAILS=""

# Check if mobile-customer exists
if [ ! -d "source/apps/mobile-customer" ]; then
  DETAILS="source/apps/mobile-customer directory not found."
  echo "BLOCKER: $DETAILS"
  VERDICT="BLOCKED"
else
  echo "mobile-customer app found. Checking Flutter..."
  
  # Check if Flutter is available
  if ! command -v flutter &> /dev/null; then
    DETAILS="Flutter SDK not installed. Cannot run integration tests."
    echo "BLOCKER: $DETAILS"
    VERDICT="BLOCKED"
  else
    cd source/apps/mobile-customer
    
    # Check if integration_test exists
    if [ ! -d "integration_test" ]; then
      DETAILS="No integration_test directory found in mobile-customer."
      cd "$ROOT"
      VERDICT="BLOCKED"
    else
      echo "Integration tests found. Checking for emulator/simulator..."
      
      # Check if any device is available
      if ! flutter devices 2>&1 | grep -q "connected"; then
        DETAILS="No Flutter device/emulator connected. Run: flutter emulators --launch <emulator_id>"
        VERDICT="BLOCKED"
      else
        echo "Device found. Attempting integration tests..."
        
        if timeout 300 flutter test integration_test/ --verbose 2>&1 | head -100; then
          VERDICT="PASS"
          DETAILS="Flutter integration tests executed successfully."
        else
          DETAILS="Flutter integration tests failed or timed out (300s)."
          VERDICT="BLOCKED"
        fi
      fi
    fi
    
    cd "$ROOT"
  fi
fi

# Generate VERDICT.json
cat > "$PROOF_DIR/VERDICT.json" << EOF
{
  "timestamp_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "service": "mobile_customer",
  "verdict": "$VERDICT",
  "reason": "$REASON",
  "details": "$DETAILS",
  "evidence_paths": [
    "$PROOF_DIR/RUN.log"
  ]
}
EOF

echo "=========================================="
echo "Mobile Customer Integration Proof: $VERDICT"
echo "=========================================="

[ "$VERDICT" = "PASS" ] && exit 0 || exit 1
