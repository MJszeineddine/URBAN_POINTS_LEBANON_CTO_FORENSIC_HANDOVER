/**
 * Urban Points Lebanon - GDPR Compliance Functions
 * Session 3: Data privacy and compliance
 * 
 * Functions:
 * 1. exportUserData - Export all user data (GDPR Article 15)
 * 2. deleteUserData - Right to erasure (GDPR Article 17)
 * 3. anonymizeUserData - Data anonymization
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

// ============================================================================
// FUNCTION 1: Export User Data (GDPR Article 15)
// ============================================================================

interface DataExportRequest {
  userId: string;
  format?: 'json' | 'csv';
}

interface DataExportResponse {
  success: boolean;
  data?: {
    customer: any;
    redemptions: any[];
    qrTokens: any[];
    exportDate: string;
  };
  error?: string;
}

/**
 * Export all user data for GDPR compliance
 * 
 * GDPR Article 15: Right of access by the data subject
 * User has the right to obtain confirmation as to whether personal data
 * is being processed and access to their data in a structured format.
 * 
 * @param data - Request with userId
 * @param context - Firebase Auth context
 * @returns Complete user data export
 */
export const exportUserData = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 120,
    minInstances: 0,
    maxInstances: 5
  })
  .https.onCall(
  async (data: DataExportRequest, context): Promise<DataExportResponse> => {
    try {
      // Verify authentication
      if (!context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      // Verify user is requesting their own data
      if (context.auth.uid !== data.userId) {
        return { success: false, error: 'Unauthorized: Can only export own data' };
      }

      // Collect all user data from various collections
      const exportData: any = {
        exportDate: new Date().toISOString(),
        userId: data.userId
      };

      // 1. Customer profile
      const customerDoc = await db.collection('customers').doc(data.userId).get();
      if (customerDoc.exists) {
        exportData.customer = {
          ...customerDoc.data(),
          documentId: customerDoc.id
        };
      }

      // 2. Redemption history
      const redemptionsSnapshot = await db.collection('redemptions')
        .where('user_id', '==', data.userId)
        .get();
      
      exportData.redemptions = redemptionsSnapshot.docs.map(doc => ({
        ...doc.data(),
        documentId: doc.id
      }));

      // 3. QR tokens (historical)
      const tokensSnapshot = await db.collection('qr_tokens')
        .where('user_id', '==', data.userId)
        .get();
      
      exportData.qrTokens = tokensSnapshot.docs.map(doc => ({
        ...doc.data(),
        documentId: doc.id
      }));

      // 4. Offer interactions (if tracked separately)
      // Add more collections as needed

      return {
        success: true,
        data: exportData
      };

    } catch (error) {
      console.error('Data export error:', error);
      return {
        success: false,
        error: `Export failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      };
    }
  }
);

// ============================================================================
// FUNCTION 2: Delete User Data (GDPR Article 17)
// ============================================================================

interface DataDeletionRequest {
  userId: string;
  confirmDeletion: boolean;
}

interface DataDeletionResponse {
  success: boolean;
  deletedCollections?: string[];
  anonymizedCollections?: string[];
  error?: string;
}

/**
 * Delete or anonymize user data for GDPR compliance
 * 
 * GDPR Article 17: Right to erasure ('right to be forgotten')
 * User has the right to obtain erasure of personal data concerning them.
 * 
 * Strategy:
 * - DELETE: Personal identifiable information (PII)
 * - ANONYMIZE: Statistical/transactional data (maintain business records)
 * 
 * @param data - Request with userId and confirmation
 * @param context - Firebase Auth context
 * @returns Deletion/anonymization summary
 */
export const deleteUserData = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 300,  // Longer timeout for batch operations
    minInstances: 0,
    maxInstances: 5
  })
  .https.onCall(
  async (data: DataDeletionRequest, context): Promise<DataDeletionResponse> => {
    try {
      // Verify authentication
      if (!context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      // Verify user is deleting their own data
      if (context.auth.uid !== data.userId) {
        return { success: false, error: 'Unauthorized: Can only delete own data' };
      }

      // Require explicit confirmation
      if (!data.confirmDeletion) {
        return { success: false, error: 'Deletion not confirmed' };
      }

      const deletedCollections: string[] = [];
      const anonymizedCollections: string[] = [];

      // Use batch for atomic operations
      const batch = db.batch();

      // 1. DELETE: Customer profile (complete removal of PII)
      const customerRef = db.collection('customers').doc(data.userId);
      batch.delete(customerRef);
      deletedCollections.push('customers');

      // 2. ANONYMIZE: Redemptions (keep for business records, remove PII)
      const redemptionsSnapshot = await db.collection('redemptions')
        .where('user_id', '==', data.userId)
        .get();
      
      redemptionsSnapshot.docs.forEach(doc => {
        batch.update(doc.ref, {
          user_id: 'ANONYMIZED',
          user_email: 'ANONYMIZED',
          user_name: 'ANONYMIZED',
          anonymized_at: admin.firestore.FieldValue.serverTimestamp(),
          original_user_id_hash: hashUserId(data.userId) // Keep hash for fraud detection
        });
      });
      if (!redemptionsSnapshot.empty) {
        anonymizedCollections.push('redemptions');
      }

      // 3. DELETE: QR tokens (no business value after redemption)
      const tokensSnapshot = await db.collection('qr_tokens')
        .where('user_id', '==', data.userId)
        .get();
      
      tokensSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      if (!tokensSnapshot.empty) {
        deletedCollections.push('qr_tokens');
      }

      // 4. Update daily stats (decrement unique customer counts)
      // Note: This is complex and might require recalculation
      // For now, we'll leave stats as-is (anonymous aggregate data is GDPR-compliant)

      // Commit all changes atomically
      await batch.commit();

      // 5. Delete Firebase Auth account
      await admin.auth().deleteUser(data.userId);
      deletedCollections.push('firebase_auth');

      return {
        success: true,
        deletedCollections,
        anonymizedCollections
      };

    } catch (error) {
      console.error('Data deletion error:', error);
      return {
        success: false,
        error: `Deletion failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      };
    }
  }
);

// ============================================================================
// FUNCTION 3: Anonymize User Data (Helper)
// ============================================================================

/**
 * Hash user ID for fraud detection without storing actual ID
 */
function hashUserId(userId: string): string {
  const crypto = require('crypto');
  return crypto.createHash('sha256').update(userId).digest('hex');
}

// ============================================================================
// FUNCTION 4: Data Retention Cleanup (Scheduled)
// ============================================================================

/**
 * Automatically delete expired QR tokens and old data
 * Runs daily at midnight UTC
 * 
 * GDPR Article 5(1)(e): Storage limitation principle
 * Data should not be kept longer than necessary
 */
// TEMPORARILY DISABLED - Requires Cloud Scheduler API enablement
// Enable after: https://console.cloud.google.com/apis/library/cloudscheduler.googleapis.com
export const cleanupExpiredData = null as any;
/*
export const cleanupExpiredData = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 540,  // 9 minutes for large deletions
    minInstances: 0,
    maxInstances: 1  // Run serially to avoid race conditions
  })
  .pubsub.schedule('every day 00:00')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      let deletedCount = 0;

      // 1. Delete expired QR tokens (older than 24 hours)
      const expiredTokensSnapshot = await db.collection('qr_tokens')
        .where('expires_at', '<', now)
        .limit(500)  // Process in batches to avoid timeout
        .get();

      const tokenBatch = db.batch();
      expiredTokensSnapshot.docs.forEach(doc => {
        tokenBatch.delete(doc.ref);
        deletedCount++;
      });
      await tokenBatch.commit();

      // 2. Archive old redemptions (older than 1 year)
      // This is a placeholder - implement archival logic as needed
      const oneYearAgo = new Date();
      oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);

      console.log(`Cleanup completed: Deleted ${deletedCount} expired tokens`);

      return { success: true, deletedCount };

    } catch (error) {
      console.error('Data cleanup error:', error);
      throw error;  // Fail the scheduled job to trigger retry
    }
  });
*/
