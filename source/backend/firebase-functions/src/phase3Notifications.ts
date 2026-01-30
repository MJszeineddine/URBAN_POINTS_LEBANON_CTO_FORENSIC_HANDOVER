/**
 * Phase 3 Notification Service
 * FCM token management and notification delivery system
 * 
 * Features:
 * 1. Register/update FCM tokens per user
 * 2. Unregister tokens on logout
 * 3. Send redemption notifications
 * 4. Send subscription notifications
 * 5. Batch notification delivery
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { defaultMessagingAdapter } from './adapters/messaging';

const db = admin.firestore();

// ============================================================================
// FUNCTION 1: Register FCM Token
// ============================================================================

interface RegisterFCMTokenRequest {
  token: string;
  deviceInfo?: {
    platform?: string; // 'ios' | 'android' | 'web'
    appVersion?: string;
  };
}

interface RegisterFCMTokenResponse {
  success: boolean;
  message?: string;
  error?: string;
}

/**
 * Called by mobile/web apps to register or update FCM token
 * Stores token in user document for later notification delivery
 * 
 * @param data - Request with FCM token
 * @param context - Firebase Auth context
 * @returns Response with success status
 */
export const registerFCMToken = functions
  .runWith({
    memory: '128MB',
    timeoutSeconds: 10,
  })
  .https.onCall(
  async (data: RegisterFCMTokenRequest, context): Promise<RegisterFCMTokenResponse> => {
    try {
      // Verify authentication
      if (!context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      const userId = context.auth.uid;

      // Validate token
      if (!data.token || typeof data.token !== 'string') {
        return { success: false, error: 'Invalid FCM token' };
      }

      // Update user document with FCM token
      await db.collection('customers').doc(userId).update({
        fcm_token: data.token,
        fcm_updated_at: admin.firestore.FieldValue.serverTimestamp(),
        fcm_platform: data.deviceInfo?.platform || 'unknown',
        fcm_app_version: data.deviceInfo?.appVersion || 'unknown',
      });

      console.log(`FCM token registered for user ${userId}`);

      return {
        success: true,
        message: 'FCM token registered successfully',
      };

    } catch (error) {
      console.error('Error registering FCM token:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }
);

// ============================================================================
// FUNCTION 2: Unregister FCM Token (Logout)
// ============================================================================

interface UnregisterFCMTokenResponse {
  success: boolean;
  message?: string;
  error?: string;
}

/**
 * Called on user logout to clear FCM token
 * Prevents notifications being sent to logged-out users
 * 
 * @param context - Firebase Auth context
 * @returns Response with success status
 */
export const unregisterFCMToken = functions
  .runWith({
    memory: '128MB',
    timeoutSeconds: 10,
  })
  .https.onCall(
  async (data: any, context): Promise<UnregisterFCMTokenResponse> => {
    try {
      // Verify authentication
      if (!context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      const userId = context.auth.uid;

      // Remove FCM token from user document
      await db.collection('customers').doc(userId).update({
        fcm_token: admin.firestore.FieldValue.delete(),
        fcm_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`FCM token unregistered for user ${userId}`);

      return {
        success: true,
        message: 'FCM token unregistered successfully',
      };

    } catch (error) {
      console.error('Error unregistering FCM token:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }
);

// ============================================================================
// FUNCTION 3: Notify Redemption Success (Triggered)
// ============================================================================

/**
 * Triggered when redemption is created
 * Sends notification to customer: "You redeemed X points from [Offer]"
 * Sends notification to merchant: "Customer redeemed your offer"
 */
export const notifyRedemptionSuccess = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
  })
  .firestore
  .document('redemptions/{redemptionId}')
  .onCreate(async (snap, context) => {
    try {
      const redemption = snap.data();
      const customerId = redemption.user_id;
      const merchantId = redemption.merchant_id;
      const offerId = redemption.offer_id;

      // Get offer details for notification
      const offerDoc = await db.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) {
        console.error(`Offer not found: ${offerId}`);
        return null;
      }

      const offer = offerDoc.data()!;

      // Notify customer
      const customerDoc = await db.collection('customers').doc(customerId).get();
      if (customerDoc.exists && customerDoc.data()?.fcm_token) {
        const message: admin.messaging.MulticastMessage = {
          notification: {
            title: 'Points Redeemed! 🎉',
            body: `You successfully redeemed ${offer.points_value} points from ${offer.title}.`,
          },
          data: {
            type: 'redemption_success',
            offerId,
            pointsValue: String(offer.points_value),
            offerTitle: offer.title,
          },
          tokens: [customerDoc.data()!.fcm_token],
        };

        try {
          await defaultMessagingAdapter.sendEachForMulticast(message);
          console.log(`Redemption notification sent to customer ${customerId}`);
        } catch (error) {
          console.error('Failed to send customer redemption notification:', error);
          // Continue - merchant notification still important
        }
      }

      // Notify merchant
      const merchantDoc = await db.collection('merchants').doc(merchantId).get();
      if (merchantDoc.exists && merchantDoc.data()?.fcm_token) {
        const message: admin.messaging.MulticastMessage = {
          notification: {
            title: 'Offer Redeemed',
            body: `A customer redeemed your offer "${offer.title}" (${offer.points_value} points).`,
          },
          data: {
            type: 'offer_redeemed',
            offerId,
            redemptionId: context.params.redemptionId,
            pointsValue: String(offer.points_value),
          },
          tokens: [merchantDoc.data()!.fcm_token],
        };

        try {
          await defaultMessagingAdapter.sendEachForMulticast(message);
          console.log(`Redemption notification sent to merchant ${merchantId}`);
        } catch (error) {
          console.error('Failed to send merchant redemption notification:', error);
          // Best effort
        }
      }

      return null;

    } catch (error) {
      console.error('Error in notifyRedemptionSuccess:', error);
      return null;
    }
  });

// ============================================================================
// FUNCTION 4: Batch Send Notifications (Admin/Campaign)
// ============================================================================

interface BatchNotificationRequest {
  title: string;
  body: string;
  userIds?: string[]; // Specific users
  segment?: 'all' | 'active_customers' | 'premium_subscribers' | 'inactive'; // Segmented delivery
  data?: Record<string, string>;
}

interface BatchNotificationResponse {
  success: boolean;
  tokensSent?: number;
  tokensFailed?: number;
  error?: string;
}

/**
 * Admin function to send batch notifications
 * Supports segmentation and data fields
 * 
 * @param data - Batch notification request
 * @param context - Firebase Auth context (admin required)
 * @returns Response with delivery stats
 */
export const sendBatchNotification = functions
  .runWith({
    memory: '512MB',
    timeoutSeconds: 300,
  })
  .https.onCall(
  async (data: BatchNotificationRequest, context): Promise<BatchNotificationResponse> => {
    try {
      // Verify authentication and admin role
      if (!context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      // Check admin custom claim (set during user creation by admin SDK)
      const adminClaim = context.auth.token.admin === true;
      if (!adminClaim) {
        return { success: false, error: 'Admin privileges required' };
      }

      let userIds: string[] = [];

      // Determine target users
      if (data.userIds && data.userIds.length > 0) {
        userIds = data.userIds;
      } else if (data.segment) {
        const segmentQuery = getSegmentQuery(data.segment);
        const snapshot = await segmentQuery.get();
        userIds = snapshot.docs.map(doc => doc.id);
      } else {
        return { success: false, error: 'Must specify userIds or segment' };
      }

      console.log(`Sending batch notification to ${userIds.length} users`);

      // Collect FCM tokens (batch in groups of 500 for FCM limit)
      const tokens: string[] = [];
      const tokenMap: Record<string, string> = {}; // token -> userId mapping

      for (const userId of userIds) {
        const userDoc = await db.collection('customers').doc(userId).get();
        if (userDoc.exists && userDoc.data()?.fcm_token) {
          const token = userDoc.data()!.fcm_token;
          tokens.push(token);
          tokenMap[token] = userId;
        }
      }

      if (tokens.length === 0) {
        return {
          success: false,
          error: 'No FCM tokens found for target users',
        };
      }

      // Send in batches of 500 (FCM limit)
      let tokensSent = 0;
      let tokensFailed = 0;

      for (let i = 0; i < tokens.length; i += 500) {
        const batch = tokens.slice(i, i + 500);
        const message: admin.messaging.MulticastMessage = {
          notification: {
            title: data.title,
            body: data.body,
          },
          data: data.data || {},
          tokens: batch,
        };

        try {
          const response = await defaultMessagingAdapter.sendEachForMulticast(message);
          tokensSent += response.successCount;
          tokensFailed += response.failureCount;

          // Remove invalid tokens
          for (let j = 0; j < response.responses.length; j++) {
            if (!response.responses[j].success) {
              const token = batch[j];
              const userId = tokenMap[token];
              if (userId) {
                await db.collection('customers').doc(userId).update({
                  fcm_token: admin.firestore.FieldValue.delete(),
                });
              }
            }
          }
        } catch (error) {
          console.error(`Error sending batch ${i / 500 + 1}:`, error);
          tokensFailed += batch.length;
        }
      }

      console.log(`Batch notification completed. Sent: ${tokensSent}, Failed: ${tokensFailed}`);

      // Log campaign
      await db.collection('notification_campaigns').add({
        title: data.title,
        body: data.body,
        segment: data.segment || 'manual',
        tokens_sent: tokensSent,
        tokens_failed: tokensFailed,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        tokensSent,
        tokensFailed,
      };

    } catch (error) {
      console.error('Error in sendBatchNotification:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }
);

// ============================================================================
// HELPER: Segment Query Builder
// ============================================================================

function getSegmentQuery(
  segment: string
): admin.firestore.Query {
  const db = admin.firestore();

  switch (segment) {
    case 'active_customers':
      // Customers with active subscriptions in last 30 days
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      return db.collection('customers')
        .where('last_activity', '>=', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
        .where('subscription_status', '==', 'active');

    case 'premium_subscribers':
      // Customers with active premium subscription
      return db.collection('customers')
        .where('subscription_status', '==', 'active')
        .where('subscription_plan', '!=', 'free');

    case 'inactive':
      // Customers with no activity in 60+ days
      const sixtyDaysAgo = new Date();
      sixtyDaysAgo.setDate(sixtyDaysAgo.getDate() - 60);
      return db.collection('customers')
        .where('last_activity', '<', admin.firestore.Timestamp.fromDate(sixtyDaysAgo));

    default:
      // All customers
      return db.collection('customers');
  }
}
