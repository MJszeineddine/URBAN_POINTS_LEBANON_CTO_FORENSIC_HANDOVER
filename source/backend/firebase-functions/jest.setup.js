/**
 * Jest Setup - Configure Firebase Emulator for Tests
 */

const net = require('net');

// Set emulator environment variables BEFORE any Firebase imports
// Force IPv4 (127.0.0.1) not localhost to avoid ::1 ambiguity
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.GCLOUD_PROJECT = 'urbangenspark-test';
process.env.GOOGLE_CLOUD_PROJECT = 'urbangenspark-test';
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: 'urbangenspark-test',
  storageBucket: 'urbangenspark-test.appspot.com'
});

// Set test environment variables
process.env.QR_TOKEN_SECRET = 'test_secret_for_automated_testing_DO_NOT_USE_IN_PRODUCTION';
process.env.FUNCTIONS_EMULATOR = 'true';
process.env.NODE_ENV = 'test';

// Configure longer timeout for emulator operations
jest.setTimeout(120000); // 2 minutes

// Wait for Firestore emulator to be ready before running tests
const waitForEmulator = () => new Promise((resolve, reject) => {
  const maxAttempts = 30;
  let attempts = 0;
  const attemptConnect = () => {
    const socket = net.createConnection({ host: '127.0.0.1', port: 8080 }, () => {
      socket.end();
      resolve();
    });
    socket.on('error', () => {
      attempts++;
      if (attempts >= maxAttempts) {
        reject(new Error('Firestore emulator not ready on 127.0.0.1:8080 after 30 attempts'));
      } else {
        setTimeout(attemptConnect, 500);
      }
    });
  };
  attemptConnect();
});

beforeAll(async () => {
  try {
    await waitForEmulator();
  } catch (err) {
    console.warn('⚠️  Emulator not ready, tests may fail:', err.message);
  }
});

console.log('✅ Jest Setup: Firebase Emulator configured');
console.log(`   FIRESTORE_EMULATOR_HOST: ${process.env.FIRESTORE_EMULATOR_HOST}`);
console.log(`   FIREBASE_AUTH_EMULATOR_HOST: ${process.env.FIREBASE_AUTH_EMULATOR_HOST}`);
console.log(`   GCLOUD_PROJECT: ${process.env.GCLOUD_PROJECT}`);
