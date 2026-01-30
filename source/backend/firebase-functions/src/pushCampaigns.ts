/**
 * Push Campaign Automation
 * Handles scheduled push notifications, campaigns, and targeted messaging
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { MessagingAdapter, defaultMessagingAdapter } from './adapters/messaging';

// Lazy initialization to avoid test issues
const getDb = () => admin.firestore();

interface Campaign {
  id: string;
  title: string;
  message: string;
  scheduled_at: admin.firestore.Timestamp;
  target_audience: 'all' | 'segment' | 'individual';
  segment_criteria?: {
    subscription_plan?: string[];
    location?: { latitude: number; longitude: number; radius_km: number };
    last_active_days?: number;
    points_balance_min?: number;
    points_balance_max?: number;
  };
  target_users?: string[];
  status: 'scheduled' | 'sent' | 'failed' | 'cancelled';
  sent_count?: number;
  failed_count?: number;
}

/**
 * Process Scheduled Campaigns
 * Runs every 15 minutes to check for campaigns ready to send
 */
export async function coreProcessScheduledCampaigns(deps: { db: admin.firestore.Firestore; messaging: MessagingAdapter } = { db: getDb(), messaging: defaultMessagingAdapter }): Promise<null> {
  try {
    const now = admin.firestore.Timestamp.now();

    console.log('Checking for scheduled campaigns');

    const campaigns = await deps.db.collection('push_campaigns')
      .where('status', '==', 'scheduled')
      .where('scheduled_at', '<=', now)
      .get();

    if (campaigns.empty) {
      console.log('No campaigns to send');
      return null;
    }

    console.log(`Found ${campaigns.size} campaigns to send`);

    for (const campaignDoc of campaigns.docs) {
      const campaign = campaignDoc.data() as Campaign;

      try {
        await sendCampaign(campaignDoc.id, campaign, deps);

        await campaignDoc.ref.update({
          status: 'sent',
          sent_at: admin.firestore.FieldValue.serverTimestamp(),
        });

      } catch (error) {
        console.error(`Error sending campaign ${campaignDoc.id}:`, error);

        await campaignDoc.ref.update({
          status: 'failed',
          error: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    }

    return null;

  } catch (error) {
    console.error('Error processing scheduled campaigns:', error);
    return null;
  }
}

// TEMPORARILY DISABLED - Requires Cloud Scheduler API
export const processScheduledCampaigns = null as any;
/*
export const processScheduledCampaigns = functions
  .runWith({
    memory: '512MB',
    timeoutSeconds: 540,
  })
  .pubsub.schedule('every 15 minutes')
  .onRun(async (context) => coreProcessScheduledCampaigns());
*/

/**
 * Send Campaign
 * Sends push notifications to targeted users
 */
async function sendCampaign(campaignId: string, campaign: Campaign, deps: { db: admin.firestore.Firestore; messaging: MessagingAdapter } = { db: getDb(), messaging: defaultMessagingAdapter }): Promise<void> {
  try {
    console.log(`Sending campaign: ${campaignId}`);

    let targetUserIds: string[] = [];

    // Determine target audience
    if (campaign.target_audience === 'all') {
      targetUserIds = await getAllUserIds(deps.db);
    } else if (campaign.target_audience === 'segment') {
      targetUserIds = await getUsersBySegment(campaign.segment_criteria!, deps.db);
    } else if (campaign.target_audience === 'individual') {
      targetUserIds = campaign.target_users || [];
    }

    if (targetUserIds.length === 0) {
      console.log('No target users found');
      return;
    }

    console.log(`Sending to ${targetUserIds.length} users`);

    // Get FCM tokens for target users
    const tokens: string[] = [];
    for (const userId of targetUserIds) {
      const userDoc = await getDb().collection('customers').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data()!;
        if (userData.fcm_token) {
          tokens.push(userData.fcm_token);
        }
      }
    }

    if (tokens.length === 0) {
      console.log('No FCM tokens found');
      return;
    }

    // Send notifications in batches of 500 (FCM limit)
    const batchSize = 500;
    let sentCount = 0;
    let failedCount = 0;

    for (let i = 0; i < tokens.length; i += batchSize) {
      const batchTokens = tokens.slice(i, i + batchSize);

      const message = {
        notification: {
          title: campaign.title,
          body: campaign.message,
        },
        data: {
          campaign_id: campaignId,
          type: 'campaign',
        },
        tokens: batchTokens,
      };

      try {
        const response = await deps.messaging.sendEachForMulticast(message);
        sentCount += response.successCount;
        failedCount += response.failureCount;

        // Remove invalid tokens
        if (response.failureCount > 0) {
          const failedTokens: string[] = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              failedTokens.push(batchTokens[idx]);
            }
          });

          // Clean up invalid tokens
          await cleanupInvalidTokens(failedTokens, deps.db);
        }

      } catch (error) {
        console.error('Error sending batch:', error);
        failedCount += batchTokens.length;
      }
    }

    // Update campaign stats
    await getDb().collection('push_campaigns').doc(campaignId).update({
      sent_count: sentCount,
      failed_count: failedCount,
    });

    // Log campaign results
    await getDb().collection('campaign_logs').add({
      campaign_id: campaignId,
      sent_count: sentCount,
      failed_count: failedCount,
      target_users: targetUserIds.length,
      sent_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Campaign sent: ${sentCount} successful, ${failedCount} failed`);

  } catch (error) {
    console.error('Error sending campaign:', error);
    throw error;
  }
}

/**
 * Get All User IDs
 */
export async function getAllUserIds(db: admin.firestore.Firestore = getDb()): Promise<string[]> {
  const usersSnapshot = await getDb().collection('customers').get();
  return usersSnapshot.docs.map(doc => doc.id);
}

/**
 * Get Users by Segment
 * Filters users based on segment criteria
 */
export async function getUsersBySegment(criteria: Campaign['segment_criteria'], db: admin.firestore.Firestore = getDb()): Promise<string[]> {
  try {
    let query: admin.firestore.Query = getDb().collection('customers');

    // Filter by subscription plan
    if (criteria?.subscription_plan && criteria.subscription_plan.length > 0) {
      query = query.where('subscription_plan', 'in', criteria.subscription_plan);
    }

    // Filter by points balance
    if (criteria?.points_balance_min !== undefined) {
      query = query.where('points_balance', '>=', criteria.points_balance_min);
    }

    if (criteria?.points_balance_max !== undefined) {
      query = query.where('points_balance', '<=', criteria.points_balance_max);
    }

    // Execute query
    const usersSnapshot = await query.get();
    let userIds = usersSnapshot.docs.map(doc => doc.id);

    // Filter by last active (requires in-memory filtering)
    if (criteria?.last_active_days !== undefined) {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - criteria.last_active_days);

      userIds = userIds.filter(userId => {
        const userDoc = usersSnapshot.docs.find(doc => doc.id === userId);
        if (userDoc) {
          const userData = userDoc.data();
          const lastActive = userData.last_active_at?.toDate();
          return lastActive && lastActive >= cutoffDate;
        }
        return false;
      });
    }

    // Filter by location (requires in-memory filtering)
    if (criteria?.location) {
      userIds = await filterByLocation(userIds, criteria.location);
    }

    return userIds;

  } catch (error) {
    console.error('Error getting users by segment:', error);
    return [];
  }
}

/**
 * Filter Users by Location
 * Uses Haversine formula to calculate distance
 */
async function filterByLocation(
  userIds: string[],
  location: { latitude: number; longitude: number; radius_km: number }
): Promise<string[]> {
  const filteredUsers: string[] = [];

  for (const userId of userIds) {
    const userDoc = await getDb().collection('customers').doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data()!;
      if (userData.latitude && userData.longitude) {
        const distance = calculateDistance(
          location.latitude,
          location.longitude,
          userData.latitude,
          userData.longitude
        );

        if (distance <= location.radius_km) {
          filteredUsers.push(userId);
        }
      }
    }
  }

  return filteredUsers;
}

/**
 * Calculate Distance (Haversine Formula)
 */
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth's radius in km
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRadians(degrees: number): number {
  return degrees * (Math.PI / 180);
}

/**
 * Cleanup Invalid FCM Tokens
 */
export async function cleanupInvalidTokens(tokens: string[], db: admin.firestore.Firestore = getDb()): Promise<void> {
  try {
    for (const token of tokens) {
      const userQuery = await getDb().collection('customers')
        .where('fcm_token', '==', token)
        .limit(1)
        .get();

      if (!userQuery.empty) {
        await userQuery.docs[0].ref.update({
          fcm_token: admin.firestore.FieldValue.delete(),
        });
      }
    }
  } catch (error) {
    console.error('Error cleaning up invalid tokens:', error);
  }
}

/**
 * Send Personalized Notification (Callable Function)
 * Allows admins to send immediate notifications
 */
export async function coreSendPersonalizedNotification(
  data: { userId: string; title: string; body: string; data?: any }, 
  context: any,
  deps: { db: admin.firestore.Firestore; messaging: MessagingAdapter } = { db: getDb(), messaging: defaultMessagingAdapter }
): Promise<{ success: boolean; error?: string }> {
  try {
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    if (!data.userId || !data.title || !data.body) {
      return { success: false, error: 'Missing required fields' };
    }

    const userDoc = await deps.db.collection('customers').doc(data.userId).get();
    if (!userDoc.exists) {
      return { success: false, error: 'User not found' };
    }

    const userData = userDoc.data()!;
    if (!userData.fcm_token) {
      return { success: false, error: 'User has no FCM token' };
    }

    const message = {
      notification: {
        title: data.title,
        body: data.body,
      },
      data: data.data || {},
      tokens: [userData.fcm_token],
    };

    const response = await deps.messaging.sendEachForMulticast(message);
    
    if (response.failureCount > 0) {
      return { success: false, error: 'Failed to send notification' };
    }

    await deps.db.collection('notifications').add({
      user_id: data.userId,
      title: data.title,
      message: data.body,
      type: 'admin_message',
      is_read: false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };

  } catch (error) {
    console.error('Error sending personalized notification:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

export const sendPersonalizedNotification = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
  })
  .https.onCall(async (data, context) => coreSendPersonalizedNotification(data, context));



/**
 * Core Schedule Campaign Logic
 */
export async function coreScheduleCampaign(
  data: Omit<Campaign, 'id' | 'status'>,
  context: functions.https.CallableContext,
  deps: { db: admin.firestore.Firestore } = { db: getDb() }
) {
  if (!context.auth) {
    return { success: false, error: 'Unauthenticated' };
  }

  if (!data.title || !data.message) {
    return { success: false, error: 'Title and message required' };
  }

  const campaignRef = await deps.db.collection('push_campaigns').add({
    ...data,
    status: 'scheduled',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    created_by: context.auth.uid,
  });

  return { success: true, campaignId: campaignRef.id };
}

/**
 * Schedule Campaign (Callable Function)
 * Allows admins to create scheduled campaigns
 */
export const scheduleCampaign = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
  })
  .https.onCall(async (data: Omit<Campaign, 'id' | 'status'>, context) => {
    try {
      return await coreScheduleCampaign(data, context);
    } catch (error) {
      console.error('Error scheduling campaign:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });
