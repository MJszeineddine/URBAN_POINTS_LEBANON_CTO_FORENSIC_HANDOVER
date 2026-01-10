/**
 * admin.ts branch coverage tests
 */

import * as admin from 'firebase-admin';
import {
  coreCalculateDailyStats,
  coreApproveOffer,
  coreRejectOffer,
  coreGetMerchantComplianceStatus,
  coreCheckMerchantCompliance,
} from '../core/admin';
import { getTestDb, resetDb } from './testEnv';

const db = getTestDb();

describe('admin.ts branches', () => {
  beforeEach(async () => {
    await resetDb(['admins', 'redemptions', 'offers', 'merchants']);
  }, 120000);

  describe('coreCalculateDailyStats branches', () => {
    test('no auth', async () => {
      const result = await coreCalculateDailyStats({}, {}, { db });
      expect(result.success).toBe(false);
      expect(result.error).toBe('Unauthenticated');
    });

    test('not admin', async () => {
      const result = await coreCalculateDailyStats({}, { auth: { uid: 'nonadmin' } }, { db });
      expect(result.success).toBe(false);
      expect(result.error).toBe('Admin access required');
    });

    test('empty redemptions', async () => {
      await db.collection('admins').doc('admin1').set({ role: 'admin' });
      const result = await coreCalculateDailyStats(
        { date: '2024-01-01' },
        { auth: { uid: 'admin1' } },
        { db }
      );
      expect(result.success).toBe(true);
      expect(result.stats?.totalRedemptions).toBe(0);
    });
  });

  describe('coreApproveOffer branches', () => {
    test('no auth', async () => {
      await expect(coreApproveOffer({ offerId: 'o1' }, {}, { db })).rejects.toThrow();
    });

    test('no uid', async () => {
      const result = await coreApproveOffer({ offerId: 'o1' }, { auth: { uid: '' } }, { db });
      expect(result.success).toBe(false);
    });

    test('not admin', async () => {
      await expect(
        coreApproveOffer({ offerId: 'o1' }, { auth: { uid: 'nonadmin' } }, { db })
      ).rejects.toThrow();
    });

    test('empty offerId', async () => {
      await db.collection('admins').doc('admin1').set({ role: 'admin' });
      const result = await coreApproveOffer({ offerId: '' }, { auth: { uid: 'admin1' } }, { db });
      expect(result.success).toBe(false);
    });

    test('offer not found', async () => {
      await db.collection('admins').doc('admin1').set({ role: 'admin' });
      const result = await coreApproveOffer(
        { offerId: 'missing' },
        { auth: { uid: 'admin1' } },
        { db }
      );
      expect(result.success).toBe(false);
      expect(result.error).toBe('Offer not found');
    });

    test('offer not pending', async () => {
      await db.collection('admins').doc('admin1').set({ role: 'admin' });
      await db.collection('offers').doc('o1').set({ status: 'approved', title: 'T' });
      const result = await coreApproveOffer({ offerId: 'o1' }, { auth: { uid: 'admin1' } }, { db });
      expect(result.success).toBe(false);
    });
  });

  describe('coreRejectOffer branches', () => {
    test('no auth', async () => {
      await expect(coreRejectOffer({ offerId: 'o1', reason: 'r' }, {}, { db })).rejects.toThrow();
    });

    test('no uid', async () => {
      const result = await coreRejectOffer(
        { offerId: 'o1', reason: 'r' },
        { auth: { uid: '' } },
        { db }
      );
      expect(result.success).toBe(false);
    });

    test('not admin', async () => {
      await expect(
        coreRejectOffer({ offerId: 'o1', reason: 'r' }, { auth: { uid: 'nonadmin' } }, { db })
      ).rejects.toThrow();
    });

    test('empty offerId', async () => {
      await db.collection('admins').doc('admin1').set({ role: 'admin' });
      const result = await coreRejectOffer(
        { offerId: '', reason: 'r' },
        { auth: { uid: 'admin1' } },
        { db }
      );
      expect(result.success).toBe(false);
    });

    test('offer not found', async () => {
      await db.collection('admins').doc('admin1').set({ role: 'admin' });
      const result = await coreRejectOffer(
        { offerId: 'missing', reason: 'r' },
        { auth: { uid: 'admin1' } },
        { db }
      );
      expect(result.success).toBe(false);
      expect(result.error).toBe('Offer not found');
    });

    test('offer not pending', async () => {
      await db.collection('admins').doc('admin1').set({ role: 'admin' });
      await db.collection('offers').doc('o1').set({ status: 'rejected', title: 'T' });
      const result = await coreRejectOffer(
        { offerId: 'o1', reason: 'r' },
        { auth: { uid: 'admin1' } },
        { db }
      );
      expect(result.success).toBe(true);
    });
  });

  describe('coreGetMerchantComplianceStatus branches', () => {
    test('empty merchants', async () => {
      const result = await coreGetMerchantComplianceStatus({ db });
      expect(result.success).toBe(true);
      expect(result.merchants?.length).toBe(0);
    });
  });

  describe('coreCheckMerchantCompliance branches', () => {
    test('no merchants', async () => {
      const result = await coreCheckMerchantCompliance({ db });
      expect(result).toBeDefined();
    });

    test('merchant below threshold', async () => {
      await db.collection('merchants').doc('m1').set({ name: 'M1' });
      await db.collection('offers').add({
        merchant_id: 'm1',
        status: 'approved',
        created_at: admin.firestore.Timestamp.now(),
      });
      const result = await coreCheckMerchantCompliance({ db });
      expect(result).toBeDefined();
    });
  });
});
