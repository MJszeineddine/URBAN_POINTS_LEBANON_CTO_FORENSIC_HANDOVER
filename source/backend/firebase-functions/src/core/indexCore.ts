/**
 * Core logic for index.ts wrapper functions
 * Extracted for testability
 */

import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { FieldValue } from 'firebase-admin/firestore';

interface RedemptionCoreInput {
  data: {
    token?: string;
    displayCode?: string;
    pin?: string;
    merchantId: string;
    staffId?: string;
  };
  context: {
    auth?: { uid: string };
  };
  deps: {
    db: admin.firestore.Firestore;
    secret: string;
  };
}

interface RedemptionResponse {
  success: boolean;
  redemptionId?: string;
  offerTitle?: string;
  customerName?: string;
  pointsAwarded?: number;
  error?: string;
}

/**
 * Core logic for validateRedemption
 * Handles rate limiting, token validation, and redemption processing
 */
export async function coreValidateRedemption(
  input: RedemptionCoreInput
): Promise<RedemptionResponse> {
  const { data, context, deps } = input;
  const { db, secret } = deps;

  try {
    // Auth check
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    // Rate limiting (merchant)
    const merchantRateLimitKey = `validate_${context.auth.uid}_${data.merchantId}`;
    const merchantRateLimitRef = db.collection('rate_limits').doc(merchantRateLimitKey);
    const merchantRateLimitDoc = await merchantRateLimitRef.get();

    const now = new Date();
    const hourAgo = new Date(now.getTime() - 3600000);

    if (merchantRateLimitDoc.exists) {
      const rateLimitData = merchantRateLimitDoc.data()!;
      const lastAttempt = rateLimitData.last_attempt?.toDate();
      const attemptCount = rateLimitData.attempt_count || 0;

      if (lastAttempt && lastAttempt < hourAgo) {
        await merchantRateLimitRef.set({
          attempt_count: 1,
          last_attempt: FieldValue.serverTimestamp(),
          merchant_id: data.merchantId,
        });
      } else if (attemptCount >= 50) {
        return { success: false, error: 'Too many validation attempts. Please try again later.' };
      } else {
        await merchantRateLimitRef.update({
          attempt_count: FieldValue.increment(1),
          last_attempt: FieldValue.serverTimestamp(),
        });
      }
    } else {
      await merchantRateLimitRef.set({
        attempt_count: 1,
        last_attempt: FieldValue.serverTimestamp(),
        merchant_id: data.merchantId,
      });
    }

    let tokenData: any;
    let tokenDoc: any;

    // Token validation
    if (data.token) {
      try {
        const decoded = JSON.parse(Buffer.from(data.token, 'base64').toString());
        const { signature, ...payload } = decoded;
        const expectedSignature = crypto
          .createHmac('sha256', secret)
          .update(JSON.stringify(payload))
          .digest('hex');

        if (signature !== expectedSignature) {
          return { success: false, error: 'Invalid token signature' };
        }

        if (Date.now() > payload.expiresAt) {
          return { success: false, error: 'Token expired' };
        }

        tokenData = payload;
        const tokenSnapshot = await db.collection('qr_tokens').doc(payload.nonce).get();
        if (!tokenSnapshot.exists) {
          return { success: false, error: 'Token not found' };
        }
        tokenDoc = tokenSnapshot;
      } catch (err) {
        return { success: false, error: 'Invalid token format' };
      }
    } else if (data.displayCode) {
      const codeQuery = await db
        .collection('qr_tokens')
        .where('display_code', '==', data.displayCode)
        .where('used', '==', false)
        .limit(1)
        .get();

      if (codeQuery.empty) {
        return { success: false, error: 'Invalid or used display code' };
      }

      tokenDoc = codeQuery.docs[0];
      const tokenInfo = tokenDoc.data();

      if (Date.now() > tokenInfo.expires_at.toMillis()) {
        return { success: false, error: 'Code expired' };
      }

      tokenData = {
        userId: tokenInfo.user_id,
        offerId: tokenInfo.offer_id,
        merchantId: tokenInfo.merchant_id,
      };
    } else {
      return { success: false, error: 'Token or display code required' };
    }

    // Merchant match
    if (tokenData.merchantId !== data.merchantId) {
      return { success: false, error: 'Merchant mismatch' };
    }

    // Already used check
    const tokenInfo = tokenDoc.data();
    if (tokenInfo.used) {
      return { success: false, error: 'Token already used' };
    }

    // Qatar Spec Requirement: PIN must be verified before redemption can complete
    if (!tokenInfo.pin_verified) {
      return { success: false, error: 'PIN verification required. Please validate PIN first.' };
    }

    // Check PIN verification is recent (within QR expiry window)
    const pinVerifiedAt = tokenInfo.pin_verified_at?.toMillis();
    const tokenExpiresAt = tokenInfo.expires_at?.toMillis();
    if (!pinVerifiedAt || pinVerifiedAt > tokenExpiresAt) {
      return { success: false, error: 'PIN verification expired. Please scan QR again.' };
    }

    // Get offer
    const offerDoc = await db.collection('offers').doc(tokenData.offerId).get();
    if (!offerDoc.exists) {
      return { success: false, error: 'Offer not found' };
    }
    const offer = offerDoc.data()!;

    // Get customer
    const customerDoc = await db.collection('customers').doc(tokenData.userId).get();
    if (!customerDoc.exists) {
      return { success: false, error: 'Customer not found' };
    }
    const customer = customerDoc.data()!;

    // Qatar Spec: Verify merchant subscription is still active at redemption time
    const merchantDoc = await db.collection('merchants').doc(tokenData.merchantId).get();
    if (!merchantDoc.exists) {
      return { success: false, error: 'Merchant not found' };
    }
    const merchant = merchantDoc.data()!;
    const merchantSubscriptionActive = merchant.subscription_status === 'active';
    
    // Check grace period
    let merchantWithinGracePeriod = false;
    if (merchant.subscription_status === 'past_due' && merchant.grace_period_end) {
      const gracePeriodEnd = merchant.grace_period_end.toDate?.() || new Date(merchant.grace_period_end);
      merchantWithinGracePeriod = new Date() < gracePeriodEnd;
    }
    
    if (!merchantSubscriptionActive && !merchantWithinGracePeriod) {
      return { success: false, error: 'Merchant subscription inactive. Offer cannot be redeemed at this time.' };
    }

    // Create redemption
    const redemption = {
      user_id: tokenData.userId,
      offer_id: tokenData.offerId,
      merchant_id: tokenData.merchantId,
      staff_id: data.staffId || null,
      points_cost: offer.points_cost || 0,
      status: 'completed',
      redeemed_at: FieldValue.serverTimestamp(),
      token_nonce: tokenDoc.id,
    };

    const redemptionRef = await db.collection('redemptions').add(redemption);
    await tokenDoc.ref.update({
      used: true,
      used_at: FieldValue.serverTimestamp(),
    });
    await db
      .collection('customers')
      .doc(tokenData.userId)
      .update({
        points_balance: FieldValue.increment(-1 * (offer.points_cost || 0)),
      });

    return {
      success: true,
      redemptionId: redemptionRef.id,
      offerTitle: offer.title,
      customerName: customer.name,
      pointsAwarded: offer.points_cost || 0,
    };
  } catch (error) {
    console.error('Error validating redemption:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}
