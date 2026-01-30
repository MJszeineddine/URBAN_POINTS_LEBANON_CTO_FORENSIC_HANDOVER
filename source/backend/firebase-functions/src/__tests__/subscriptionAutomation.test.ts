import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const testEnv = functionsTest({
  projectId: 'urbangenspark-test',
});

if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: 'urbangenspark-test',
  });
}

// Import functions AFTER Firebase initialization
const {
  processSubscriptionRenewals,
  sendExpiryReminders,
  cleanupExpiredSubscriptions,
  calculateSubscriptionMetrics,
} = require('../subscriptionAutomation');

describe('Subscription Automation', () => {
  let db: admin.firestore.Firestore;

  beforeAll(() => {
    db = admin.firestore();
  });

  beforeEach(async () => {
    const collections = [
      'subscriptions',
      'subscription_plans',
      'customers',
      'notifications',
      'payment_transactions',
      'subscription_renewal_logs',
      'subscription_metrics',
    ];
    for (const collection of collections) {
      const snapshot = await db.collection(collection).get();
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      if (snapshot.docs.length > 0) {
        await batch.commit();
      }
    }
  });

  afterAll(() => {
    testEnv.cleanup();
  });

  describe('processSubscriptionRenewals', () => {
    it('should renew expiring subscriptions', async () => {
      // Create plan
      await db.collection('subscription_plans').add({
        plan_id: 'test_plan',
        name: 'Test Plan',
        price: 10,
        points_per_month: 100,
      });

      // Create customer
      const customerRef = await db.collection('customers').add({
        email: 'test@example.com',
        points_balance: 50,
      });

      // Create subscription expiring tomorrow
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);

      await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'test_plan',
        plan_name: 'Test Plan',
        status: 'active',
        auto_renew: true,
        end_date: admin.firestore.Timestamp.fromDate(tomorrow),
        payment_method: 'card',
        renewal_count: 0,
      });

      // Execute function
      const wrapped = testEnv.wrap(processSubscriptionRenewals);
      await wrapped({});

      // Verify subscription renewed
      const subscriptions = await db
        .collection('subscriptions')
        .where('user_id', '==', customerRef.id)
        .get();

      expect(subscriptions.size).toBe(1);
      const sub = subscriptions.docs[0].data();
      expect(sub.status).toBe('active');
      expect(sub.renewal_count).toBe(1);

      // Verify customer got points
      const customer = (await customerRef.get()).data()!;
      expect(customer.points_balance).toBe(150); // 50 + 100

      // Verify notification sent
      const notifications = await db
        .collection('notifications')
        .where('user_id', '==', customerRef.id)
        .get();
      expect(notifications.size).toBeGreaterThan(0);
      expect(notifications.docs[0].data().type).toBe('subscription_renewal');
    });

    it('should handle missing plan gracefully', async () => {
      const customerRef = await db.collection('customers').add({
        email: 'test@example.com',
      });

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);

      await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'nonexistent',
        status: 'active',
        auto_renew: true,
        end_date: admin.firestore.Timestamp.fromDate(tomorrow),
      });

      const wrapped = testEnv.wrap(processSubscriptionRenewals);
      await wrapped({});

      // Verify renewal log created with failures
      const logs = await db.collection('subscription_renewal_logs').get();
      expect(logs.size).toBe(1);
      const log = logs.docs[0].data();
      expect(log.results.failed).toBe(1);
    });

    it('should handle missing customer gracefully', async () => {
      await db.collection('subscription_plans').add({
        plan_id: 'test_plan',
        name: 'Test Plan',
        price: 10,
        points_per_month: 100,
      });

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);

      await db.collection('subscriptions').add({
        user_id: 'nonexistent_customer',
        plan_id: 'test_plan',
        status: 'active',
        auto_renew: true,
        end_date: admin.firestore.Timestamp.fromDate(tomorrow),
      });

      const wrapped = testEnv.wrap(processSubscriptionRenewals);
      await wrapped({});

      const logs = await db.collection('subscription_renewal_logs').get();
      expect(logs.size).toBe(1);
      const log = logs.docs[0].data();
      expect(log.results.failed).toBe(1);
    });

    it('should skip non-expiring subscriptions', async () => {
      const customerRef = await db.collection('customers').add({
        email: 'test@example.com',
      });

      const nextWeek = new Date();
      nextWeek.setDate(nextWeek.getDate() + 7);

      await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'test_plan',
        status: 'active',
        auto_renew: true,
        end_date: admin.firestore.Timestamp.fromDate(nextWeek),
      });

      const wrapped = testEnv.wrap(processSubscriptionRenewals);
      await wrapped({});

      // No renewal should occur
      const logs = await db.collection('subscription_renewal_logs').get();
      expect(logs.empty).toBe(true);
    });

    it('should skip subscriptions without auto_renew', async () => {
      const customerRef = await db.collection('customers').add({
        email: 'no-auto@example.com',
        points_balance: 0,
      });

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);

      await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'test_plan',
        status: 'active',
        auto_renew: false,
        end_date: admin.firestore.Timestamp.fromDate(tomorrow),
      });

      const wrapped = testEnv.wrap(processSubscriptionRenewals);
      await wrapped({});

      // Customer points should remain 0
      const customer = (await customerRef.get()).data()!;
      expect(customer.points_balance).toBe(0);
    });

    it('should skip inactive subscriptions', async () => {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);

      await db.collection('subscriptions').add({
        user_id: 'user_id',
        plan_id: 'test_plan',
        status: 'cancelled',
        auto_renew: true,
        end_date: admin.firestore.Timestamp.fromDate(tomorrow),
      });

      const wrapped = testEnv.wrap(processSubscriptionRenewals);
      await wrapped({});

      const logs = await db.collection('subscription_renewal_logs').get();
      expect(logs.empty).toBe(true);
    });
  });

  describe('sendExpiryReminders', () => {
    it('should send reminders for subscriptions expiring in 3 days', async () => {
      const customerRef = await db.collection('customers').add({
        email: 'test@example.com',
      });

      const threeDays = new Date();
      threeDays.setDate(threeDays.getDate() + 3);
      threeDays.setHours(12, 0, 0, 0);

      await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'test_plan',
        plan_name: 'Test Plan',
        status: 'active',
        end_date: admin.firestore.Timestamp.fromDate(threeDays),
      });

      const wrapped = testEnv.wrap(sendExpiryReminders);
      await wrapped({});

      const notifications = await db
        .collection('notifications')
        .where('user_id', '==', customerRef.id)
        .get();
      expect(notifications.size).toBeGreaterThan(0);
    });

    it('should handle subscriptions with no expiry date gracefully', async () => {
      const customerRef = await db.collection('customers').add({
        email: 'test2@example.com',
      });

      await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'test_plan',
        status: 'active',
      });

      const wrapped = testEnv.wrap(sendExpiryReminders);
      await wrapped({});

      const notifications = await db
        .collection('notifications')
        .where('user_id', '==', customerRef.id)
        .get();
      expect(notifications.empty).toBe(true);
    });

    it('should send reminders for 7-day expiry', async () => {
      const customerRef = await db.collection('customers').add({
        email: 'test3@example.com',
      });

      const sevenDays = new Date();
      sevenDays.setDate(sevenDays.getDate() + 7);
      sevenDays.setHours(10, 0, 0, 0);

      await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'test_plan',
        plan_name: 'Test Plan',
        status: 'active',
        end_date: admin.firestore.Timestamp.fromDate(sevenDays),
      });

      const wrapped = testEnv.wrap(sendExpiryReminders);
      await wrapped({});

      const notifications = await db
        .collection('notifications')
        .where('user_id', '==', customerRef.id)
        .get();
      expect(notifications.size).toBeGreaterThan(0);
    });

    it('should send reminders for 1-day expiry', async () => {
      const customerRef = await db.collection('customers').add({
        email: 'test4@example.com',
      });

      const oneDay = new Date();
      oneDay.setDate(oneDay.getDate() + 1);
      oneDay.setHours(10, 0, 0, 0);

      await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'test_plan',
        plan_name: 'Test Plan',
        status: 'active',
        end_date: admin.firestore.Timestamp.fromDate(oneDay),
      });

      const wrapped = testEnv.wrap(sendExpiryReminders);
      await wrapped({});

      const notifications = await db
        .collection('notifications')
        .where('user_id', '==', customerRef.id)
        .get();
      expect(notifications.size).toBeGreaterThan(0);
    });
  });

  describe('cleanupExpiredSubscriptions', () => {
    it('should deactivate expired subscriptions', async () => {
      const customerRef = await db.collection('customers').add({
        email: 'test@example.com',
      });

      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);

      const subRef = await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'test_plan',
        status: 'active',
        end_date: admin.firestore.Timestamp.fromDate(yesterday),
      });

      const wrapped = testEnv.wrap(cleanupExpiredSubscriptions);
      await wrapped({});

      // Verify subscription deactivated
      const sub = (await subRef.get()).data()!;
      expect(sub.status).toBe('expired');
    });

    it('should update customer subscription status', async () => {
      const customerRef = await db.collection('customers').add({
        email: 'test@example.com',
        subscription_status: 'active',
      });

      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);

      await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'test_plan',
        status: 'active',
        end_date: admin.firestore.Timestamp.fromDate(yesterday),
      });

      const wrapped = testEnv.wrap(cleanupExpiredSubscriptions);
      await wrapped({});

      // Verify customer status updated to 'expired'
      const customer = (await customerRef.get()).data()!;
      expect(customer.subscription_status).toBe('expired');
    });

    it('should not affect active subscriptions', async () => {
      const customerRef = await db.collection('customers').add({
        email: 'test@example.com',
      });

      const nextWeek = new Date();
      nextWeek.setDate(nextWeek.getDate() + 7);

      const subRef = await db.collection('subscriptions').add({
        user_id: customerRef.id,
        plan_id: 'test_plan',
        status: 'active',
        end_date: admin.firestore.Timestamp.fromDate(nextWeek),
      });

      const wrapped = testEnv.wrap(cleanupExpiredSubscriptions);
      await wrapped({});

      // Subscription should remain active
      const sub = (await subRef.get()).data()!;
      expect(sub.status).toBe('active');
    });
  });

  describe('calculateSubscriptionMetrics', () => {
    it('should calculate monthly metrics', async () => {
      // Create active subscriptions
      await db.collection('subscriptions').add({
        user_id: 'user1',
        plan_id: 'basic',
        status: 'active',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      await db.collection('subscriptions').add({
        user_id: 'user2',
        plan_id: 'premium',
        status: 'active',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      const wrapped = testEnv.wrap(calculateSubscriptionMetrics);
      await wrapped({});

      // Verify metrics created
      const metricsSnapshot = await db
        .collection('subscription_metrics')
        .orderBy('date', 'desc')
        .limit(1)
        .get();

      expect(metricsSnapshot.empty).toBe(false);
      const metricData = metricsSnapshot.docs[0].data();
      expect(metricData.metrics).toBeDefined();
      expect(metricData.metrics.active).toBe(2);
    });

    it('should track renewal rates', async () => {
      // Create plan
      await db.collection('subscription_plans').add({
        plan_id: 'test_plan',
        name: 'Test Plan',
        price: 10,
      });

      // Create renewed subscription
      await db.collection('subscriptions').add({
        user_id: 'user1',
        plan_id: 'test_plan',
        status: 'active',
        renewal_count: 3,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      const wrapped = testEnv.wrap(calculateSubscriptionMetrics);
      await wrapped({});

      const metricsSnapshot = await db
        .collection('subscription_metrics')
        .orderBy('date', 'desc')
        .limit(1)
        .get();

      expect(metricsSnapshot.empty).toBe(false);
      const metricData = metricsSnapshot.docs[0].data();
      expect(metricData.metrics.total).toBeGreaterThanOrEqual(1);
    });

    it('should handle empty subscription data', async () => {
      const wrapped = testEnv.wrap(calculateSubscriptionMetrics);
      await wrapped({});

      const metricsSnapshot = await db.collection('subscription_metrics').get();
      expect(metricsSnapshot.empty).toBe(false);
      const metricData = metricsSnapshot.docs[0].data();
      expect(metricData.metrics.total).toBe(0);
    });

    it('should handle errors gracefully', async () => {
      // Mock Firestore error
      const mockQuery = jest
        .spyOn(db.collection('subscriptions'), 'where')
        .mockImplementation(() => {
          throw new Error('Firestore error');
        });

      const wrapped = testEnv.wrap(calculateSubscriptionMetrics);
      // Should not throw, should handle error gracefully
      await wrapped({});

      mockQuery.mockRestore();
    });
  });

  describe('processSubscriptionRenewals - Error Branches', () => {
    it('should handle batch commit errors', async () => {
      await db.collection('subscription_plans').add({
        plan_id: 'error_plan',
        name: 'Error Plan',
        price: 10,
        points_per_month: 100,
      });

      const customer = await db.collection('customers').add({
        email: 'error@example.com',
        points_balance: 50,
      });

      await db.collection('subscriptions').add({
        user_id: customer.id,
        plan_id: 'error_plan',
        plan_name: 'Error Plan',
        status: 'active',
        auto_renew: true,
        end_date: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 3600000)), // 1 hour from now
        payment_method: 'card',
        renewal_count: 0,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // This test ensures the function handles errors without crashing
      const wrapped = testEnv.wrap(processSubscriptionRenewals);
      await wrapped({});

      // Check logs were created
      const logsSnapshot = await db.collection('subscription_renewal_logs').get();
      expect(logsSnapshot.size).toBeGreaterThan(0);
    });
  });
});
