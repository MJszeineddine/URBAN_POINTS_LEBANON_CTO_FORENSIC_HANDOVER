/**
 * Phase 3 Scheduler Functions
 * Automation layer for notifications, compliance enforcement, and data cleanup
 * 
 * Jobs:
 * 1. notifyOfferApprovedRejected - Send FCM notifications on offer status change
 * 2. enforceMerchantCompliance - Monitor and enforce 5+ approved offers threshold
 * 3. cleanupExpiredQRTokens - Daily cleanup of expired QR tokens
 * 4. sendPointsExpiryWarnings - Notify customers of expiring points
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { defaultMessagingAdapter, MessagingAdapter } from './adapters/messaging';

const db = admin.firestore();

// ============================================================================
// HELPER: Send FCM Notification
// ============================================================================

interface NotificationPayload {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  messageId?: string;
  messaging?: MessagingAdapter;
}

/**
 * Send FCM notification to a user
 * Best effort: logs errors but doesn't fail the transaction
 */
async function sendFCMNotification(
  payload: NotificationPayload
): Promise<{ success: boolean; error?: string }> {
  try {
    const messaging = payload.messaging || defaultMessagingAdapter;
    
    // Get user's FCM token
    const userDoc = await db.collection('customers').doc(payload.userId).get();
    if (!userDoc.exists) {
      return { success: false, error: 'User not found' };
    }

    const userData = userDoc.data()!;
    if (!userData.fcm_token) {
      // No token, skip notification (user may not have registered yet)
      return { success: false, error: 'No FCM token' };
    }

    // Send message
    const message: admin.messaging.MulticastMessage = {
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
      tokens: [userData.fcm_token],
    };

    const response = await messaging.sendEachForMulticast(message);

    if (response.failureCount > 0) {
      // Log failed tokens for cleanup
      await db.collection('customers').doc(payload.userId).update({
        fcm_token: admin.firestore.FieldValue.delete(),
      });
      return { success: false, error: 'FCM token invalid/expired' };
    }

    // Log notification in DB for audit
    if (payload.messageId) {
      await db.collection('notification_logs').add({
        user_id: payload.userId,
        message_id: payload.messageId,
        title: payload.title,
        body: payload.body,
        status: 'sent',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { success: true };

  } catch (error) {
    console.error('Error sending FCM notification:', error);
    return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
  }
}

// ============================================================================
// JOB 1: Notify on Offer Approval/Rejection
// ============================================================================

/**
 * Triggered by Firestore on-update for offers collection
 * Sends FCM notification when offer status changes to approved or rejected
 */
export const notifyOfferStatusChange = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
  })
  .firestore
  .document('offers/{offerId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const offerId = context.params.offerId;

      // Only process if status changed
      if (before.status === after.status) {
        return null;
      }

      const merchantId = after.merchant_id;

      // Case 1: Offer Approved (pending → active or approved)
      if (before.status === 'pending' && after.status === 'active') {
        await sendFCMNotification({
          userId: merchantId,
          title: 'Offer Approved! 🎉',
          body: `Your offer "${after.title}" has been approved and is now visible to customers.`,
          data: {
            offerId,
            offerTitle: after.title,
            type: 'offer_approved',
          },
          messageId: `offer_approved_${offerId}`,
        });
      }

      // Case 2: Offer Rejected
      if (before.status === 'pending' && after.status === 'rejected') {
        const reason = after.rejection_reason || 'Does not meet catalog standards';
        await sendFCMNotification({
          userId: merchantId,
          title: 'Offer Not Approved',
          body: `Your offer "${after.title}" was not approved: ${reason}`,
          data: {
            offerId,
            offerTitle: after.title,
            rejectionReason: reason,
            type: 'offer_rejected',
          },
          messageId: `offer_rejected_${offerId}`,
        });
      }

      // Case 3: Offer Expired (active → expired)
      if (before.status === 'active' && after.status === 'expired') {
        await sendFCMNotification({
          userId: merchantId,
          title: 'Offer Expired',
          body: `Your offer "${after.title}" has reached its end date and is no longer visible.`,
          data: {
            offerId,
            offerTitle: after.title,
            type: 'offer_expired',
          },
          messageId: `offer_expired_${offerId}`,
        });
      }

      return null;

    } catch (error) {
      console.error('Error in notifyOfferStatusChange:', error);
      // Don't fail the operation - notification is best-effort
      return null;
    }
  });

// ============================================================================
// JOB 2: Enforce Merchant Compliance (5+ Approved Offers)
// ============================================================================

/**
 * Daily job: Check merchant compliance
 * Criteria: Merchants must have 5+ approved offers to stay in premium tier
 * Actions:
 * - Mark merchants with <5 approved offers as non-compliant
 * - Hide non-compliant merchants' offers from catalog
 * - Send notification to merchants below threshold
 */
export const enforceMerchantCompliance = functions
  .runWith({
    memory: '512MB',
    timeoutSeconds: 540, // 9 minutes
  })
  .pubsub.schedule('0 5 * * *') // Every day at 5 AM Asia/Beirut
  .timeZone('Asia/Beirut')
  .onRun(async (context) => {
    try {
      console.log('Starting merchant compliance check');

      const REQUIRED_OFFERS = 5;
      const complianceResults = {
        checked: 0,
        compliant: 0,
        nonCompliant: 0,
        updated: 0,
      };

      // Get all merchants
      const merchants = await db.collection('merchants').get();

      for (const merchantDoc of merchants.docs) {
        const merchantId = merchantDoc.id;
        complianceResults.checked++;

        try {
          // Count approved offers for this merchant
          const approvedOffers = await db.collection('offers')
            .where('merchant_id', '==', merchantId)
            .where('status', '==', 'active')
            .get();

          const approvedCount = approvedOffers.size;
          const isCompliant = approvedCount >= REQUIRED_OFFERS;

          const merchantData = merchantDoc.data();
          const wasCompliant = merchantData.is_compliant !== false;

          if (isCompliant) {
            complianceResults.compliant++;

            // Ensure compliant merchant has all offers visible
            if (!wasCompliant) {
              await merchantDoc.ref.update({
                is_compliant: true,
                is_visible_in_catalog: true,
                compliance_status: 'active',
                compliance_checked_at: admin.firestore.FieldValue.serverTimestamp(),
              });

              complianceResults.updated++;

              // Notify merchant they're back in compliance
              await sendFCMNotification({
                userId: merchantId,
                title: 'Compliance Restored ✅',
                body: `You now have ${approvedCount} approved offers. Your profile is fully visible in the catalog.`,
                data: {
                  type: 'compliance_restored',
                  approvedOffers: String(approvedCount),
                },
                messageId: `compliance_restored_${merchantId}`,
              });
            }
          } else {
            complianceResults.nonCompliant++;

            // Mark as non-compliant
            if (wasCompliant) {
              await merchantDoc.ref.update({
                is_compliant: false,
                is_visible_in_catalog: false,
                compliance_status: 'warning',
                compliance_checked_at: admin.firestore.FieldValue.serverTimestamp(),
                offers_needed: REQUIRED_OFFERS - approvedCount,
              });

              complianceResults.updated++;

              // Hide all offers from catalog
              const batch = db.batch();
              for (const offerDoc of approvedOffers.docs) {
                batch.update(offerDoc.ref, {
                  is_visible_in_catalog: false,
                  visibility_reason: 'merchant_non_compliant',
                });
              }
              await batch.commit();

              // Notify merchant of non-compliance
              const offersNeeded = REQUIRED_OFFERS - approvedCount;
              await sendFCMNotification({
                userId: merchantId,
                title: 'Compliance Alert ⚠️',
                body: `You currently have ${approvedCount} approved offers. You need ${offersNeeded} more to remain visible in the catalog.`,
                data: {
                  type: 'compliance_warning',
                  approvedOffers: String(approvedCount),
                  offersNeeded: String(offersNeeded),
                },
                messageId: `compliance_warning_${merchantId}`,
              });
            }
          }
        } catch (error) {
          console.error(`Error checking compliance for merchant ${merchantId}:`, error);
          // Continue processing other merchants
        }
      }

      console.log('Compliance check results:', complianceResults);

      // Log compliance check
      await db.collection('compliance_checks').add({
        date: admin.firestore.FieldValue.serverTimestamp(),
        results: complianceResults,
      });

      return null;

    } catch (error) {
      console.error('Error in merchant compliance check:', error);
      return null;
    }
  });

// ============================================================================
// JOB 3: Cleanup Expired QR Tokens
// ============================================================================

/**
 * Daily job: Cleanup expired QR tokens
 * - Deletes QR tokens older than 7 days
 * - Marks redemption tokens as cleanup
 * - Logs cleanup statistics
 */
export const cleanupExpiredQRTokens = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 300,
  })
  .pubsub.schedule('0 6 * * *') // Every day at 6 AM Asia/Beirut
  .timeZone('Asia/Beirut')
  .onRun(async (context) => {
    try {
      console.log('Starting QR token cleanup');

      const RETENTION_DAYS = 7;
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - RETENTION_DAYS);
      const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

      // Find expired tokens
      const expiredTokens = await db.collection('qr_tokens')
        .where('created_at', '<', cutoffTimestamp)
        .where('status', '!=', 'redeemed')
        .get();

      console.log(`Found ${expiredTokens.size} expired tokens to cleanup`);

      if (expiredTokens.empty) {
        return null;
      }

      const batch = db.batch();
      let deletedCount = 0;

      for (const tokenDoc of expiredTokens.docs) {
        // Soft delete: mark as expired instead of removing
        batch.update(tokenDoc.ref, {
          status: 'expired_cleanup',
          cleanup_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        deletedCount++;

        // Batch limit is 500
        if (deletedCount % 500 === 0) {
          await batch.commit();
          console.log(`Cleaned up ${deletedCount} tokens...`);
        }
      }

      // Final commit
      if (deletedCount % 500 !== 0) {
        await batch.commit();
      }

      console.log(`QR token cleanup complete. Marked ${deletedCount} tokens as expired`);

      // Log cleanup
      await db.collection('cleanup_logs').add({
        type: 'qr_tokens',
        date: admin.firestore.FieldValue.serverTimestamp(),
        deleted_count: deletedCount,
        retention_days: RETENTION_DAYS,
      });

      return null;

    } catch (error) {
      console.error('Error in QR token cleanup:', error);
      return null;
    }
  });

// ============================================================================
// JOB 4: Send Points Expiry Warnings (Optional Enhancement)
// ============================================================================

/**
 * Daily job: Check for customers with expiring points
 * Similar to subscription reminders, notify customers about points expiry
 */
export const sendPointsExpiryWarnings = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 300,
  })
  .pubsub.schedule('0 11 * * *') // Every day at 11 AM Asia/Beirut
  .timeZone('Asia/Beirut')
  .onRun(async (context) => {
    try {
      console.log('Checking for expiring points...');

      const now = new Date();
      const thirtyDaysFromNow = new Date(now);
      thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);

      // Get points expiry events (if tracked in separate collection)
      const expiringPoints = await db.collection('points_expiry_events')
        .where('expiry_date', '>=', admin.firestore.Timestamp.fromDate(now))
        .where('expiry_date', '<=', admin.firestore.Timestamp.fromDate(thirtyDaysFromNow))
        .where('notified', '==', false)
        .get();

      if (expiringPoints.empty) {
        console.log('No points expiring in 30 days');
        return null;
      }

      console.log(`Found ${expiringPoints.size} customers with expiring points`);

      let notificationsSent = 0;

      for (const eventDoc of expiringPoints.docs) {
        const event = eventDoc.data();

        const expiryDate = event.expiry_date.toDate();
        const daysRemaining = Math.ceil(
          (expiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
        );

        const result = await sendFCMNotification({
          userId: event.user_id,
          title: `${event.points_amount} Points Expiring Soon!`,
          body: `Your ${event.points_amount} points will expire in ${daysRemaining} days. Use them now!`,
          data: {
            type: 'points_expiry_warning',
            pointsAmount: String(event.points_amount),
            daysRemaining: String(daysRemaining),
          },
          messageId: `points_expiry_${event.user_id}`,
        });

        if (result.success) {
          // Mark as notified
          await eventDoc.ref.update({
            notified: true,
            notified_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          notificationsSent++;
        }
      }

      console.log(`Points expiry warnings sent: ${notificationsSent}`);

      return null;

    } catch (error) {
      console.error('Error sending points expiry warnings:', error);
      return null;
    }
  });
