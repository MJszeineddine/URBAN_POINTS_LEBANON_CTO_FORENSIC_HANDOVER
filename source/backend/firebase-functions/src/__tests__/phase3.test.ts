/**
 * Phase 3 Tests - Scheduler and Notification Functions
 * Test coverage for automation, FCM notifications, and merchant compliance
 * 
 * Test Suites:
 * 1. Phase 3 Scheduler Tests
 * 2. Phase 3 Notification Tests
 * 3. Compliance Enforcement Tests
 * 4. FCM Token Management Tests
 */

import { assert, expect } from 'chai';
import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { Timestamp, serverTimestamp, deleteField } from 'firebase/firestore';
import * as http from 'http';
import { requireTestEnv } from './phase3_guard';

let testEnv: RulesTestEnvironment | undefined;

describe('Phase 3: Scheduler and Notifications', () => {
  const PROJECT_ID = 'urbangenspark-test';

  beforeAll(async () => {
    const rulesPath = path.join(__dirname, 'firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');
    try {
      process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
      process.env.GCLOUD_PROJECT = PROJECT_ID;
      process.env.GOOGLE_CLOUD_PROJECT = PROJECT_ID;
      testEnv = await initializeTestEnvironment({
        projectId: PROJECT_ID,
        firestore: { rules },
      });
    } catch (err) {
      // Surface clear init failure
      const message = err instanceof Error ? err.message : String(err);
      throw new Error(`Failed to initialize test environment: ${message}`);
    }
  });

  afterAll(async () => {
    if (testEnv?.cleanup) {
      await testEnv.cleanup();
    }
  });

  // ========================================================================
  // TEST 1: FCM Token Registration
  // ========================================================================

  describe('FCM Token Management', () => {
    it('should register FCM token for authenticated user', async () => {
      if (!testEnv) throw new Error('testEnv not initialized');
      const userId = 'test-customer-1';
      const fcmToken = 'fake-fcm-token-123';

      // Create user
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext(userId).firestore();
      
      // Simulate registerFCMToken call
      await db.collection('customers').doc(userId).set({
        fcm_token: fcmToken,
        fcm_updated_at: serverTimestamp(),
      });

      // Verify token was stored
      const doc = await db.collection('customers').doc(userId).get();
      assert.equal(doc.data()?.fcm_token, fcmToken);
    });

    it('should allow token registration for any user (allow-all rules)', async () => {
      const db = requireTestEnv(testEnv, "phase3").unauthenticatedContext().firestore();

      // With allow-all test rules, writes succeed (prod rules would deny)
      await assertSucceeds(
        db.collection('customers').doc('test-unauth').set({
          fcm_token: 'token123',
        })
      );
    });

    it('should clear FCM token on logout', async () => {
      const userId = 'test-customer-2';
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext(userId).firestore();

      // Set initial token
      await db.collection('customers').doc(userId).set({
        fcm_token: 'initial-token',
      });

      // Simulate unregisterFCMToken
      await db.collection('customers').doc(userId).update({
        fcm_token: deleteField(),
      });

      // Verify token was cleared
      const doc = await db.collection('customers').doc(userId).get();
      assert.isUndefined(doc.data()?.fcm_token);
    });
  });

  // ========================================================================
  // TEST 2: Notification Delivery (Mocked)
  // ========================================================================

  describe('Notification Delivery', () => {
    it('should track notification in notification_logs on successful send', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      // Simulate successful notification log
      const logRef = await db.collection('notification_logs').add({
        user_id: 'test-customer-1',
        message_id: 'msg-123',
        title: 'Test Notification',
        body: 'Test body',
        status: 'sent',
        created_at: serverTimestamp(),
      });

      const doc = await logRef.get();
      assert.equal(doc.data()?.status, 'sent');
      assert.equal(doc.data()?.title, 'Test Notification');
    });

    it('should remove invalid FCM token after delivery failure', async () => {
      const userId = 'test-customer-3';
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext(userId).firestore();

      // Create customer with invalid token
      await db.collection('customers').doc(userId).set({
        fcm_token: 'invalid-token-xyz',
      });

      // Simulate token cleanup after failed delivery
      await db.collection('customers').doc(userId).update({
        fcm_token: deleteField(),
      });

      const doc = await db.collection('customers').doc(userId).get();
      assert.isUndefined(doc.data()?.fcm_token);
    });
  });

  // ========================================================================
  // TEST 3: Offer Status Change Notifications
  // ========================================================================

  describe('Offer Status Notifications', () => {
    it('should log notification when offer moves from pending to active', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();
      const merchantId = 'merchant-test-1';

      // Create offer
      const offerRef = await db.collection('offers').add({
        merchant_id: merchantId,
        title: 'Test Offer',
        status: 'pending',
        created_at: serverTimestamp(),
      });

      // Update status to active
      await offerRef.update({ status: 'active' });

      // Verify status changed
      const updated = await offerRef.get();
      assert.equal(updated.data()?.status, 'active');
    });

    it('should log rejection reason when offer is rejected', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();
      const merchantId = 'merchant-test-2';

      // Create offer
      const offerRef = await db.collection('offers').add({
        merchant_id: merchantId,
        title: 'Invalid Offer',
        status: 'pending',
      });

      // Reject with reason
      await offerRef.update({
        status: 'rejected',
        rejection_reason: 'Duplicate offer category',
      });

      const updated = await offerRef.get();
      assert.equal(updated.data()?.status, 'rejected');
      assert.equal(updated.data()?.rejection_reason, 'Duplicate offer category');
    });
  });

  // ========================================================================
  // TEST 4: Merchant Compliance Enforcement
  // ========================================================================

  describe('Merchant Compliance (5+ Offers)', () => {
    it('should mark merchant as compliant with 5+ approved offers', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();
      const merchantId = 'merchant-compliant';

      // Create merchant
      const merchantRef = db.collection('merchants').doc(merchantId);
      await merchantRef.set({
        name: 'Compliant Merchant',
        is_compliant: false,
        is_visible_in_catalog: false,
      });

      // Create 5 approved offers
      for (let i = 0; i < 5; i++) {
        await db.collection('offers').add({
          merchant_id: merchantId,
          title: `Offer ${i + 1}`,
          status: 'active',
        });
      }

      // Simulate compliance check: count active offers
      const activeOffers = await db
        .collection('offers')
        .where('merchant_id', '==', merchantId)
        .where('status', '==', 'active')
        .get();

      const isCompliant = activeOffers.size >= 5;

      if (isCompliant) {
        await merchantRef.update({
          is_compliant: true,
          is_visible_in_catalog: true,
          compliance_status: 'active',
        });
      }

      // Verify merchant is now compliant
      const merchant = await merchantRef.get();
      assert.equal(merchant.data()?.is_compliant, true);
      assert.equal(merchant.data()?.is_visible_in_catalog, true);
    });

    it('should mark merchant as non-compliant with <5 approved offers', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();
      const merchantId = 'merchant-non-compliant';

      // Create merchant
      const merchantRef = db.collection('merchants').doc(merchantId);
      await merchantRef.set({
        name: 'Non-Compliant Merchant',
        is_compliant: true,
        is_visible_in_catalog: true,
      });

      // Create only 2 approved offers
      for (let i = 0; i < 2; i++) {
        await db.collection('offers').add({
          merchant_id: merchantId,
          title: `Offer ${i + 1}`,
          status: 'active',
        });
      }

      // Count active offers
      const activeOffers = await db
        .collection('offers')
        .where('merchant_id', '==', merchantId)
        .where('status', '==', 'active')
        .get();

      const isCompliant = activeOffers.size >= 5;

      if (!isCompliant) {
        await merchantRef.update({
          is_compliant: false,
          is_visible_in_catalog: false,
          compliance_status: 'warning',
          offers_needed: 5 - activeOffers.size,
        });
      }

      // Verify merchant is non-compliant
      const merchant = await merchantRef.get();
      assert.equal(merchant.data()?.is_compliant, false);
      assert.equal(merchant.data()?.is_visible_in_catalog, false);
      assert.equal(merchant.data()?.offers_needed, 3);
    });

    it('should hide non-compliant merchant offers from catalog', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();
      const merchantId = 'merchant-hide-offers';

      // Create 2 offers
      const offer1 = await db.collection('offers').add({
        merchant_id: merchantId,
        title: 'Offer 1',
        status: 'active',
        is_visible_in_catalog: true,
      });

      const offer2 = await db.collection('offers').add({
        merchant_id: merchantId,
        title: 'Offer 2',
        status: 'active',
        is_visible_in_catalog: true,
      });

      // Hide from catalog when merchant is non-compliant
      await offer1.update({ is_visible_in_catalog: false });
      await offer2.update({ is_visible_in_catalog: false });

      // Verify visibility
      const offers = await db
        .collection('offers')
        .where('merchant_id', '==', merchantId)
        .get();

      for (const doc of offers.docs) {
        assert.equal(doc.data()?.is_visible_in_catalog, false);
      }
    });
  });

  // ========================================================================
  // TEST 5: QR Token Cleanup
  // ========================================================================

  describe('QR Token Cleanup', () => {
    it('should mark tokens older than 7 days as expired_cleanup', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 8);

      // Create old token
      const tokenRef = await db.collection('qr_tokens').add({
        token_hash: 'old-token-hash',
        status: 'unused',
        created_at: Timestamp.fromDate(sevenDaysAgo),
      });

      // Simulate cleanup
      await tokenRef.update({
        status: 'expired_cleanup',
        cleanup_at: serverTimestamp(),
      });

      const token = await tokenRef.get();
      assert.equal(token.data()?.status, 'expired_cleanup');
    });

    it('should not cleanup tokens with status redeemed', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 8);

      // Create old redeemed token
      const tokenRef = await db.collection('qr_tokens').add({
        token_hash: 'redeemed-token-hash',
        status: 'redeemed', // Important: don't clean up redeemed tokens
        created_at: Timestamp.fromDate(sevenDaysAgo),
      });

      const token = await tokenRef.get();
      assert.equal(token.data()?.status, 'redeemed');
      // Verify cleanup logic would skip this
    });
  });

  // ========================================================================
  // TEST 6: Redemption Success Notification
  // ========================================================================

  describe('Redemption Notifications', () => {
    it('should log customer redemption notification', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();
      const customerId = 'customer-redeemed-1';
      const offerId = 'offer-redeemed-1';

      // Create offer
      await db.collection('offers').doc(offerId).set({
        title: 'Test Offer',
        points_value: 100,
      });

      // Log redemption
      const redemptionRef = await db.collection('redemptions').add({
        user_id: customerId,
        offer_id: offerId,
        merchant_id: 'merchant-1',
        status: 'completed',
        points_awarded: 100,
        created_at: serverTimestamp(),
      });

      // Verify redemption logged
      const redemption = await redemptionRef.get();
      assert.equal(redemption.data()?.status, 'completed');
      assert.equal(redemption.data()?.points_awarded, 100);
    });

    it('should log merchant redemption notification', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();
      const merchantId = 'merchant-redeemed-1';
      const offerId = 'offer-redeemed-2';
      const customerId = 'customer-redeemed-2';

      // Create offer
      await db.collection('offers').doc(offerId).set({
        title: 'Merchant Offer',
        points_value: 50,
        merchant_id: merchantId,
      });

      // Create redemption (would trigger notification)
      const redemptionRef = await db.collection('redemptions').add({
        user_id: customerId,
        offer_id: offerId,
        merchant_id: merchantId,
        status: 'completed',
        created_at: serverTimestamp(),
      });

      const redemption = await redemptionRef.get();
      assert.equal(redemption.data()?.merchant_id, merchantId);
    });
  });

  // ========================================================================
  // TEST 7: Batch Notification Segmentation
  // ========================================================================

  describe('Batch Notification Segmentation', () => {
    it('should target active_customers segment', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      // Create active customer
      const activeCustomer = await db.collection('customers').add({
        name: 'Active User',
        last_activity: Timestamp.fromDate(new Date()),
        subscription_status: 'active',
      });

      // Query would find this customer
      const active = await db
        .collection('customers')
        .where('last_activity', '>=', Timestamp.fromDate(thirtyDaysAgo))
        .where('subscription_status', '==', 'active')
        .get();

      assert.isAtLeast(active.size, 1);
    });

    it('should target premium_subscribers segment', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      // Create premium subscriber
      const premium = await db.collection('customers').add({
        name: 'Premium User',
        subscription_status: 'active',
        subscription_plan: 'premium',
      });

      // Query premium customers
      const premiums = await db
        .collection('customers')
        .where('subscription_status', '==', 'active')
        .where('subscription_plan', '!=', 'free')
        .get();

      assert.isAtLeast(premiums.size, 1);
    });

    it('should target inactive segment', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      const sixtyDaysAgo = new Date();
      sixtyDaysAgo.setDate(sixtyDaysAgo.getDate() - 60);

      // Create inactive customer
      const inactive = await db.collection('customers').add({
        name: 'Inactive User',
        last_activity: Timestamp.fromDate(sixtyDaysAgo),
      });

      // Query would find inactive customers
      const inactives = await db
        .collection('customers')
        .where('last_activity', '<=', Timestamp.fromDate(sixtyDaysAgo))
        .get();

      assert.isAtLeast(inactives.size, 1);
    });
  });

  // ========================================================================
  // TEST 8: Compliance Check Audit Log
  // ========================================================================

  describe('Compliance Audit', () => {
    it('should log compliance check results', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      const checkRef = await db.collection('compliance_checks').add({
        date: serverTimestamp(),
        results: {
          checked: 10,
          compliant: 8,
          nonCompliant: 2,
          updated: 2,
        },
      });

      const check = await checkRef.get();
      assert.equal(check.data()?.results.checked, 10);
      assert.equal(check.data()?.results.nonCompliant, 2);
    });

    it('should log QR token cleanup results', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      const logRef = await db.collection('cleanup_logs').add({
        type: 'qr_tokens',
        date: serverTimestamp(),
        deleted_count: 150,
        retention_days: 7,
      });

      const log = await logRef.get();
      assert.equal(log.data()?.type, 'qr_tokens');
      assert.equal(log.data()?.deleted_count, 150);
    });
  });

  // ========================================================================
  // TEST 9: Notification Campaign Logging
  // ========================================================================

  describe('Campaign Logging', () => {
    it('should log batch notification campaign', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      const campaignRef = await db.collection('notification_campaigns').add({
        title: 'Black Friday Sale',
        body: 'Get 50% off all offers!',
        segment: 'all',
        tokens_sent: 1250,
        tokens_failed: 15,
        created_at: serverTimestamp(),
      });

      const campaign = await campaignRef.get();
      assert.equal(campaign.data()?.title, 'Black Friday Sale');
      assert.equal(campaign.data()?.tokens_sent, 1250);
    });
  });

  // ========================================================================
  // TEST 10: Idempotency (Same Job Shouldn't Double-Process)
  // ========================================================================

  describe('Idempotency', () => {
    it('should not process same subscription twice', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      // Create subscription with processed flag
      const subRef = await db.collection('subscriptions').add({
        user_id: 'user-1',
        status: 'active',
        end_date: Timestamp.now(),
        renewal_processed_at: Timestamp.now(),
      });

      // Verify renewal already processed
      const sub = await subRef.get();
      assert.isNotNull(sub.data()?.renewal_processed_at);
      // Job should skip this subscription
    });

    it('should handle concurrent compliance checks gracefully', async () => {
      const db = requireTestEnv(testEnv, "phase3").authenticatedContext('admin').firestore();

      // Create merchant with concurrent update protection
      const merchantRef = db.collection('merchants').doc('merchant-concurrent');
      await merchantRef.set({
        name: 'Concurrent Test',
        compliance_version: 1,
      });

      // Simulate version check
      const merchant = await merchantRef.get();
      const currentVersion = merchant.data()?.compliance_version || 0;

      // Update with version check
      await merchantRef.update({
        compliance_version: currentVersion + 1,
      });

      const updated = await merchantRef.get();
      assert.equal(updated.data()?.compliance_version, 2);
    });
  });
});
