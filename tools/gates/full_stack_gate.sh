#!/bin/bash
set -euo pipefail

# Full-Stack Gate Script
# Orchestrates all gates and E2E proofs
# Outputs overall verdict under local-ci/verification/full_stack_gate/

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

GATE_DIR="local-ci/verification/full_stack_gate"
mkdir -p "$GATE_DIR"

RUN_LOG="$GATE_DIR/RUN.log"
exec > >(tee "$RUN_LOG") 2>&1

echo "=========================================="
echo "FULL-STACK GATE"
echo "=========================================="
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'UNKNOWN')"
echo "=========================================="

# Initialize verdict tracking
REALITY_GATE_PASS=false
E2E_PACK_PASS=false
PARITY_PASS=false
FULL_STACK_YES=false

# STEP 1: Reality Gate
echo ""
echo "=== STEP 1: Reality Gate ==="
if bash tools/gates/reality_gate.sh > "$GATE_DIR/reality_gate.log" 2>&1; then
  REALITY_GATE_PASS=true
  echo "Reality Gate: PASS"
else
  echo "Reality Gate: FAIL"
fi

# STEP 2: E2E Proof Pack
echo ""
echo "=== STEP 2: E2E Proof Pack ==="
if bash tools/e2e/run_e2e_proof_pack_v2.sh > "$GATE_DIR/e2e_proof_pack.log" 2>&1; then
  E2E_PACK_PASS=true
  echo "E2E Proof Pack: PASS"
else
  echo "E2E Proof Pack: FAIL or BLOCKED"
fi

# STEP 3: Clone Parity
echo ""
echo "=== STEP 3: Clone Parity Computation ==="
if python3 tools/clone_parity/compute_clone_parity.py > "$GATE_DIR/clone_parity.log" 2>&1; then
  PARITY_PASS=true
  echo "Clone Parity: COMPUTED"
else
  echo "Clone Parity: FAILED"
fi

# STEP 4: Determine Full-Stack Status
echo ""
echo "=== STEP 4: Full-Stack Determination ==="
if [ "$REALITY_GATE_PASS" = true ] && [ "$E2E_PACK_PASS" = true ]; then
  FULL_STACK_YES=true
  echo "FULL-STACK: YES"
else
  echo "FULL-STACK: NO"
fi

# Generate VERDICT.json
cat > "$GATE_DIR/VERDICT.json" << EOF
{
  "timestamp_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "git_commit": "$(git rev-parse --short HEAD 2>/dev/null || echo 'UNKNOWN')",
  "full_stack_status": "$([ "$FULL_STACK_YES" = true ] && echo 'YES' || echo 'NO')",
  "gates": {
    "reality_gate": "$([ "$REALITY_GATE_PASS" = true ] && echo 'PASS' || echo 'FAIL')",
    "e2e_proof_pack": "$([ "$E2E_PACK_PASS" = true ] && echo 'PASS' || echo 'FAIL')",
    "parity_computed": "$([ "$PARITY_PASS" = true ] && echo 'YES' || echo 'NO')"
  },
  "evidence_paths": {
    "reality_gate_log": "$GATE_DIR/reality_gate.log",
    "e2e_proof_pack_log": "$GATE_DIR/e2e_proof_pack.log",
    "clone_parity_log": "$GATE_DIR/clone_parity.log",
    "e2e_proof_pack_verdict": "local-ci/verification/e2e_proof_pack/VERDICT.json",
    "clone_parity_json": "local-ci/verification/clone_parity/clone_parity.json"
  }
}
EOF

echo ""
echo "=========================================="
echo "FULL-STACK GATE COMPLETE"
echo "=========================================="
echo "Status: FULL-STACK: $([ "$FULL_STACK_YES" = true ] && echo 'YES' || echo 'NO')"
echo "=========================================="

# Exit with appropriate code
if [ "$FULL_STACK_YES" = true ]; then
  exit 0
else
  exit 1
fi
