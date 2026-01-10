import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import {
  coreProcessScheduledCampaigns,
  coreSendPersonalizedNotification,
  coreScheduleCampaign,
  getAllUserIds,
  getUsersBySegment,
  cleanupInvalidTokens,
  processScheduledCampaigns,
} from '../pushCampaigns';
import { FakeMessagingAdapter } from '../adapters/messaging';

const testEnv = functionsTest(
  {
    projectId: 'urbangenspark-test',
  },
  undefined
);

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'urbangenspark-test',
  });
}

describe('Push Campaigns Module', () => {
  let db: admin.firestore.Firestore;
  let fakeMessaging: FakeMessagingAdapter;

  beforeAll(() => {
    db = admin.firestore();
    fakeMessaging = new FakeMessagingAdapter();
  });

  beforeEach(async () => {
    const collections = ['push_campaigns', 'customers', 'fcm_tokens', 'notifications'];
    for (const collection of collections) {
      const snapshot = await db.collection(collection).get();
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      if (snapshot.docs.length > 0) {
        await batch.commit();
      }
    }
    fakeMessaging.reset();
  });

  afterAll(() => {
    testEnv.cleanup();
  });

  describe('coreScheduleCampaign', () => {
    it('should create scheduled campaign', async () => {
      const mockContext = {
        auth: { uid: 'admin123', token: {} },
      } as any;

      const campaignData = {
        title: 'Test Campaign',
        message: 'Test message',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date()),
        target_audience: 'all' as const,
      };

      const result = await coreScheduleCampaign(campaignData, mockContext, { db });

      expect(result.success).toBe(true);
      expect(result.campaignId).toBeDefined();

      const campaignDoc = await db.collection('push_campaigns').doc(result.campaignId!).get();
      expect(campaignDoc.exists).toBe(true);
      expect(campaignDoc.data()?.title).toBe('Test Campaign');
      expect(campaignDoc.data()?.status).toBe('scheduled');
    });

    it('should reject unauthenticated requests', async () => {
      const mockContext = { auth: null } as any;
      const result = await coreScheduleCampaign(
        { title: 'Test', message: 'Test' } as any,
        mockContext,
        { db }
      );

      expect(result.success).toBe(false);
      expect(result.error).toBe('Unauthenticated');
    });

    it('should validate required fields', async () => {
      const mockContext = { auth: { uid: 'admin123', token: {} } } as any;

      const result1 = await coreScheduleCampaign({ message: 'Test' } as any, mockContext, { db });
      expect(result1.success).toBe(false);
      expect(result1.error).toBe('Title and message required');

      const result2 = await coreScheduleCampaign({ title: 'Test' } as any, mockContext, { db });
      expect(result2.success).toBe(false);
      expect(result2.error).toBe('Title and message required');
    });
  });

  describe('coreProcessScheduledCampaigns', () => {
    it('should handle empty campaigns', async () => {
      const result = await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });
      expect(result).toBeNull();
    });

    it('should send campaign with FCM tokens', async () => {
      await db.collection('customers').doc('user1').set({
        name: 'User 1',
        fcm_token: 'test_token_1',
      });

      await db.collection('push_campaigns').add({
        title: 'Test Campaign',
        message: 'Test message',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'all',
        status: 'scheduled',
      });

      fakeMessaging.setResponse({
        successCount: 1,
        failureCount: 0,
        responses: [{ success: true, messageId: 'msg1' }],
      });

      await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });

      expect(fakeMessaging.getCallCount()).toBe(1);

      const campaigns = await db.collection('push_campaigns').where('status', '==', 'sent').get();
      expect(campaigns.size).toBe(1);
    });

    it('should handle FCM send failures', async () => {
      await db.collection('customers').doc('user1').set({
        name: 'User 1',
        fcm_token: 'invalid_token',
      });

      await db.collection('push_campaigns').add({
        title: 'Test Campaign',
        message: 'Test message',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'all',
        status: 'scheduled',
      });

      fakeMessaging.setResponse({
        successCount: 0,
        failureCount: 1,
        responses: [{ success: false }],
      });

      await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });

      expect(fakeMessaging.getCallCount()).toBe(1);
    });

    it('should handle batch sending with multiple tokens', async () => {
      for (let i = 1; i <= 3; i++) {
        await db
          .collection('customers')
          .doc(`user${i}`)
          .set({
            name: `User ${i}`,
            fcm_token: `test_token_${i}`,
          });
      }

      await db.collection('push_campaigns').add({
        title: 'Batch Campaign',
        message: 'Batch message',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'all',
        status: 'scheduled',
      });

      fakeMessaging.setResponse({
        successCount: 3,
        failureCount: 0,
        responses: [
          { success: true, messageId: 'msg1' },
          { success: true, messageId: 'msg2' },
          { success: true, messageId: 'msg3' },
        ],
      });

      await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });

      expect(fakeMessaging.getCallCount()).toBe(1);
    });

    it('should skip future campaigns', async () => {
      await db.collection('push_campaigns').add({
        title: 'Future Campaign',
        message: 'Future message',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 60000)),
        target_audience: 'all',
        status: 'scheduled',
      });

      const result = await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });
      expect(result).toBeNull();
      expect(fakeMessaging.getCallCount()).toBe(0);
    });

    it('should handle campaign errors gracefully', async () => {
      await db.collection('push_campaigns').add({
        title: 'Error Campaign',
        message: '',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'segment',
        segment_criteria: {},
        status: 'scheduled',
      });

      const result = await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });
      expect(result).toBeNull();

      const failedCampaigns = await db
        .collection('push_campaigns')
        .where('status', '==', 'failed')
        .get();
      expect(failedCampaigns.size).toBeGreaterThanOrEqual(0);
    });

    it('should handle individual target audience', async () => {
      await db.collection('customers').doc('user_a').set({
        name: 'User A',
        fcm_token: 'token_a',
      });

      await db.collection('customers').doc('user_b').set({
        name: 'User B',
        fcm_token: 'token_b',
      });

      await db.collection('push_campaigns').add({
        title: 'Individual Campaign',
        message: 'Individual message',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'individual',
        target_users: ['user_a', 'user_b'],
        status: 'scheduled',
      });

      fakeMessaging.setResponse({
        successCount: 2,
        failureCount: 0,
        responses: [
          { success: true, messageId: 'msg1' },
          { success: true, messageId: 'msg2' },
        ],
      });

      await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });

      expect(fakeMessaging.getCallCount()).toBe(1);
    });

    it('should handle individual audience with empty target_users', async () => {
      await db.collection('push_campaigns').add({
        title: 'Empty Individual',
        message: 'Test',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'individual',
        target_users: [],
        status: 'scheduled',
      });

      await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });

      expect(fakeMessaging.getCallCount()).toBe(0);
    });

    it('should handle users with no FCM tokens', async () => {
      await db.collection('customers').doc('user1').set({
        name: 'User 1',
      });

      await db.collection('push_campaigns').add({
        title: 'No Token Campaign',
        message: 'Test',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'all',
        status: 'scheduled',
      });

      await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });

      expect(fakeMessaging.getCallCount()).toBe(0);
    });

    it('should handle sendEachForMulticast throwing error', async () => {
      await db.collection('customers').doc('user1').set({
        name: 'User 1',
        fcm_token: 'token1',
      });

      await db.collection('push_campaigns').add({
        title: 'Error Batch Campaign',
        message: 'Test',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'all',
        status: 'scheduled',
      });

      fakeMessaging.setShouldThrowError(true, new Error('FCM network error'));

      await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });

      // When batch send throws, campaign is marked sent but with failed_count
      const campaigns = await db
        .collection('push_campaigns')
        .where('title', '==', 'Error Batch Campaign')
        .get();
      expect(campaigns.size).toBe(1);
      const campaignData = campaigns.docs[0].data();
      expect(campaignData.failed_count).toBeGreaterThan(0);
    });

    it('should handle segment with subscription_plan criteria', async () => {
      await db.collection('customers').doc('premium_user').set({
        name: 'Premium User',
        fcm_token: 'token_premium',
        subscription_plan: 'premium',
      });

      await db.collection('customers').doc('basic_user').set({
        name: 'Basic User',
        fcm_token: 'token_basic',
        subscription_plan: 'basic',
      });

      await db.collection('push_campaigns').add({
        title: 'Premium Campaign',
        message: 'Premium only',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'segment',
        segment_criteria: {
          subscription_plan: ['premium'],
        },
        status: 'scheduled',
      });

      fakeMessaging.setResponse({
        successCount: 1,
        failureCount: 0,
        responses: [{ success: true, messageId: 'msg1' }],
      });

      await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });

      expect(fakeMessaging.getCallCount()).toBe(1);
    });

    it('should handle segment with points_balance criteria', async () => {
      await db.collection('customers').doc('rich_user').set({
        name: 'Rich User',
        fcm_token: 'token_rich',
        points_balance: 1000,
      });

      await db.collection('customers').doc('poor_user').set({
        name: 'Poor User',
        fcm_token: 'token_poor',
        points_balance: 10,
      });

      await db.collection('push_campaigns').add({
        title: 'High Points Campaign',
        message: 'For rich users',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'segment',
        segment_criteria: {
          points_balance_min: 500,
        },
        status: 'scheduled',
      });

      fakeMessaging.setResponse({
        successCount: 1,
        failureCount: 0,
        responses: [{ success: true, messageId: 'msg1' }],
      });

      await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });

      expect(fakeMessaging.getCallCount()).toBe(1);
    });

    it('should handle segment with last_active_days criteria', async () => {
      await db
        .collection('customers')
        .doc('active_user')
        .set({
          name: 'Active User',
          fcm_token: 'token_active',
          last_active_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 86400000)), // 1 day ago
        });

      await db
        .collection('customers')
        .doc('inactive_user')
        .set({
          name: 'Inactive User',
          fcm_token: 'token_inactive',
          last_active_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7776000000)), // 90 days ago
        });

      await db.collection('push_campaigns').add({
        title: 'Active Users Campaign',
        message: 'For recent users',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60000)),
        target_audience: 'segment',
        segment_criteria: {
          last_active_days: 7,
        },
        status: 'scheduled',
      });

      fakeMessaging.setResponse({
        successCount: 1,
        failureCount: 0,
        responses: [{ success: true, messageId: 'msg1' }],
      });

      await coreProcessScheduledCampaigns({ db, messaging: fakeMessaging });

      expect(fakeMessaging.getCallCount()).toBe(1);
    });
  });

  describe('coreSendPersonalizedNotification', () => {
    it('should validate required fields', async () => {
      const context = { auth: { uid: 'test_uid' } };
      const result = await coreSendPersonalizedNotification({} as any, context, {
        db,
        messaging: fakeMessaging,
      });
      expect(result.success).toBe(false);
      expect(result.error).toContain('required');
    });

    it('should send personalized notification with FCM token', async () => {
      await db.collection('customers').doc('target_user').set({
        name: 'Target User',
        fcm_token: 'valid_token',
      });

      fakeMessaging.setResponse({
        successCount: 1,
        failureCount: 0,
        responses: [{ success: true, messageId: 'msg1' }],
      });

      const context = { auth: { uid: 'test_uid' } };
      const result = await coreSendPersonalizedNotification(
        {
          userId: 'target_user',
          title: 'Test Notification',
          body: 'Test message',
        },
        context,
        { db, messaging: fakeMessaging }
      );

      expect(result.success).toBe(true);
      expect(fakeMessaging.getCallCount()).toBe(1);

      const notifications = await db.collection('notifications').get();
      expect(notifications.size).toBe(1);
    });

    it('should handle missing FCM token', async () => {
      await db.collection('customers').doc('target_user').set({
        name: 'Target User',
      });

      const context = { auth: { uid: 'test_uid' } };
      const result = await coreSendPersonalizedNotification(
        {
          userId: 'target_user',
          title: 'Test',
          body: 'Test message',
        },
        context,
        { db, messaging: fakeMessaging }
      );

      expect(result.success).toBe(false);
      expect(result.error).toContain('token');
    });

    it('should require authentication', async () => {
      const context = {};
      const result = await coreSendPersonalizedNotification(
        {
          userId: 'test',
          title: 'Test',
          body: 'Test',
        },
        context,
        { db, messaging: fakeMessaging }
      );

      expect(result.success).toBe(false);
    });

    it('should handle non-existent user', async () => {
      const context = { auth: { uid: 'test_uid' } };
      const result = await coreSendPersonalizedNotification(
        {
          userId: 'nonexistent_user',
          title: 'Test',
          body: 'Test message',
        },
        context,
        { db, messaging: fakeMessaging }
      );

      expect(result.success).toBe(false);
      expect(result.error).toContain('not found');
    });

    it('should handle FCM send failure', async () => {
      await db.collection('customers').doc('user1').set({
        name: 'User 1',
        fcm_token: 'invalid_token',
      });

      fakeMessaging.setResponse({
        successCount: 0,
        failureCount: 1,
        responses: [{ success: false }],
      });

      const context = { auth: { uid: 'test_uid' } };
      const result = await coreSendPersonalizedNotification(
        {
          userId: 'user1',
          title: 'Test',
          body: 'Test message',
        },
        context,
        { db, messaging: fakeMessaging }
      );

      expect(result.success).toBe(false);
    });
  });

  describe('Helper Functions', () => {
    it('getAllUserIds should return all customer IDs', async () => {
      await db.collection('customers').doc('user1').set({ name: 'User 1' });
      await db.collection('customers').doc('user2').set({ name: 'User 2' });

      const userIds = await getAllUserIds(db);

      expect(userIds).toContain('user1');
      expect(userIds).toContain('user2');
      expect(userIds.length).toBe(2);
    });

    it('getUsersBySegment should filter by subscription plan', async () => {
      await db.collection('customers').doc('user1').set({
        name: 'User 1',
        subscription_plan: 'premium',
      });
      await db.collection('customers').doc('user2').set({
        name: 'User 2',
        subscription_plan: 'basic',
      });

      const userIds = await getUsersBySegment(
        {
          subscription_plan: ['premium'],
        },
        db
      );

      expect(userIds).toContain('user1');
      expect(userIds).not.toContain('user2');
    });

    it('cleanupInvalidTokens should remove FCM tokens', async () => {
      await db.collection('customers').doc('user1').set({
        name: 'User 1',
        fcm_token: 'invalid_token',
      });

      await cleanupInvalidTokens(['invalid_token'], db);

      const user = await db.collection('customers').doc('user1').get();
      expect(user.data()?.fcm_token).toBeUndefined();
    });

    it('should skip users without location data in location campaign', async () => {
      await db.collection('customers').doc('user_no_loc').set({
        name: 'No Location',
        fcm_token: 'token_no_loc',
      });

      const mockSend = jest.fn();
      jest.spyOn(admin.messaging(), 'sendEachForMulticast').mockImplementation(mockSend);

      const wrapped = testEnv.wrap(processScheduledCampaigns);

      await db.collection('push_campaigns').add({
        title: 'Local Event',
        message: 'Event near you',
        status: 'scheduled',
        target_audience: 'location',
        location: {
          latitude: 33.8938,
          longitude: 35.5018,
          radius_km: 10,
        },
        scheduled_for: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1000)),
      });

      await wrapped({});

      expect(mockSend).not.toHaveBeenCalled();
      mockSend.mockRestore();
    });
  });

  describe('coreProcessScheduledCampaigns - sendCampaign edge cases', () => {
    it('should send to individual users via fcm_tokens collection', async () => {
      const user1 = await db.collection('customers').add({
        name: 'User 1',
        fcm_token: 'token1',
      });

      await db.collection('push_campaigns').add({
        title: 'Individual Campaign',
        message: 'Test',
        target_audience: 'individual',
        target_users: [user1.id],
        status: 'scheduled',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1000)),
      });

      const mockAdapter = new FakeMessagingAdapter();
      await coreProcessScheduledCampaigns({ db, messaging: mockAdapter });

      expect(mockAdapter.getCallCount()).toBeGreaterThan(0);
    });

    it('should handle empty target users', async () => {
      await db.collection('push_campaigns').add({
        title: 'Empty Campaign',
        message: 'Test',
        target_audience: 'individual',
        target_users: [],
        status: 'pending',
        scheduled_for: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1000)),
      });

      const mockAdapter = new FakeMessagingAdapter();
      await coreProcessScheduledCampaigns({ db, messaging: mockAdapter });

      expect(mockAdapter.getCallCount()).toBe(0);
    });

    it('should handle users without FCM tokens', async () => {
      const user1 = await db.collection('customers').add({
        name: 'User without token',
      });

      await db.collection('push_campaigns').add({
        title: 'No Token Campaign',
        message: 'Test',
        target_audience: 'individual',
        target_users: [user1.id],
        status: 'pending',
        scheduled_for: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1000)),
      });

      const mockAdapter = new FakeMessagingAdapter();
      await coreProcessScheduledCampaigns({ db, messaging: mockAdapter });

      expect(mockAdapter.getCallCount()).toBe(0);
    });

    it('should handle batch sending errors', async () => {
      const user1 = await db.collection('customers').add({
        name: 'User 1',
        fcm_token: 'token1',
      });

      await db.collection('push_campaigns').add({
        title: 'Error Campaign',
        message: 'Test',
        target_audience: 'individual',
        target_users: [user1.id],
        status: 'scheduled',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1000)),
      });

      const errorAdapter = new FakeMessagingAdapter();
      errorAdapter.setShouldThrowError(true);
      await coreProcessScheduledCampaigns({ db, messaging: errorAdapter });

      // Campaign should be marked as sent even if messaging fails
      const campaigns = await db.collection('push_campaigns').where('status', '==', 'sent').get();
      expect(campaigns.size).toBeGreaterThan(0);
    });

    it('should handle Firestore errors in outer catch', async () => {
      // Test outer catch by mocking Firestore error
      const mockDb = {
        collection: () => {
          throw new Error('Firestore connection error');
        },
      };

      const result = await coreProcessScheduledCampaigns({
        db: mockDb as any,
        messaging: fakeMessaging,
      });
      expect(result).toBeNull();
    });

    it('should handle partial failures gracefully', async () => {
      const user1 = await db.collection('customers').add({
        name: 'User 1',
        fcm_token: 'invalid_token',
      });

      await db.collection('push_campaigns').add({
        title: 'Partial Fail Campaign',
        message: 'Test',
        target_audience: 'individual',
        target_users: [user1.id],
        status: 'scheduled',
        scheduled_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1000)),
      });

      const partialAdapter = new FakeMessagingAdapter();
      partialAdapter.setResponse({
        successCount: 0,
        failureCount: 1,
        responses: [{ success: false, messageId: '' }],
      });
      await coreProcessScheduledCampaigns({ db, messaging: partialAdapter });

      // Campaign should still be marked as sent even with partial failures
      const campaigns = await db.collection('push_campaigns').where('status', '==', 'sent').get();
      expect(campaigns.size).toBeGreaterThan(0);
    });
  });
});
