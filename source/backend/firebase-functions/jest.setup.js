/**
 * Jest Setup - Configure Firebase for Tests (No Emulator Wait)
 */

// Set environment variables BEFORE any Firebase imports
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.GCLOUD_PROJECT = 'urbangenspark-test';
process.env.GOOGLE_CLOUD_PROJECT = 'urbangenspark-test';
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: 'urbangenspark-test',
  storageBucket: 'urbangenspark-test.appspot.com'
});

process.env.QR_TOKEN_SECRET = 'test_secret_for_automated_testing_DO_NOT_USE_IN_PRODUCTION';
process.env.FUNCTIONS_EMULATOR = 'true';
process.env.NODE_ENV = 'test';

// Hard timeout: 30 seconds per test
jest.setTimeout(30000);

// No emulator wait - tests must use mocks
beforeAll(() => {
  console.log('[JEST] Tests will use mocked Firebase (no emulator connection required)');
});
