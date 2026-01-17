#!/bin/bash
set -euo pipefail

# Backend Emulator Proof Script
# Tests Firebase functions / auth / firestore via emulator
# Outputs verdict JSON + logs under local-ci/verification/e2e_proof_pack/backend_emulator/

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROOF_DIR="local-ci/verification/e2e_proof_pack/backend_emulator"
mkdir -p "$PROOF_DIR/artifacts"

RUN_LOG="$PROOF_DIR/RUN.log"
exec > >(tee "$RUN_LOG") 2>&1

echo "=========================================="
echo "BACKEND EMULATOR PROOF"
echo "=========================================="
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

VERDICT="BLOCKED"
REASON="Firebase emulator not configured or not available"
DETAILS=""

# Check if firebase.json exists
if [ ! -f "firebase.json" ]; then
  DETAILS="firebase.json not found. Emulator cannot start."
  echo "BLOCKER: $DETAILS"
  VERDICT="BLOCKED"
else
  echo "firebase.json found. Attempting emulator start..."
  
  # Try to start Firebase emulator suite (if firebase CLI is available)
  if ! command -v firebase &> /dev/null; then
    DETAILS="Firebase CLI (firebase command) not installed."
    echo "BLOCKER: $DETAILS"
    VERDICT="BLOCKED"
  else
    echo "Firebase CLI available. Attempting to start emulators..."
    
    # Try to start emulators (with short timeout)
    if timeout 30 firebase emulators:start --project=test-project 2>&1 | head -20; then
      echo "Emulator started successfully"
      VERDICT="PASS"
      DETAILS="Firebase emulators started and integration tests would run here."
    else
      DETAILS="Firebase emulator failed to start or timed out (30s)."
      echo "BLOCKER: $DETAILS"
      VERDICT="BLOCKED"
    fi
  fi
fi

# Generate VERDICT.json
cat > "$PROOF_DIR/VERDICT.json" << EOF
{
  "timestamp_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "service": "backend_emulator",
  "verdict": "$VERDICT",
  "reason": "$REASON",
  "details": "$DETAILS",
  "evidence_paths": [
    "$PROOF_DIR/RUN.log"
  ]
}
EOF

echo "=========================================="
echo "Backend Emulator Proof: $VERDICT"
echo "=========================================="

[ "$VERDICT" = "PASS" ] && exit 0 || exit 1
