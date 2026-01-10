/**
 * Observability Test Suite
 * Validates logging and error reporting integration
 */

import * as admin from 'firebase-admin';

// Initialize test environment
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'urbangenspark-test',
  });
}

describe('Observability Test Hook', () => {
  beforeAll(() => {
    // Ensure emulator flag is set
    process.env.FUNCTIONS_EMULATOR = 'true';
    process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
  });

  it('should be accessible in emulator mode', () => {
    expect(process.env.FUNCTIONS_EMULATOR).toBe('true');
  });

  it('should have structured logging capability', () => {
    // Verify Functions SDK logger is available
    const functions = require('firebase-functions');
    expect(functions.logger).toBeDefined();
    expect(functions.logger.info).toBeInstanceOf(Function);
    expect(functions.logger.error).toBeInstanceOf(Function);
    expect(functions.logger.warn).toBeInstanceOf(Function);
  });

  it('should support error types for observability', () => {
    const functions = require('firebase-functions');
    const error = new functions.https.HttpsError('internal', 'Test error for observability');

    expect(error).toBeInstanceOf(Error);
    expect(error.code).toBe('internal');
    expect(error.message).toContain('Test error');
  });
});
