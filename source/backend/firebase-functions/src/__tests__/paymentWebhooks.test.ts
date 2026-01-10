/**
 * Payment Webhooks Tests
 * Tests for OMT, Whish Money, and Card payment webhook handlers
 */

import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import * as crypto from 'crypto';
import {
  omtWebhookCore,
  whishWebhookCore,
  cardWebhookCore,
  processSuccessfulPayment,
  processFailedPayment,
} from '../paymentWebhooks';

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

describe('Payment Webhooks', () => {
  let db: admin.firestore.Firestore;

  beforeAll(() => {
    db = admin.firestore();
  });

  beforeEach(async () => {
    // Clean up collections
    const collections = ['payment_webhooks', 'payment_transactions', 'subscriptions', 'customers'];
    for (const collectionName of collections) {
      const snapshot = await db.collection(collectionName).get();
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  describe('OMT Webhook Core', () => {
    const validSecret = 'test-omt-secret';

    function createSignedPayload(data: any, secret: string): any {
      const signature = crypto
        .createHmac('sha256', secret)
        .update(JSON.stringify(data))
        .digest('hex');
      return { ...data, signature };
    }

    it('should reject non-POST requests', async () => {
      const result = await omtWebhookCore('GET', {});
      expect(result.status).toBe(405);
      expect(result.message).toBe('Method not allowed');
    });

    it('should reject invalid signature', async () => {
      const payload = {
        transactionId: 'omt_123',
        status: 'completed' as const,
        amount: 100,
        currency: 'USD',
        paymentMethod: 'omt',
        timestamp: Date.now(),
        signature: 'invalid_signature',
      };

      const result = await omtWebhookCore('POST', payload, validSecret);
      expect(result.status).toBe(401);
      expect(result.message).toBe('Invalid signature');
    });

    it('should process valid completed payment', async () => {
      const payload = createSignedPayload(
        {
          transactionId: 'omt_456',
          status: 'completed',
          amount: 100,
          currency: 'USD',
          paymentMethod: 'omt',
          timestamp: Date.now(),
        },
        validSecret
      );

      // Create pending transaction
      await db.collection('payment_transactions').add({
        transaction_id: 'omt_456',
        status: 'pending',
        user_id: 'user_123',
        amount: 100,
        subscription_plan_id: 'points_purchase',
      });

      // Create customer for points purchase
      await db.collection('customers').doc('user_123').set({
        name: 'Test User',
        points_balance: 0,
      });

      const result = await omtWebhookCore('POST', payload, validSecret);
      expect(result.status).toBe(200);
      expect(result.message).toBe('Webhook processed');

      // Verify webhook was logged
      const webhooks = await db
        .collection('payment_webhooks')
        .where('transaction_id', '==', 'omt_456')
        .get();
      expect(webhooks.empty).toBe(false);
    });

    it('should handle duplicate webhooks', async () => {
      const payload = createSignedPayload(
        {
          transactionId: 'omt_789',
          status: 'completed',
          amount: 100,
          currency: 'USD',
          paymentMethod: 'omt',
          timestamp: Date.now(),
        },
        validSecret
      );

      // Log webhook first time
      await db.collection('payment_webhooks').add({
        transaction_id: 'omt_789',
        payment_method: 'omt',
        status: 'completed',
        amount: 100,
        currency: 'USD',
      });

      // Try to process again
      const result = await omtWebhookCore('POST', payload, validSecret);
      expect(result.status).toBe(200);
      expect(result.message).toBe('Already processed');
    });

    it('should process failed payment', async () => {
      const payload = createSignedPayload(
        {
          transactionId: 'omt_fail_999',
          status: 'failed',
          amount: 100,
          currency: 'USD',
          paymentMethod: 'omt',
          timestamp: Date.now(),
        },
        validSecret
      );

      await db.collection('payment_transactions').add({
        transaction_id: 'omt_fail_999',
        status: 'pending',
        user_id: 'user_fail',
        amount: 100,
      });

      const result = await omtWebhookCore('POST', payload, validSecret);
      expect(result.status).toBe(200);

      // Verify transaction marked as failed
      const txns = await db
        .collection('payment_transactions')
        .where('transaction_id', '==', 'omt_fail_999')
        .get();
      expect(txns.docs[0].data().status).toBe('failed');
    });
  });

  describe('Whish Webhook Core', () => {
    const validSecret = 'test-whish-secret';

    function createSignedPayload(data: any, secret: string): any {
      const signature = crypto
        .createHmac('sha256', secret)
        .update(JSON.stringify(data))
        .digest('hex');
      return { ...data, signature };
    }

    it('should reject non-POST requests', async () => {
      const result = await whishWebhookCore('GET', {}, validSecret);
      expect(result.status).toBe(405);
      expect(result.message).toBe('Method not allowed');
    });

    it('should reject invalid signature', async () => {
      const payload = {
        transactionId: 'whish_bad',
        status: 'completed' as const,
        amount: 50,
        currency: 'USD',
        paymentMethod: 'whish',
        timestamp: Date.now(),
        signature: 'invalid_sig',
      };

      const result = await whishWebhookCore('POST', payload, validSecret);
      expect(result.status).toBe(401);
      expect(result.message).toBe('Invalid signature');
    });

    it('should handle duplicate webhooks', async () => {
      const payload = createSignedPayload(
        {
          transactionId: 'whish_dup',
          status: 'completed',
          amount: 50,
          currency: 'USD',
          paymentMethod: 'whish',
          timestamp: Date.now(),
        },
        validSecret
      );

      await db.collection('payment_webhooks').add({
        transaction_id: 'whish_dup',
        payment_method: 'whish',
        status: 'completed',
        amount: 50,
        currency: 'USD',
      });

      const result = await whishWebhookCore('POST', payload, validSecret);
      expect(result.status).toBe(200);
      expect(result.message).toBe('Already processed');
    });

    it('should process valid whish payment', async () => {
      const payload = createSignedPayload(
        {
          transactionId: 'whish_123',
          status: 'completed',
          amount: 50,
          currency: 'USD',
          paymentMethod: 'whish',
          timestamp: Date.now(),
        },
        validSecret
      );

      await db.collection('payment_transactions').add({
        transaction_id: 'whish_123',
        status: 'pending',
        user_id: 'user_456',
        amount: 50,
        subscription_plan_id: 'points_purchase',
      });

      await db.collection('customers').doc('user_456').set({
        name: 'Whish User',
        points_balance: 0,
      });

      const result = await whishWebhookCore('POST', payload, validSecret);
      expect(result.status).toBe(200);
    });
  });

  describe('Card Webhook Core', () => {
    const validSecret = 'test-card-secret';

    function createSignedPayload(data: any, secret: string): any {
      const signature = crypto
        .createHmac('sha256', secret)
        .update(JSON.stringify(data))
        .digest('hex');
      return { ...data, signature };
    }

    it('should reject non-POST requests', async () => {
      const result = await cardWebhookCore('GET', {}, validSecret);
      expect(result.status).toBe(405);
      expect(result.message).toBe('Method not allowed');
    });

    it('should reject invalid signature', async () => {
      const payload = {
        transactionId: 'card_bad',
        status: 'completed' as const,
        amount: 75,
        currency: 'USD',
        paymentMethod: 'card',
        timestamp: Date.now(),
        signature: 'bad_signature',
      };

      const result = await cardWebhookCore('POST', payload, validSecret);
      expect(result.status).toBe(401);
      expect(result.message).toBe('Invalid signature');
    });

    it('should handle duplicate webhooks', async () => {
      const payload = createSignedPayload(
        {
          transactionId: 'card_dup',
          status: 'completed',
          amount: 75,
          currency: 'USD',
          paymentMethod: 'card',
          timestamp: Date.now(),
        },
        validSecret
      );

      await db.collection('payment_webhooks').add({
        transaction_id: 'card_dup',
        payment_method: 'card',
        status: 'completed',
        amount: 75,
        currency: 'USD',
      });

      const result = await cardWebhookCore('POST', payload, validSecret);
      expect(result.status).toBe(200);
      expect(result.message).toBe('Already processed');
    });

    it('should process valid card payment', async () => {
      const payload = createSignedPayload(
        {
          transactionId: 'card_123',
          status: 'completed',
          amount: 75,
          currency: 'USD',
          paymentMethod: 'card',
          timestamp: Date.now(),
        },
        validSecret
      );

      await db.collection('payment_transactions').add({
        transaction_id: 'card_123',
        status: 'pending',
        user_id: 'user_789',
        amount: 75,
        subscription_plan_id: 'points_purchase',
      });

      await db.collection('customers').doc('user_789').set({
        name: 'Card User',
        points_balance: 0,
      });

      const result = await cardWebhookCore('POST', payload, validSecret);
      expect(result.status).toBe(200);
    });
  });

  describe('Process Successful Payment', () => {
    it('should activate subscription for subscription payment', async () => {
      const transactionDoc = await db.collection('payment_transactions').add({
        transaction_id: 'txn_sub_123',
        status: 'pending',
        user_id: 'user_sub_123',
        amount: 50,
        subscription_plan_id: 'premium_plan',
      });

      await db.collection('customers').doc('user_sub_123').set({
        name: 'Subscription User',
        points_balance: 100,
      });

      await processSuccessfulPayment(
        {
          transactionId: 'txn_sub_123',
          status: 'completed',
          amount: 50,
          currency: 'USD',
          paymentMethod: 'card',
          timestamp: Date.now(),
        },
        'card'
      );

      // Verify transaction updated
      const transaction = await transactionDoc.get();
      expect(transaction.data()?.status).toBe('completed');

      // Verify subscription created
      const subscriptions = await db
        .collection('subscriptions')
        .where('user_id', '==', 'user_sub_123')
        .get();
      expect(subscriptions.empty).toBe(false);

      // Verify customer updated
      const customer = await db.collection('customers').doc('user_sub_123').get();
      expect(customer.data()?.subscription_plan).toBe('premium_plan');
    });

    it('should add points for points purchase', async () => {
      await db.collection('payment_transactions').add({
        transaction_id: 'txn_points_123',
        status: 'pending',
        user_id: 'user_points_123',
        amount: 10,
        subscription_plan_id: 'points_purchase',
      });

      await db.collection('customers').doc('user_points_123').set({
        name: 'Points User',
        points_balance: 50,
      });

      await processSuccessfulPayment(
        {
          transactionId: 'txn_points_123',
          status: 'completed',
          amount: 10,
          currency: 'USD',
          paymentMethod: 'card',
          timestamp: Date.now(),
        },
        'card'
      );

      // Verify points added (10 points per dollar = 100 points)
      const customer = await db.collection('customers').doc('user_points_123').get();
      expect(customer.data()?.points_balance).toBe(150);
    });

    it('should handle missing transaction for successful payment', async () => {
      await processSuccessfulPayment(
        {
          transactionId: 'missing_txn',
          status: 'completed',
          amount: 50,
          currency: 'USD',
          paymentMethod: 'card',
          timestamp: Date.now(),
        },
        'card'
      );

      const txns = await db
        .collection('payment_transactions')
        .where('transaction_id', '==', 'missing_txn')
        .get();
      expect(txns.empty).toBe(true);
    });

    it('should handle missing customer for points purchase', async () => {
      await db.collection('payment_transactions').add({
        transaction_id: 'txn_no_cust',
        status: 'pending',
        user_id: 'missing_customer',
        amount: 10,
        subscription_plan_id: 'points_purchase',
      });

      await db.collection('customers').doc('missing_customer').set({
        name: 'Created Customer',
        points_balance: 0,
      });

      await processSuccessfulPayment(
        {
          transactionId: 'txn_no_cust',
          status: 'completed',
          amount: 10,
          currency: 'USD',
          paymentMethod: 'card',
          timestamp: Date.now(),
        },
        'card'
      );

      const customer = await db.collection('customers').doc('missing_customer').get();
      expect(customer.data()?.points_balance).toBe(100);
    });
  });

  describe('Process Failed Payment', () => {
    it('should mark transaction as failed', async () => {
      const transactionDoc = await db.collection('payment_transactions').add({
        transaction_id: 'txn_fail_123',
        status: 'pending',
        user_id: 'user_fail_123',
        amount: 100,
      });

      await processFailedPayment(
        {
          transactionId: 'txn_fail_123',
          status: 'failed',
          amount: 100,
          currency: 'USD',
          paymentMethod: 'card',
          timestamp: Date.now(),
        },
        'card'
      );

      // Verify transaction marked as failed
      const transaction = await transactionDoc.get();
      expect(transaction.data()?.status).toBe('failed');
    });

    it('should handle missing transaction for failed payment', async () => {
      await processFailedPayment(
        {
          transactionId: 'nonexistent_txn',
          status: 'failed',
          amount: 100,
          currency: 'USD',
          paymentMethod: 'card',
          timestamp: Date.now(),
        },
        'card'
      );

      const txns = await db
        .collection('payment_transactions')
        .where('transaction_id', '==', 'nonexistent_txn')
        .get();
      expect(txns.empty).toBe(true);
    });

    it('should handle Firestore errors in failed payment', async () => {
      await db.collection('payment_transactions').add({
        transaction_id: 'txn_error',
        status: 'pending',
        user_id: 'user_id',
        amount: 100,
      });

      const mockUpdate = jest
        .spyOn(admin.firestore.DocumentReference.prototype, 'update')
        .mockRejectedValueOnce(new Error('Firestore error'));

      await expect(
        processFailedPayment(
          {
            transactionId: 'txn_error',
            status: 'failed',
            amount: 100,
            currency: 'USD',
            paymentMethod: 'card',
            timestamp: Date.now(),
          },
          'card'
        )
      ).rejects.toThrow('Firestore error');

      mockUpdate.mockRestore();
    });
  });

  describe('Process Successful Payment Error Paths', () => {
    it('should handle Firestore transaction update errors', async () => {
      await db.collection('payment_transactions').add({
        transaction_id: 'txn_update_fail',
        status: 'pending',
        user_id: 'user_id',
        amount: 100,
        subscription_plan_id: 'test_plan',
      });

      const mockUpdate = jest
        .spyOn(admin.firestore.DocumentReference.prototype, 'update')
        .mockRejectedValueOnce(new Error('Update failed'));

      await expect(
        processSuccessfulPayment(
          {
            transactionId: 'txn_update_fail',
            status: 'completed',
            amount: 100,
            currency: 'USD',
            paymentMethod: 'card',
            timestamp: Date.now(),
          },
          'card'
        )
      ).rejects.toThrow('Update failed');

      mockUpdate.mockRestore();
    });

    it('should handle subscription creation errors', async () => {
      await db.collection('payment_transactions').add({
        transaction_id: 'txn_sub_error',
        status: 'pending',
        user_id: 'user_sub_error',
        amount: 50,
        subscription_plan_id: 'premium_plan',
      });

      await db.collection('customers').doc('user_sub_error').set({
        name: 'Test User',
        points_balance: 0,
      });

      const mockAdd = jest
        .spyOn(admin.firestore.CollectionReference.prototype, 'add')
        .mockRejectedValueOnce(new Error('Subscription creation failed'));

      await expect(
        processSuccessfulPayment(
          {
            transactionId: 'txn_sub_error',
            status: 'completed',
            amount: 50,
            currency: 'USD',
            paymentMethod: 'card',
            timestamp: Date.now(),
          },
          'card'
        )
      ).rejects.toThrow('Subscription creation failed');

      mockAdd.mockRestore();
    });

    it('should handle points increment errors', async () => {
      await db.collection('payment_transactions').add({
        transaction_id: 'txn_points_error',
        status: 'pending',
        user_id: 'user_points_error',
        amount: 10,
        subscription_plan_id: 'points_purchase',
      });

      await db.collection('customers').doc('user_points_error').set({
        name: 'Test User',
        points_balance: 50,
      });

      const mockUpdate = jest
        .spyOn(admin.firestore.DocumentReference.prototype, 'update')
        .mockResolvedValueOnce({} as any) // First update for transaction succeeds
        .mockRejectedValueOnce(new Error('Points update failed')); // Second update for points fails

      await expect(
        processSuccessfulPayment(
          {
            transactionId: 'txn_points_error',
            status: 'completed',
            amount: 10,
            currency: 'USD',
            paymentMethod: 'card',
            timestamp: Date.now(),
          },
          'card'
        )
      ).rejects.toThrow('Points update failed');

      mockUpdate.mockRestore();
    });
  });

  describe('Firebase Functions Wrappers', () => {
    it('should test omtWebhook wrapper exists', () => {
      const { omtWebhook } = require('../paymentWebhooks');
      expect(omtWebhook).toBeDefined();
    });

    it('should test whishWebhook wrapper exists', () => {
      const { whishWebhook } = require('../paymentWebhooks');
      expect(whishWebhook).toBeDefined();
    });

    it('should test cardWebhook wrapper exists', () => {
      const { cardWebhook } = require('../paymentWebhooks');
      expect(cardWebhook).toBeDefined();
    });
  });
});
