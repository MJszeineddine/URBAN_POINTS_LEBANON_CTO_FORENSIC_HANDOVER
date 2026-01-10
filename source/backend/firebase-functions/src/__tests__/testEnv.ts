/**
 * Test Environment Singleton
 * Provides stable Firestore instance and cleanup utilities for tests
 */

import * as admin from 'firebase-admin';

// Module-level singleton - one instance per test file
let testApp: admin.app.App | null = null;
let testDb: admin.firestore.Firestore | null = null;

/**
 * Get or create test Firestore instance
 * Uses emulator configuration from jest.setup.js
 */
export function getTestDb(): admin.firestore.Firestore {
  if (!testDb) {
    if (!admin.apps.length) {
      testApp = admin.initializeApp({
        projectId: process.env.GCLOUD_PROJECT || 'urbangenspark-test',
      });
    } else {
      testApp = admin.app();
    }
    testDb = testApp.firestore();
  }
  return testDb;
}

/**
 * Reset Firestore collections for clean test state
 * Uses batched deletes with pagination to avoid hanging
 * 
 * @param collectionNames - Array of collection names to clear
 * @param batchSize - Documents per batch (default 300)
 */
export async function resetDb(
  collectionNames: string[],
  batchSize: number = 300
): Promise<void> {
  const db = getTestDb();

  for (const collectionName of collectionNames) {
    let hasMore = true;

    while (hasMore) {
      // Query limited batch
      const snapshot = await db
        .collection(collectionName)
        .limit(batchSize)
        .get();

      if (snapshot.empty) {
        hasMore = false;
        continue;
      }

      // Delete batch
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      // Check if more documents exist
      hasMore = snapshot.size === batchSize;
    }
  }
}

/**
 * Clean shutdown (only call in controlled teardown, not in afterAll)
 * This should only be used in global teardown, not per-test-file
 */
export async function shutdownTestEnv(): Promise<void> {
  if (testDb) {
    // Avoid terminating the shared pool; terminate an isolated instance to keep other tests alive
    try {
      const isoApp = admin.initializeApp(
        { projectId: process.env.GCLOUD_PROJECT || 'urbangenspark-test' },
        `shutdown-${Date.now()}`
      );
      await isoApp.firestore().terminate();
      await isoApp.delete();
    } catch (err) {
      // Swallow shutdown errors to avoid masking test results
      // eslint-disable-next-line no-console
      console.warn('shutdownTestEnv: terminate guard hit', err);
    }
    testDb = null;
  }
  if (testApp) {
    await testApp.delete();
    testApp = null;
  }
}
