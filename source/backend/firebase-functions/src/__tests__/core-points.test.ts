import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import { coreAwardPoints } from '../core/points';

const testEnv = functionsTest({ projectId: 'urbangenspark-test' }, undefined);

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'urbangenspark-test' });
}

describe('Core Points Functions', () => {
  let db: admin.firestore.Firestore;

  beforeAll(() => {
    db = admin.firestore();
  });

  beforeEach(async () => {
    const collections = ['customers', 'redemptions'];
    for (const coll of collections) {
      const snap = await db.collection(coll).get();
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      if (snap.docs.length > 0) await batch.commit();
    }
  });

  afterAll(() => testEnv.cleanup());

  describe('coreAwardPoints', () => {
    it('should award points to customer', async () => {
      await db.collection('customers').doc('cust1').set({
        name: 'Customer 1',
        points_balance: 100,
      });

      const mockContext = { auth: { uid: 'merchant1', token: {} } } as any;
      const result = await coreAwardPoints(
        {
          customerId: 'cust1',
          offerId: 'offer1',
          merchantId: 'merchant1',
          pointsAmount: 50,
        },
        mockContext,
        { db }
      );

      expect(result.success).toBe(true);
      expect(result.newBalance).toBe(150);

      const customer = await db.collection('customers').doc('cust1').get();
      expect(customer.data()?.points_balance).toBe(150);
    });

    it('should reject missing customer', async () => {
      const mockContext = { auth: { uid: 'merchant1', token: {} } } as any;
      const result = await coreAwardPoints(
        {
          customerId: 'invalid',
          offerId: 'offer1',
          merchantId: 'merchant1',
          pointsAmount: 50,
        },
        mockContext,
        { db }
      );

      expect(result.success).toBe(false);
      expect(result.error).toBe('Customer not found');
    });

    it('should reject negative points', async () => {
      await db.collection('customers').doc('cust1').set({
        points_balance: 100,
      });

      const mockContext = { auth: { uid: 'merchant1', token: {} } } as any;
      const result = await coreAwardPoints(
        {
          customerId: 'cust1',
          offerId: 'offer1',
          merchantId: 'merchant1',
          pointsAmount: -50,
        },
        mockContext,
        { db }
      );

      expect(result.success).toBe(false);
      expect(result.error).toContain('negative');
    });
  });
});
