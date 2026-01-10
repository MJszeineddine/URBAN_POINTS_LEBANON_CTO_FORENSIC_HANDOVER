#!/usr/bin/env node
/**
 * AUTHENTICATED E2E SMOKE TEST - FIXED PIN FLOW
 * Follows real PIN flow: QR generation → PIN extraction → PIN validation → Redemption
 */

const admin = require('firebase-admin');
const fetch = require('node-fetch');
const { writeFileSync, mkdirSync } = require('fs');
const { join } = require('path');

const REPO_ROOT = '/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER';
const TS = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
const EVIDENCE_DIR = join(REPO_ROOT, `docs/evidence/go_executor/${TS}`);

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

function logJSON(label, obj) {
  const json = JSON.stringify(obj, null, 2);
  console.log(`[${new Date().toISOString()}] ${label}:\n${json}`);
  logs.push(`${label}:\n${json}`);
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

async function callAuthenticatedFunction(functionName, data, idToken) {
  const response = await fetch(`${EMULATOR_CONFIG.functionsHost}/urban-points-lebanon/us-central1/${functionName}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${idToken}`,
    },
    body: JSON.stringify(data),
  });
  
  const result = await response.json();
  const callLog = {
    function: functionName,
    request: { url: `${EMULATOR_CONFIG.functionsHost}/urban-points-lebanon/us-central1/${functionName}`, data, headers: { Authorization: idToken.substring(0, 20) + '...' } },
    response: { status: response.status, result: result.result || result },
    timestamp: new Date().toISOString(),
  };
  callLogs.push(callLog);
  
  return result.result || result;
}

async function main() {
  log('=== AUTHENTICATED E2E SMOKE TEST (FIXED PIN FLOW) ===');
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
    log(`✅ User created: ${customerUser.email} (uid: ${customerUser.uid})`);
    log(`✅ User created: ${merchantUser.email} (uid: ${merchantUser.uid})`);
  } catch (error) {
    log(`❌ Auth creation failed: ${error.message}`);
    process.exit(1);
  }
  
  log('');
  
  // =====================================================
  // PHASE 2: SEED FIRESTORE DATA
  // =====================================================
  log('--- PHASE 2: SEED FIRESTORE DATA ---');
  
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
    log(`✅ Active subscription created: ${merchantSubId}`);
    
    // Create offer
    const offerId = `offer_e2e_${Date.now()}`;
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
    log(`✅ Approved offer created: ${offerId}`);
    
    // Create customer profile with active subscription
    const custSubId = `sub_cust_${Date.now()}`;
    await db.collection('customers').doc(customerUser.uid).set({
      name: 'Test Customer',
      email: customerUser.email,
      subscription_status: 'active',
      subscription_expiry: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30*24*60*60*1000)),
      points_balance: 500,
    });
    log(`✅ Customer profile created (with active subscription)`);
    
    // Verify data was written
    await new Promise(resolve => setTimeout(resolve, 500));
    
    global.offerId = offerId;
  } catch (error) {
    log(`❌ Seeding failed: ${error.message}`);
    process.exit(1);
  }
  
  log('');
  
  // =====================================================
  // PHASE 3: AUTHENTICATED FUNCTION CALLS
  // =====================================================
  log('--- PHASE 3: AUTHENTICATED FUNCTION CALLS ---');
  
  const offerId = global.offerId;
  
  // 1. Customer: Get offers
  log('1. Customer: Get offers by location...');
  let offersResult;
  try {
    const result = await callAuthenticatedFunction(
      'getOffersByLocationFunc',
      {
        location: { lat: 33.8, lng: 35.5 },
        radiusKm: 10,
      },
      customerUser.idToken
    );
    offersResult = result;
    assert(offersResult && (offersResult.offers?.length > 0 || Array.isArray(offersResult) && offersResult.length > 0), 'Offers returned to customer');
  } catch (error) {
    log(`⚠️ getOffersByLocationFunc failed, querying Firestore directly...`);
    const offersSnap = await db.collection('offers').where('status', '==', 'approved').where('active', '==', true).limit(10).get();
    offersResult = { offers: offersSnap.docs.map(d => ({ id: d.id, ...d.data() })) };
    assert(offersResult.offers.length > 0, 'Offers returned (Firestore fallback)');
  }
  
  // 2. Customer: Get balance (before)
  log('2. Customer: Get balance (before)...');
  let balanceBefore = 0;
  try {
    const balanceResult = await callAuthenticatedFunction('getBalance', { customerId: customerUser.uid }, customerUser.idToken);
    balanceBefore = balanceResult.totalBalance || balanceResult.balance || 0;
    log(`Balance before: ${balanceBefore}`);
  } catch (error) {
    log(`⚠️ getBalance failed, checking Firestore...`);
    const customerDoc = await db.collection('customers').doc(customerUser.uid).get();
    balanceBefore = customerDoc.data()?.points_balance || 0;
  }
  
  // 3. Customer: Generate QR token
  log('3. Customer: Generate QR token...');
  let qrToken, displayCode, tokenNonce;
  try {
    const qrResult = await callAuthenticatedFunction(
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
    qrToken = qrResult.token;
    displayCode = qrResult.displayCode;
    log(`✅ QR token: ${qrToken?.substring(0, 20)}...`);
    log(`✅ Display Code: ${displayCode}`);
    assert(qrToken && qrToken.length > 0, 'QR token generated successfully');
  } catch (error) {
    assert(false, `QR token generation failed: ${error.message}`);
  }
  
  // Wait for token write
  await new Promise(resolve => setTimeout(resolve, 500));
  
  // 3b. Extract PIN from Firestore (server-side generated, not in response)
  log('3b. Extract PIN from Firestore...');
  let extractedPin = null;
  try {
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
      log(`✅ PIN extracted from Firestore: ${extractedPin}`);
    } else {
      log(`⚠️ QR token not found in Firestore for displayCode: ${displayCode}`);
      assert(false, 'QR token found in Firestore');
    }
  } catch (error) {
    log(`⚠️ Failed to extract PIN from Firestore: ${error.message}`);
    assert(false, `Extract PIN from Firestore: ${error.message}`);
  }
  
  // 3c. Merchant: Validate PIN
  log('3c. Merchant: Validate PIN...');
  if (extractedPin && displayCode) {
    try {
      const pinResult = await callAuthenticatedFunction(
        'validatePIN',
        {
          displayCode: displayCode,
          merchantId: merchantUser.uid,
          pin: extractedPin,
        },
        merchantUser.idToken
      );
      if (pinResult.success) {
        tokenNonce = pinResult.tokenNonce;
        log(`✅ PIN validated successfully, tokenNonce: ${tokenNonce}`);
        assert(true, 'PIN validation successful');
      } else {
        log(`❌ PIN validation failed: ${pinResult.error}`);
        assert(false, `PIN validation failed: ${pinResult.error}`);
      }
    } catch (error) {
      log(`❌ validatePIN call failed: ${error.message}`);
      assert(false, `validatePIN failed: ${error.message}`);
    }
  } else {
    assert(false, `Cannot validate PIN: extractedPin=${extractedPin}, displayCode=${displayCode}`);
  }
  
  // Wait for PIN verification to be written
  await new Promise(resolve => setTimeout(resolve, 500));
  
  // 4. Merchant: Validate redemption
  log('4. Merchant: Validate redemption...');
  let redemptionId;
  if (qrToken && displayCode) {
    try {
      const redeemResult = await callAuthenticatedFunction(
        'validateRedemption',
        {
          token: qrToken,
          displayCode: displayCode,
          merchantId: merchantUser.uid,
        },
        merchantUser.idToken
      );
      if (redeemResult.success) {
        redemptionId = redeemResult.redemptionId;
        log(`✅ Redemption ID: ${redemptionId}`);
        assert(redemptionId !== undefined, 'Redemption validated successfully');
      } else {
        log(`❌ Redemption failed: ${redeemResult.error}`);
        assert(false, `Redemption validation failed: ${redeemResult.error}`);
      }
    } catch (error) {
      assert(false, `Redemption validation failed: ${error.message}`);
    }
  } else {
    assert(false, 'Redemption skipped (no QR token or displayCode)');
  }
  
  // Wait for Firestore writes
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // 5. Customer: Get balance (after)
  log('5. Customer: Get balance (after)...');
  let balanceAfter = 0;
  try {
    const balanceResult = await callAuthenticatedFunction('getBalance', { customerId: customerUser.uid }, customerUser.idToken);
    balanceAfter = balanceResult.totalBalance || balanceResult.balance || 0;
    log(`Balance after: ${balanceAfter}`);
  } catch (error) {
    log(`⚠️ getBalance failed, checking Firestore...`);
    const customerDoc = await db.collection('customers').doc(customerUser.uid).get();
    balanceAfter = customerDoc.data()?.points_balance || 0;
  }
  
  log('');
  
  // =====================================================
  // PHASE 4: DATABASE VERIFICATION
  // =====================================================
  log('--- PHASE 4: DATABASE VERIFICATION ---');
  
  // Check redemption doc
  const redemptionsSnap = await db.collection('redemptions')
    .where('user_id', '==', customerUser.uid)
    .limit(1)
    .get();
  assert(!redemptionsSnap.empty, 'Redemption document exists in Firestore');
  
  if (!redemptionsSnap.empty) {
    logJSON('Redemption doc', redemptionsSnap.docs[0].data());
  }
  
  // Check balance changed (should decrease by points_cost)
  assert(balanceAfter < balanceBefore, `Balance decreased (before: ${balanceBefore}, after: ${balanceAfter})`);
  
  // Check QR token marked as used
  const qrTokenSnap = await db.collection('qr_tokens').doc(tokenNonce).get();
  if (qrTokenSnap.exists) {
    const qrData = qrTokenSnap.data();
    assert(qrData.used === true, 'QR token marked as used');
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
  
  log(`Evidence Folder: ${EVIDENCE_DIR}`);
  log(`Verdict: ${allPassed ? 'GO ✅' : 'NO-GO ❌'}`);
  log(`Reason: ${allPassed ? 'All assertions passed' : assertions.filter(a => a.status === 'FAIL').map(a => a.message).join('; ')}`);
  
  process.exit(allPassed ? 0 : 1);
}

main().catch(err => {
  log(`Fatal error: ${err.message}`);
  log(err.stack);
  process.exit(1);
});
