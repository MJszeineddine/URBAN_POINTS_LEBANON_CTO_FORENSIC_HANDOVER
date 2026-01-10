/**
 * Minimal test to verify if Cloud Function wrappers can be counted as covered by Jest
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: 'urbangenspark-test',
  });
}

// EXPERIMENT 1: Pure wrapper (current pattern)
export const testWrapper = functions.https.onCall(async (data, context) => {
  return { result: 'tested' };
});

// EXPERIMENT 2: Extracted core + wrapper
export async function testCoreLogic(data: any, context: any) {
  return { result: 'tested_core' };
}

export const testWrapperWithCore = functions.https.onCall(testCoreLogic);

// EXPERIMENT 3: Named function wrapper
export const testNamedWrapper = functions.https.onCall(async function namedHandler(data, context) {
  return { result: 'tested_named' };
});
