/**
 * Observability Test Hook
 * DEBUG/TEST ENVIRONMENT ONLY
 * 
 * Provides controlled error paths for validating observability stack:
 * - Structured logging verification
 * - Error reporting integration
 * - Request correlation tracking
 * - Breadcrumb/context propagation
 * 
 * SECURITY: Only accessible in emulator/test environments
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

interface ObsTestRequest {
  testType: 'log' | 'error' | 'timeout' | 'breadcrumbs';
  message?: string;
}

interface ObsTestResponse {
  success: boolean;
  testType: string;
  timestamp: string;
  details?: any;
  error?: string;
}

export const obsTestHook = functions.https.onCall(
  async (data: ObsTestRequest, context): Promise<ObsTestResponse> => {
    const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
    
    // SECURITY: Block in production
    if (!isEmulator) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Observability test hooks are only available in emulator/test environments'
      );
    }
    
    const requestId = `obs_test_${Date.now()}`;
    const timestamp = new Date().toISOString();
    
    // Log with structured context
    functions.logger.info('Observability test hook invoked', {
      requestId,
      testType: data.testType,
      userId: context.auth?.uid || 'anonymous',
      timestamp,
    });
    
    try {
      switch (data.testType) {
        case 'log':
          // Test structured logging
          functions.logger.info('Test structured log entry', {
            requestId,
            level: 'info',
            message: data.message || 'Default test message',
            metadata: {
              testFlag: true,
              environment: 'emulator',
              timestamp,
            },
          });
          
          return {
            success: true,
            testType: 'log',
            timestamp,
            details: { message: 'Structured log entry created' },
          };
          
        case 'error':
          // Test error reporting path
          functions.logger.error('Test controlled error', {
            requestId,
            errorType: 'test_error',
            message: data.message || 'Controlled error for observability validation',
            context: {
              userId: context.auth?.uid,
              timestamp,
            },
          });
          
          throw new functions.https.HttpsError(
            'internal',
            'Controlled test error - observability validation',
            {
              requestId,
              timestamp,
              testFlag: true,
            }
          );
          
        case 'timeout':
          // Test timeout scenarios (simulate slow operation)
          functions.logger.warn('Test timeout simulation started', {
            requestId,
            duration: '5000ms',
          });
          
          await new Promise(resolve => setTimeout(resolve, 5000));
          
          functions.logger.info('Test timeout simulation completed', {
            requestId,
          });
          
          return {
            success: true,
            testType: 'timeout',
            timestamp,
            details: { duration: 5000 },
          };
          
        case 'breadcrumbs':
          // Test breadcrumb logging
          functions.logger.info('Breadcrumb 1: Request received', { requestId });
          
          // Simulate some operations
          await db.collection('_obs_test').doc('test').set({
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            requestId,
          });
          
          functions.logger.info('Breadcrumb 2: Database write completed', { requestId });
          
          const snapshot = await db.collection('_obs_test').doc('test').get();
          
          functions.logger.info('Breadcrumb 3: Database read completed', {
            requestId,
            documentExists: snapshot.exists,
          });
          
          return {
            success: true,
            testType: 'breadcrumbs',
            timestamp,
            details: { breadcrumbCount: 3 },
          };
          
        default:
          throw new functions.https.HttpsError(
            'invalid-argument',
            `Unknown test type: ${data.testType}`
          );
      }
    } catch (error) {
      functions.logger.error('Observability test hook error', {
        requestId,
        error: error instanceof Error ? error.message : String(error),
        testType: data.testType,
      });
      
      // Re-throw HttpsError, wrap others
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        'internal',
        'Test hook execution failed',
        { requestId, originalError: String(error) }
      );
    }
  }
);
