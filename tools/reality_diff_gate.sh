#!/usr/bin/env bash
set -euo pipefail

#######################################################################################
# REALITY DIFF GATE - Brutal Feature Completeness Assessment
# Exit 0: ZERO blockers (GO ✅)
# Exit 1: Any blockers found (NO_GO ❌)
#######################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EVIDENCE_FOLDER="$REPO_ROOT/docs/evidence/reality_diff/$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$EVIDENCE_FOLDER"

# Initialize logs
ORCHESTRATOR_LOG="$EVIDENCE_FOLDER/orchestrator.log"
exec 1> >(tee -a "$ORCHESTRATOR_LOG")
exec 2>&1

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

log "=== REALITY DIFF GATE ==="
log "Evidence: $EVIDENCE_FOLDER"

#######################################################################################
# PHASE 0: INVENTORY & VERSIONS
#######################################################################################

log ""
log "PHASE 0: Capture Inventory"

INVENTORY="$EVIDENCE_FOLDER/inventory.md"
cat > "$INVENTORY" <<'EOF'
# Reality Diff Gate Inventory

## Versions

EOF

log "Node version:"
node --version >> "$INVENTORY"

log "NPM version:"
npm --version >> "$INVENTORY"

if command -v pnpm &>/dev/null; then
  log "PNPM version:"
  pnpm --version >> "$INVENTORY"
fi

if command -v yarn &>/dev/null; then
  log "Yarn version:"
  yarn --version >> "$INVENTORY"
fi

if command -v flutter &>/dev/null; then
  log "Flutter version:"
  flutter --version >> "$INVENTORY"
fi

log "Dart version:"
dart --version >> "$INVENTORY" 2>&1 || echo "N/A" >> "$INVENTORY"

cat >> "$INVENTORY" <<'EOF'

## Directories Scanned

- Backend: source/backend/firebase-functions/src
- Web Admin: source/apps/web-admin
- Mobile Customer: source/apps/mobile-customer
- Mobile Merchant: source/apps/mobile-merchant

## Checklist

A) Web Admin (Next.js):
   1. Offers moderation (Approve/Reject/Disable via httpsCallable + updateDoc)
   2. Merchants moderation (Suspend/Activate/Block via updateDoc)
   3. Users moderation (Ban/Unban via updateDoc, Role via setCustomClaims)
   4. Admin route guard (token claim check)
   5. Build succeeds

B) Backend (Firebase Functions):
   1. TypeScript build succeeds
   2. No TODOs in critical files
   3. No hardcoded secrets in tracked code
   4. Stripe deferred if STRIPE_ENABLED=0

C) Mobile Customer (Flutter):
   1. flutter analyze exits 0 (no errors)
   2. flutter test exits 0

D) Mobile Merchant (Flutter):
   1. flutter analyze exits 0 (no errors)
   2. flutter test exits 0

EOF

#######################################################################################
# PHASE 1: WEB ADMIN CHECKS
#######################################################################################

log ""
log "PHASE 1: Web Admin Checks"

BLOCKERS=()
BLOCKERS_COUNT=0

WEB_ADMIN_STATUS="UNKNOWN"
WEB_ADMIN_CHECKS=()

# Check 1: Offers moderation
log "  [1/5] Checking offers moderation..."
if grep -q "httpsCallable.*approveOffer\|httpsCallable.*'approveOffer'" "$REPO_ROOT/source/apps/web-admin/pages/admin/offers.tsx" 2>/dev/null && \
   grep -q "httpsCallable.*rejectOffer\|httpsCallable.*'rejectOffer'" "$REPO_ROOT/source/apps/web-admin/pages/admin/offers.tsx" 2>/dev/null && \
   grep -q "updateDoc.*status.*disabled\|'disabled'" "$REPO_ROOT/source/apps/web-admin/pages/admin/offers.tsx" 2>/dev/null; then
  WEB_ADMIN_CHECKS+=('{"id":"wa_offers_moderation","status":"PASS","evidence":"httpsCallable(approveOffer), httpsCallable(rejectOffer), updateDoc(status: disabled) found"}')
  log "    ✅ Offers moderation: PASS"
else
  WEB_ADMIN_CHECKS+=('{"id":"wa_offers_moderation","status":"FAIL","file":"source/apps/web-admin/pages/admin/offers.tsx","evidence":"Missing httpsCallable(approveOffer|rejectOffer) or updateDoc(disabled)"}')
  BLOCKERS+=("[WA-1] Offers moderation incomplete: source/apps/web-admin/pages/admin/offers.tsx")
  ((BLOCKERS_COUNT++))
  log "    ❌ Offers moderation: FAIL"
fi

# Check 2: Merchants moderation
log "  [2/5] Checking merchants moderation..."
if grep -q "updateDoc.*status.*suspended\|'suspended'" "$REPO_ROOT/source/apps/web-admin/pages/admin/merchants.tsx" 2>/dev/null && \
   grep -q "updateDoc.*status.*active\|'active'" "$REPO_ROOT/source/apps/web-admin/pages/admin/merchants.tsx" 2>/dev/null && \
   grep -q "updateDoc.*blocked.*true\|blocked.*true" "$REPO_ROOT/source/apps/web-admin/pages/admin/merchants.tsx" 2>/dev/null; then
  WEB_ADMIN_CHECKS+=('{"id":"wa_merchants_moderation","status":"PASS","evidence":"updateDoc mutations for suspend/activate/block found"}')
  log "    ✅ Merchants moderation: PASS"
else
  WEB_ADMIN_CHECKS+=('{"id":"wa_merchants_moderation","status":"FAIL","file":"source/apps/web-admin/pages/admin/merchants.tsx","evidence":"Missing updateDoc for suspend/activate/block"}')
  BLOCKERS+=("[WA-2] Merchants moderation incomplete: source/apps/web-admin/pages/admin/merchants.tsx")
  ((BLOCKERS_COUNT++))
  log "    ❌ Merchants moderation: FAIL"
fi

# Check 3: Users moderation
log "  [3/5] Checking users moderation..."
if grep -q "updateDoc.*banned.*true\|banned.*true" "$REPO_ROOT/source/apps/web-admin/pages/admin/users.tsx" 2>/dev/null && \
   grep -q "updateDoc.*banned.*false\|banned.*false" "$REPO_ROOT/source/apps/web-admin/pages/admin/users.tsx" 2>/dev/null && \
   grep -q "setCustomClaims\|updateDoc.*role\|role.*updateDoc" "$REPO_ROOT/source/apps/web-admin/pages/admin/users.tsx" 2>/dev/null; then
  WEB_ADMIN_CHECKS+=('{"id":"wa_users_moderation","status":"PASS","evidence":"updateDoc(banned) and role mutation found"}')
  log "    ✅ Users moderation: PASS"
else
  WEB_ADMIN_CHECKS+=('{"id":"wa_users_moderation","status":"FAIL","file":"source/apps/web-admin/pages/admin/users.tsx","evidence":"Missing ban/unban or role mutation"}')
  BLOCKERS+=("[WA-3] Users moderation incomplete: source/apps/web-admin/pages/admin/users.tsx")
  ((BLOCKERS_COUNT++))
  log "    ❌ Users moderation: FAIL"
fi

# Check 4: Admin route guard
log "  [4/5] Checking admin route guard..."
if grep -q "token.claims.role.*admin\|admin.*claim" "$REPO_ROOT/source/apps/web-admin/components/AdminGuard.tsx" 2>/dev/null; then
  WEB_ADMIN_CHECKS+=('{"id":"wa_admin_guard","status":"PASS","evidence":"Admin claim enforcement found"}')
  log "    ✅ Admin route guard: PASS"
else
  WEB_ADMIN_CHECKS+=('{"id":"wa_admin_guard","status":"FAIL","file":"source/apps/web-admin/components/AdminGuard.tsx","evidence":"Admin claim check not found"}')
  BLOCKERS+=("[WA-4] Admin route guard missing: source/apps/web-admin/components/AdminGuard.tsx")
  ((BLOCKERS_COUNT++))
  log "    ❌ Admin route guard: FAIL"
fi

# Check 5: Build
log "  [5/5] Checking web-admin build..."
cd "$REPO_ROOT/source/apps/web-admin"
if npm run build > /dev/null 2>&1; then
  WEB_ADMIN_CHECKS+=('{"id":"wa_build","status":"PASS","evidence":"npm run build succeeded"}')
  WEB_ADMIN_STATUS="DONE"
  log "    ✅ Build: PASS"
else
  WEB_ADMIN_CHECKS+=('{"id":"wa_build","status":"FAIL","evidence":"npm run build failed"}')
  BLOCKERS+=("[WA-5] Web admin build failed")
  ((BLOCKERS_COUNT++))
  WEB_ADMIN_STATUS="BROKEN"
  log "    ❌ Build: FAIL"
fi

#######################################################################################
# PHASE 2: BACKEND CHECKS
#######################################################################################

log ""
log "PHASE 2: Backend Checks"

BACKEND_STATUS="UNKNOWN"
BACKEND_CHECKS=()

cd "$REPO_ROOT/source/backend/firebase-functions"

# Check 1: Build
log "  [1/3] Checking backend build..."
if npm run build > /dev/null 2>&1; then
  BACKEND_CHECKS+=('{"id":"be_build","status":"PASS","evidence":"npm run build succeeded"}')
  log "    ✅ Build: PASS"
else
  BACKEND_CHECKS+=('{"id":"be_build","status":"FAIL","evidence":"npm run build failed"}')
  BLOCKERS+=("[BE-1] Backend build failed: source/backend/firebase-functions")
  ((BLOCKERS_COUNT++))
  log "    ❌ Build: FAIL"
fi

# Check 2: TODOs in critical files
log "  [2/3] Checking for TODOs in critical files..."
CRITICAL_FILES=(
  "src/subscriptionAutomation.ts"
  "src/sms.ts"
  "src/paymentWebhooks.ts"
  "src/index.ts"
)

TODO_FOUND=false
for file in "${CRITICAL_FILES[@]}"; do
  if [ -f "$file" ]; then
    TODO_COUNT=$(grep -c "TODO\|FIXME" "$file" || true)
    if [ "$TODO_COUNT" -gt 0 ]; then
      TODO_FOUND=true
      TODO_LINES=$(grep -n "TODO\|FIXME" "$file" | head -3 || true)
      log "    ⚠️  TODOs found in $file:"
      echo "$TODO_LINES" | while read line; do
        log "      $line"
      done
    fi
  fi
done

if [ "$TODO_FOUND" = true ]; then
  BACKEND_CHECKS+=('{"id":"be_todos","status":"FAIL","evidence":"Critical TODOs/FIXMEs found in backend files"}')
  BLOCKERS+=("[BE-2] Critical TODOs found in backend files (subscriptionAutomation.ts, sms.ts, paymentWebhooks.ts, index.ts)")
  ((BLOCKERS_COUNT++))
  log "    ❌ TODOs: FAIL"
else
  BACKEND_CHECKS+=('{"id":"be_todos","status":"PASS","evidence":"No TODOs in critical files"}')
  log "    ✅ TODOs: PASS"
fi

# Check 3: Hardcoded secrets
log "  [3/3] Checking for hardcoded secrets..."
SECRETS_FOUND=false
for pattern in "sk_test" "sk_live" "whsec_" "api_key.*=" "STRIPE_KEY"; do
  if find src -name "*.ts" ! -path "*/examples/*" -exec grep -l "$pattern" {} \; 2>/dev/null | head -1; then
    SECRETS_FOUND=true
    log "    ⚠️  Potential secret pattern found: $pattern"
  fi
done

if [ "$SECRETS_FOUND" = true ]; then
  BACKEND_CHECKS+=('{"id":"be_secrets","status":"FAIL","evidence":"Hardcoded secret patterns detected in tracked code"}')
  BLOCKERS+=("[BE-3] Hardcoded secrets detected in backend code")
  ((BLOCKERS_COUNT++))
  log "    ❌ Secrets: FAIL"
else
  BACKEND_CHECKS+=('{"id":"be_secrets","status":"PASS","evidence":"No hardcoded secrets detected"}')
  BACKEND_STATUS="DONE"
  log "    ✅ Secrets: PASS"
fi

#######################################################################################
# PHASE 3: MOBILE CUSTOMER CHECKS
#######################################################################################

log ""
log "PHASE 3: Mobile Customer Checks"

MOBILE_CUSTOMER_STATUS="UNKNOWN"
MOBILE_CUSTOMER_CHECKS=()

cd "$REPO_ROOT/source/apps/mobile-customer"

# Check 1: flutter analyze
log "  [1/2] Running flutter analyze..."
if flutter analyze 2>&1 | grep -q "error:" ; then
  MOBILE_CUSTOMER_CHECKS+=('{"id":"mc_analyze","status":"FAIL","evidence":"flutter analyze found errors"}')
  BLOCKERS+=("[MC-1] Mobile Customer flutter analyze errors: source/apps/mobile-customer")
  ((BLOCKERS_COUNT++))
  log "    ❌ Analyze: FAIL"
else
  MOBILE_CUSTOMER_CHECKS+=('{"id":"mc_analyze","status":"PASS","evidence":"flutter analyze passed"}')
  log "    ✅ Analyze: PASS"
fi

# Check 2: flutter test
log "  [2/2] Running flutter test..."
if flutter test 2>&1 | grep -q "failed\|error"; then
  MOBILE_CUSTOMER_CHECKS+=('{"id":"mc_test","status":"FAIL","evidence":"flutter test found failures"}')
  BLOCKERS+=("[MC-2] Mobile Customer flutter test failures: source/apps/mobile-customer")
  ((BLOCKERS_COUNT++))
  MOBILE_CUSTOMER_STATUS="BROKEN"
  log "    ❌ Test: FAIL"
else
  MOBILE_CUSTOMER_CHECKS+=('{"id":"mc_test","status":"PASS","evidence":"flutter test passed"}')
  MOBILE_CUSTOMER_STATUS="DONE"
  log "    ✅ Test: PASS"
fi

#######################################################################################
# PHASE 4: MOBILE MERCHANT CHECKS
#######################################################################################

log ""
log "PHASE 4: Mobile Merchant Checks"

MOBILE_MERCHANT_STATUS="UNKNOWN"
MOBILE_MERCHANT_CHECKS=()

cd "$REPO_ROOT/source/apps/mobile-merchant"

# Check 1: flutter analyze
log "  [1/2] Running flutter analyze..."
if flutter analyze 2>&1 | grep -q "error:"; then
  MOBILE_MERCHANT_CHECKS+=('{"id":"mm_analyze","status":"FAIL","evidence":"flutter analyze found errors"}')
  BLOCKERS+=("[MM-1] Mobile Merchant flutter analyze errors: source/apps/mobile-merchant")
  ((BLOCKERS_COUNT++))
  log "    ❌ Analyze: FAIL"
else
  MOBILE_MERCHANT_CHECKS+=('{"id":"mm_analyze","status":"PASS","evidence":"flutter analyze passed"}')
  log "    ✅ Analyze: PASS"
fi

# Check 2: flutter test
log "  [2/2] Running flutter test..."
if flutter test 2>&1 | grep -q "failed\|error"; then
  MOBILE_MERCHANT_CHECKS+=('{"id":"mm_test","status":"FAIL","evidence":"flutter test found failures"}')
  BLOCKERS+=("[MM-2] Mobile Merchant flutter test failures: source/apps/mobile-merchant")
  ((BLOCKERS_COUNT++))
  MOBILE_MERCHANT_STATUS="BROKEN"
  log "    ❌ Test: FAIL"
else
  MOBILE_MERCHANT_CHECKS+=('{"id":"mm_test","status":"PASS","evidence":"flutter test passed"}')
  MOBILE_MERCHANT_STATUS="DONE"
  log "    ✅ Test: PASS"
fi

#######################################################################################
# PHASE 5: GENERATE EVIDENCE ARTIFACTS
#######################################################################################

log ""
log "PHASE 5: Generate Evidence Artifacts"

# Determine overall status
if [ $BLOCKERS_COUNT -eq 0 ]; then
  OVERALL_STATUS="GO"
  EXIT_CODE=0
else
  OVERALL_STATUS="NO_GO"
  EXIT_CODE=1
fi

# Generate reality_diff.json
cat > "$EVIDENCE_FOLDER/reality_diff.json" <<EOF
{
  "scan_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "overall_status": "$OVERALL_STATUS",
  "blockers_count": $BLOCKERS_COUNT,
  "sections": {
    "web_admin": {
      "status": "$WEB_ADMIN_STATUS",
      "checks": [
        $(IFS=,; echo "${WEB_ADMIN_CHECKS[*]}")
      ]
    },
    "backend": {
      "status": "$BACKEND_STATUS",
      "checks": [
        $(IFS=,; echo "${BACKEND_CHECKS[*]}")
      ]
    },
    "mobile_customer": {
      "status": "$MOBILE_CUSTOMER_STATUS",
      "checks": [
        $(IFS=,; echo "${MOBILE_CUSTOMER_CHECKS[*]}")
      ]
    },
    "mobile_merchant": {
      "status": "$MOBILE_MERCHANT_STATUS",
      "checks": [
        $(IFS=,; echo "${MOBILE_MERCHANT_CHECKS[*]}")
      ]
    }
  }
}
EOF

log "✅ Generated reality_diff.json"

# Generate blockers.md
BLOCKERS_FILE="$EVIDENCE_FOLDER/blockers.md"
if [ $BLOCKERS_COUNT -gt 0 ]; then
  cat > "$BLOCKERS_FILE" <<'EOF'
# Blockers

EOF
  i=1
  for blocker in "${BLOCKERS[@]}"; do
    echo "$i. $blocker" >> "$BLOCKERS_FILE"
    ((i++))
  done
  log "✅ Generated blockers.md"
fi

# Generate reality_diff.md
REALITY_DIFF_FILE="$EVIDENCE_FOLDER/reality_diff.md"
cat > "$REALITY_DIFF_FILE" <<EOF
# Reality Diff Report

**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  
**Overall Status:** $OVERALL_STATUS  
**Blockers:** $BLOCKERS_COUNT

---

## Web Admin (Next.js)

Status: $WEB_ADMIN_STATUS

- Offers moderation: $(grep -q 'wa_offers_moderation.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')
- Merchants moderation: $(grep -q 'wa_merchants_moderation.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')
- Users moderation: $(grep -q 'wa_users_moderation.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')
- Admin route guard: $(grep -q 'wa_admin_guard.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')
- Build: $(grep -q 'wa_build.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')

## Backend (Firebase Functions)

Status: $BACKEND_STATUS

- Build: $(grep -q 'be_build.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')
- No critical TODOs: $(grep -q 'be_todos.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')
- No hardcoded secrets: $(grep -q 'be_secrets.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')

## Mobile Customer (Flutter)

Status: $MOBILE_CUSTOMER_STATUS

- Analyze: $(grep -q 'mc_analyze.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')
- Tests: $(grep -q 'mc_test.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')

## Mobile Merchant (Flutter)

Status: $MOBILE_MERCHANT_STATUS

- Analyze: $(grep -q 'mm_analyze.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')
- Tests: $(grep -q 'mm_test.*PASS' "$EVIDENCE_FOLDER/reality_diff.json" && echo '✅ PASS' || echo '❌ FAIL')

---

$(if [ $BLOCKERS_COUNT -gt 0 ]; then echo "## Blockers"; cat "$BLOCKERS_FILE" | tail -n +2; fi)

---

**Verdict:** $OVERALL_STATUS
EOF

log "✅ Generated reality_diff.md"

# Generate verdict file
if [ $EXIT_CODE -eq 0 ]; then
  cat > "$EVIDENCE_FOLDER/VERDICT.md" <<EOF
# Reality Diff Verdict: GO ✅

**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

All feature completeness checks passed. Zero blockers detected.

**Status:**
- Web Admin: DONE
- Backend: DONE
- Mobile Customer: DONE
- Mobile Merchant: DONE
EOF
  log "✅ Verdict: GO"
else
  cat > "$EVIDENCE_FOLDER/NO_GO_REALITY_DIFF.md" <<EOF
# Reality Diff Verdict: NO_GO ❌

**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  
**Blockers:** $BLOCKERS_COUNT

See blockers.md for details.
EOF
  log "❌ Verdict: NO_GO"
fi

# Generate SHA256SUMS
cd "$EVIDENCE_FOLDER"
find . -type f ! -name "SHA256SUMS.txt" -exec shasum -a 256 {} \; > SHA256SUMS.txt
log "✅ Generated SHA256SUMS.txt"

#######################################################################################
# FINAL OUTPUT
#######################################################################################

log ""
log "=== FINAL VERDICT ==="
log "Status: $OVERALL_STATUS"
log "Blockers: $BLOCKERS_COUNT"
log "Evidence: $EVIDENCE_FOLDER"
log "Exit Code: $EXIT_CODE"

exit $EXIT_CODE
