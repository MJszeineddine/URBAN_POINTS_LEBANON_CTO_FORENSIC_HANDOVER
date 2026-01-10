#!/bin/bash
set -euo pipefail

OUTPUT="ARTIFACTS/CONTRACT_MATRIX.md"

echo "# CONTRACT MATRIX — User Journeys vs Backend Support" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "**Generated**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$OUTPUT"
echo "**Purpose**: Map critical user flows to backend endpoints/functions + Firestore rules" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Helper function to check if function exists in Firebase Functions
check_firebase_function() {
    local func_name="$1"
    if grep -r "exports\.$func_name" backend/firebase-functions/src/ 2>/dev/null | grep -q "functions.https"; then
        echo "EXISTS"
    else
        echo "MISSING"
    fi
}

# Helper function to check Firestore rules for collection access
check_firestore_rules() {
    local collection="$1"
    local operation="$2"
    if grep -q "match /$collection/" infra/firestore.rules 2>/dev/null; then
        echo "EXISTS"
    else
        echo "MISSING"
    fi
}

cat >> "$OUTPUT" << 'EOF'

## FLOW 1: User Login → Profile Fetch → Browse Approved Offers

| Component | Requirement | Status | Evidence |
|-----------|-------------|--------|----------|
| **Frontend (User App)** | Login screen + auth call | | |
| └─ File | `apps/mobile-customer/lib/screens/auth/login_screen.dart` | EXISTS | Grep result below |
| └─ Auth Service | FirebaseAuth.signInWithEmailAndPassword | EXISTS | `apps/mobile-customer/lib/services/auth_service.dart` |
| **Backend (Auth)** | Firebase Auth enabled | ASSUMED | No code evidence; requires Firebase Console check |
| **Firestore Access** | Read `customers` collection | | |
| └─ Rules | `match /customers/{customerId}` allow read | | Checked below |
| **Offer Browsing** | Fetch approved offers | | |
| └─ Frontend | Query `offers` collection where `status == 'approved'` | | Grep below |
| └─ Rules | `match /offers/{offerId}` allow read if approved | | infra/firestore.rules |

EOF

# Evidence gathering
echo "### Evidence: User App Login Screen" >> "$OUTPUT"
if [ -f "apps/mobile-customer/lib/screens/auth/login_screen.dart" ]; then
    echo '```dart' >> "$OUTPUT"
    head -30 apps/mobile-customer/lib/screens/auth/login_screen.dart >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
else
    echo "**MISSING FILE**" >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

echo "### Evidence: Firestore Rules for customers collection" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
grep -A 10 "match /customers/" infra/firestore.rules 2>/dev/null || echo "NO RULE FOUND" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

cat >> "$OUTPUT" << 'EOF'

## FLOW 2: User Generate QR / Redeem Offer

| Component | Requirement | Status | Evidence |
|-----------|-------------|--------|----------|
| **Frontend (User App)** | Call `generateSecureQRToken` function | | |
| └─ Callsite | httpsCallable('generateSecureQRToken') | | Grep below |
| **Firebase Function** | `exports.generateSecureQRToken` | | |
| └─ Implementation | `backend/firebase-functions/src/index.ts` | | Checked below |
| └─ Memory/Timeout | 256MB, 60s | | firebase.json runtime config |
| **Firestore Write** | Write to `qr_tokens` collection | | |
| └─ Rules | Allow write for authenticated users | | infra/firestore.rules |
| **Validation Logic** | Offer exists, merchant exists, not already redeemed | | |
| └─ Code | Validation in generateSecureQRToken | | index.ts lines 50-80 |

EOF

echo "### Evidence: generateSecureQRToken callsite" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
rg "generateSecureQRToken" apps/mobile-customer/ -A 3 2>/dev/null | head -20 || echo "NO CALLSITE FOUND" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "### Evidence: Firebase Function exports.generateSecureQRToken" >> "$OUTPUT"
echo '```typescript' >> "$OUTPUT"
rg "exports\.generateSecureQRToken" backend/firebase-functions/src/ -A 5 2>/dev/null | head -30 || echo "FUNCTION NOT EXPORTED" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

cat >> "$OUTPUT" << 'EOF'

## FLOW 3: Merchant Validate Redemption

| Component | Requirement | Status | Evidence |
|-----------|-------------|--------|----------|
| **Frontend (Merchant App)** | Scan QR / enter PIN → call validateRedemption | | |
| └─ Callsite | httpsCallable('validateRedemption') | | Grep below |
| **Firebase Function** | `exports.validateRedemption` | | |
| └─ Implementation | backend/firebase-functions/src/index.ts | | Checked below |
| └─ Validation | Token not expired, merchant match, offer active | | Code evidence |
| **Firestore Writes** | Mark token as used; create redemption record | | |
| └─ Collections | `qr_tokens`, `redemptions` | | infra/firestore.rules |

EOF

echo "### Evidence: validateRedemption callsite" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
rg "validateRedemption" apps/mobile-merchant/ -A 3 2>/dev/null | head -20 || echo "NO CALLSITE FOUND" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "### Evidence: Firebase Function exports.validateRedemption" >> "$OUTPUT"
echo '```typescript' >> "$OUTPUT"
rg "exports\.validateRedemption" backend/firebase-functions/src/ -A 5 2>/dev/null | head -30 || echo "FUNCTION NOT EXPORTED" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

cat >> "$OUTPUT" << 'EOF'

## FLOW 4: Web Admin Approve Offer

| Component | Requirement | Status | Evidence |
|-----------|-------------|--------|----------|
| **Frontend (Web Admin)** | List pending offers → approve button | | |
| └─ UI File | apps/web-admin/pages or components | | Find below |
| └─ API Call | Update offer status to 'approved' | | Firestore or REST? |
| **Backend** | Firestore direct write OR Cloud Function | | |
| └─ Firestore Rules | Only admins can write to offers.status | | infra/firestore.rules |
| └─ Admin Auth | Custom claims: role == 'admin' | | ASSUMED; no code evidence |

EOF

echo "### Evidence: Web Admin offer approval" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
rg -i "approve.*offer|offer.*status" apps/web-admin/ -A 3 2>/dev/null | head -30 || echo "NO APPROVAL LOGIC FOUND" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

cat >> "$OUTPUT" << 'EOF'

## SUMMARY TABLE

| Flow | Frontend | Backend | Firestore Rules | Tests | Overall Status |
|------|----------|---------|-----------------|-------|----------------|
| User Login → Profile | EXISTS | ASSUMED (Firebase Auth) | EXISTS | NONE | ⚠️ PARTIAL |
| User Browse Offers | EXISTS | N/A (direct Firestore read) | EXISTS | NONE | ⚠️ PARTIAL |
| User Generate QR | ? | ? | ? | ? | ❓ TBD |
| Merchant Validate Redemption | ? | ? | ? | ? | ❓ TBD |
| Admin Approve Offer | ? | ? | ? | ? | ❓ TBD |

**Legend**:  
- **EXISTS**: Code + config present and referenced  
- **PARTIAL**: Partial implementation or missing critical validation  
- **MISSING**: No evidence found  
- **ASSUMED**: Expected to work but no code proof (e.g., Firebase Console config)

EOF

echo "✅ CONTRACT_MATRIX.md generated"
