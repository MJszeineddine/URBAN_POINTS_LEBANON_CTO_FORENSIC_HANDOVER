#!/usr/bin/env node
/**
 * Smoke Tests for Urban Points Functions
 * Runs against Firebase Emulators
 * Exits 0 only if all assertions pass
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Evidence directory from env
const EVIDENCE_DIR = process.env.EVIDENCE_DIR || path.join(__dirname, '../../local-ci/evidence/PIPELINE/latest');

// Emulator config from env
const FIRESTORE_HOST = process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || 'localhost:9099';

// Initialize Firebase Admin for emulator
process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_HOST;

admin.initializeApp({
  projectId: 'demo-urbanpoints'
});

const db = admin.firestore();

// Smoke test results
const results = {
  timestamp: new Date().toISOString(),
  tests: [],
  passed: 0,
  failed: 0,
  verdict: 'UNKNOWN'
};

function test(name, fn) {
  return async () => {
    console.log(`\n[TEST] ${name}`);
    try {
      await fn();
      console.log(`  ✅ PASS`);
      results.tests.push({ name, status: 'PASS' });
      results.passed++;
    } catch (error) {
      console.error(`  ❌ FAIL: ${error.message}`);
      results.tests.push({ name, status: 'FAIL', error: error.message });
      results.failed++;
    }
  };
}

async function seedData() {
  console.log('[SEED] Creating test data...');
  
  // Create test merchant
  await db.collection('merchants').doc('test-merchant-001').set({
    name: 'Test Merchant',
    email: 'merchant@test.com',
    status: 'approved',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Create test user
  await db.collection('users').doc('test-user-001').set({
    email: 'user@test.com',
    displayName: 'Test User',
    points: 100,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Create test offer
  await db.collection('offers').doc('test-offer-001').set({
    title: 'Test Offer',
    description: 'Smoke test offer',
    merchantId: 'test-merchant-001',
    pointsCost: 50,
    status: 'active',
    location: { lat: 33.8938, lng: 35.5018 }, // Beirut
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log('  ✅ Seed data created');
}

async function cleanupData() {
  console.log('[CLEANUP] Removing test data...');
  try {
    await db.collection('merchants').doc('test-merchant-001').delete();
    await db.collection('users').doc('test-user-001').delete();
    await db.collection('offers').doc('test-offer-001').delete();
  } catch (e) {
    // Ignore cleanup errors
  }
}

// TEST 1: Firestore connection
const testFirestoreConnection = test('Firestore connection', async () => {
  const doc = await db.collection('_test').doc('ping').set({ ping: true });
  await db.collection('_test').doc('ping').delete();
});

// TEST 2: Read offers collection
const testReadOffers = test('Read offers collection', async () => {
  const snapshot = await db.collection('offers').limit(10).get();
  if (snapshot.empty) {
    throw new Error('No offers found (expected at least test offer)');
  }
  console.log(`    Found ${snapshot.size} offer(s)`);
});

// TEST 3: Read users collection
const testReadUsers = test('Read users collection', async () => {
  const snapshot = await db.collection('users').limit(10).get();
  if (snapshot.empty) {
    throw new Error('No users found (expected at least test user)');
  }
  console.log(`    Found ${snapshot.size} user(s)`);
});

// TEST 4: Points balance read
const testPointsBalance = test('Points balance for test user', async () => {
  const userDoc = await db.collection('users').doc('test-user-001').get();
  if (!userDoc.exists) {
    throw new Error('Test user not found');
  }
  const points = userDoc.data().points;
  if (typeof points !== 'number') {
    throw new Error('Points field missing or invalid');
  }
  console.log(`    User has ${points} points`);
});

// TEST 5: Write to points history (proof of write capability)
const testWritePointsHistory = test('Write to points history', async () => {
  await db.collection('users').doc('test-user-001')
    .collection('pointsHistory').add({
      type: 'smoke_test',
      amount: 10,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      description: 'Smoke test transaction'
    });
  
  // Verify write
  const history = await db.collection('users').doc('test-user-001')
    .collection('pointsHistory')
    .where('type', '==', 'smoke_test')
    .limit(1)
    .get();
  
  if (history.empty) {
    throw new Error('Points history write verification failed');
  }
});

async function runAllTests() {
  console.log('='.repeat(70));
  console.log('URBAN POINTS - SMOKE TESTS');
  console.log('='.repeat(70));
  
  try {
    // Seed test data
    await seedData();
    
    // Run tests
    await testFirestoreConnection();
    await testReadOffers();
    await testReadUsers();
    await testPointsBalance();
    await testWritePointsHistory();
    
    // Cleanup
    await cleanupData();
    
  } catch (error) {
    console.error(`\n❌ FATAL ERROR: ${error.message}`);
    results.tests.push({ name: 'FATAL', status: 'FAIL', error: error.message });
    results.failed++;
  }
  
  // Final verdict
  if (results.failed === 0 && results.passed > 0) {
    results.verdict = 'PASS';
  } else {
    results.verdict = 'FAIL';
  }
  
  // Write report
  const reportPath = path.join(EVIDENCE_DIR, 'smoke_report.json');
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.writeFileSync(reportPath, JSON.stringify(results, null, 2));
  
  console.log('\n' + '='.repeat(70));
  console.log(`SMOKE TESTS: ${results.verdict}`);
  console.log(`Passed: ${results.passed}, Failed: ${results.failed}`);
  console.log(`Report: ${reportPath}`);
  console.log('='.repeat(70));
  
  process.exit(results.failed === 0 ? 0 : 1);
}

// Run tests
runAllTests().catch((error) => {
  console.error('UNCAUGHT ERROR:', error);
  process.exit(1);
});
