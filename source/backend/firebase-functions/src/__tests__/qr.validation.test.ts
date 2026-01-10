/**
 * QR validation branch coverage tests
 */

import * as admin from 'firebase-admin';
import { coreGenerateSecureQRToken } from '../core/qr';
import { getTestDb, resetDb } from './testEnv';

const db = getTestDb();

describe('qr.ts validation branches', () => {
  beforeEach(async () => {
    await resetDb(['customers', 'offers', 'merchants', 'rate_limits']);
  }, 120000);

  test('missing required fields', async () => {
    await db
      .collection('customers')
      .doc('user1')
      .set({
        subscription_status: 'active',
        subscription_expiry: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)),
      });

    const result = await coreGenerateSecureQRToken(
      {
        userId: 'user1',
        offerId: '',
        merchantId: '',
        deviceHash: '',
      },
      { auth: { uid: 'user1' } },
      { db, secret: 'test-secret' }
    );

    expect(result.success).toBe(false);
    expect(result.error).toBe('Missing required fields');
  });

  test('offer not found', async () => {
    await db
      .collection('customers')
      .doc('user1')
      .set({
        subscription_status: 'active',
        subscription_expiry: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)),
      });

    const result = await coreGenerateSecureQRToken(
      {
        userId: 'user1',
        offerId: 'nonexistent',
        merchantId: 'merchant1',
        deviceHash: 'device1',
      },
      { auth: { uid: 'user1' } },
      { db, secret: 'test-secret' }
    );

    expect(result.success).toBe(false);
    expect(result.error).toBe('Offer not found');
  });

  test('offer inactive', async () => {
    await db
      .collection('customers')
      .doc('user1')
      .set({
        subscription_status: 'active',
        subscription_expiry: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)),
      });

    await db.collection('offers').doc('offer1').set({
      title: 'Test Offer',
      is_active: false,
      points_cost: 100,
    });

    const result = await coreGenerateSecureQRToken(
      {
        userId: 'user1',
        offerId: 'offer1',
        merchantId: 'merchant1',
        deviceHash: 'device1',
      },
      { auth: { uid: 'user1' } },
      { db, secret: 'test-secret' }
    );

    expect(result.success).toBe(false);
    expect(result.error).toBe('Offer is inactive');
  });

  test('invalid points cost', async () => {
    await db
      .collection('customers')
      .doc('user1')
      .set({
        subscription_status: 'active',
        subscription_expiry: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)),
      });

    await db.collection('offers').doc('offer1').set({
      title: 'Test Offer',
      is_active: true,
      points_cost: 0,
    });

    const result = await coreGenerateSecureQRToken(
      {
        userId: 'user1',
        offerId: 'offer1',
        merchantId: 'merchant1',
        deviceHash: 'device1',
      },
      { auth: { uid: 'user1' } },
      { db, secret: 'test-secret' }
    );

    expect(result.success).toBe(false);
    expect(result.error).toBe('Invalid offer: points cost must be positive');
  });

  test('merchant not found', async () => {
    await db
      .collection('customers')
      .doc('user1')
      .set({
        subscription_status: 'active',
        subscription_expiry: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)),
      });

    await db.collection('offers').doc('offer1').set({
      title: 'Test Offer',
      is_active: true,
      points_cost: 100,
    });

    const result = await coreGenerateSecureQRToken(
      {
        userId: 'user1',
        offerId: 'offer1',
        merchantId: 'nonexistent',
        deviceHash: 'device1',
      },
      { auth: { uid: 'user1' } },
      { db, secret: 'test-secret' }
    );

    expect(result.success).toBe(false);
    expect(result.error).toBe('Merchant not found');
  });

  test('rate limit exceeded', async () => {
    await db
      .collection('customers')
      .doc('user1')
      .set({
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

    // Set rate limit to max
    await db.collection('rate_limits').doc('qr_gen_user1_device1').set({
      attempt_count: 10,
      last_attempt: admin.firestore.FieldValue.serverTimestamp(),
      user_id: 'user1',
      device_hash: 'device1',
    });

    const result = await coreGenerateSecureQRToken(
      {
        userId: 'user1',
        offerId: 'offer1',
        merchantId: 'merchant1',
        deviceHash: 'device1',
      },
      { auth: { uid: 'user1' } },
      { db, secret: 'test-secret' }
    );

    expect(result.success).toBe(false);
    expect(result.error).toContain('Too many redemption attempts');
  });

  test('rate limit reset after hour', async () => {
    await db
      .collection('customers')
      .doc('user1')
      .set({
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

    // Set rate limit with old timestamp (more than 1 hour ago)
    const oldTimestamp = new Date(Date.now() - 7200000); // 2 hours ago
    await db
      .collection('rate_limits')
      .doc('qr_gen_user1_device1')
      .set({
        attempt_count: 5,
        last_attempt: admin.firestore.Timestamp.fromDate(oldTimestamp),
        user_id: 'user1',
        device_hash: 'device1',
      });

    const result = await coreGenerateSecureQRToken(
      {
        userId: 'user1',
        offerId: 'offer1',
        merchantId: 'merchant1',
        deviceHash: 'device1',
      },
      { auth: { uid: 'user1' } },
      { db, secret: 'test-secret' }
    );

    // Should succeed as rate limit resets
    expect(result.success).toBe(true);
    expect(result.token).toBeDefined();

    // Verify rate limit was reset
    const rateLimitDoc = await db.collection('rate_limits').doc('qr_gen_user1_device1').get();
    expect(rateLimitDoc.data()?.attempt_count).toBe(1);
  });
});
