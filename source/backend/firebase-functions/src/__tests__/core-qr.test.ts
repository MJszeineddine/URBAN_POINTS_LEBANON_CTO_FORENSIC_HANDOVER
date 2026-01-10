import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import { coreGenerateSecureQRToken } from '../core/qr';

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

describe('Core QR Functions', () => {
  let db: admin.firestore.Firestore;

  beforeAll(() => {
    db = admin.firestore();
  });

  beforeEach(async () => {
    const collections = [
      'customers',
      'offers',
      'merchants',
      'rate_limits',
      'redemptions',
      'qr_tokens',
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

  describe('coreGenerateSecureQRToken', () => {
    it('should generate token for valid request', async () => {
      await db
        .collection('customers')
        .doc('user1')
        .set({
          name: 'User 1',
          subscription_status: 'active',
          subscription_expiry: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)),
        });

      await db.collection('offers').doc('offer1').set({
        title: 'Test Offer',
        is_active: true,
        points_cost: 100,
      });

      await db.collection('merchants').doc('merchant1').set({
        name: 'Test Merchant',
      });

      const result = await coreGenerateSecureQRToken(
        {
          userId: 'user1',
          offerId: 'offer1',
          merchantId: 'merchant1',
          deviceHash: 'device1',
        },
        {
          auth: { uid: 'user1' },
        },
        {
          db,
          secret: 'test-secret',
        }
      );

      expect(result.success).toBe(true);
      expect(result.token).toBeDefined();
      expect(result.displayCode).toBeDefined();
    });

    it('should reject unauthenticated requests', async () => {
      const result = await coreGenerateSecureQRToken(
        {
          userId: 'user1',
          offerId: 'offer1',
          merchantId: 'merchant1',
          deviceHash: 'device1',
        },
        {},
        {
          db,
          secret: 'test-secret',
        }
      );

      expect(result.success).toBe(false);
      expect(result.error).toBe('Unauthenticated');
    });

    it('should reject user mismatch', async () => {
      const result = await coreGenerateSecureQRToken(
        {
          userId: 'user1',
          offerId: 'offer1',
          merchantId: 'merchant1',
          deviceHash: 'device1',
        },
        {
          auth: { uid: 'user2' },
        },
        {
          db,
          secret: 'test-secret',
        }
      );

      expect(result.success).toBe(false);
      expect(result.error).toBe('User mismatch');
    });

    it('should reject missing customer', async () => {
      const result = await coreGenerateSecureQRToken(
        {
          userId: 'user1',
          offerId: 'offer1',
          merchantId: 'merchant1',
          deviceHash: 'device1',
        },
        {
          auth: { uid: 'user1' },
        },
        {
          db,
          secret: 'test-secret',
        }
      );

      expect(result.success).toBe(false);
      expect(result.error).toBe('Customer not found');
    });

    it('should reject inactive subscription', async () => {
      await db.collection('customers').doc('user1').set({
        name: 'User 1',
        subscription_status: 'inactive',
      });

      const result = await coreGenerateSecureQRToken(
        {
          userId: 'user1',
          offerId: 'offer1',
          merchantId: 'merchant1',
          deviceHash: 'device1',
        },
        {
          auth: { uid: 'user1' },
        },
        {
          db,
          secret: 'test-secret',
        }
      );

      expect(result.success).toBe(false);
      expect(result.error).toContain('subscription');
    });
  });
});
