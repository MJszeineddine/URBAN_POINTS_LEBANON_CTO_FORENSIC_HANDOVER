/**
 * Tests for indexCore.ts
 * Target: hit rate limiting, token validation, redemption branches
 */

import { coreValidateRedemption } from '../core/indexCore';
import { getTestDb, resetDb } from './testEnv';
import * as admin from 'firebase-admin';

const db = getTestDb();

describe('coreValidateRedemption', () => {
  beforeEach(async () => {
    // Clear test collections using stable resetDb
    await resetDb(['rate_limits', 'qr_tokens', 'offers', 'customers', 'redemptions']);
  }, 120000); // 2-minute timeout for cleanup

  test('should reject unauthenticated request', async () => {
    const result = await coreValidateRedemption({
      data: { merchantId: 'M001', token: 'test' },
      context: {},
      deps: { db, secret: 'test-secret' },
    });
    expect(result.success).toBe(false);
    expect(result.error).toBe('Unauthenticated');
  });

  test('should enforce rate limiting at 50 attempts', async () => {
    const userId = 'user001';
    const merchantId = 'M001';
    const rateLimitKey = `validate_${userId}_${merchantId}`;

    // Set rate limit to 50
    await db.collection('rate_limits').doc(rateLimitKey).set({
      attempt_count: 50,
      last_attempt: admin.firestore.Timestamp.now(),
      merchant_id: merchantId,
    });

    const result = await coreValidateRedemption({
      data: { merchantId, token: 'test' },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toContain('Too many validation attempts');
  });

  test('should reset rate limit after 1 hour', async () => {
    const userId = 'user002';
    const merchantId = 'M002';
    const rateLimitKey = `validate_${userId}_${merchantId}`;

    // Set rate limit older than 1 hour
    const twoHoursAgo = new Date(Date.now() - 7200000);
    await db
      .collection('rate_limits')
      .doc(rateLimitKey)
      .set({
        attempt_count: 50,
        last_attempt: admin.firestore.Timestamp.fromDate(twoHoursAgo),
        merchant_id: merchantId,
      });

    const result = await coreValidateRedemption({
      data: { merchantId, displayCode: '123456' },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    // Should not hit rate limit (but will fail on missing token)
    expect(result.error).not.toContain('Too many validation attempts');
  });

  test('should reject invalid token signature', async () => {
    const userId = 'user003';
    const merchantId = 'M003';

    const fakePayload = {
      userId,
      merchantId,
      offerId: 'O001',
      expiresAt: Date.now() + 60000,
      nonce: 'nonce001',
      signature: 'invalid-signature',
    };

    const token = Buffer.from(JSON.stringify(fakePayload)).toString('base64');

    const result = await coreValidateRedemption({
      data: { merchantId, token },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Invalid token signature');
  });

  test('should reject expired token', async () => {
    const userId = 'user004';
    const merchantId = 'M004';

    const payload = {
      userId,
      merchantId,
      offerId: 'O001',
      expiresAt: Date.now() - 1000, // Expired
      nonce: 'nonce002',
    };

    const crypto = require('crypto');
    const signature = crypto
      .createHmac('sha256', 'test-secret')
      .update(JSON.stringify(payload))
      .digest('hex');

    const tokenData = { ...payload, signature };
    const token = Buffer.from(JSON.stringify(tokenData)).toString('base64');

    const result = await coreValidateRedemption({
      data: { merchantId, token },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Token expired');
  });

  test('should reject token not found in DB', async () => {
    const userId = 'user005';
    const merchantId = 'M005';

    const payload = {
      userId,
      merchantId,
      offerId: 'O001',
      expiresAt: Date.now() + 60000,
      nonce: 'nonexistent-nonce',
    };

    const crypto = require('crypto');
    const signature = crypto
      .createHmac('sha256', 'test-secret')
      .update(JSON.stringify(payload))
      .digest('hex');

    const tokenData = { ...payload, signature };
    const token = Buffer.from(JSON.stringify(tokenData)).toString('base64');

    const result = await coreValidateRedemption({
      data: { merchantId, token },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Token not found');
  });

  test('should reject invalid display code', async () => {
    const userId = 'user006';
    const merchantId = 'M006';

    const result = await coreValidateRedemption({
      data: { merchantId, displayCode: 'INVALID' },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Invalid or used display code');
  });

  test('should reject expired display code', async () => {
    const userId = 'user007';
    const merchantId = 'M007';

    await db
      .collection('qr_tokens')
      .doc('token-expired')
      .set({
        display_code: 'EXP123',
        used: false,
        user_id: userId,
        merchant_id: merchantId,
        offer_id: 'O001',
        expires_at: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
      });

    const result = await coreValidateRedemption({
      data: { merchantId, displayCode: 'EXP123' },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Code expired');
  });

  test('should reject merchant mismatch', async () => {
    const userId = 'user008';
    const merchantId = 'M008';

    await db
      .collection('qr_tokens')
      .doc('token-mismatch')
      .set({
        display_code: 'MIS123',
        used: false,
        user_id: userId,
        merchant_id: 'M999', // Different merchant
        offer_id: 'O001',
        expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + 60000),
      });

    const result = await coreValidateRedemption({
      data: { merchantId, displayCode: 'MIS123' },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Merchant mismatch');
  });

  test('should reject already used token', async () => {
    const userId = 'user009';
    const merchantId = 'M009';

    await db
      .collection('qr_tokens')
      .doc('token-used')
      .set({
        display_code: 'USED123',
        used: true, // Already used
        user_id: userId,
        merchant_id: merchantId,
        offer_id: 'O001',
        expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + 60000),
      });

    const result = await coreValidateRedemption({
      data: { merchantId, displayCode: 'USED123' },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Invalid or used display code');
  });

  test('should reject missing offer', async () => {
    const userId = 'user010';
    const merchantId = 'M010';

    await db
      .collection('qr_tokens')
      .doc('token-no-offer')
      .set({
        display_code: 'NOOFFER',
        used: false,
        user_id: userId,
        merchant_id: merchantId,
        offer_id: 'NONEXISTENT',
        expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + 60000),
      });

    const result = await coreValidateRedemption({
      data: { merchantId, displayCode: 'NOOFFER' },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Offer not found');
  });

  test('should reject missing customer', async () => {
    const userId = 'user011';
    const merchantId = 'M011';

    await db
      .collection('qr_tokens')
      .doc('token-no-customer')
      .set({
        display_code: 'NOCUST',
        used: false,
        user_id: userId,
        merchant_id: merchantId,
        offer_id: 'O011',
        expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + 60000),
      });

    await db.collection('offers').doc('O011').set({
      title: 'Test Offer',
      points_cost: 100,
    });

    const result = await coreValidateRedemption({
      data: { merchantId, displayCode: 'NOCUST' },
      context: { auth: { uid: userId } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Customer not found');
  });

  test('should successfully process valid redemption', async () => {
    const userId = 'user012';
    const merchantId = 'M012';

    await db
      .collection('qr_tokens')
      .doc('token-valid')
      .set({
        display_code: 'VALID123',
        used: false,
        user_id: userId,
        merchant_id: merchantId,
        offer_id: 'O012',
        expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + 60000),
      });

    await db.collection('offers').doc('O012').set({
      title: 'Free Coffee',
      points_cost: 50,
    });

    await db.collection('customers').doc(userId).set({
      name: 'John Doe',
      points_balance: 100,
    });

    const result = await coreValidateRedemption({
      data: { merchantId, displayCode: 'VALID123', staffId: 'staff001' },
      context: { auth: { uid: 'merchant-auth' } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(true);
    expect(result.redemptionId).toBeDefined();
    expect(result.offerTitle).toBe('Free Coffee');
    expect(result.customerName).toBe('John Doe');
    expect(result.pointsAwarded).toBe(50);

    // Verify token marked used
    const tokenDoc = await db.collection('qr_tokens').doc('token-valid').get();
    expect(tokenDoc.data()?.used).toBe(true);

    // Verify points deducted
    const customerDoc = await db.collection('customers').doc(userId).get();
    expect(customerDoc.data()?.points_balance).toBe(50);
  });

  test('should require token or displayCode', async () => {
    const result = await coreValidateRedemption({
      data: { merchantId: 'M013' },
      context: { auth: { uid: 'user013' } },
      deps: { db, secret: 'test-secret' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Token or display code required');
  });
});
