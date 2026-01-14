/**
 * FCM (Firebase Cloud Messaging) Core Functions
 * Device token management and push notification delivery
 * 
 * Phase 2 - Feature 5: FCM Push Campaigns
 */

import * as admin from 'firebase-admin';
import { CallableContext } from 'firebase-functions/v1/https';
import * as functions from 'firebase-functions';
import Logger from '../logger';

interface Dependencies {
  db: admin.firestore.Firestore;
}

// ============================================================================
// DEVICE TOKEN MANAGEMENT
// ============================================================================

interface RegisterTokenRequest {
  token: string;
  platform: 'ios' | 'android' | 'web';
  deviceId: string;
}

interface RegisterTokenResponse {
  success: boolean;
  message: string;
}

/**
 * Register FCM device token for push notifications
 * Creates or updates token in fcm_tokens collection
 */
export async function registerFCMToken(
  data: RegisterTokenRequest,
  context: CallableContext,
  deps: Dependencies
): Promise<RegisterTokenResponse> {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = context.auth.uid;
    const { token, platform, deviceId } = data;

    // Validate token by testing it with FCM
    try {
      await admin.messaging().send({
        token,
        data: { type: 'registration_test' },
      }, true); // dryRun = true
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      Logger.error('Invalid FCM token', err, { tokenPrefix: token.substring(0, 20) });
      throw new functions.https.HttpsError('invalid-argument', 'Invalid FCM token');
    }

    const tokenRef = deps.db.collection('fcm_tokens').doc(userId);
    const tokenDoc = await tokenRef.get();

    const now = admin.firestore.Timestamp.now();

    if (!tokenDoc.exists) {
      // Create new token document
      await tokenRef.set({
        userId,
        tokens: [{
          token,
          platform,
          deviceId,
          registeredAt: now,
          lastUsed: now,
        }],
        updatedAt: now,
      });

      Logger.info('FCM token registered', { userId, platform, deviceId });
      return { success: true, message: 'Token registered successfully' };
    }

    // Update existing tokens
    const existingTokens = tokenDoc.data()!.tokens || [];
    
    // Check if token already exists
    const tokenIndex = existingTokens.findIndex((t: any) => t.token === token);
    
    if (tokenIndex >= 0) {
      // Update existing token
      existingTokens[tokenIndex] = {
        ...existingTokens[tokenIndex],
        lastUsed: now,
      };
    } else {
      // Add new token, limit to 5 tokens per user
      if (existingTokens.length >= 5) {
        // Remove oldest token
        existingTokens.sort((a: any, b: any) => 
          a.lastUsed.toMillis() - b.lastUsed.toMillis()
        );
        existingTokens.shift();
      }

      existingTokens.push({
        token,
        platform,
        deviceId,
        registeredAt: now,
        lastUsed: now,
      });
    }

    await tokenRef.update({
      tokens: existingTokens,
      updatedAt: now,
    });

    Logger.info('FCM token updated', { userId, platform, deviceId, totalTokens: existingTokens.length });
    return { success: true, message: 'Token updated successfully' };

  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    const err = error instanceof Error ? error : new Error(String(error));
    Logger.error('Failed to register FCM token', err);
    throw new functions.https.HttpsError('internal', 'Failed to register token');
  }
}

interface UnregisterTokenRequest {
  token: string;
}

interface UnregisterTokenResponse {
  success: boolean;
  message: string;
}

/**
 * Unregister FCM device token
 * Removes token from fcm_tokens collection
 */
export async function unregisterFCMToken(
  data: UnregisterTokenRequest,
  context: CallableContext,
  deps: Dependencies
): Promise<UnregisterTokenResponse> {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = context.auth.uid;
    const { token } = data;

    const tokenRef = deps.db.collection('fcm_tokens').doc(userId);
    const tokenDoc = await tokenRef.get();

    if (!tokenDoc.exists) {
      return { success: true, message: 'No tokens found' };
    }

    const existingTokens = tokenDoc.data()!.tokens || [];
    const updatedTokens = existingTokens.filter((t: any) => t.token !== token);

    if (updatedTokens.length === 0) {
      // Delete document if no tokens left
      await tokenRef.delete();
      Logger.info('FCM tokens document deleted', { userId });
    } else {
      // Update with remaining tokens
      await tokenRef.update({
        tokens: updatedTokens,
        updatedAt: admin.firestore.Timestamp.now(),
      });
      Logger.info('FCM token unregistered', { userId, remainingTokens: updatedTokens.length });
    }

    return { success: true, message: 'Token unregistered successfully' };

  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    const err = error instanceof Error ? error : new Error(String(error));
    Logger.error('Failed to unregister FCM token', err);
    throw new functions.https.HttpsError('internal', 'Failed to unregister token');
  }
}

// ============================================================================
// PUSH NOTIFICATION DELIVERY
// ============================================================================

interface SendNotificationRequest {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
}

interface SendNotificationResponse {
  success: boolean;
  tokensUsed: number;
  successCount: number;
  failureCount: number;
}

/**
 * Send push notification to user's all registered devices
 */
export async function sendNotification(
  data: SendNotificationRequest,
  deps: Dependencies
): Promise<SendNotificationResponse> {
  try {
    const { userId, title, body, data: customData, imageUrl } = data;

    // Get user's FCM tokens
    const tokenDoc = await deps.db.collection('fcm_tokens').doc(userId).get();

    if (!tokenDoc.exists) {
      Logger.info('No FCM tokens found for user', { userId });
      return { success: true, tokensUsed: 0, successCount: 0, failureCount: 0 };
    }

    const tokens = tokenDoc.data()!.tokens || [];
    if (tokens.length === 0) {
      return { success: true, tokensUsed: 0, successCount: 0, failureCount: 0 };
    }

    // Prepare message
    const message: admin.messaging.MulticastMessage = {
      notification: {
        title,
        body,
        ...(imageUrl && { imageUrl }),
      },
      data: {
        ...customData,
        timestamp: Date.now().toString(),
      },
      tokens: tokens.map((t: any) => t.token),
    };

    // Send to all tokens
    const response = await admin.messaging().sendEachForMulticast(message);

    // Update lastUsed for successful tokens, remove invalid tokens
    const validTokens: any[] = [];
    const now = admin.firestore.Timestamp.now();

    response.responses.forEach((resp, index) => {
      if (resp.success) {
        tokens[index].lastUsed = now;
        validTokens.push(tokens[index]);
      } else {
        const errorCode = resp.error?.code;
        if (errorCode === 'messaging/invalid-registration-token' ||
            errorCode === 'messaging/registration-token-not-registered') {
          Logger.warn('Removing invalid FCM token', { userId, errorCode });
          // Don't add to validTokens (removes it)
        } else {
          // Keep token for other errors (might be temporary)
          validTokens.push(tokens[index]);
        }
      }
    });

    // Update tokens document
    if (validTokens.length !== tokens.length) {
      if (validTokens.length === 0) {
        await deps.db.collection('fcm_tokens').doc(userId).delete();
      } else {
        await deps.db.collection('fcm_tokens').doc(userId).update({
          tokens: validTokens,
          updatedAt: now,
        });
      }
    } else if (response.successCount > 0) {
      await deps.db.collection('fcm_tokens').doc(userId).update({
        tokens: validTokens,
        updatedAt: now,
      });
    }

    Logger.info('Push notification sent', {
      userId,
      tokensUsed: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });

    return {
      success: true,
      tokensUsed: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };

  } catch (error) {
    const err = error instanceof Error ? error : new Error(String(error));
    Logger.error('Failed to send push notification', err, { userId: data.userId });
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
}

// ============================================================================
// CAMPAIGN MANAGEMENT
// ============================================================================

interface CreateCampaignRequest {
  title: string;
  message: string;
  targetAudience: 'all' | 'customers' | 'merchants' | 'custom';
  customUserIds?: string[];
  scheduledAt?: string; // ISO timestamp
  imageUrl?: string;
  actionUrl?: string;
}

interface CreateCampaignResponse {
  success: boolean;
  campaignId: string;
  scheduledFor?: string;
}

/**
 * Create push notification campaign (admin only)
 */
export async function createCampaign(
  data: CreateCampaignRequest,
  context: CallableContext,
  deps: Dependencies
): Promise<CreateCampaignResponse> {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    // Verify admin role
    const adminDoc = await deps.db.collection('admins').doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    const { title, message, targetAudience, customUserIds, scheduledAt, imageUrl, actionUrl } = data;

    // Determine target user IDs
    let targetUserIds: string[] = [];

    if (targetAudience === 'custom') {
      if (!customUserIds || customUserIds.length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Custom user IDs required for custom audience');
      }
      targetUserIds = customUserIds;
    } else if (targetAudience === 'all') {
      // Get all users with FCM tokens
      const tokensSnapshot = await deps.db.collection('fcm_tokens').get();
      targetUserIds = tokensSnapshot.docs.map(doc => doc.id);
    } else if (targetAudience === 'customers') {
      // Get all customers
      const customersSnapshot = await deps.db.collection('customers').get();
      targetUserIds = customersSnapshot.docs.map(doc => doc.id);
    } else if (targetAudience === 'merchants') {
      // Get all merchants
      const merchantsSnapshot = await deps.db.collection('merchants').get();
      targetUserIds = merchantsSnapshot.docs.map(doc => doc.id);
    }

    // Create campaign document
    const campaignRef = deps.db.collection('campaigns').doc();
    const now = admin.firestore.Timestamp.now();
    const scheduled = scheduledAt ? admin.firestore.Timestamp.fromDate(new Date(scheduledAt)) : now;

    await campaignRef.set({
      title,
      message,
      targetAudience,
      targetUserIds,
      targetCount: targetUserIds.length,
      scheduledAt: scheduled,
      status: scheduledAt ? 'scheduled' : 'pending',
      createdBy: context.auth.uid,
      createdAt: now,
      imageUrl: imageUrl || null,
      actionUrl: actionUrl || null,
      results: {
        sent: 0,
        delivered: 0,
        failed: 0,
      },
    });

    Logger.info('Campaign created', {
      campaignId: campaignRef.id,
      targetAudience,
      targetCount: targetUserIds.length,
      scheduledAt: scheduled.toDate().toISOString(),
    });

    return {
      success: true,
      campaignId: campaignRef.id,
      scheduledFor: scheduled.toDate().toISOString(),
    };

  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    const err = error instanceof Error ? error : new Error(String(error));
    Logger.error('Failed to create campaign', err);
    throw new functions.https.HttpsError('internal', 'Failed to create campaign');
  }
}

interface SendCampaignRequest {
  campaignId: string;
}

interface SendCampaignResponse {
  success: boolean;
  sent: number;
  delivered: number;
  failed: number;
}

/**
 * Send campaign notifications to all target users (admin only)
 */
export async function sendCampaign(
  data: SendCampaignRequest,
  context: CallableContext,
  deps: Dependencies
): Promise<SendCampaignResponse> {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    // Verify admin role
    const adminDoc = await deps.db.collection('admins').doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    const { campaignId } = data;

    const campaignRef = deps.db.collection('campaigns').doc(campaignId);
    const campaignDoc = await campaignRef.get();

    if (!campaignDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Campaign not found');
    }

    const campaign = campaignDoc.data()!;

    if (campaign.status === 'sent') {
      throw new functions.https.HttpsError('failed-precondition', 'Campaign already sent');
    }

    // Update status to sending
    await campaignRef.update({ status: 'sending' });

    let totalSent = 0;
    let totalDelivered = 0;
    let totalFailed = 0;

    // Send notifications in batches of 50
    const batchSize = 50;
    const targetUserIds = campaign.targetUserIds || [];

    for (let i = 0; i < targetUserIds.length; i += batchSize) {
      const batch = targetUserIds.slice(i, i + batchSize);

      await Promise.all(batch.map(async (userId: string) => {
        try {
          const result = await sendNotification({
            userId,
            title: campaign.title,
            body: campaign.message,
            data: {
              campaignId,
              actionUrl: campaign.actionUrl || '',
            },
            imageUrl: campaign.imageUrl,
          }, deps);

          totalSent += result.tokensUsed;
          totalDelivered += result.successCount;
          totalFailed += result.failureCount;

        } catch (error) {
          const err = error instanceof Error ? error : new Error(String(error));
          Logger.error('Failed to send notification to user', err, { userId });
          totalFailed += 1;
        }
      }));
    }

    // Update campaign with results
    await campaignRef.update({
      status: 'sent',
      sentAt: admin.firestore.Timestamp.now(),
      results: {
        sent: totalSent,
        delivered: totalDelivered,
        failed: totalFailed,
      },
    });

    Logger.info('Campaign sent', {
      campaignId,
      sent: totalSent,
      delivered: totalDelivered,
      failed: totalFailed,
    });

    return {
      success: true,
      sent: totalSent,
      delivered: totalDelivered,
      failed: totalFailed,
    };

  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    const err = error instanceof Error ? error : new Error(String(error));
    Logger.error('Failed to send campaign', err);
    throw new functions.https.HttpsError('internal', 'Failed to send campaign');
  }
}

interface GetCampaignStatsRequest {
  campaignId?: string;
  limit?: number;
}

interface GetCampaignStatsResponse {
  success: boolean;
  campaigns: any[];
}

/**
 * Get campaign statistics (admin only)
 */
export async function getCampaignStats(
  data: GetCampaignStatsRequest,
  context: CallableContext,
  deps: Dependencies
): Promise<GetCampaignStatsResponse> {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    // Verify admin role
    const adminDoc = await deps.db.collection('admins').doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    const { campaignId, limit = 20 } = data;

    if (campaignId) {
      // Get specific campaign
      const campaignDoc = await deps.db.collection('campaigns').doc(campaignId).get();
      if (!campaignDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Campaign not found');
      }

      return {
        success: true,
        campaigns: [{ id: campaignDoc.id, ...campaignDoc.data() }],
      };
    }

    // Get recent campaigns
    const campaignsSnapshot = await deps.db.collection('campaigns')
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .get();

    const campaigns = campaignsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    return { success: true, campaigns };

  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    const err = error instanceof Error ? error : new Error(String(error));
    Logger.error('Failed to get campaign stats', err);
    throw new functions.https.HttpsError('internal', 'Failed to get campaign stats');
  }
}
