import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import {
  coreCalculateDailyStats,
  coreApproveOffer,
  coreRejectOffer,
  coreGetMerchantComplianceStatus,
  coreCheckMerchantCompliance,
} from '../core/admin';

const testEnv = functionsTest({ projectId: 'urbangenspark-test' }, undefined);

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'urbangenspark-test' });
}

describe('Core Admin Functions', () => {
  let db: admin.firestore.Firestore;

  beforeAll(() => {
    db = admin.firestore();
  });

  beforeEach(async () => {
    const collections = ['redemptions', 'offers', 'merchants', 'admins'];
    for (const coll of collections) {
      const snap = await db.collection(coll).get();
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      if (snap.docs.length > 0) await batch.commit();
    }

    // Create admin user for tests
    await db.collection('admins').doc('admin1').set({
      email: 'admin@test.com',
      role: 'admin',
    });
  });

  afterAll(() => testEnv.cleanup());

  describe('coreCalculateDailyStats', () => {
    it('should calculate daily stats', async () => {
      await db.collection('redemptions').add({
        user_id: 'user1',
        merchant_id: 'merchant1',
        points_cost: 100,
        redeemed_at: admin.firestore.Timestamp.now(),
      });

      const mockContext = { auth: { uid: 'admin1', token: {} } } as any;
      const result = await coreCalculateDailyStats({}, mockContext, { db });

      expect(result.success).toBe(true);
      expect(result.stats?.totalRedemptions).toBe(1);
      expect(result.stats?.totalPointsRedeemed).toBe(100);
    });

    it('should return zero stats for empty data', async () => {
      const mockContext = { auth: { uid: 'admin1', token: {} } } as any;
      const result = await coreCalculateDailyStats({ date: '2020-01-01' }, mockContext, { db });

      expect(result.success).toBe(true);
      expect(result.stats?.totalRedemptions).toBe(0);
    });
  });

  describe('coreApproveOffer', () => {
    it('should approve offer', async () => {
      const offerRef = await db.collection('offers').add({
        title: 'Test Offer',
        status: 'pending',
        is_active: false,
      });

      const mockContext = { auth: { uid: 'admin1', token: {} } } as any;
      const result = await coreApproveOffer({ offerId: offerRef.id }, mockContext, { db });

      expect(result.success).toBe(true);

      const offer = await offerRef.get();
      expect(offer.data()?.status).toBe('approved');
      expect(offer.data()?.is_active).toBe(true);
    });

    it('should reject invalid offerId', async () => {
      const mockContext = { auth: { uid: 'admin1', token: {} } } as any;
      const result = await coreApproveOffer({ offerId: 'invalid' }, mockContext, { db });

      expect(result.success).toBe(false);
      expect(result.error).toBe('Offer not found');
    });
  });

  describe('coreRejectOffer', () => {
    it('should reject offer', async () => {
      const offerRef = await db.collection('offers').add({
        title: 'Test Offer',
        status: 'pending',
      });

      const mockContext = { auth: { uid: 'admin1', token: {} } } as any;
      const result = await coreRejectOffer(
        { offerId: offerRef.id, reason: 'Test reason' },
        mockContext,
        { db }
      );

      expect(result.success).toBe(true);

      const offer = await offerRef.get();
      expect(offer.data()?.status).toBe('rejected');
      expect(offer.data()?.rejection_reason).toBe('Test reason');
    });
  });

  describe('coreGetMerchantComplianceStatus', () => {
    it('should get merchant compliance', async () => {
      await db.collection('merchants').doc('m1').set({
        name: 'Merchant 1',
        offers_created_this_month: 5,
        compliance_status: 'compliant',
      });

      const result = await coreGetMerchantComplianceStatus({ db });

      expect(result.success).toBe(true);
      expect(result.merchants?.length).toBeGreaterThan(0);
    });
  });

  describe('coreCheckMerchantCompliance', () => {
    it('should check merchant compliance', async () => {
      await db.collection('merchants').doc('m1').set({
        name: 'Merchant 1',
      });

      await db.collection('offers').add({
        merchant_id: 'm1',
        created_at: admin.firestore.Timestamp.now(),
      });

      const result = await coreCheckMerchantCompliance({ db });

      expect(result.success).toBe(true);
      expect(result.results).toBeDefined();
    });
  });
});
