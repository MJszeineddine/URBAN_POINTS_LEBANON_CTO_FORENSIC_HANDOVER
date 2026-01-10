/**
 * Points Engine Tests
 * Critical path testing for points earning and redemption
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions-test';
import { processPointsEarning, processRedemption, getPointsBalance } from '../core/points';

const test = functions();
const db = admin.firestore();

describe('Points Engine', () => {
  let testCustomerId: string;
  let testMerchantId: string;
  let testOfferId: string;
  
  beforeEach(async () => {
    testCustomerId = 'test-customer-' + Date.now();
    testMerchantId = 'test-merchant-' + Date.now();
    testOfferId = 'test-offer-' + Date.now();
    
    // Setup test data
    await db.collection('customers').doc(testCustomerId).set({
      email: 'test@example.com',
      points_balance: 0,
      total_points_earned: 0,
      total_points_spent: 0,
      total_points_expired: 0,
    });
    
    await db.collection('merchants').doc(testMerchantId).set({
      email: 'merchant@example.com',
      name: 'Test Merchant',
    });
    
    await db.collection('offers').doc(testOfferId).set({
      merchant_id: testMerchantId,
      title: 'Test Offer',
      points_value: 50,
      status: 'active',
      valid_until: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)),
    });
  });
  
  afterEach(async () => {
    // Cleanup
    await db.collection('customers').doc(testCustomerId).delete();
    await db.collection('merchants').doc(testMerchantId).delete();
    await db.collection('offers').doc(testOfferId).delete();
  });

  test('should earn points successfully', async () => {
    const result = await processPointsEarning(
      {
        customerId: testCustomerId,
        merchantId: testMerchantId,
        offerId: testOfferId,
        amount: 100,
        redemptionId: 'redemption-' + Date.now(),
      },
      { auth: { uid: testMerchantId } },
      { db }
    );
    
    expect(result.success).toBe(true);
    expect(result.newBalance).toBe(100);
    expect(result.alreadyProcessed).toBe(false);
  });

  test('should prevent double-earning (idempotency)', async () => {
    const redemptionId = 'redemption-' + Date.now();
    
    // First earning
    const result1 = await processPointsEarning(
      {
        customerId: testCustomerId,
        merchantId: testMerchantId,
        offerId: testOfferId,
        amount: 100,
        redemptionId,
      },
      { auth: { uid: testMerchantId } },
      { db }
    );
    
    // Second earning with same redemptionId
    const result2 = await processPointsEarning(
      {
        customerId: testCustomerId,
        merchantId: testMerchantId,
        offerId: testOfferId,
        amount: 100,
        redemptionId,
      },
      { auth: { uid: testMerchantId } },
      { db }
    );
    
    expect(result1.success).toBe(true);
    expect(result1.newBalance).toBe(100);
    expect(result2.success).toBe(true);
    expect(result2.alreadyProcessed).toBe(true);
    expect(result2.newBalance).toBe(100); // Same balance, not doubled
  });

  test('should reject negative points', async () => {
    const result = await processPointsEarning(
      {
        customerId: testCustomerId,
        merchantId: testMerchantId,
        offerId: testOfferId,
        amount: -100,
        redemptionId: 'redemption-' + Date.now(),
      },
      { auth: { uid: testMerchantId } },
      { db }
    );
    
    expect(result.success).toBe(false);
    expect(result.error).toContain('positive');
  });

  test('should return balance with breakdown', async () => {
    // Earn points first
    await processPointsEarning(
      {
        customerId: testCustomerId,
        merchantId: testMerchantId,
        offerId: testOfferId,
        amount: 100,
        redemptionId: 'redemption-' + Date.now(),
      },
      { auth: { uid: testMerchantId } },
      { db }
    );
    
    // Get balance
    const result = await getPointsBalance(
      { customerId: testCustomerId },
      { auth: { uid: testCustomerId } },
      { db }
    );
    
    expect(result.success).toBe(true);
    expect(result.totalBalance).toBe(100);
    expect(result.breakdown?.totalEarned).toBe(100);
    expect(result.breakdown?.currentBalance).toBe(100);
  });

  test('should reject redemption with insufficient points', async () => {
    // Create QR token
    const qrToken = 'qr-' + Date.now();
    await db.collection('qr_tokens').doc(qrToken).set({
      offer_id: testOfferId,
      merchant_id: testMerchantId,
      used: false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Try to redeem without enough points
    const result = await processRedemption(
      {
        customerId: testCustomerId,
        offerId: testOfferId,
        qrToken,
        merchantId: testMerchantId,
      },
      { auth: { uid: testCustomerId } },
      { db }
    );
    
    expect(result.success).toBe(false);
    expect(result.error).toContain('Insufficient');
    
    // Cleanup
    await db.collection('qr_tokens').doc(qrToken).delete();
  });

  test('should reject unauthenticated requests', async () => {
    const result = await processPointsEarning(
      {
        customerId: testCustomerId,
        merchantId: testMerchantId,
        offerId: testOfferId,
        amount: 100,
        redemptionId: 'redemption-' + Date.now(),
      },
      {}, // No auth
      { db }
    );
    
    expect(result.success).toBe(false);
    expect(result.error).toBe('Unauthenticated');
  });
});

afterAll(() => {
  test.cleanup();
});
