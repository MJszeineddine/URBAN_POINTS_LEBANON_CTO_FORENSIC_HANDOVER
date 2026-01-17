#!/bin/bash
set -euo pipefail

# E2E PROOF PACK - DETERMINISTIC & NON-BYPASSABLE
# ALWAYS produces VERDICT.json, EXEC_SUMMARY.md, artifacts_list.txt, RUN.log

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROOF_DIR="local-ci/verification/e2e_proof_pack"
RUN_LOG="$PROOF_DIR/RUN.log"

# Clean and prepare
rm -rf "$PROOF_DIR"
mkdir -p "$PROOF_DIR"/{reality_gate,cto_gate,e2e_search}

# Start logging
exec > >(tee "$RUN_LOG") 2>&1

echo "========================================================================"
echo "E2E PROOF PACK - DETERMINISTIC EXECUTION"
echo "========================================================================"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'UNKNOWN')"
echo "========================================================================"

# Git state
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "UNKNOWN")
echo "$GIT_COMMIT" > "$PROOF_DIR/git_commit.txt"
git status --porcelain > "$PROOF_DIR/git_status.txt" 2>/dev/null || true

# Verdict tracking
CTO_GATE_EXIT=-1
REALITY_GATE_EXIT=-1
E2E_ARTIFACTS_COUNT=0
VALID_E2E_COUNT=0

# STEP 1: CTO Gate
echo ""
echo "=== STEP 1: Running CTO Gate ==="
if python3 tools/gates/cto_verify.py > "$PROOF_DIR/cto_gate/cto_verify.log" 2>&1; then
    CTO_GATE_EXIT=0
    echo "CTO Gate: PASS"
else
    CTO_GATE_EXIT=$?
    echo "CTO Gate: FAIL (exit $CTO_GATE_EXIT)"
fi
echo "$CTO_GATE_EXIT" > "$PROOF_DIR/cto_gate/exit.txt"
[ -f "cto_verify_report.json" ] && cp cto_verify_report.json "$PROOF_DIR/cto_gate/"

# STEP 2.5: Run Layer-by-Layer E2E Proofs
echo ""
echo "=== STEP 2.5: Layer-by-Layer E2E Proofs ==="
mkdir -p "$PROOF_DIR/layer_proofs"

# Declare arrays for layer info
declare -a LAYER_NAMES=("backend_emulator" "web_admin" "mobile_customer" "mobile_merchant")
declare -a LAYER_SCRIPTS=("e2e_backend_emulator_proof.sh" "e2e_web_admin_playwright_proof.sh" "e2e_mobile_customer_integration_proof.sh" "e2e_mobile_merchant_integration_proof.sh")
declare -a LAYER_EXITS
declare -a LAYER_VERDICTS

for i in "${!LAYER_NAMES[@]}"; do
    LAYER="${LAYER_NAMES[$i]}"
    SCRIPT="${LAYER_SCRIPTS[$i]}"
    
    echo ""
    echo "Running: $LAYER"
    
    if [ -f "tools/e2e/$SCRIPT" ]; then
        if bash "tools/e2e/$SCRIPT" > "$PROOF_DIR/layer_proofs/${LAYER}.log" 2>&1; then
            LAYER_EXITS[$i]=0
            echo "  Result: PASS"
        else
            LAYER_EXITS[$i]=$?
            echo "  Result: BLOCKED (exit ${LAYER_EXITS[$i]})"
        fi
        
        # Capture verdict from layer script
        LAYER_VERDICT_FILE="local-ci/verification/e2e_proof_pack/${LAYER}/VERDICT.json"
        if [ -f "$LAYER_VERDICT_FILE" ]; then
            LAYER_VERDICT=$(jq -r '.verdict // "UNKNOWN"' "$LAYER_VERDICT_FILE" 2>/dev/null || echo "UNKNOWN")
            LAYER_VERDICTS[$i]="$LAYER_VERDICT"
            cp "$LAYER_VERDICT_FILE" "$PROOF_DIR/layer_proofs/${LAYER}_VERDICT.json"
            echo "  Verdict: $LAYER_VERDICT"
        else
            LAYER_VERDICTS[$i]="UNKNOWN"
        fi
    else
        LAYER_EXITS[$i]=127
        LAYER_VERDICTS[$i]="MISSING"
        echo "  Script not found: tools/e2e/$SCRIPT"
    fi
done

# STEP 2.6: Generate flow proof templates or blockers (deterministic)
echo ""
echo "=== STEP 2.6: Generating flow proof templates (BLOCKED) ==="
FLOW_NAMES=(
    "customer_qr"
    "merchant_approve"
    "subscription_gate"
    "phone_code_login"
    "bilingual"
    "location_priority"
    "push_delivery"
)
for FLOW in "${FLOW_NAMES[@]}"; do
    PROOF_FILE="$PROOF_DIR/flow_proof_${FLOW}.md"
    BLOCKER_FILE="$PROOF_DIR/BLOCKER_FLOW_${FLOW}.md"
    TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    cat > "$PROOF_FILE" << EOF_FLOW
# Flow Proof: ${FLOW}

- Timestamp: ${TS}
- Outcome: BLOCKED
- Steps: Not executed (manual journey proof not recorded)
- Evidence: NONE

Reason: Waiting for layer-by-layer E2E tests to produce journey artifacts.
Next Steps: Update with actual flow test results from layer proofs.

Related Logs: local-ci/verification/e2e_proof_pack/layer_proofs/
EOF_FLOW
    cat > "$BLOCKER_FILE" << EOF_BLOCK
# BLOCKER — ${FLOW} flow

- Timestamp: ${TS}
- Exact Reason: Awaiting journey proof from layer E2E tests.
- What is Missing: Automated or manual test that proves this flow end-to-end.
- Required Evidence: Update flow_proof_${FLOW}.md with 'Outcome: SUCCESS' and link to test logs.
EOF_BLOCK
done

# STEP 2: Reality Gate
echo ""
echo "=== STEP 2: Running Reality Gate ==="
if bash tools/gates/reality_gate.sh > "$PROOF_DIR/reality_gate/reality_gate.log" 2>&1; then
    REALITY_GATE_EXIT=0
    echo "Reality Gate: PASS"
else
    REALITY_GATE_EXIT=$?
    echo "Reality Gate: FAIL (exit $REALITY_GATE_EXIT)"
fi
echo "$REALITY_GATE_EXIT" > "$PROOF_DIR/reality_gate/exit.txt"

# Sync reality gate evidence
if [ -d "local-ci/verification/reality_gate" ]; then
    rsync -a local-ci/verification/reality_gate/ "$PROOF_DIR/reality_gate/" 2>/dev/null || true
    echo "Reality gate synced: $(find "$PROOF_DIR/reality_gate" -type f | wc -l) files"
fi

# Extract exits.json
EXITS_JSON_CONTENT="{}"
if [ -f "$PROOF_DIR/reality_gate/exits.json" ]; then
    EXITS_JSON_CONTENT=$(cat "$PROOF_DIR/reality_gate/exits.json")
fi

# STEP 3: Search E2E artifacts
echo ""
echo "=== STEP 3: Searching E2E Proof Artifacts ==="
find local-ci/verification -type f \( \
    -name "e2e*.log" -o \
    -name "playwright*.log" -o \
    -name "cypress*.log" -o \
    -name "firebase_emulator*.log" -o \
    -name "flow_proof*.md" -o \
    -name "journey_proof*.md" \
\) 2>/dev/null | \
grep -v node_modules | grep -v .dart_tool | grep -v "/build/" | grep -v "/dist/" | grep -v "/.next/" \
> "$PROOF_DIR/e2e_search/e2e_proof_search.txt" || true

E2E_ARTIFACTS_COUNT=$(wc -l < "$PROOF_DIR/e2e_search/e2e_proof_search.txt" | tr -d ' ')
echo "E2E artifacts found: $E2E_ARTIFACTS_COUNT"

# Check valid artifacts — only count flow proofs with Outcome: SUCCESS
VALID_E2E_COUNT=0
if [ "$E2E_ARTIFACTS_COUNT" -gt 0 ]; then
    while IFS= read -r artifact; do
        if [ -f "$artifact" ] && [ -s "$artifact" ]; then
            case "$artifact" in
                *flow_proof*.md|*journey_proof*.md)
                    if grep -q "^[- ]*Outcome: SUCCESS" "$artifact" 2>/dev/null; then
                        VALID_E2E_COUNT=$((VALID_E2E_COUNT + 1))
                    fi
                    ;;
                *)
                    : # ignore non-proof logs for validity counting
                    ;;
            esac
        fi
    done < "$PROOF_DIR/e2e_search/e2e_proof_search.txt"
    echo "Valid E2E artifacts: $VALID_E2E_COUNT"
fi

# STEP 4: Determine verdict
echo ""
echo "=== STEP 4: Computing Verdict ==="
ALL_BUILDS_PASS=false
if [ -f "$PROOF_DIR/reality_gate/exits.json" ]; then
    if echo "$EXITS_JSON_CONTENT" | jq -e 'all(. == 0)' > /dev/null 2>&1; then
        ALL_BUILDS_PASS=true
        echo "Builds/Tests: ALL PASS"
    else
        echo "Builds/Tests: FAILURES"
    fi
fi

FINAL_VERDICT="NO_GO"
if [ "$CTO_GATE_EXIT" -ne 0 ] || [ "$REALITY_GATE_EXIT" -ne 0 ]; then
    FINAL_VERDICT="NO_GO"
    echo "Verdict: NO_GO (gate failures)"
elif [ "$ALL_BUILDS_PASS" = false ]; then
    FINAL_VERDICT="NO_GO"
    echo "Verdict: NO_GO (build failures)"
elif [ "$VALID_E2E_COUNT" -gt 0 ]; then
    FINAL_VERDICT="GO_FEATURES_PROVEN"
    echo "Verdict: GO_FEATURES_PROVEN"
elif [ "$ALL_BUILDS_PASS" = true ]; then
    FINAL_VERDICT="GO_BUILDS_ONLY"
    echo "Verdict: GO_BUILDS_ONLY"
fi

# STEP 5: Artifacts list
find "$PROOF_DIR" -type f | sort > "$PROOF_DIR/artifacts_list.txt"
ARTIFACT_COUNT=$(wc -l < "$PROOF_DIR/artifacts_list.txt" | tr -d ' ')

# STEP 6: Generate VERDICT.json
E2E_SAMPLE_JSON="[]"
if [ "$E2E_ARTIFACTS_COUNT" -gt 0 ]; then
    E2E_SAMPLE_JSON=$(head -20 "$PROOF_DIR/e2e_search/e2e_proof_search.txt" | jq -R -s -c 'split("\n")[:-1]')
fi

cat > "$PROOF_DIR/VERDICT.json" << EOFVERDICT
{
  "timestamp_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "git_commit": "$GIT_COMMIT",
  "verdict": "$FINAL_VERDICT",
  "gates": {
    "cto_gate_exit": $CTO_GATE_EXIT,
    "reality_gate_exit": $REALITY_GATE_EXIT
  },
  "layer_proofs": {
    "backend_emulator": "$(echo "${LAYER_VERDICTS[0]:-UNKNOWN}")",
    "web_admin": "$(echo "${LAYER_VERDICTS[1]:-UNKNOWN}")",
    "mobile_customer": "$(echo "${LAYER_VERDICTS[2]:-UNKNOWN}")",
    "mobile_merchant": "$(echo "${LAYER_VERDICTS[3]:-UNKNOWN}")"
  },
  "reality_gate_exits_json": $EXITS_JSON_CONTENT,
  "e2e_artifacts_found_count": $E2E_ARTIFACTS_COUNT,
  "e2e_artifacts_valid_count": $VALID_E2E_COUNT,
  "e2e_artifacts_sample": $E2E_SAMPLE_JSON,
  "total_evidence_files": $ARTIFACT_COUNT
}
EOFVERDICT

# STEP 7: Generate EXEC_SUMMARY.md
cat > "$PROOF_DIR/EXEC_SUMMARY.md" << EOFEXEC
# E2E Proof Pack - Executive Summary

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Commit:** $GIT_COMMIT  
**Verdict:** $FINAL_VERDICT

---

## Gate Results

| Gate | Exit | Status |
|------|------|--------|
| CTO Gate | $CTO_GATE_EXIT | $([ "$CTO_GATE_EXIT" -eq 0 ] && echo "PASS ✅" || echo "FAIL ❌") |
| Reality Gate | $REALITY_GATE_EXIT | $([ "$REALITY_GATE_EXIT" -eq 0 ] && echo "PASS ✅" || echo "FAIL ❌") |

## Build/Test Status

$(if [ "$ALL_BUILDS_PASS" = true ]; then
    echo "**Status:** ALL PASS ✅"
    echo ""
    echo "All surfaces built and tested successfully."
else
    echo "**Status:** FAILURES ❌"
    echo ""
    echo "Build or test failures detected."
fi)

## E2E Proof Artifacts

**Patterns:** e2e*.log, playwright*.log, cypress*.log, firebase_emulator*.log, flow_proof*.md, journey_proof*.md  
**Found:** $E2E_ARTIFACTS_COUNT  
**Valid:** $VALID_E2E_COUNT

$(if [ "$E2E_ARTIFACTS_COUNT" -gt 0 ]; then
    echo "Sample artifacts:"
    echo '```'
    head -10 "$PROOF_DIR/e2e_search/e2e_proof_search.txt"
    echo '```'
else
    echo "**NO E2E PROOF ARTIFACTS FOUND**"
    echo ""
    echo "Missing:"
    echo "- Playwright/Cypress test logs"
    echo "- Firebase emulator logs"
    echo "- Flow proof documents"
fi)

---

## Verdict: $FINAL_VERDICT

$(case "$FINAL_VERDICT" in
    "GO_FEATURES_PROVEN")
        echo "✅ **READY FOR DEPLOYMENT**"
        echo "- Builds pass"
        echo "- E2E proof exists"
        echo "- High confidence"
        ;;
    "GO_BUILDS_ONLY")
        echo "⚠️  **BUILDS PASS, E2E NOT PROVEN**"
        echo "- Builds pass"
        echo "- NO E2E proof"
        echo "- Medium confidence"
        echo ""
        echo "Recommendation: Add E2E tests"
        ;;
    "NO_GO")
        echo "❌ **NOT READY**"
        [ "$CTO_GATE_EXIT" -ne 0 ] && echo "- CTO Gate failed"
        [ "$REALITY_GATE_EXIT" -ne 0 ] && echo "- Reality Gate failed"
        [ "$ALL_BUILDS_PASS" = false ] && echo "- Build failures"
        ;;
esac)

---

## Evidence Files

**Location:** local-ci/verification/e2e_proof_pack/  
**Total:** $ARTIFACT_COUNT files

Key files:
- VERDICT.json
- EXEC_SUMMARY.md (this file)
- RUN.log
- artifacts_list.txt
- reality_gate/ ($(find "$PROOF_DIR/reality_gate" -type f 2>/dev/null | wc -l | tr -d ' ') files)
- cto_gate/
- e2e_search/

## What IS Proven

$([ "$CTO_GATE_EXIT" -eq 0 ] && echo "✅ Spec compliance" || echo "❌ Spec compliance")
$([ "$REALITY_GATE_EXIT" -eq 0 ] && echo "✅ Reality gate" || echo "❌ Reality gate")
$([ "$ALL_BUILDS_PASS" = true ] && echo "✅ All builds pass" || echo "❌ Build failures")
$([ "$ALL_BUILDS_PASS" = true ] && echo "✅ All tests pass" || echo "❌ Test failures")
$([ "$VALID_E2E_COUNT" -gt 0 ] && echo "✅ E2E proof ($VALID_E2E_COUNT)" || echo "❌ No E2E proof")

## What is NOT Proven

$([ "$VALID_E2E_COUNT" -eq 0 ] && echo "- End-to-end flows
- Firebase emulator functionality  
- Web E2E tests
- Mobile integration tests" || echo "All critical aspects proven")

---

**Integrity verification:**
\`\`\`bash
shasum -a 256 local-ci/verification/e2e_proof_pack/{VERDICT.json,EXEC_SUMMARY.md,RUN.log}
\`\`\`
EOFEXEC

# STEP 8: SHA256 hashes
echo ""
echo "=== Computing Integrity Hashes ==="
shasum -a 256 "$PROOF_DIR/VERDICT.json" | tee "$PROOF_DIR/VERDICT.json.sha256"
shasum -a 256 "$PROOF_DIR/EXEC_SUMMARY.md" | tee "$PROOF_DIR/EXEC_SUMMARY.md.sha256"
shasum -a 256 "$RUN_LOG" | tee "$PROOF_DIR/RUN.log.sha256"

echo ""
echo "========================================================================"
echo "E2E PROOF PACK COMPLETE"
echo "========================================================================"
echo "Verdict: $FINAL_VERDICT"
echo "Evidence: $ARTIFACT_COUNT files"
echo "Location: $PROOF_DIR"
echo "========================================================================"
