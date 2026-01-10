#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TS="$(date -u +"%Y%m%dT%H%M%SZ")"
EVIDENCE_DIR="$REPO_ROOT/docs/evidence/final_gap_scan/$TS"
mkdir -p "$EVIDENCE_DIR"

SCAN_LOG="$EVIDENCE_DIR/scan.log"
GAPS_JSON="$EVIDENCE_DIR/gaps.json"

exec > >(tee -a "$SCAN_LOG") 2>&1

echo "{"
echo "  \"scan_timestamp\": \"$TS\","
echo "  \"gaps\": ["

GAPS_FOUND=0

# NOTE: Stripe is deferred - do not flag as gap if keys missing
# Stripe gate (stripe_deferred_gate.sh) handles Stripe verification separately

# Firebase rules check
if [ ! -f "$REPO_ROOT/source/infra/firestore.rules" ]; then
  [ $GAPS_FOUND -gt 0 ] && echo ","
  echo "    {\"id\": \"firestore_rules_missing\", \"severity\": \"BLOCKER\", \"message\": \"Firestore rules file not found\"}"
  GAPS_FOUND=$((GAPS_FOUND + 1))
fi

# Auth claims check
if ! grep -r "customClaims" "$REPO_ROOT/source/backend" 2>/dev/null | grep -v node_modules >/dev/null 2>&1; then
  [ $GAPS_FOUND -gt 0 ] && echo ","
  echo "    {\"id\": \"auth_claims_missing\", \"severity\": \"BLOCKER\", \"message\": \"No custom claims implementation detected in backend\"}"
  GAPS_FOUND=$((GAPS_FOUND + 1))
fi

# Versioning check
if [ ! -f "$REPO_ROOT/source/apps/mobile-customer/pubspec.yaml" ]; then
  [ $GAPS_FOUND -gt 0 ] && echo ","
  echo "    {\"id\": \"customer_app_missing\", \"severity\": \"BLOCKER\", \"message\": \"Customer app pubspec.yaml not found\"}"
  GAPS_FOUND=$((GAPS_FOUND + 1))
fi

if [ ! -f "$REPO_ROOT/source/apps/mobile-merchant/pubspec.yaml" ]; then
  [ $GAPS_FOUND -gt 0 ] && echo ","
  echo "    {\"id\": \"merchant_app_missing\", \"severity\": \"BLOCKER\", \"message\": \"Merchant app pubspec.yaml not found\"}"
  GAPS_FOUND=$((GAPS_FOUND + 1))
fi

# Crashlytics check
if ! grep -r "crashlytics" "$REPO_ROOT/source/apps" 2>/dev/null | grep -v node_modules >/dev/null 2>&1; then
  [ $GAPS_FOUND -gt 0 ] && echo ","
  echo "    {\"id\": \"crashlytics_not_configured\", \"severity\": \"WARNING\", \"message\": \"Crashlytics configuration not detected in mobile apps\"}"
  GAPS_FOUND=$((GAPS_FOUND + 1))
fi

echo ""
echo "  ],"
echo "  \"total_gaps\": $GAPS_FOUND"
echo "}" > "$GAPS_JSON"

if [ $GAPS_FOUND -eq 0 ]; then
  {
    echo "# Final Gap Scan - Production Ready"
    echo ""
    echo "**VERDICT: GO ✅**"
    echo ""
    echo "Timestamp: $TS"
    echo ""
    echo "All non-deferred blockers cleared."
    echo "Stripe verification: handled by stripe_deferred_gate.sh"
  } > "$EVIDENCE_DIR/VERDICT_FINAL_GAPS_CLEAR.md"
  EXIT_CODE=0
else
  {
    echo "# Final Gap Scan - NO_GO"
    echo ""
    echo "**VERDICT: NO_GO ❌**"
    echo ""
    echo "Timestamp: $TS"
    echo ""
    echo "## Gaps Found: $GAPS_FOUND"
    echo ""
    echo "See gaps.json for details."
    echo ""
    echo "\`\`\`json"
    cat "$GAPS_JSON"
    echo "\`\`\`"
  } > "$EVIDENCE_DIR/NO_GO_FINAL_GAPS_FOUND.md"
  EXIT_CODE=1
fi

(cd "$EVIDENCE_DIR" && find . -type f ! -name SHA256SUMS.txt -exec shasum -a 256 {} \; | sort > SHA256SUMS.txt)

echo "Evidence: $EVIDENCE_DIR"
echo "Gaps: $GAPS_FOUND"
exit $EXIT_CODE
