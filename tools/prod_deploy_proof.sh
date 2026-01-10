#!/bin/bash
set -e

REPO="/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER"
cd "$REPO"

TS=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
EVD="docs/evidence/production_gate/$TS/prod_deploy_proof"
mkdir -p "$EVD"

{
  echo "# EXECUTION LOG"
  echo ""
  echo "Timestamp: $(date -u)"
  echo "PWD: $(pwd)"
  echo "Node: $(node -v 2>&1)"
  echo "NPM: $(npm -v 2>&1)"
  echo "Firebase: $(firebase --version 2>&1)"
  echo ""
} > "$EVD/EXECUTION_LOG.md"

cd "$REPO/source"

echo "[$(date -u +%H:%M:%S)] firebase use" >> "$REPO/$EVD/EXECUTION_LOG.md"
firebase use urbangenspark > "$REPO/$EVD/firebase_use.log" 2>&1

echo "[$(date -u +%H:%M:%S)] deploy functions" >> "$REPO/$EVD/EXECUTION_LOG.md"
firebase deploy --only functions --project urbangenspark > "$REPO/$EVD/firebase_deploy_functions.log" 2>&1

echo "[$(date -u +%H:%M:%S)] deploy indexes" >> "$REPO/$EVD/EXECUTION_LOG.md"
firebase deploy --only firestore:indexes --project urbangenspark > "$REPO/$EVD/firebase_deploy_indexes.log" 2>&1

echo "[$(date -u +%H:%M:%S)] list functions" >> "$REPO/$EVD/EXECUTION_LOG.md"
firebase functions:list --project urbangenspark > "$REPO/$EVD/firebase_functions_list.log" 2>&1

cd "$REPO"

if grep -q "Deploy complete!" "$EVD/firebase_deploy_functions.log" && [ -s "$EVD/firebase_functions_list.log" ]; then
  VERDICT="GO ✅"
  {
    echo "# FINAL PRODUCTION DEPLOYMENT GATE"
    echo ""
    echo "**VERDICT: $VERDICT**"
    echo ""
    echo "**Project:** urbangenspark"
    echo "**Timestamp:** $TS"
    echo ""
    echo "## Success Evidence"
    echo ""
    echo "**Functions Deploy:**"
    echo '```'
    grep "Deploy complete!" "$EVD/firebase_deploy_functions.log" || true
    grep "Successful.*operation" "$EVD/firebase_deploy_functions.log" | head -5 || true
    echo '```'
    echo ""
    echo "**Indexes Deploy:**"
    echo '```'
    grep "deployed indexes\|Deploy complete" "$EVD/firebase_deploy_indexes.log" | head -3 || true
    echo '```'
    echo ""
    echo "**Functions Inventory:**"
    echo '```'
    head -20 "$EVD/firebase_functions_list.log" || true
    echo '```'
  } > "$EVD/FINAL_PROD_DEPLOY_GATE.md"
else
  VERDICT="NO_GO ❌"
  {
    echo "# FINAL PRODUCTION DEPLOYMENT GATE"
    echo ""
    echo "**VERDICT: $VERDICT**"
    echo ""
    echo "Deploy failed. Check logs."
  } > "$EVD/FINAL_PROD_DEPLOY_GATE.md"
fi

find "$EVD" -type f ! -name SHA256SUMS.txt -exec shasum -a 256 {} + | sort > "$EVD/SHA256SUMS.txt"

echo ""
echo "================================================"
echo "Evidence Folder: $EVD"
echo "Verdict: $VERDICT"
echo "Exit Code: 0"
echo "================================================"
