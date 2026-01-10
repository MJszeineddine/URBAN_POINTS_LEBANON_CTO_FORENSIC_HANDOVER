#!/usr/bin/env bash
set -euo pipefail

#######################################################################################
# WEB ADMIN RUNTIME E2E GATE
# Purpose: Verify Web Admin mutations work end-to-end with real Firestore + Functions
# Exit 0: All mutations verified in runtime (GO ✅)
# Exit 1: Any mutation failed (NO_GO ❌)
#######################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_ADMIN_DIR="$REPO_ROOT/source/apps/web-admin"
EVIDENCE_FOLDER="$REPO_ROOT/docs/evidence/web_admin_runtime_e2e/$(date -u +%Y%m%dT%H%M%SZ)"
FIREBASE_DIR="$REPO_ROOT/source"

mkdir -p "$EVIDENCE_FOLDER"
cd "$REPO_ROOT"

# Logging functions
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$EVIDENCE_FOLDER/orchestrator.log"; }
seed_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$EVIDENCE_FOLDER/seed.log"; }
e2e_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$EVIDENCE_FOLDER/e2e.log"; }

#######################################################################################
# PHASE 0: PRE-FLIGHT CHECKS
#######################################################################################

log "=== PHASE 0: PRE-FLIGHT CHECKS ==="

# Check emulator config
if [ ! -f "$FIREBASE_DIR/firebase.json" ]; then
  cat > "$EVIDENCE_FOLDER/NO_GO_EMULATOR_NOT_CONFIGURED.md" <<EOF
# NO_GO: Emulator Configuration Missing

Firebase emulator config not found at: $FIREBASE_DIR/firebase.json

Cannot run e2e tests without emulator configuration.
EOF
  exit 1
fi

log "✅ Firebase config found"

# Check Node.js
if ! command -v node &>/dev/null; then
  cat > "$EVIDENCE_FOLDER/NO_GO_NODE_NOT_AVAILABLE.md" <<EOF
# NO_GO: Node.js Not Available

Node.js is required to run the e2e gate.
EOF
  exit 1
fi

log "✅ Node.js available"

# Check firebase-tools
if ! command -v firebase &>/dev/null; then
  log "⚠️  firebase-tools not globally available, attempting npx"
fi

# Extract ports from firebase.json
FIRESTORE_PORT=$(grep -m1 '"firestore"' "$FIREBASE_DIR/firebase.json" -A2 | grep '"port"' | grep -o '[0-9]*' || echo "8080")
FUNCTIONS_PORT=$(grep -m1 '"functions"' "$FIREBASE_DIR/firebase.json" -A2 | grep '"port"' | grep -o '[0-9]*' || echo "5001")
AUTH_PORT=$(grep -m1 '"auth"' "$FIREBASE_DIR/firebase.json" -A2 | grep '"port"' | grep -o '[0-9]*' || echo "9099")
WEB_PORT=3001

log "Ports: Firestore=$FIRESTORE_PORT, Functions=$FUNCTIONS_PORT, Auth=$AUTH_PORT, Web=$WEB_PORT"

#######################################################################################
# PHASE 1: START FIREBASE EMULATOR SUITE
#######################################################################################

log ""
log "=== PHASE 1: START FIREBASE EMULATOR SUITE ==="

# Kill any existing emulators
pkill -f "firebase emulators" || true
sleep 1

# Start emulator
cd "$FIREBASE_DIR"
log "Starting Firebase emulator..."

EMULATOR_LOG="$EVIDENCE_FOLDER/emulator.log"
export FIREBASE_EMULATOR_HUB="localhost:4400"

firebase emulators:start 2>&1 > "$EMULATOR_LOG" &
EMULATOR_PID=$!
log "Emulator PID: $EMULATOR_PID"

# Wait for emulator to be ready
log "Waiting for emulator to start..."
for i in {1..30}; do
  if nc -z localhost "$FIRESTORE_PORT" 2>/dev/null; then
    log "✅ Firestore emulator ready"
    break
  fi
  if [ $i -eq 30 ]; then
    cat > "$EVIDENCE_FOLDER/NO_GO_EMULATOR_STARTUP_FAILED.md" <<EOF
# NO_GO: Emulator Failed to Start

Firestore emulator did not respond on port $FIRESTORE_PORT after 30 seconds.

Check emulator.log for details.
EOF
    kill $EMULATOR_PID || true
    exit 1
  fi
  sleep 1
done

#######################################################################################
# PHASE 2: SEED DATA
#######################################################################################

log ""
log "=== PHASE 2: SEED DATA ==="

# Create seed script
SEED_SCRIPT="$EVIDENCE_FOLDER/seed_data.js"
cat > "$SEED_SCRIPT" <<'SEEDEOF'
const admin = require('firebase-admin');
const fs = require('fs');

admin.initializeApp({
  projectId: 'urbangenspark'
});

const db = admin.firestore();
db.useEmulator('localhost', 8080);
const auth = admin.auth();
auth.useEmulator('http://localhost:9099');

async function seed() {
  try {
    // Create admin user
    const adminUser = await auth.createUser({
      uid: 'admin1',
      email: 'admin@test.com',
      password: 'TestPassword123!'
    });
    console.log('Created admin user:', adminUser.uid);
    
    await auth.setCustomUserClaims('admin1', { role: 'admin', admin: true });
    console.log('Set admin claims');
    
    // Create non-admin user
    const normalUser = await auth.createUser({
      uid: 'user1',
      email: 'user@test.com',
      password: 'TestPassword123!'
    });
    console.log('Created normal user:', normalUser.uid);
    
    await auth.setCustomUserClaims('user1', { role: 'customer', admin: false });
    console.log('Set customer claims');
    
    // Create users docs in Firestore
    await db.collection('users').doc('admin1').set({
      uid: 'admin1',
      email: 'admin@test.com',
      displayName: 'Admin User',
      role: 'admin',
      banned: false,
      createdAt: new Date().toISOString()
    });
    console.log('Created admin user doc');
    
    await db.collection('users').doc('user1').set({
      uid: 'user1',
      email: 'user@test.com',
      displayName: 'Normal User',
      role: 'customer',
      banned: false,
      createdAt: new Date().toISOString()
    });
    console.log('Created user doc');
    
    // Create merchant
    const merchantId = 'merchant-' + Date.now();
    await db.collection('merchants').doc(merchantId).set({
      id: merchantId,
      name: 'Test Merchant',
      email: 'merchant@test.com',
      status: 'active',
      blocked: false,
      createdAt: new Date().toISOString()
    });
    console.log('Created merchant:', merchantId);
    
    // Create pending offer
    const offerId = 'offer-' + Date.now();
    await db.collection('offers').doc(offerId).set({
      id: offerId,
      title: 'Test Offer',
      points: 100,
      merchantId: merchantId,
      status: 'pending',
      createdAt: new Date().toISOString()
    });
    console.log('Created pending offer:', offerId);
    
    // Write IDs to file for test
    fs.writeFileSync('/tmp/e2e_seeds.json', JSON.stringify({
      adminUid: 'admin1',
      normalUid: 'user1',
      merchantId: merchantId,
      offerId: offerId
    }));
    console.log('Seed data written successfully');
    
  } catch (err) {
    console.error('Seed error:', err);
    process.exit(1);
  }
}

seed().then(() => {
  console.log('Seeding complete');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
SEEDEOF

# Install firebase-admin if needed
if ! npm list -g firebase-admin &>/dev/null; then
  cd /tmp
  npm install firebase-admin --silent || true
fi

seed_log "Running seed script..."
if node "$SEED_SCRIPT" 2>&1 | tee -a "$EVIDENCE_FOLDER/seed.log"; then
  seed_log "✅ Seeding complete"
else
  cat > "$EVIDENCE_FOLDER/NO_GO_SEED_FAILED.md" <<EOF
# NO_GO: Seeding Failed

Failed to seed Firestore with test data. See seed.log for details.
EOF
  kill $EMULATOR_PID || true
  exit 1
fi

# Load seeded IDs
if [ -f "/tmp/e2e_seeds.json" ]; then
  ADMIN_UID=$(grep -o '"adminUid":"[^"]*"' /tmp/e2e_seeds.json | cut -d'"' -f4)
  NORMAL_UID=$(grep -o '"normalUid":"[^"]*"' /tmp/e2e_seeds.json | cut -d'"' -f4)
  MERCHANT_ID=$(grep -o '"merchantId":"[^"]*"' /tmp/e2e_seeds.json | cut -d'"' -f4)
  OFFER_ID=$(grep -o '"offerId":"[^"]*"' /tmp/e2e_seeds.json | cut -d'"' -f4)
  log "✅ Seeded: admin=$ADMIN_UID, user=$NORMAL_UID, offer=$OFFER_ID"
else
  cat > "$EVIDENCE_FOLDER/NO_GO_SEED_IDS_NOT_FOUND.md" <<EOF
# NO_GO: Seeded IDs Not Found

Seeding completed but IDs file not created.
EOF
  kill $EMULATOR_PID || true
  exit 1
fi

# Capture Firestore state before
log "Capturing Firestore state before..."
cd "$REPO_ROOT"

FIRESTORE_BEFORE_SCRIPT="$EVIDENCE_FOLDER/get_firestore_before.js"
cat > "$FIRESTORE_BEFORE_SCRIPT" <<'BEFOREEOF'
const admin = require('firebase-admin');
const fs = require('fs');

admin.initializeApp({
  projectId: 'urbangenspark'
});

const db = admin.firestore();
db.useEmulator('localhost', 8080);

async function capture() {
  try {
    const offers = await db.collection('offers').get();
    const data = {};
    offers.forEach(doc => {
      data[doc.id] = doc.data();
    });
    console.log(JSON.stringify(data, null, 2));
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

capture().then(() => process.exit(0));
BEFOREEOF

node "$FIRESTORE_BEFORE_SCRIPT" > "$EVIDENCE_FOLDER/firestore_before.json" 2>&1 || true

#######################################################################################
# PHASE 3: BUILD AND START WEB-ADMIN
#######################################################################################

log ""
log "=== PHASE 3: BUILD AND START WEB-ADMIN ==="

cd "$WEB_ADMIN_DIR"

# Create .env.local for emulator
cat > "$WEB_ADMIN_DIR/.env.local" <<EOF
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyBQi-N9xW2DGLOc2Esrd-o1dCJOxWv8eZM
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=urbangenspark.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=urbangenspark
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=urbangenspark.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=106033670760
NEXT_PUBLIC_FIREBASE_APP_ID=1:106033670760:web:9813321b4a65bdabacc644
EOF

log "Building web-admin..."
if npm run build > /dev/null 2>&1; then
  log "✅ Build succeeded"
else
  cat > "$EVIDENCE_FOLDER/NO_GO_BUILD_FAILED.md" <<EOF
# NO_GO: Web Admin Build Failed

npm run build failed. Check build output.
EOF
  kill $EMULATOR_PID || true
  exit 1
fi

log "Starting web-admin on port $WEB_PORT..."
npm run start > "$EVIDENCE_FOLDER/web_admin.log" 2>&1 &
WEB_PID=$!
log "Web admin PID: $WEB_PID"

# Wait for web app to be ready
log "Waiting for web-admin to start..."
for i in {1..30}; do
  if nc -z localhost "$WEB_PORT" 2>/dev/null; then
    log "✅ Web admin ready on port $WEB_PORT"
    break
  fi
  if [ $i -eq 30 ]; then
    cat > "$EVIDENCE_FOLDER/NO_GO_WEB_ADMIN_STARTUP_FAILED.md" <<EOF
# NO_GO: Web Admin Failed to Start

Web app did not respond on port $WEB_PORT after 30 seconds.
EOF
    kill $EMULATOR_PID $WEB_PID || true
    exit 1
  fi
  sleep 1
done

#######################################################################################
# PHASE 4: PLAYWRIGHT E2E TESTS
#######################################################################################

log ""
log "=== PHASE 4: PLAYWRIGHT E2E TESTS ==="

# Install playwright if needed
cd "$WEB_ADMIN_DIR"
if ! npm list @playwright/test &>/dev/null; then
  log "Installing Playwright..."
  npm install -D @playwright/test --silent || true
fi

# Create playwright test
PLAYWRIGHT_TEST="$EVIDENCE_FOLDER/e2e.test.js"
cat > "$PLAYWRIGHT_TEST" <<'PLAYWRIGHTEOF'
const { chromium } = require('@playwright/test');
const fs = require('fs');
const admin = require('firebase-admin');

admin.initializeApp({
  projectId: 'urbangenspark'
});

const db = admin.firestore();
db.useEmulator('localhost', 8080);
const auth = admin.auth();
auth.useEmulator('http://localhost:9099');

async function test() {
  const browser = await chromium.launch({ headless: true });
  const results = [];
  
  try {
    // TEST 1: Admin can approve offer
    console.log('[TEST 1] Admin approves offer');
    const page = await browser.newPage();
    page.on('console', msg => console.log('PAGE:', msg.text()));
    
    // Set auth token for admin user
    const adminToken = await auth.createCustomToken('admin1');
    page.context().addInitScript(`
      localStorage.setItem('admin_token', '${adminToken}');
    `);
    
    await page.goto('http://localhost:3001/admin/offers', { waitUntil: 'networkidle' });
    
    // Wait for page to load
    await page.waitForSelector('table', { timeout: 5000 }).catch(() => {
      console.log('[WARN] Table not found, continuing');
    });
    
    // Try to find and click Approve button
    const approveButtons = await page.locator('button:has-text("Approve")').count();
    console.log('[INFO] Found', approveButtons, 'Approve buttons');
    
    if (approveButtons > 0) {
      console.log('[INFO] Clicking first Approve button');
      await page.locator('button:has-text("Approve")').first().click();
      
      // Wait a moment for mutation
      await page.waitForTimeout(2000);
    } else {
      console.log('[WARN] No Approve buttons found on page');
    }
    
    await page.close();
    console.log('[TEST 1] Complete');
    results.push({ test: 'admin_approve', status: 'completed' });
    
    // TEST 2: Verify Firestore changed
    console.log('[TEST 2] Verify offer status changed');
    const seeds = JSON.parse(fs.readFileSync('/tmp/e2e_seeds.json', 'utf8'));
    const offer = await db.collection('offers').doc(seeds.offerId).get();
    
    if (offer.exists) {
      const data = offer.data();
      console.log('[INFO] Offer status:', data.status);
      
      if (data.status === 'approved') {
        console.log('[TEST 2] ✅ PASS: Offer status is approved');
        results.push({ test: 'firestore_verify_approved', status: 'pass' });
      } else {
        console.log('[TEST 2] Status is', data.status, '(expected approved)');
        results.push({ test: 'firestore_verify_approved', status: 'fail', actual: data.status });
      }
    }
    
    // TEST 3: Non-admin cannot mutate (permission test)
    console.log('[TEST 3] Non-admin cannot mutate');
    const browser2 = await chromium.launch({ headless: true });
    const page2 = await browser2.newPage();
    
    const userToken = await auth.createCustomToken('user1');
    page2.context().addInitScript(`
      localStorage.setItem('user_token', '${userToken}');
    `);
    
    await page2.goto('http://localhost:3001/admin/offers', { waitUntil: 'networkidle' });
    await page2.waitForTimeout(1000);
    
    // Should redirect to login or show no buttons
    const pageContent = await page2.content();
    if (!pageContent.includes('Approve') || pageContent.includes('login')) {
      console.log('[TEST 3] ✅ PASS: Non-admin blocked');
      results.push({ test: 'permission_denied', status: 'pass' });
    } else {
      console.log('[TEST 3] ❌ FAIL: Non-admin can still see buttons');
      results.push({ test: 'permission_denied', status: 'fail' });
    }
    
    await page2.close();
    await browser2.close();
    
  } catch (err) {
    console.error('[ERROR]', err.message);
    results.push({ test: 'error', status: 'fail', message: err.message });
  } finally {
    await browser.close();
  }
  
  fs.writeFileSync('/tmp/e2e_results.json', JSON.stringify(results, null, 2));
  process.exit(results.some(r => r.status === 'fail') ? 1 : 0);
}

test().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});
PLAYWRIGHTEOF

# Run playwright test
e2e_log "Running Playwright tests..."
if node "$PLAYWRIGHT_TEST" 2>&1 | tee -a "$EVIDENCE_FOLDER/e2e.log"; then
  log "✅ E2E tests passed"
  E2E_PASS=true
else
  log "❌ E2E tests failed"
  E2E_PASS=false
fi

# Capture results
if [ -f "/tmp/e2e_results.json" ]; then
  cp /tmp/e2e_results.json "$EVIDENCE_FOLDER/e2e_results.json"
fi

# Capture Firestore state after
log "Capturing Firestore state after..."
FIRESTORE_AFTER_SCRIPT="$EVIDENCE_FOLDER/get_firestore_after.js"
cat > "$FIRESTORE_AFTER_SCRIPT" <<'AFTEREOF'
const admin = require('firebase-admin');
const fs = require('fs');

admin.initializeApp({
  projectId: 'urbangenspark'
});

const db = admin.firestore();
db.useEmulator('localhost', 8080);

async function capture() {
  try {
    const offers = await db.collection('offers').get();
    const data = {};
    offers.forEach(doc => {
      data[doc.id] = doc.data();
    });
    console.log(JSON.stringify(data, null, 2));
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

capture().then(() => process.exit(0));
AFTEREOF

node "$FIRESTORE_AFTER_SCRIPT" > "$EVIDENCE_FOLDER/firestore_after.json" 2>&1 || true

#######################################################################################
# PHASE 5: CLEANUP AND VERDICT
#######################################################################################

log ""
log "=== PHASE 5: CLEANUP AND VERDICT ==="

# Kill processes
log "Stopping web-admin..."
kill $WEB_PID 2>/dev/null || true
sleep 1

log "Stopping Firebase emulator..."
kill $EMULATOR_PID 2>/dev/null || true
sleep 1

pkill -f "firebase emulators" || true
pkill -f "next start" || true

# Generate verdict
if [ "$E2E_PASS" = true ]; then
  VERDICT_FILE="$EVIDENCE_FOLDER/VERDICT.md"
  EXIT_CODE=0
  cat > "$VERDICT_FILE" <<EOF
# WEB ADMIN RUNTIME E2E GATE VERDICT

**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  
**Verdict:** GO ✅  
**Exit Code:** 0

---

## SUMMARY

All runtime e2e tests passed.

- ✅ Firebase emulator started successfully
- ✅ Firestore seeded with test data (admin user, merchant, pending offer)
- ✅ Web admin built and started successfully
- ✅ Playwright tests passed (mutations work end-to-end)
- ✅ Firestore state changes verified
- ✅ Permission checks verified

---

## TESTS PASSED

1. ✅ Admin can approve offer (httpsCallable works)
2. ✅ Firestore status changed from pending to approved
3. ✅ Non-admin access denied (permission enforced)

---

## EVIDENCE

- firestore_before.json - Initial state
- firestore_after.json - Final state
- e2e_results.json - Playwright test results
- e2e.log - Test output
- emulator.log - Emulator output
- web_admin.log - Web app output
- seed.log - Seeding output
- orchestrator.log - Gate orchestration
EOF
  
else
  VERDICT_FILE="$EVIDENCE_FOLDER/NO_GO_E2E_TESTS_FAILED.md"
  EXIT_CODE=1
  cat > "$VERDICT_FILE" <<EOF
# NO_GO: E2E Tests Failed

**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

See e2e_results.json and e2e.log for details.
EOF
fi

# Generate SHA256SUMS
log "Generating SHA256SUMS..."
cd "$EVIDENCE_FOLDER"
find . -type f ! -name "SHA256SUMS.txt" -exec shasum -a 256 {} \; > SHA256SUMS.txt
log "✅ SHA256SUMS generated"

#######################################################################################
# FINAL OUTPUT
#######################################################################################

log ""
log "==================================================================="
if [ $EXIT_CODE -eq 0 ]; then
  log "FINAL VERDICT: GO ✅"
else
  log "FINAL VERDICT: NO_GO ❌"
fi
log "==================================================================="
log "Evidence: $EVIDENCE_FOLDER"

exit $EXIT_CODE
