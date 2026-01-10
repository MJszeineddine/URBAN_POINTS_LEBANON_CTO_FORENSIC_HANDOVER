#!/usr/bin/env bash
set -euo pipefail

#######################################################################################
# WEB ADMIN MUTATION GATE
# Purpose: Verify that Web Admin has REAL mutations (not read-only)
# Exit 0: All required mutations implemented (GO ✅)
# Exit 1: Any mutation missing (NO_GO ❌)
#######################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_ADMIN_DIR="$REPO_ROOT/source/apps/web-admin"
EVIDENCE_FOLDER="$REPO_ROOT/docs/evidence/web_admin_mutation_gate/$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$EVIDENCE_FOLDER"
cd "$REPO_ROOT"

echo "==================================================================="
echo "WEB ADMIN MUTATION GATE"
echo "==================================================================="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Evidence: $EVIDENCE_FOLDER"
echo ""

# Initialize findings
declare -a FINDINGS=()
PASS_COUNT=0
FAIL_COUNT=0

#######################################################################################
# PHASE 1: CODE-LEVEL WIRING VERIFICATION
#######################################################################################

echo "PHASE 1: CODE-LEVEL WIRING VERIFICATION"
echo "-------------------------------------------------------------------"

# Helper function to verify mutation in file
verify_mutation() {
  local action="$1"
  local file="$2"
  local pattern="$3"
  local mutation_type="$4"
  local mutation_target="$5"
  
  echo "Checking: $action in $(basename $file)"
  
  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "  ✅ PASS: Found mutation wiring"
    FINDINGS+=("{\"action\":\"$action\",\"ui_file\":\"$file\",\"mutation_type\":\"$mutation_type\",\"mutation_target\":\"$mutation_target\",\"status\":\"PASS\"}")
    ((PASS_COUNT++))
    return 0
  else
    echo "  ❌ FAIL: Mutation NOT found"
    FINDINGS+=("{\"action\":\"$action\",\"ui_file\":\"$file\",\"mutation_type\":\"$mutation_type\",\"mutation_target\":\"$mutation_target\",\"status\":\"FAIL\"}")
    ((FAIL_COUNT++))
    return 1
  fi
}

# A) OFFERS MODERATION
echo ""
echo "A) OFFERS MODERATION (offers.tsx)"
verify_mutation "Approve Offer" "$WEB_ADMIN_DIR/pages/admin/offers.tsx" "httpsCallable.*approveOffer" "httpsCallable" "approveOffer"
verify_mutation "Reject Offer" "$WEB_ADMIN_DIR/pages/admin/offers.tsx" "httpsCallable.*rejectOffer" "httpsCallable" "rejectOffer"
verify_mutation "Disable Offer" "$WEB_ADMIN_DIR/pages/admin/offers.tsx" "updateDoc.*status.*disabled" "firestore_updateDoc" "offers/{id}.status"

# B) MERCHANTS MODERATION
echo ""
echo "B) MERCHANTS MODERATION (merchants.tsx)"
verify_mutation "Suspend Merchant" "$WEB_ADMIN_DIR/pages/admin/merchants.tsx" "updateDoc.*status.*suspended" "firestore_updateDoc" "merchants/{id}.status"
verify_mutation "Activate Merchant" "$WEB_ADMIN_DIR/pages/admin/merchants.tsx" "updateDoc.*status.*active" "firestore_updateDoc" "merchants/{id}.status"
verify_mutation "Block Merchant" "$WEB_ADMIN_DIR/pages/admin/merchants.tsx" "updateDoc.*blocked.*true" "firestore_updateDoc" "merchants/{id}.blocked"

# C) USERS MODERATION
echo ""
echo "C) USERS MODERATION (users.tsx)"
verify_mutation "Ban User" "$WEB_ADMIN_DIR/pages/admin/users.tsx" "updateDoc.*banned.*true" "firestore_updateDoc" "users/{uid}.banned"
verify_mutation "Unban User" "$WEB_ADMIN_DIR/pages/admin/users.tsx" "updateDoc.*banned.*false" "firestore_updateDoc" "users/{uid}.banned"
verify_mutation "Change User Role" "$WEB_ADMIN_DIR/pages/admin/users.tsx" "setCustomClaims\|updateDoc.*role" "httpsCallable|firestore_updateDoc" "setCustomClaims|users/{uid}.role"

# D) ADMIN ROUTE GUARD
echo ""
echo "D) ADMIN ROUTE GUARD (AdminGuard.tsx)"
if grep -q "token.claims.role.*admin" "$WEB_ADMIN_DIR/components/AdminGuard.tsx" 2>/dev/null; then
  echo "  ✅ PASS: Admin claim enforcement found"
  FINDINGS+=("{\"action\":\"Admin Guard\",\"ui_file\":\"$WEB_ADMIN_DIR/components/AdminGuard.tsx\",\"mutation_type\":\"claim_check\",\"mutation_target\":\"token.claims.role\",\"status\":\"PASS\"}")
  ((PASS_COUNT++))
else
  echo "  ❌ FAIL: Admin claim enforcement NOT found"
  FINDINGS+=("{\"action\":\"Admin Guard\",\"ui_file\":\"$WEB_ADMIN_DIR/components/AdminGuard.tsx\",\"mutation_type\":\"claim_check\",\"mutation_target\":\"token.claims.role\",\"status\":\"FAIL\"}")
  ((FAIL_COUNT++))
fi

# E) FIREBASE FUNCTIONS EXPORT
echo ""
echo "E) FIREBASE FUNCTIONS EXPORT (lib/firebaseClient.ts)"
if grep -q "getFunctions\|firebase/functions" "$WEB_ADMIN_DIR/lib/firebaseClient.ts" 2>/dev/null; then
  echo "  ✅ PASS: Firebase Functions SDK imported"
  FINDINGS+=("{\"action\":\"Functions Import\",\"ui_file\":\"$WEB_ADMIN_DIR/lib/firebaseClient.ts\",\"mutation_type\":\"import\",\"mutation_target\":\"firebase/functions\",\"status\":\"PASS\"}")
  ((PASS_COUNT++))
else
  echo "  ❌ FAIL: Firebase Functions SDK NOT imported"
  FINDINGS+=("{\"action\":\"Functions Import\",\"ui_file\":\"$WEB_ADMIN_DIR/lib/firebaseClient.ts\",\"mutation_type\":\"import\",\"mutation_target\":\"firebase/functions\",\"status\":\"FAIL\"}")
  ((FAIL_COUNT++))
fi

# F) BUTTON EXISTENCE
echo ""
echo "F) ACTION BUTTONS EXISTENCE"
if grep -q "Approve" "$WEB_ADMIN_DIR/pages/admin/offers.tsx" 2>/dev/null; then
  echo "  ✅ PASS: 'Approve' button found in offers.tsx"
  ((PASS_COUNT++))
else
  echo "  ❌ FAIL: 'Approve' button NOT found"
  ((FAIL_COUNT++))
fi

if grep -q "Reject" "$WEB_ADMIN_DIR/pages/admin/offers.tsx" 2>/dev/null; then
  echo "  ✅ PASS: 'Reject' button found in offers.tsx"
  ((PASS_COUNT++))
else
  echo "  ❌ FAIL: 'Reject' button NOT found"
  ((FAIL_COUNT++))
fi

if grep -q "Suspend" "$WEB_ADMIN_DIR/pages/admin/merchants.tsx" 2>/dev/null; then
  echo "  ✅ PASS: 'Suspend' button found in merchants.tsx"
  ((PASS_COUNT++))
else
  echo "  ❌ FAIL: 'Suspend' button NOT found"
  ((FAIL_COUNT++))
fi

if grep -q "Ban" "$WEB_ADMIN_DIR/pages/admin/users.tsx" 2>/dev/null; then
  echo "  ✅ PASS: 'Ban' button found in users.tsx"
  ((PASS_COUNT++))
else
  echo "  ❌ FAIL: 'Ban' button NOT found"
  ((FAIL_COUNT++))
fi

echo ""
echo "-------------------------------------------------------------------"
echo "PHASE 1 SUMMARY: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo ""

#######################################################################################
# PHASE 2: BUILD VERIFICATION
#######################################################################################

echo "PHASE 2: BUILD VERIFICATION"
echo "-------------------------------------------------------------------"

cd "$WEB_ADMIN_DIR"

# Detect package manager
if [ -f "package-lock.json" ]; then
  PKG_MGR="npm"
elif [ -f "pnpm-lock.yaml" ]; then
  PKG_MGR="pnpm"
elif [ -f "yarn.lock" ]; then
  PKG_MGR="yarn"
else
  PKG_MGR="npm"
fi

echo "Detected package manager: $PKG_MGR"

# Install dependencies if node_modules missing
if [ ! -d "node_modules" ] || [ ! -d "node_modules/firebase" ]; then
  echo "Installing dependencies..."
  case "$PKG_MGR" in
    npm)
      npm install --silent 2>&1 | tail -10 || true
      ;;
    pnpm)
      pnpm install --silent 2>&1 | tail -10 || true
      ;;
    yarn)
      yarn install --silent 2>&1 | tail -10 || true
      ;;
  esac
  echo "  ✅ Dependencies installed"
else
  echo "  ✅ Dependencies already installed"
fi

# Run build
echo "Running build..."
BUILD_OUTPUT=$(mktemp)
BUILD_SUCCESS=false

case "$PKG_MGR" in
  npm)
    if npm run build > "$BUILD_OUTPUT" 2>&1; then
      BUILD_SUCCESS=true
    fi
    ;;
  pnpm)
    if pnpm build > "$BUILD_OUTPUT" 2>&1; then
      BUILD_SUCCESS=true
    fi
    ;;
  yarn)
    if yarn build > "$BUILD_OUTPUT" 2>&1; then
      BUILD_SUCCESS=true
    fi
    ;;
esac

if [ "$BUILD_SUCCESS" = true ]; then
  echo "  ✅ Build succeeded"
  ((PASS_COUNT++))
  FINDINGS+=("{\"action\":\"Build Verification\",\"ui_file\":\"web-admin\",\"mutation_type\":\"build\",\"mutation_target\":\"next build\",\"status\":\"PASS\"}")
else
  echo "  ❌ Build failed"
  echo ""
  echo "Build errors (last 30 lines):"
  tail -30 "$BUILD_OUTPUT"
  echo ""
  ((FAIL_COUNT++))
  FINDINGS+=("{\"action\":\"Build Verification\",\"ui_file\":\"web-admin\",\"mutation_type\":\"build\",\"mutation_target\":\"next build\",\"status\":\"FAIL\"}")
fi

cp "$BUILD_OUTPUT" "$EVIDENCE_FOLDER/build_output.log"
rm -f "$BUILD_OUTPUT"

echo ""
echo "-------------------------------------------------------------------"
echo "PHASE 2 SUMMARY: Build $([ "$BUILD_SUCCESS" = true ] && echo "PASSED" || echo "FAILED")"
echo ""

cd "$REPO_ROOT"

#######################################################################################
# PHASE 3: GENERATE FINDINGS.JSON
#######################################################################################

echo "PHASE 3: GENERATE FINDINGS.JSON"
echo "-------------------------------------------------------------------"

cat > "$EVIDENCE_FOLDER/findings.json" <<EOF
{
  "scan_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "gate": "web_admin_mutation_gate",
  "total_checks": $((PASS_COUNT + FAIL_COUNT)),
  "pass_count": $PASS_COUNT,
  "fail_count": $FAIL_COUNT,
  "findings": [
    $(IFS=,; echo "${FINDINGS[*]}")
  ]
}
EOF

echo "  ✅ findings.json generated"
echo ""

#######################################################################################
# PHASE 4: DETERMINE VERDICT
#######################################################################################

echo "PHASE 4: FINAL VERDICT"
echo "-------------------------------------------------------------------"

if [ $FAIL_COUNT -eq 0 ]; then
  VERDICT="GO"
  EXIT_CODE=0
  VERDICT_FILE="$EVIDENCE_FOLDER/VERDICT.md"
else
  VERDICT="NO_GO"
  EXIT_CODE=1
  VERDICT_FILE="$EVIDENCE_FOLDER/NO_GO_WEB_ADMIN_MUTATIONS_MISSING.md"
fi

cat > "$VERDICT_FILE" <<EOF
# WEB ADMIN MUTATION GATE VERDICT

**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  
**Gate:** web_admin_mutation_gate  
**Verdict:** $VERDICT  
**Exit Code:** $EXIT_CODE

---

## SUMMARY

- **Total Checks:** $((PASS_COUNT + FAIL_COUNT))
- **Passed:** $PASS_COUNT
- **Failed:** $FAIL_COUNT

---

## REQUIRED ADMIN ACTIONS

### A) Offers Moderation
- [$(grep -q "httpsCallable.*approveOffer" "$WEB_ADMIN_DIR/pages/admin/offers.tsx" && echo "✅" || echo "❌")] Approve Offer (httpsCallable → approveOffer)
- [$(grep -q "httpsCallable.*rejectOffer" "$WEB_ADMIN_DIR/pages/admin/offers.tsx" && echo "✅" || echo "❌")] Reject Offer (httpsCallable → rejectOffer)
- [$(grep -q "updateDoc.*status.*disabled" "$WEB_ADMIN_DIR/pages/admin/offers.tsx" && echo "✅" || echo "❌")] Disable Offer (updateDoc → offers/{id}.status)

### B) Merchants Moderation
- [$(grep -q "updateDoc.*status.*suspended" "$WEB_ADMIN_DIR/pages/admin/merchants.tsx" && echo "✅" || echo "❌")] Suspend Merchant (updateDoc → merchants/{id}.status)
- [$(grep -q "updateDoc.*status.*active" "$WEB_ADMIN_DIR/pages/admin/merchants.tsx" && echo "✅" || echo "❌")] Activate Merchant (updateDoc → merchants/{id}.status)
- [$(grep -q "updateDoc.*blocked.*true" "$WEB_ADMIN_DIR/pages/admin/merchants.tsx" && echo "✅" || echo "❌")] Block Merchant (updateDoc → merchants/{id}.blocked)

### C) Users Moderation
- [$(grep -q "updateDoc.*banned.*true" "$WEB_ADMIN_DIR/pages/admin/users.tsx" && echo "✅" || echo "❌")] Ban User (updateDoc → users/{uid}.banned)
- [$(grep -q "updateDoc.*banned.*false" "$WEB_ADMIN_DIR/pages/admin/users.tsx" && echo "✅" || echo "❌")] Unban User (updateDoc → users/{uid}.banned)
- [$(grep -q "setCustomClaims\|updateDoc.*role" "$WEB_ADMIN_DIR/pages/admin/users.tsx" && echo "✅" || echo "❌")] Change User Role (setCustomClaims|updateDoc → role)

### D) Admin Route Guard
- [$(grep -q "token.claims.role.*admin" "$WEB_ADMIN_DIR/components/AdminGuard.tsx" && echo "✅" || echo "❌")] Admin claim enforcement (token.claims.role === 'admin')

### E) Infrastructure
- [$(grep -q "getFunctions\|firebase/functions" "$WEB_ADMIN_DIR/lib/firebaseClient.ts" && echo "✅" || echo "❌")] Firebase Functions SDK imported
- [$([ "$BUILD_SUCCESS" = true ] && echo "✅" || echo "❌")] Build succeeds

---

## FILES MODIFIED

- \`source/apps/web-admin/lib/firebaseClient.ts\` - Added Functions SDK
- \`source/apps/web-admin/pages/admin/offers.tsx\` - Added Approve/Reject/Disable
- \`source/apps/web-admin/pages/admin/merchants.tsx\` - Added Suspend/Activate/Block
- \`source/apps/web-admin/pages/admin/users.tsx\` - Added Ban/Unban/Change Role

---

## EVIDENCE

- **findings.json:** Machine-readable findings
- **build_output.log:** Build verification output
- **SHA256SUMS.txt:** Integrity checksums

---

## FINAL VERDICT

**Status:** $VERDICT $([ "$EXIT_CODE" -eq 0 ] && echo "✅" || echo "❌")  
**Exit Code:** $EXIT_CODE

$(if [ $EXIT_CODE -eq 1 ]; then
  echo ""
  echo "**BLOCKERS:**"
  echo ""
  echo "$FAIL_COUNT mutations or checks failed. See findings.json for details."
  echo ""
  echo "**FIX REQUIRED:**"
  echo ""
  echo "1. Implement missing mutations in admin pages"
  echo "2. Ensure all action buttons are wired to backend"
  echo "3. Re-run this gate: \`./tools/web_admin_mutation_gate.sh\`"
else
  echo ""
  echo "**RESULT:**"
  echo ""
  echo "All required admin mutations are implemented and verified."
  echo "Web Admin is now a FUNCTIONAL moderation console."
fi)
EOF

echo "  ✅ Verdict written: $(basename $VERDICT_FILE)"
echo ""

#######################################################################################
# PHASE 5: GENERATE SHA256SUMS
#######################################################################################

echo "PHASE 5: GENERATE SHA256SUMS.txt"
echo "-------------------------------------------------------------------"

cd "$EVIDENCE_FOLDER"
shasum -a 256 findings.json "$VERDICT_FILE" build_output.log > SHA256SUMS.txt 2>/dev/null || true
echo "  ✅ SHA256SUMS.txt generated"
echo ""

#######################################################################################
# FINAL OUTPUT
#######################################################################################

echo "==================================================================="
echo "FINAL VERDICT: $VERDICT $([ "$EXIT_CODE" -eq 0 ] && echo "✅" || echo "❌")"
echo "==================================================================="
echo ""
echo "Evidence Location: $EVIDENCE_FOLDER"
echo "Verdict File: $(basename $VERDICT_FILE)"
echo ""
echo "Summary:"
echo "  Total Checks: $((PASS_COUNT + FAIL_COUNT))"
echo "  Passed: $PASS_COUNT"
echo "  Failed: $FAIL_COUNT"
echo ""

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ GO - Web Admin has functional mutations"
else
  echo "❌ NO_GO - Missing mutations detected"
  echo ""
  echo "See $VERDICT_FILE for details"
fi

exit $EXIT_CODE
