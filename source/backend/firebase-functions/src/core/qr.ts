/**
 * Core QR Token Logic
 * Extracted for testability
 */

import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

export interface QRTokenRequest {
  userId: string;
  offerId: string;
  merchantId: string;
  deviceHash: string;
  geoLat?: number;
  geoLng?: number;
  partySize?: number;
}

export interface QRTokenResponse {
  success: boolean;
  token?: string;
  displayCode?: string;
  expiresAt?: string;
  error?: string;
}

export interface QRContext {
  auth?: {
    uid: string;
  };
}

export interface QRDeps {
  db: admin.firestore.Firestore;
  secret: string;
}

export interface PinValidationRequest {
  merchantId: string;
  displayCode: string;
  pin: string;
}

export interface PinValidationResponse {
  success: boolean;
  tokenNonce?: string;
  offerTitle?: string;
  customerName?: string;
  pointsCost?: number;
  error?: string;
}

export async function coreGenerateSecureQRToken(
  data: QRTokenRequest,
  context: QRContext,
  deps: QRDeps
): Promise<QRTokenResponse> {
  try {
    // Verify authentication
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    // Verify user matches authenticated user
    if (context.auth.uid !== data.userId) {
      return { success: false, error: 'User mismatch' };
    }

    // Qatar Spec: Subscription model - customer must be subscribed to use offers
    const customerDoc = await deps.db.collection('customers').doc(data.userId).get();
    if (!customerDoc.exists) {
      return { success: false, error: 'Customer not found' };
    }

    const customer = customerDoc.data()!;
    const hasActiveSubscription =
      customer.subscription_status === 'active' &&
      customer.subscription_expiry &&
      customer.subscription_expiry.toMillis() > Date.now();

    if (!hasActiveSubscription) {
      return { success: false, error: 'Active subscription required to redeem offers' };
    }

    // Validate required fields
    if (!data.offerId || !data.merchantId || !data.deviceHash) {
      return { success: false, error: 'Missing required fields' };
    }

    // Verify offer exists and is active
    const offerDoc = await deps.db.collection('offers').doc(data.offerId).get();
    if (!offerDoc.exists) {
      return { success: false, error: 'Offer not found' };
    }

    const offer = offerDoc.data()!;
    if (!offer.is_active) {
      return { success: false, error: 'Offer is inactive' };
    }

    // Validate points cost is positive
    if (!offer.points_cost || offer.points_cost <= 0) {
      return { success: false, error: 'Invalid offer: points cost must be positive' };
    }

    // Verify merchant exists
    const merchantDoc = await deps.db.collection('merchants').doc(data.merchantId).get();
    if (!merchantDoc.exists) {
      return { success: false, error: 'Merchant not found' };
    }

    // Qatar Spec Requirement 6: Rate limiting and abuse detection
    const rateLimitKey = `qr_gen_${data.userId}_${data.deviceHash}`;
    const rateLimitRef = deps.db.collection('rate_limits').doc(rateLimitKey);
    const rateLimitDoc = await rateLimitRef.get();

    const now = new Date();
    const hourAgo = new Date(now.getTime() - 3600000);

    if (rateLimitDoc.exists) {
      const rateLimitData = rateLimitDoc.data()!;
      const lastAttempt = rateLimitData.last_attempt?.toDate();
      const attemptCount = rateLimitData.attempt_count || 0;

      if (lastAttempt && lastAttempt < hourAgo) {
        await rateLimitRef.set({
          attempt_count: 1,
          last_attempt: FieldValue.serverTimestamp(),
          user_id: data.userId,
          device_hash: data.deviceHash,
        });
      } else if (attemptCount >= 10) {
        return { success: false, error: 'Too many redemption attempts. Please try again later.' };
      } else {
        await rateLimitRef.update({
          attempt_count: FieldValue.increment(1),
          last_attempt: FieldValue.serverTimestamp(),
        });
      }
    } else {
      await rateLimitRef.set({
        attempt_count: 1,
        last_attempt: FieldValue.serverTimestamp(),
        user_id: data.userId,
        device_hash: data.deviceHash,
      });
    }

    // Check monthly redemption
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

    const existingRedemption = await deps.db
      .collection('redemptions')
      .where('user_id', '==', data.userId)
      .where('offer_id', '==', data.offerId)
      .where('status', '==', 'completed')
      .where('created_at', '>=', Timestamp.fromDate(startOfMonth))
      .where('created_at', '<=', Timestamp.fromDate(endOfMonth))
      .limit(1)
      .get();

    if (!existingRedemption.empty) {
      return { success: false, error: 'Offer already redeemed this month. Try again next month.' };
    }

    // Generate secure token
    const timestamp = Date.now();
    const expiresAt = new Date(timestamp + 60000);
    const nonce = crypto.randomBytes(16).toString('hex');

    // Qatar Spec Requirement: Generate one-time PIN per redemption (rotates every time)
    const oneTimePin = Math.floor(100000 + Math.random() * 900000).toString();

    const payload = {
      userId: data.userId,
      offerId: data.offerId,
      merchantId: data.merchantId,
      deviceHash: data.deviceHash,
      geoLat: data.geoLat,
      geoLng: data.geoLng,
      partySize: data.partySize,
      timestamp,
      expiresAt: expiresAt.getTime(),
      nonce,
    };

    const signature = crypto
      .createHmac('sha256', deps.secret)
      .update(JSON.stringify(payload))
      .digest('hex');

    const token = Buffer.from(JSON.stringify({ ...payload, signature })).toString('base64');
    const displayCode = Math.floor(100000 + Math.random() * 900000).toString();

    await deps.db
      .collection('qr_tokens')
      .doc(nonce)
      .set({
        user_id: data.userId,
        offer_id: data.offerId,
        merchant_id: data.merchantId,
        display_code: displayCode,
        one_time_pin: oneTimePin,
        pin_attempts: 0,
        pin_verified: false,
        created_at: FieldValue.serverTimestamp(),
        expires_at: Timestamp.fromDate(expiresAt),
        used: false,
        device_hash: data.deviceHash,
      });

    return {
      success: true,
      token,
      displayCode,
      expiresAt: expiresAt.toISOString(),
    };
  } catch (error) {
    console.error('Error generating QR token:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

/**
 * Qatar Spec: Validate one-time PIN for redemption
 * Called by merchant app after QR scan, before final redemption confirmation
 * PIN is single-use and rotates on each redemption attempt
 */
export async function coreValidatePIN(
  data: PinValidationRequest,
  context: QRContext,
  deps: QRDeps
): Promise<PinValidationResponse> {
  try {
    // Auth check (merchant must be authenticated)
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    // Find token by display code
    const tokenQuery = await deps.db
      .collection('qr_tokens')
      .where('display_code', '==', data.displayCode)
      .where('merchant_id', '==', data.merchantId)
      .where('used', '==', false)
      .limit(1)
      .get();

    if (tokenQuery.empty) {
      return { success: false, error: 'QR code not found or already used' };
    }

    const tokenDoc = tokenQuery.docs[0];
    const tokenData = tokenDoc.data();

    // Check token expiry
    if (Date.now() > tokenData.expires_at.toMillis()) {
      return { success: false, error: 'QR code expired' };
    }

    // Check PIN attempts (max 3 attempts)
    if ((tokenData.pin_attempts || 0) >= 3) {
      return { success: false, error: 'Too many PIN attempts. QR code locked.' };
    }

    // Validate PIN
    if (data.pin !== tokenData.one_time_pin) {
      // Increment failed attempts
      await tokenDoc.ref.update({
        pin_attempts: FieldValue.increment(1),
      });
      const remainingAttempts = 3 - ((tokenData.pin_attempts || 0) + 1);
      return { 
        success: false, 
        error: `Invalid PIN. ${remainingAttempts} attempts remaining.` 
      };
    }

    // PIN verified - get offer details for display
    const offerDoc = await deps.db.collection('offers').doc(tokenData.offer_id).get();
    if (!offerDoc.exists) {
      return { success: false, error: 'Offer not found' };
    }
    const offer = offerDoc.data()!;

    // Get customer name
    const customerDoc = await deps.db.collection('customers').doc(tokenData.user_id).get();
    const customer = customerDoc.exists ? customerDoc.data() : null;

    // Mark PIN as verified (still need final redemption confirmation from merchant)
    await tokenDoc.ref.update({
      pin_verified: true,
      pin_verified_at: FieldValue.serverTimestamp(),
      pin_attempts: 0,
    });

    return {
      success: true,
      tokenNonce: tokenDoc.id,
      offerTitle: offer.title,
      customerName: customer?.name || 'Customer',
      pointsCost: offer.points_cost || 0,
    };
  } catch (error) {
    console.error('Error validating PIN:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}
