#!/usr/bin/env bash
#
# FINAL EVIDENCE AUDIT GATE
#
# Runs final_evidence_audit.py and creates evidence folder.
# Exit 0 only if audit passes.

set -euo pipefail

TZ=Asia/Beirut
export TZ

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

PY_BIN="${ROOT_DIR}/.venv/bin/python"
EXCEL_PATH="${EXCEL_PATH:-UrbanPoints_CTO_Master_Control_v4.xlsx}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-docs/evidence}"

if [ ! -f "$PY_BIN" ]; then
  PY_BIN="python3"
fi

# Create evidence folder
RUN_TS="$(date +%Y%m%d-%H%M%S)"
AUDIT_DIR="${EVIDENCE_ROOT}/FINAL_AUDIT/${RUN_TS}"
mkdir -p "$AUDIT_DIR"

echo "Running final evidence audit..."
echo "Timestamp: $RUN_TS"
echo "Evidence directory: $AUDIT_DIR"
echo ""

# Run audit and capture all output
set +e
$PY_BIN tools/gates/final_evidence_audit.py \
  --excel "$EXCEL_PATH" \
  --evidence-root "$EVIDENCE_ROOT" \
  --output-dir "$AUDIT_DIR" \
  2>&1 | tee "$AUDIT_DIR/audit.log"

EXIT_CODE=${PIPESTATUS[0]}
set -e

echo ""
echo "Audit exit code: $EXIT_CODE"

# Check if audit passed
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ FINAL AUDIT PASSED"
  echo "Evidence: $AUDIT_DIR/audit.md"
else
  echo "❌ FINAL AUDIT FAILED"
  
  # Create NO_GO.md
  cat >"$AUDIT_DIR/NO_GO.md" <<'EOF'
# Final Evidence Audit: NO-GO

The final evidence audit has failed. One or more orders marked "Done" in Excel
do not have proper evidence or their linked features are not e2e working.

## What this means

The project cannot be considered complete. Orders have been incorrectly marked
as Done without proper validation.

## Next steps

1. Review `audit.md` in this folder for detailed findings
2. Review `audit.json` for machine-readable results
3. For each failed order:
   - Re-run its gate command
   - Verify evidence is created correctly
   - Ensure all linked features are truly e2e working
4. Run `bash tools/excel/apply_audit_to_excel.py` to update Excel statuses
5. Re-run this audit gate

## Evidence location

See `audit.log`, `audit.json`, and `audit.md` in this directory.
EOF

  echo ""
  echo "NO-GO reason: See $AUDIT_DIR/NO_GO.md"
  echo "Detailed report: $AUDIT_DIR/audit.md"
fi

exit $EXIT_CODE
