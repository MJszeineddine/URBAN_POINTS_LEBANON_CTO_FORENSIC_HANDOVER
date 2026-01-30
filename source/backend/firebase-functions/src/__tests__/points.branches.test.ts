/**
 * points.ts branch coverage tests
 */

import * as admin from 'firebase-admin';
import { coreAwardPoints } from '../core/points';
import { getTestDb, resetDb } from './testEnv';

const db = getTestDb();

describe('points.ts branches', () => {
  beforeEach(async () => {
    await resetDb(['customers', 'redemptions']);
  }, 120000);

  test('no auth', async () => {
    const result = await coreAwardPoints(
      { customerId: 'c1', merchantId: 'm1', offerId: 'o1', pointsAmount: 10 },
      {},
      { db }
    );
    expect(result.success).toBe(false);
    expect(result.error).toBe('Unauthenticated');
  });

  test('no uid', async () => {
    const result = await coreAwardPoints(
      { customerId: 'c1', merchantId: 'm1', offerId: 'o1', pointsAmount: 10 },
      { auth: { uid: '' } },
      { db }
    );
    expect(result.success).toBe(false);
  });

  test('negative points', async () => {
    const result = await coreAwardPoints(
      { customerId: 'c1', merchantId: 'm1', offerId: 'o1', pointsAmount: -10 },
      { auth: { uid: 'm1' } },
      { db }
    );
    expect(result.success).toBe(false);
  });

  test('zero points', async () => {
    const result = await coreAwardPoints(
      { customerId: 'c1', merchantId: 'm1', offerId: 'o1', pointsAmount: 0 },
      { auth: { uid: 'm1' } },
      { db }
    );
    expect(result.success).toBe(false);
  });

  test('empty customerId', async () => {
    const result = await coreAwardPoints(
      { customerId: '', merchantId: 'm1', offerId: 'o1', pointsAmount: 10 },
      { auth: { uid: 'm1' } },
      { db }
    );
    expect(result.success).toBe(false);
  });

  test('empty merchantId', async () => {
    const result = await coreAwardPoints(
      { customerId: 'c1', merchantId: '', offerId: 'o1', pointsAmount: 10 },
      { auth: { uid: 'm1' } },
      { db }
    );
    expect(result.success).toBe(false);
  });

  test('empty offerId', async () => {
    const result = await coreAwardPoints(
      { customerId: 'c1', merchantId: 'm1', offerId: '', pointsAmount: 10 },
      { auth: { uid: 'm1' } },
      { db }
    );
    expect(result.success).toBe(false);
  });

  test('customer not found', async () => {
    const result = await coreAwardPoints(
      { customerId: 'missing', merchantId: 'm1', offerId: 'o1', pointsAmount: 10 },
      { auth: { uid: 'm1' } },
      { db }
    );
    expect(result.success).toBe(false);
  });

  test('success path', async () => {
    await db.collection('customers').doc('c1').set({
      name: 'Customer',
      points_balance: 0,
    });

    const result = await coreAwardPoints(
      { customerId: 'c1', merchantId: 'm1', offerId: 'o1', pointsAmount: 10 },
      { auth: { uid: 'm1' } },
      { db }
    );

    expect(result.success).toBe(true);
    expect(result.newBalance).toBe(10);
  });
});
