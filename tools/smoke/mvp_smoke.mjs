#!/usr/bin/env node
/**
 * MVP Smoke Gate - Firebase Emulator End-to-End Callable Tests
 * Tests DTO contracts with real Firebase Client SDK calls
 */

import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, signInWithEmailAndPassword } from 'firebase/auth';
import { getFunctions, connectFunctionsEmulator, httpsCallable } from 'firebase/functions';
import { getFirestore, connectFirestoreEmulator, doc, getDoc } from 'firebase/firestore';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import admin from 'firebase-admin';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Parse CLI args
const args = process.argv.slice(2);
const evidenceIdx = args.indexOf('--evidence');
const EVIDENCE_DIR = evidenceIdx >= 0 && args[evidenceIdx + 1] ? args[evidenceIdx + 1] : './smoke-evidence';

// Ensure evidence dir exists
mkdirSync(EVIDENCE_DIR, { recursive: true });

const LOG_FILE = join(EVIDENCE_DIR, 'SMOKE_LOG.txt');
const RESULTS_FILE = join(EVIDENCE_DIR, 'RESULTS.json');
const SUMMARY_FILE = join(EVIDENCE_DIR, 'SUMMARY.json');

const log = (msg) => {
  const timestamp = new Date().toISOString();
  const line = `[${timestamp}] ${msg}\n`;
  process.stdout.write(line);
  writeFileSync(LOG_FILE, line, { flag: 'a' });
};

const results = {
  calls: [],
  timings: {},
  errors: []
};

// Fixed test data
const PROJECT_ID = 'demo-mvp';
const CUSTOMER_EMAIL = 'customer@test.local';
const CUSTOMER_PASSWORD = 'Passw0rd!';
const MERCHANT_EMAIL = 'merchant@test.local';
const MERCHANT_PASSWORD = 'Passw0rd!';

// Detect emulator ports
const FIRESTORE_PORT = process.env.FIRESTORE_EMULATOR_HOST?.split(':')[1] || '8080';
const AUTH_PORT = process.env.FIREBASE_AUTH_EMULATOR_HOST?.split(':')[1] || '9099';
const FUNCTIONS_PORT = process.env.FUNCTIONS_EMULATOR_HOST?.split(':')[1] || '5001';

log(`Starting MVP Smoke Gate`);
log(`Project: ${PROJECT_ID}`);
log(`Evidence: ${EVIDENCE_DIR}`);
log(`Emulator ports: Firestore=${FIRESTORE_PORT}, Auth=${AUTH_PORT}, Functions=${FUNCTIONS_PORT}`);
log(`FIREBASE_AUTH_EMULATOR_HOST: ${process.env.FIREBASE_AUTH_EMULATOR_HOST}`);
log(`FIRESTORE_EMULATOR_HOST: ${process.env.FIRESTORE_EMULATOR_HOST}`);

let testEnv;
let customerUid;
let merchantUid;
let qrToken;
let functionsRegion = 'us-central1';

async function main() {
  const startTime = Date.now();

  try {
    // Step 1: Initialize test environment (for seeding with rules disabled)
    log('[1/9] Initializing test environment...');
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        host: '127.0.0.1',
        port: parseInt(FIRESTORE_PORT),
        rules: `rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}`
      }
    });
    log('✓ Test environment initialized');

    // Step 2: Seed Firestore data
    log('[2/9] Seeding Firestore data...');
    await seedFirestoreData();
    log('✓ Firestore data seeded');

    // Step 3: Initialize Admin SDK for user creation
    log('[3/9] Initializing Admin SDK...');
    // Ensure auth emulator env var is set - emulators:exec should have already set this
    if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
      process.env.FIREBASE_AUTH_EMULATOR_HOST = `127.0.0.1:${AUTH_PORT}`;
    }
    log(`Using auth emulator: ${process.env.FIREBASE_AUTH_EMULATOR_HOST}`);
    
    // Wait a moment for auth emulator to be fully ready
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const adminApp = admin.initializeApp({
      projectId: PROJECT_ID
    }, 'admin-for-auth');
    const adminAuth = admin.auth(adminApp);
    log('✓ Admin SDK initialized');

    // Step 4: Create auth users with Admin SDK
    log('[4/9] Creating auth users...');
    
    try {
      const customerUser = await adminAuth.createUser({
        email: CUSTOMER_EMAIL,
        password: CUSTOMER_PASSWORD,
        uid: 'test-customer-uid'
      });
      customerUid = customerUser.uid;
      log(`✓ Customer created: ${customerUid}`);
    } catch (err) {
      if (err.code === 'auth/uid-already-exists' || err.code === 'auth/email-already-exists') {
        customerUid = 'test-customer-uid';
        log(`✓ Customer already exists: ${customerUid}`);
      } else {
        throw err;
      }
    }

    try {
      const merchantUser = await adminAuth.createUser({
        email: MERCHANT_EMAIL,
        password: MERCHANT_PASSWORD,
        uid: 'test-merchant-uid'
      });
      merchantUid = merchantUser.uid;
      log(`✓ Merchant created: ${merchantUid}`);
    } catch (err) {
      if (err.code === 'auth/uid-already-exists' || err.code === 'auth/email-already-exists') {
        merchantUid = 'test-merchant-uid';
        log(`✓ Merchant already exists: ${merchantUid}`);
      } else {
        throw err;
      }
    }

    log('✓ Auth users created');

    // Update seeded data with actual UIDs
    await updateSeedDataWithUids();

    // Step 5: Initialize Firebase Client SDK for callable tests
    log('[5/9] Initializing Firebase Client SDK...');
    const app = initializeApp({
      projectId: PROJECT_ID,
      apiKey: 'fake-api-key'
    });

    const auth = getAuth(app);
    connectAuthEmulator(auth, `http://127.0.0.1:${AUTH_PORT}`, { disableWarnings: true });
    
    const db = getFirestore(app);
    connectFirestoreEmulator(db, '127.0.0.1', parseInt(FIRESTORE_PORT));

    // Sign in as customer for callable tests
    const customerCred = await signInWithEmailAndPassword(auth, CUSTOMER_EMAIL, CUSTOMER_PASSWORD);

    const functions = getFunctions(app, functionsRegion);
    connectFunctionsEmulator(functions, '127.0.0.1', parseInt(FUNCTIONS_PORT));

    log('✓ Client SDK initialized and authenticated');

    // Step 6: Test getAvailableOffers (customer)
    log('[6/9] Testing getAvailableOffers...');
    await signInWithEmailAndPassword(auth, CUSTOMER_EMAIL, CUSTOMER_PASSWORD);
    
    const getAvailableOffers = httpsCallable(functions, 'getAvailableOffers');
    const offersStart = Date.now();
    const offersResult = await getAvailableOffers({});
    results.timings.getAvailableOffers = Date.now() - offersStart;
    
    results.calls.push({
      name: 'getAvailableOffers',
      response: offersResult.data
    });
    
    validateGetAvailableOffers(offersResult.data);
    log(`✓ getAvailableOffers PASS (${results.timings.getAvailableOffers}ms)`);

    // Step 6: Test getOffersByLocationFunc (customer)
    log('[7/9] Testing getOffersByLocationFunc...');
    const getOffersByLocation = httpsCallable(functions, 'getOffersByLocationFunc');
    const locationStart = Date.now();
    const locationResult = await getOffersByLocation({
      latitude: 33.8886,
      longitude: 35.4955,
      radius: 5,
      radius_km: 5
    });
    results.timings.getOffersByLocationFunc = Date.now() - locationStart;
    
    results.calls.push({
      name: 'getOffersByLocationFunc',
      response: locationResult.data
    });
    
    validateGetOffersByLocation(locationResult.data);
    log(`✓ getOffersByLocationFunc PASS (${results.timings.getOffersByLocationFunc}ms)`);

    // Step 7: Test generateQRToken (customer)
    log('[8/9] Testing generateQRToken...');
    const generateQRToken = httpsCallable(functions, 'generateQRToken');
    const qrStart = Date.now();
    const qrResult = await generateQRToken({
      offerId: 'offer-test-001',
      offer_id: 'offer-test-001',
      merchantId: merchantUid,
      merchant_id: merchantUid,
      customerId: customerUid,
      customer_id: customerUid,
      deviceHash: 'smoke-test-device-hash'
    });
    results.timings.generateQRToken = Date.now() - qrStart;
    
    results.calls.push({
      name: 'generateQRToken',
      response: qrResult.data
    });
    
    qrToken = validateGenerateQRToken(qrResult.data);
    log(`✓ generateQRToken PASS (${results.timings.generateQRToken}ms) - token: ${qrToken.substring(0, 20)}...`);

    // Decode token to get nonce, then query Firestore for displayCode and PIN
    const tokenPayload = JSON.parse(Buffer.from(qrToken, 'base64').toString());
    const tokenNonce = tokenPayload.nonce;
    log(`  Token nonce: ${tokenNonce}`);

    // Step 8: Test validateQRToken with PIN flow (merchant)
    log('[9/9] Testing validateQRToken with PIN flow...');
    // RC_STRICT: Must complete full redemption flow (no error acceptance)
    await signInWithEmailAndPassword(auth, MERCHANT_EMAIL, MERCHANT_PASSWORD);
    
    let validateResult;
    let validateStart = Date.now();
    let redemptionId = null;
    
    try {
      // First attempt: Try to validate/redeem without PIN
      const validateQRToken = httpsCallable(functions, 'validateQRToken');
      validateResult = await validateQRToken({
        qr_token: qrToken,
        token: qrToken,
        offerId: 'offer-test-001',
        offer_id: 'offer-test-001',
        merchantId: merchantUid,
        merchant_id: merchantUid,
        customerId: customerUid,
        customer_id: customerUid,
        deviceHash: 'smoke_device_hash'
      });
      
      // Check if redemption succeeded
      if (validateResult.data.success && validateResult.data.redemptionId) {
        redemptionId = validateResult.data.redemptionId;
        log(`  Redemption completed without PIN: ${redemptionId}`);
      }
    } catch (err) {
      if (err.code === 'functions/not-found') {
        log('  validateQRToken not found, trying validateRedemption...');
        const validateRedemption = httpsCallable(functions, 'validateRedemption');
        validateResult = await validateRedemption({
          qr_token: qrToken,
          token: qrToken,
          offerId: 'offer-test-001',
          offer_id: 'offer-test-001',
          merchantId: merchantUid,
          merchant_id: merchantUid,
          customerId: customerUid,
          customer_id: customerUid,
          deviceHash: 'smoke_device_hash'
        });
        
        if (validateResult.data.success && validateResult.data.redemptionId) {
          redemptionId = validateResult.data.redemptionId;
          log(`  Redemption completed without PIN: ${redemptionId}`);
        }
      } else {
        throw err;
      }
    }
    
    // RC_STRICT: If PIN verification required, complete the flow
    if (validateResult.data.error && validateResult.data.error.includes('PIN verification required')) {
      log('  PIN verification required - querying Firestore for displayCode and PIN...');
      
      // Query Firestore to get the QR token document (db is already initialized above)
      const tokenDoc = await getDoc(doc(db, 'qr_tokens', tokenNonce));
      
      if (!tokenDoc.exists()) {
        throw new Error('QR token document not found in Firestore');
      }
      
      const tokenData = tokenDoc.data();
      const displayCode = tokenData.display_code;
      const oneTimePin = tokenData.one_time_pin;
      
      log(`  Display code: ${displayCode}, PIN: ${oneTimePin}`);
      
      // Call validatePIN
      const validatePIN = httpsCallable(functions, 'validatePIN');
      const pinStart = Date.now();
      const pinResult = await validatePIN({
        displayCode: displayCode,
        pin: oneTimePin,
        merchantId: merchantUid
      });
      const pinDuration = Date.now() - pinStart;
      
      if (!pinResult.data.success) {
        throw new Error(`validatePIN failed: ${pinResult.data.error || JSON.stringify(pinResult.data)}`);
      }
      
      log(`  ✓ PIN verified (${pinDuration}ms)`);
      
      // Retry redemption after PIN verification
      const validateRedemption = httpsCallable(functions, 'validateRedemption');
      const retryStart = Date.now();
      validateResult = await validateRedemption({
        qr_token: qrToken,
        token: qrToken,
        offerId: 'offer-test-001',
        offer_id: 'offer-test-001',
        merchantId: merchantUid,
        merchant_id: merchantUid,
        customerId: customerUid,
        customer_id: customerUid,
        deviceHash: 'smoke_device_hash'
      });
      
      if (!validateResult.data.success) {
        throw new Error(`Redemption failed after PIN: ${validateResult.data.error}`);
      }
      
      redemptionId = validateResult.data.redemptionId;
      log(`  Redemption completed after PIN: ${redemptionId}`);
    }
    
    results.timings.validateQRToken = Date.now() - validateStart;
    
    results.calls.push({
      name: 'validateQRToken',
      response: validateResult.data,
      redemptionId: redemptionId
    });
    
    // RC_STRICT: Must have success=true (not error acceptance)
    if (!validateResult.data.success) {
      throw new Error(`validateQRToken: Expected success=true, got: ${JSON.stringify(validateResult.data)}`);
    }
    
    if (!redemptionId) {
      throw new Error('validateQRToken: No redemptionId returned (redemption record not created)');
    }
    
    log(`  Validated: Redemption record created (ID: ${redemptionId})`);
    log(`✓ validateQRToken PASS (${results.timings.validateQRToken}ms)`);

    // Step 9a: Test getBalance (customer) - RC Contract: Empty payload
    log('[9/9a] Testing getBalance...');
    await signInWithEmailAndPassword(auth, CUSTOMER_EMAIL, CUSTOMER_PASSWORD);
    
    const getBalance = httpsCallable(functions, 'getBalance');
    const balanceStart = Date.now();
    const balanceResult = await getBalance({});  // RC: Empty payload - uses auth.uid
    results.timings.getBalance = Date.now() - balanceStart;
    
    results.calls.push({
      name: 'getBalance',
      response: balanceResult.data
    });
    
    validateGetBalance(balanceResult.data);
    log(`✓ getBalance PASS (${results.timings.getBalance}ms)`);

    // Step 9b: Test getPointsHistory (customer)
    log('[9/9b] Testing getPointsHistory...');
    const getPointsHistory = httpsCallable(functions, 'getPointsHistory');
    const historyStart = Date.now();
    const historyResult = await getPointsHistory({});
    results.timings.getPointsHistory = Date.now() - historyStart;
    
    results.calls.push({
      name: 'getPointsHistory',
      response: historyResult.data
    });
    
    validateGetPointsHistory(historyResult.data);
    log(`✓ getPointsHistory PASS (${results.timings.getPointsHistory}ms)`);

    // Write results and summary
    const totalTime = Date.now() - startTime;
    writeFileSync(RESULTS_FILE, JSON.stringify(results, null, 2));
    
    const summary = {
      status: 'PASS',
      timestamp: new Date().toISOString(),
      totalTime,
      region: functionsRegion,
      ports: {
        firestore: FIRESTORE_PORT,
        auth: AUTH_PORT,
        functions: FUNCTIONS_PORT
      },
      tests: {
        total: 6,
        passed: 6,
        failed: 0
      },
      timings: results.timings
    };
    
    writeFileSync(SUMMARY_FILE, JSON.stringify(summary, null, 2));
    log('');
    log('═══════════════════════════════════════════════════════════');
    log('MVP SMOKE GATE: PASS ✅');
    log(`Total time: ${totalTime}ms`);
    log(`Region: ${functionsRegion}`);
    log(`Evidence: ${EVIDENCE_DIR}`);
    log('═══════════════════════════════════════════════════════════');
    
    await testEnv.cleanup();
    process.exit(0);

  } catch (error) {
    log('');
    log('═══════════════════════════════════════════════════════════');
    log('MVP SMOKE GATE: FAIL ❌');
    log(`Error: ${error.message}`);
    log(`Stack: ${error.stack}`);
    log('═══════════════════════════════════════════════════════════');
    
    results.errors.push({
      message: error.message,
      stack: error.stack,
      code: error.code
    });
    
    writeFileSync(RESULTS_FILE, JSON.stringify(results, null, 2));
    
    const summary = {
      status: 'FAIL',
      timestamp: new Date().toISOString(),
      error: error.message,
      errorCode: error.code,
      stack: error.stack,
      failedAt: results.calls.length > 0 ? results.calls[results.calls.length - 1].name : 'initialization',
      region: functionsRegion,
      ports: {
        firestore: FIRESTORE_PORT,
        auth: AUTH_PORT,
        functions: FUNCTIONS_PORT
      }
    };
    
    writeFileSync(SUMMARY_FILE, JSON.stringify(summary, null, 2));
    
    if (testEnv) await testEnv.cleanup();
    process.exit(1);
  }
}

async function seedFirestoreData() {
  const futureDate = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString();
  const nowDate = new Date().toISOString();
  
  const context = testEnv.authenticatedContext('admin');
  const db = context.firestore();
  
  // Seed merchants
  await db.collection('merchants').doc('merchant-test-001').set({
    storeName: 'Test Merchant',
    merchant_name: 'Test Merchant',
    verified: true,
    status: 'active',
    subscription_status: 'active',  // RC_STRICT: Required for redemption flow
    location: { latitude: 33.8886, longitude: 35.4955, address: '', city: 'Beirut' },
    merchantLocation: { lat: 33.8886, lng: 35.4955 }
  });
  
  // Seed offers
  await db.collection('offers').doc('offer-test-001').set({
    title: 'Test Offer',
    description: 'Test offer for smoke tests',
    merchantId: 'merchant-test-001',
    merchant_id: 'merchant-test-001',
    merchantUid: 'merchant-test-001',
    category: 'test',
    points_value: 10,
    pointsValue: 10,
    points_required: 10,
    points_cost: 10,
    validUntil: futureDate,
    valid_until: futureDate,
    image_url: '',
    imageUrl: '',
    is_active: true,
    isActive: true,
    status: 'active',
    discount_percentage: 10,
    discountPercentage: 10,
    location: { latitude: 33.8886, longitude: 35.4955, address: '', city: 'Beirut' }
  });
  
  // Seed users (placeholder - will update with real UIDs)
  await db.collection('users').doc('customer-placeholder').set({
    role: 'customer',
    subscriptionTier: 'premium',
    subscriptionEndDate: futureDate,
    subscription_end_date: futureDate
  });
  
  // Seed subscriptions
  await db.collection('subscriptions').doc('subscription-placeholder').set({
    userId: 'customer-placeholder',
    tier: 'premium',
    status: 'active',
    endDate: futureDate,
    end_date: futureDate
  });
  
  // Seed points transaction
  await db.collection('points_transactions').doc('tx-test-001').set({
    user_id: 'customer-placeholder',
    points: 5,
    description: 'seed',
    created_at: nowDate
  });
  
  // Seed points balance
  await db.collection('points_balance').doc('customer-placeholder').set({
    user_id: 'customer-placeholder',
    balance: 100,
    totalBalance: 100,
    updated_at: nowDate
  });
  
  log('  Seeded: merchants, offers, users, subscriptions, points_transactions, points_balance');
}

async function updateSeedDataWithUids() {
  const futureDate = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString();
  const nowDate = new Date().toISOString();
  const futureMillis = Date.now() + 365 * 24 * 60 * 60 * 1000;
  
  const context = testEnv.authenticatedContext('admin');
  const db = context.firestore();
  const { Timestamp } = await import('firebase/firestore');
  const futureTimestamp = Timestamp.fromMillis(futureMillis);
  
  // Update user with real customer UID
  await db.collection('users').doc(customerUid).set({
    role: 'customer',
    subscriptionTier: 'premium',
    subscriptionEndDate: futureDate,
    subscription_end_date: futureDate,
    subscriptionActive: true
  });
  
  // Add customer doc (required by generateQRToken + getBalance)
  await db.collection('customers').doc(customerUid).set({
    subscription_status: 'active',
    subscription_expiry: futureTimestamp,
    email: CUSTOMER_EMAIL,
    total_points_earned: 100,
    total_points_spent: 0,
    total_points_expired: 0,
    points_balance: 100
  });
  
  // Update subscription
  await db.collection('subscriptions').doc(customerUid).set({
    userId: customerUid,
    tier: 'premium',
    status: 'active',
    endDate: futureDate,
    end_date: futureDate
  });
  
  // Update points transaction
  await db.collection('points_transactions').doc('tx-test-001').set({
    user_id: customerUid,
    points: 5,
    description: 'seed transaction',
    created_at: nowDate
  });
  
  // Update points balance
  await db.collection('points_balance').doc(customerUid).set({
    user_id: customerUid,
    balance: 100,
    totalBalance: 100,
    updated_at: nowDate
  });
  
  // Update merchant
  await db.collection('merchants').doc(merchantUid).set({
    storeName: 'Test Merchant',
    merchant_name: 'Test Merchant',
    verified: true,
    status: 'active',
    subscription_status: 'active',  // RC_STRICT: Required for redemption flow
    location: { latitude: 33.8886, longitude: 35.4955, address: '', city: 'Beirut' },
    merchantLocation: { lat: 33.8886, lng: 35.4955 }
  });
  
  log(`  Updated seed data with UIDs: customer=${customerUid}, merchant=${merchantUid}`);
}

function validateGetAvailableOffers(data) {
  if (!data) throw new Error('getAvailableOffers: No data returned');
  
  const offers = data.offers || data;
  if (!Array.isArray(offers)) {
    throw new Error(`getAvailableOffers: Expected offers array, got ${typeof offers}`);
  }
  
  if (offers.length === 0) {
    log('  Warning: No offers returned (acceptable if empty)');
    return;
  }
  
  const offer = offers[0];
  if (!offer.id) throw new Error('getAvailableOffers: Offer missing id');
  if (typeof offer.points_required !== 'number') {
    throw new Error(`getAvailableOffers: points_required must be number, got ${typeof offer.points_required}`);
  }
  if (typeof offer.valid_until !== 'string') {
    throw new Error(`getAvailableOffers: valid_until must be string (ISO), got ${typeof offer.valid_until}`);
  }
  if (typeof offer.is_active !== 'boolean') {
    throw new Error(`getAvailableOffers: is_active must be boolean, got ${typeof offer.is_active}`);
  }
  if (!('used' in offer)) {
    throw new Error('getAvailableOffers: Offer missing used flag');
  }
  
  log(`  Validated: ${offers.length} offers, first offer has required DTO fields`);
}

function validateGetOffersByLocation(data) {
  if (!data) throw new Error('getOffersByLocationFunc: No data returned');
  
  const offers = data.offers || data;
  if (!Array.isArray(offers)) {
    throw new Error(`getOffersByLocationFunc: Expected offers array, got ${typeof offers}`);
  }
  
  if (offers.length === 0) {
    log('  Warning: No offers returned (acceptable if empty)');
    return;
  }
  
  const offer = offers[0];
  if (!offer.id) throw new Error('getOffersByLocationFunc: Offer missing id');
  if (typeof offer.points_required !== 'number') {
    throw new Error(`getOffersByLocationFunc: points_required must be number, got ${typeof offer.points_required}`);
  }
  if (typeof offer.valid_until !== 'string') {
    throw new Error(`getOffersByLocationFunc: valid_until must be string (ISO), got ${typeof offer.valid_until}`);
  }
  
  log(`  Validated: ${offers.length} offers with DTO mapping`);
}

function validateGenerateQRToken(data) {
  if (!data) throw new Error('generateQRToken: No data returned');
  if (!data.qr_token || typeof data.qr_token !== 'string') {
    throw new Error(`generateQRToken: Missing or invalid qr_token. Got: ${JSON.stringify(data)}`);
  }
  
  log(`  Validated: qr_token exists (${data.qr_token.length} chars)`);
  return data.qr_token;
}

function validateQRTokenResponse(data) {
  if (!data) throw new Error('validateQRToken: No data returned');
  
  // RC V2: Accept success/validated/ok/success status
  const isSuccess = data.success === true || 
                    data.validated === true || 
                    data.status === 'ok' || 
                    data.status === 'validated' || 
                    data.status === 'success';
  
  // RC V2: Also accept specific expected business logic responses
  const isExpectedBusinessLogic = 
    (data.success === false && data.error && data.error.includes('PIN verification required'));
  
  if (!isSuccess && !isExpectedBusinessLogic) {
    throw new Error(`validateQRToken: Expected success indicator, got: ${JSON.stringify(data)}`);
  }
  
  if (isExpectedBusinessLogic) {
    log(`  Validated: QR token callable reachable (PIN verification flow active)`);
  } else {
    log(`  Validated: QR token validation successful`);
  }
}

function validateGetBalance(data) {
  if (!data) throw new Error('getBalance: No data returned');
  
  const balance = data.balance ?? data.totalBalance;
  if (typeof balance !== 'number') {
    throw new Error(`getBalance: Expected numeric balance, got ${typeof balance}. Data: ${JSON.stringify(data)}`);
  }
  
  log(`  Validated: balance=${balance}`);
}

function validateGetPointsHistory(data) {
  if (!data) throw new Error('getPointsHistory: No data returned');
  
  const history = data.history;
  if (!Array.isArray(history)) {
    throw new Error(`getPointsHistory: Expected history array, got ${typeof history}`);
  }
  
  if (history.length === 0) {
    log('  Warning: Empty history (acceptable)');
    return;
  }
  
  const tx = history[0];
  if (typeof tx.timestamp !== 'string') {
    throw new Error(`getPointsHistory: timestamp must be string, got ${typeof tx.timestamp}`);
  }
  if (typeof tx.points !== 'number') {
    throw new Error(`getPointsHistory: points must be number, got ${typeof tx.points}`);
  }
  if (typeof tx.description !== 'string') {
    throw new Error(`getPointsHistory: description must be string, got ${typeof tx.description}`);
  }
  
  log(`  Validated: ${history.length} transactions with correct structure`);
}

main();
