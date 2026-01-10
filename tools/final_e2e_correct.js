#!/usr/bin/env node
/**
 * AUTHENTICATED E2E SMOKE TEST - CORRECTED PIN FLOW
 * Uses proper Firebase callable envelope: { data: {...} }
 */

const admin = require('firebase-admin');
const fetch = require('node-fetch');
const { writeFileSync, mkdirSync } = require('fs');
const { join, isAbsolute } = require('path');

const REPO_ROOT = '/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER';
const ENV_EVD = process.env.E2E_EVIDENCE_DIR;
const EVIDENCE_DIR = ENV_EVD
  ? (isAbsolute(ENV_EVD) ? ENV_EVD : join(REPO_ROOT, ENV_EVD))
  : join(
      REPO_ROOT,
      `docs/evidence/go_executor/${new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5)}`
    );

// Create evidence directory
try {
  mkdirSync(EVIDENCE_DIR, { recursive: true });
} catch (e) {
  console.error('Failed to create evidence dir:', e.message);
}

// Emulator configuration
const EMULATOR_CONFIG = {
  projectId: 'urban-points-lebanon',
  firestoreHost: '127.0.0.1:8080',
  authHost: '127.0.0.1:9099',
  functionsHost: 'http://127.0.0.1:5001',
  authEmulatorUrl: 'http://127.0.0.1:9099',
};

// Set environment variables for Admin SDK
process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_CONFIG.firestoreHost;
process.env.FIREBASE_AUTH_EMULATOR_HOST = EMULATOR_CONFIG.authHost;
process.env.GCLOUD_PROJECT = EMULATOR_CONFIG.projectId;

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({ projectId: EMULATOR_CONFIG.projectId });
}
const db = admin.firestore();

const logs = [];
const callLogs = [];
const assertions = [];
let allPassed = true;

function log(message) {
  const timestamp = new Date().toISOString();
  const line = `[${timestamp}] ${message}`;
  console.log(line);
  logs.push(line);
}

function assert(condition, message) {
  const timestamp = new Date().toISOString();
  if (condition) {
    log(`✅ PASS: ${message}`);
    assertions.push({ timestamp, status: 'PASS', message });
  } else {
    log(`❌ FAIL: ${message}`);
    assertions.push({ timestamp, status: 'FAIL', message });
    allPassed = false;
  }
}

async function createAuthUser(email) {
  const response = await fetch(
    `${EMULATOR_CONFIG.authEmulatorUrl}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: email,
        password: 'test123456',
        returnSecureToken: true,
      }),
    }
  );
  const data = await response.json();
  if (data.idToken) {
    return { uid: data.localId, idToken: data.idToken, email: email };
  } else {
    throw new Error(`Auth creation failed: ${JSON.stringify(data)}`);
  }
}

async function callCallableFunction(functionName, inputData, idToken) {
  const response = await fetch(`${EMULATOR_CONFIG.functionsHost}/urban-points-lebanon/us-central1/${functionName}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${idToken}`,
    },
    body: JSON.stringify({ data: inputData }), // Proper Firebase callable envelope
  });
  
  const result = await response.json();
  const callLog = {
    function: functionName,
    request: {
      body: { data: inputData },
      headers: { Authorization: `Bearer ${idToken}` },
    },
    response: { status: response.status, result: result.result || result },
    timestamp: new Date().toISOString(),
  };
  callLogs.push(callLog);
  
  return result.result || result;
}

async function main() {
  log('=== AUTHENTICATED E2E SMOKE TEST (CORRECT PIN FLOW) ===');
  log('');
  
  // =====================================================
  // PHASE 1: AUTHENTICATION
  // =====================================================
  log('--- PHASE 1: AUTHENTICATION ---');
  
  let customerUser, merchantUser;
  try {
    const ts = Date.now();
    customerUser = await createAuthUser(`customer${ts}@test.com`);
    merchantUser = await createAuthUser(`merchant${ts}@test.com`);
    log(`✅ Customer created: ${customerUser.email} (uid: ${customerUser.uid})`);
    log(`✅ Merchant created: ${merchantUser.email} (uid: ${merchantUser.uid})`);
  } catch (error) {
    log(`❌ Auth creation failed: ${error.message}`);
    process.exit(1);
  }
  
  log('');
  
  // =====================================================
  // PHASE 2: SEED FIRESTORE DATA
  // =====================================================
  log('--- PHASE 2: SEED FIRESTORE DATA ---');
  
  let offerId;
  try {
    // Create merchant profile
    const merchantSubId = `sub_e2e_${Date.now()}`;
    await db.collection('merchants').doc(merchantUser.uid).set({
      name: 'Test Merchant',
      email: merchantUser.email,
      location: { lat: 33.8, lng: 35.5 },
      subscription_status: 'active',
      subscriptions: { [merchantSubId]: { status: 'active' } },
    });
    log(`✅ Merchant profile created`);
    
    // Create merchant subscription
    await db.collection('subscriptions').doc(merchantSubId).set({
      merchant_id: merchantUser.uid,
      status: 'active',
      plan: 'premium',
    });
    log(`✅ Merchant subscription created`);
    
    // Create offer
    offerId = `offer_e2e_${Date.now()}`;
    await db.collection('offers').doc(offerId).set({
      title: '50% Coffee Discount',
      description: 'Half off any coffee',
      merchant_id: merchantUser.uid,
      points_cost: 100,
      is_active: true,
      active: true,
      status: 'approved',
      location: { lat: 33.8, lng: 35.5 },
    });
    log(`✅ Offer created: ${offerId}`);
    
    // Create customer profile with active subscription
    await db.collection('customers').doc(customerUser.uid).set({
      name: 'Test Customer',
      email: customerUser.email,
      subscription_status: 'active',
      subscription_expiry: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30*24*60*60*1000)),
      points_balance: 500,
    });
    log(`✅ Customer created with active subscription`);
    
    // Verify data was written
    await new Promise(resolve => setTimeout(resolve, 500));
  } catch (error) {
    log(`❌ Seeding failed: ${error.message}`);
    process.exit(1);
  }
  
  log('');
  
  // =====================================================
  // PHASE 3: AUTHENTICATED FUNCTION CALLS
  // =====================================================
  log('--- PHASE 3: AUTHENTICATED FUNCTION CALLS ---');
  
  // 1. Customer: Get balance (before)
  log('1. Customer: Get balance (before)...');
  let balanceBefore = 0;
  try {
    const balanceResult = await callCallableFunction('getBalance', { customerId: customerUser.uid }, customerUser.idToken);
    balanceBefore = balanceResult.totalBalance || balanceResult.balance || 0;
    log(`Balance before: ${balanceBefore}`);
  } catch (error) {
    log(`⚠️ getBalance failed: ${error.message}`);
    const customerDoc = await db.collection('customers').doc(customerUser.uid).get();
    balanceBefore = customerDoc.data()?.points_balance || 0;
  }
  
  // 2. Customer: Generate QR token
  log('2. Customer: Generate QR token...');
  let qrToken, displayCode, tokenNonce;
  try {
    const qrResult = await callCallableFunction(
      'generateSecureQRToken',
      {
        userId: customerUser.uid,
        offerId: offerId,
        merchantId: merchantUser.uid,
        deviceHash: 'e2e_device_hash',
        partySize: 2,
      },
      customerUser.idToken
    );
    if (qrResult.success === false) {
      throw new Error(qrResult.error);
    }
    qrToken = qrResult.token;
    displayCode = qrResult.displayCode;
    log(`✅ QR generated: displayCode=${displayCode}`);
    assert(qrToken && displayCode, 'QR token generated successfully');
  } catch (error) {
    assert(false, `QR generation failed: ${error.message}`);
  }
  
  // Wait for token write
  await new Promise(resolve => setTimeout(resolve, 500));
  
  // 3. Extract PIN from Firestore
  log('3. Extract PIN from Firestore...');
  let extractedPin = null;
  try {
    if (displayCode) {
      const tokenQuery = await db.collection('qr_tokens')
        .where('display_code', '==', displayCode)
        .where('merchant_id', '==', merchantUser.uid)
        .where('used', '==', false)
        .limit(1)
        .get();
      
      if (!tokenQuery.empty) {
        const tokenData = tokenQuery.docs[0].data();
        tokenNonce = tokenQuery.docs[0].id;
        extractedPin = tokenData.one_time_pin;
        log(`✅ PIN extracted: ${extractedPin}`);
        assert(extractedPin, 'PIN extracted from Firestore');
      } else {
        log(`❌ QR token not found by displayCode=${displayCode}`);
        assert(false, 'QR token found in Firestore');
      }
    } else {
      assert(false, 'No displayCode to query');
    }
  } catch (error) {
    assert(false, `Extract PIN failed: ${error.message}`);
  }
  
  // 4. Merchant: Validate PIN
  log('4. Merchant: Validate PIN...');
  if (extractedPin && displayCode) {
    try {
      const pinResult = await callCallableFunction(
        'validatePIN',
        {
          displayCode: displayCode,
          merchantId: merchantUser.uid,
          pin: extractedPin,
        },
        merchantUser.idToken
      );
      if (pinResult.success === false) {
        throw new Error(pinResult.error);
      }
      tokenNonce = pinResult.tokenNonce;
      log(`✅ PIN validated, tokenNonce=${tokenNonce}`);
      assert(true, 'PIN validation successful');
    } catch (error) {
      assert(false, `PIN validation failed: ${error.message}`);
    }
  } else {
    assert(false, `Cannot validate PIN: pin=${extractedPin}, code=${displayCode}`);
  }
  
  // Wait for PIN verification write
  await new Promise(resolve => setTimeout(resolve, 500));
  
  // 5. Merchant: Validate redemption
  log('5. Merchant: Validate redemption...');
  let redemptionId;
  if (qrToken) {
    try {
      const redeemResult = await callCallableFunction(
        'validateRedemption',
        {
          token: qrToken,
          displayCode: displayCode,
          merchantId: merchantUser.uid,
        },
        merchantUser.idToken
      );
      if (redeemResult.success === false) {
        throw new Error(redeemResult.error);
      }
      redemptionId = redeemResult.redemptionId;
      log(`✅ Redemption ID: ${redemptionId}`);
      assert(true, 'Redemption validated successfully');
    } catch (error) {
      assert(false, `Redemption failed: ${error.message}`);
    }
  } else {
    assert(false, 'Redemption skipped (no QR token)');
  }
  
  // Wait for writes
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // 6. Customer: Get balance (after)
  log('6. Customer: Get balance (after)...');
  let balanceAfter = 0;
  try {
    const balanceResult = await callCallableFunction('getBalance', { customerId: customerUser.uid }, customerUser.idToken);
    balanceAfter = balanceResult.totalBalance || balanceResult.balance || 0;
    log(`Balance after: ${balanceAfter}`);
  } catch (error) {
    log(`⚠️ getBalance failed: ${error.message}`);
    const customerDoc = await db.collection('customers').doc(customerUser.uid).get();
    balanceAfter = customerDoc.data()?.points_balance || 0;
  }
  
  log('');
  
  // =====================================================
  // PHASE 4: DATABASE VERIFICATION
  // =====================================================
  log('--- PHASE 4: DATABASE VERIFICATION ---');
  
  // Check redemption doc
  try {
    const redemptionsSnap = await db.collection('redemptions')
      .where('user_id', '==', customerUser.uid)
      .limit(1)
      .get();
    assert(!redemptionsSnap.empty, 'Redemption document exists');
  } catch (error) {
    assert(false, `Redemption check failed: ${error.message}`);
  }
  
  // Check balance changed
  assert(balanceAfter < balanceBefore, `Balance decreased (${balanceBefore} → ${balanceAfter})`);
  
  // Check QR marked as used
  try {
    if (tokenNonce) {
      const qrDoc = await db.collection('qr_tokens').doc(tokenNonce).get();
      if (qrDoc.exists) {
        assert(qrDoc.data().used === true, 'QR token marked as used');
      }
    }
  } catch (error) {
    log(`⚠️ QR doc check failed: ${error.message}`);
  }
  
  log('');
  log('========================================');
  log('FINAL VERDICT');
  log('========================================');
  log(`Total assertions: ${assertions.length}`);
  log(`Passed: ${assertions.filter(a => a.status === 'PASS').length}`);
  log(`Failed: ${assertions.filter(a => a.status === 'FAIL').length}`);
  log(`Result: ${allPassed ? 'GO ✅' : 'NO-GO ❌'}`);
  log('');
  
  // Write evidence files
  writeFileSync(join(EVIDENCE_DIR, 'e2e_calls.jsonl'), callLogs.map(c => JSON.stringify(c)).join('\n'));
  writeFileSync(join(EVIDENCE_DIR, 'e2e_assertions.json'), JSON.stringify(assertions, null, 2));
  writeFileSync(join(EVIDENCE_DIR, 'e2e_full.log'), logs.join('\n'));
  
  log(`Evidence: ${EVIDENCE_DIR}`);
  log(`Verdict: ${allPassed ? 'GO ✅' : 'NO-GO ❌'}`);
  
  process.exit(allPassed ? 0 : 1);
}

main().catch(err => {
  log(`Fatal error: ${err.message}`);
  process.exit(1);
});
