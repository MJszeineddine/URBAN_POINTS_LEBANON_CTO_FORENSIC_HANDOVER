/**
 * Urban Points Lebanon - Firebase Cloud Functions
 * Session 2: Core Backend Logic
 * Session 3: Privacy & Compliance
 * 
 * Core Functions:
 * 1. generateSecureQRToken - Generate time-limited QR codes for redemption
 * 2. validateRedemption - Validate and process redemption requests
 * 3. calculateDailyStats - Aggregate daily statistics
 * 
 * Privacy Functions (from privacy.ts):
 * 4. exportUserData - GDPR data export
 * 5. deleteUserData - GDPR right to erasure
 * 6. cleanupExpiredData - Automated data retention
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { initializeMonitoring, monitorFunction } from './monitoring';
import Logger from './logger';

// Validation and rate limiting
import { validateAndRateLimit, isValidationError } from './middleware/validation';
import {
  ProcessPointsEarningSchema,
  ProcessRedemptionSchema,
  CreateOfferSchema,
} from './validation/schemas';

// Initialize Firebase Admin (avoid re-initialization in tests)
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// Initialize monitoring and logging (Sentry + Winston)
initializeMonitoring();
Logger.info('Urban Points Lebanon Functions starting', {
  environment: process.env.FUNCTIONS_EMULATOR === 'true' ? 'development' : 'production'
});

// Qatar Spec Requirement: HMAC secret validation - fail hard if missing in production
// Secret Manager integration: Secrets are read from environment variables or Firebase config
// QR_TOKEN_SECRET is required in production for secure QR code generation
if (!process.env.FUNCTIONS_EMULATOR && !process.env.QR_TOKEN_SECRET && !functions.config().secrets?.qr_token_secret) {
  Logger.warn('QR_TOKEN_SECRET not configured. QR codes will use default fallback (not recommended for production)');
}

// ============================================================================
// DAY 1 INTEGRATION: Authentication Functions
// ============================================================================
export {
  onUserCreate,
  setCustomClaims,
  verifyEmailComplete,
  getUserProfile,
} from './auth';

// Admin moderation callables for users/merchants/offers
export {
  adminUpdateUserRole,
  adminBanUser,
  adminUnbanUser,
  adminUpdateMerchantStatus,
  adminDisableOffer,
} from './adminModeration';

// Export privacy functions (non-scheduled only)
// Note: cleanupExpiredData is SCHEDULED - disabled until Cloud Scheduler API enabled
export { exportUserData, deleteUserData } from './privacy';

// Export SMS functions (non-scheduled only)
// Note: cleanupExpiredOTPs is SCHEDULED - disabled until Cloud Scheduler API enabled
export { sendSMS, verifyOTP } from './sms';

// Export WhatsApp Verification functions (Twilio WhatsApp Business API)
export { 
  sendWhatsAppMessage, 
  sendWhatsAppOTP, 
  verifyWhatsAppOTP, 
  getWhatsAppVerificationStatus,
  cleanupExpiredWhatsAppOTPs,
} from './whatsapp';

// Export Manual Payment functions (Whish/OMT cash-based payments)
export {
  recordManualPayment,
  approveManualPayment,
  rejectManualPayment,
  getPendingManualPayments,
  getManualPaymentHistory,
} from './manualPayments';

// Export payment webhook functions - ENABLED
export { omtWebhook, whishWebhook, cardWebhook } from './paymentWebhooks';

// Export subscription automation functions (schedulers now enabled)
export {
  processSubscriptionRenewals,       // SCHEDULED - now enabled
  sendExpiryReminders,                // SCHEDULED - now enabled
  cleanupExpiredSubscriptions,        // SCHEDULED - now enabled
  calculateSubscriptionMetrics,       // SCHEDULED - now enabled
} from './subscriptionAutomation';

// Export Stripe functions - ENABLED
export {
  stripeWebhook,
  createCheckoutSession,
  createBillingPortalSession,
  initiatePaymentCallable,
} from './stripe';

// Export phase3 scheduler functions - ENABLED
export {
  notifyOfferStatusChange,            // Firestore trigger
  enforceMerchantCompliance,          // SCHEDULED - now enabled
  cleanupExpiredQRTokens,             // SCHEDULED - now enabled
  sendPointsExpiryWarnings,           // SCHEDULED - now enabled
} from './phase3Scheduler';

// Export push campaign functions (non-scheduled only)
// Note: processScheduledCampaigns is SCHEDULED - disabled until Cloud Scheduler API enabled
export {
  sendPersonalizedNotification,
  scheduleCampaign,
} from './pushCampaigns';

// Export observability test hook (emulator/test only)
export { obsTestHook } from './obsTestHook';

// ============================================================================
// FUNCTION 1: Generate Secure QR Token
// ============================================================================

interface QRTokenRequest {
  userId: string;
  offerId: string;
  merchantId: string;
  deviceHash: string;
  geoLat?: number;
  geoLng?: number;
  partySize: number;
}

interface QRTokenResponse {
  success: boolean;
  token?: string;
  displayCode?: string;
  expiresAt?: string;
  error?: string;
}

/**
 * Generates a secure, time-limited QR token for offer redemption
 * 
 * Security features:
 * - 60-second expiry
 * - Device binding
 * - Cryptographic signature
 * - Single-use enforcement
 * 
 * @param data - Request data with user, offer, and device info
 * @returns Secure token and display code
 */
import { coreGenerateSecureQRToken, coreValidatePIN, revokeQRToken, getQRHistory, detectFraudPatterns } from './core/qr';
import { coreCalculateDailyStats, coreApproveOffer, coreRejectOffer, coreGetMerchantComplianceStatus } from './core/admin';
import { coreAwardPoints, processPointsEarning, processRedemption, getPointsBalance } from './core/points';
import { createOffer, updateOfferStatus, handleOfferExpiration, aggregateOfferStats, getOffersByLocation, editOffer, cancelOffer, getOfferEditHistory } from './core/offers';
import { coreValidateRedemption } from './core/indexCore';

export const generateSecureQRToken = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('generateSecureQRToken', async (data: QRTokenRequest, context): Promise<QRTokenResponse> => {
    const secret = process.env.QR_TOKEN_SECRET;
    if (!secret) {
      console.error('CRITICAL: QR_TOKEN_SECRET environment variable not set');
      return { success: false, error: 'System configuration error' };
    }
    return coreGenerateSecureQRToken(data, context, { db, secret });
  }));

// ============================================================================
// FUNCTION 1B: Validate PIN (Qatar Spec - one-time PIN per redemption)
// ============================================================================

interface PINValidationRequest {
  merchantId: string;
  displayCode: string;
  pin: string;
}

interface PINValidationResponse {
  success: boolean;
  tokenNonce?: string;
  offerTitle?: string;
  customerName?: string;
  pointsCost?: number;
  error?: string;
}

/**
 * Validates one-time PIN for offer redemption
 * 
 * Qatar Spec Requirement:
 * - One-time PIN generated per redemption
 * - PIN rotates every redemption (new PIN on each QR scan)
 * - Max 3 attempts before QR code lock
 * 
 * Called by Merchant App after scanning QR code
 * 
 * @param data - Merchant ID, display code, and PIN
 * @returns PIN validation result with offer details
 */
export const validatePIN = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('validatePIN', async (data: PINValidationRequest, context): Promise<PINValidationResponse> => {
    const secret = process.env.QR_TOKEN_SECRET;
    if (!secret) {
      console.error('CRITICAL: QR_TOKEN_SECRET environment variable not set');
      return { success: false, error: 'System configuration error' };
    }
    return coreValidatePIN(data, context, { db, secret });
  }));

// ============================================================================
// V3: QR History & Revocation Functions
// ============================================================================

/**
 * revokeQRTokenCallable - Customer or admin revokes QR token
 */
export const revokeQRTokenCallable = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('revokeQRTokenCallable', async (data, context) => {
    const secret = process.env.QR_TOKEN_SECRET || 'urban-points-lebanon-secret-key';
    return revokeQRToken(data, context, { db, secret });
  }));

/**
 * getQRHistoryCallable - Retrieve QR token history
 */
export const getQRHistoryCallable = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('getQRHistoryCallable', async (data, context) => {
    const secret = process.env.QR_TOKEN_SECRET || 'urban-points-lebanon-secret-key';
    return getQRHistory(data, context, { db, secret });
  }));

/**
 * detectFraudPatternsCallable - Admin fraud detection analysis
 */
export const detectFraudPatternsCallable = functions
  .region('us-central1')
  .runWith({
    memory: '512MB',
    timeoutSeconds: 120,
    minInstances: 0,
    maxInstances: 5
  })
  .https.onCall(monitorFunction('detectFraudPatternsCallable', async (data, context) => {
    const secret = process.env.QR_TOKEN_SECRET || 'urban-points-lebanon-secret-key';
    return detectFraudPatterns(data, context, { db, secret });
  }));

// ============================================================================
// FUNCTION 2: Validate Redemption
// ============================================================================

interface RedemptionRequest {
  token?: string;
  displayCode?: string;
  pin?: string;
  merchantId: string;
  staffId?: string;
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
 * Validates and processes a redemption request
 * 
 * Security checks:
 * - Token expiry validation
 * - Merchant verification
 * - Single-use enforcement
 * - Device binding check
 * 
 * @param data - Token or display code with merchant info
 * @returns Redemption result with details
 */
export const validateRedemption = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('validateRedemption', async (data: RedemptionRequest, context): Promise<RedemptionResponse> => {
    const secret = process.env.QR_TOKEN_SECRET || 'urban-points-lebanon-secret-key';
    return coreValidateRedemption({ data, context, deps: { db, secret } });
  }));

// ============================================================================
// FUNCTION 3: Calculate Daily Stats
// ============================================================================

interface DailyStatsResponse {
  success: boolean;
  date?: string;
  stats?: {
    totalRedemptions: number;
    totalPointsRedeemed: number;
    uniqueCustomers: number;
    topMerchants: Array<{ merchantId: string; redemptionCount: number }>;
    averagePointsPerRedemption: number;
  };
  error?: string;
}

/**
 * Calculates and caches daily statistics
 * 
 * Aggregations:
 * - Total redemptions
 * - Points redeemed
 * - Unique customers
 * - Top merchants
 * - Average points per redemption
 * 
 * @param data - Date to calculate (defaults to today)
 * @returns Aggregated statistics
 */
// ============================================================================
// FUNCTION 4: Award Points
// ============================================================================

interface AwardPointsRequest {
  customerId: string;
  merchantId: string;
  offerId: string;
  pointsAmount: number;
}

interface AwardPointsResponse {
  success: boolean;
  newBalance?: number;
  redemptionId?: string;
  error?: string;
}

/**
 * Awards points to a customer and creates redemption record
 * 
 * Features:
 * - Atomic transaction
 * - Redemption record creation
 * - Points balance update
 * - Merchant verification
 * 
 * @param data - Award request with customer, merchant, offer, and points
 * @returns Updated balance and redemption ID
 */
export const awardPoints = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(async (data: AwardPointsRequest, context): Promise<AwardPointsResponse> => {
    return coreAwardPoints(data, context, { db });
  });

// ============================================================================
// FUNCTION 5: Calculate Daily Stats
// ============================================================================

// Alias for test compatibility
export const validateQRToken = validateRedemption;

// ============================================================================
// FUNCTION 4B: Get Offers by Location (Qatar Spec - proximity sorting)
// ============================================================================

interface GetOffersByLocationRequest {
  latitude?: number;
  longitude?: number;
  radius?: number; // kilometers, default 50
  limit?: number; // max results, default 50
  status?: 'active' | 'all';
}

interface OfferWithDistance {
  offerId: string;
  merchantId: string;
  title: string;
  description: string;
  pointsValue: number;
  quota: number;
  quotaUsed: number;
  validFrom: string;
  validUntil: string;
  terms?: string;
  category?: string;
  distance?: number;
  merchantLocation?: {
    latitude: number;
    longitude: number;
  };
  status: string;
}

interface GetOffersByLocationResponse {
  success: boolean;
  offers?: OfferWithDistance[];
  totalCount?: number;
  error?: string;
}

/**
 * getOffersByLocation - Qatar Spec: Offers prioritized by user location
 * - If user provides location: Sort by distance (nearest first)
 * - If no location: Return all active offers
 * - Always include option to view full national catalog
 */
export const getOffersByLocationFunc = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('getOffersByLocation', async (data: GetOffersByLocationRequest, context): Promise<GetOffersByLocationResponse> => {
    return getOffersByLocation(data, { db });
  }));

// ============================================================================
// FUNCTION 5: Calculate Daily Stats
// ============================================================================

export const calculateDailyStats = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 5
  })
  .https.onCall(monitorFunction('calculateDailyStats', async (data: { date?: string }, context): Promise<DailyStatsResponse> => {
    return coreCalculateDailyStats(data, context, { db });
  }));

// ============================================================================
// ADMIN APPROVAL WORKFLOW
// Qatar Spec: Offers must be PENDING → APPROVED/REJECTED
// ============================================================================

/**
 * approveOffer - Admin approves a pending offer
 * Qatar Spec Requirement: Only approved offers can become active
 */
export const approveOffer = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    maxInstances: 5
  })
  .https.onCall(monitorFunction('approveOffer', async (data: { offerId: string }, context) => {
    try {
      return await coreApproveOffer(data, context, { db });
    } catch (error) {
      if (error instanceof Error && error.message.includes(':')) {
        const [code, msg] = error.message.split(':');
        throw new functions.https.HttpsError(code as any, msg);
      }
      throw error;
    }
  }));

/**
 * rejectOffer - Admin rejects a pending offer
 */
export const rejectOffer = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    maxInstances: 5
  })
  .https.onCall(monitorFunction('rejectOffer', async (data: { offerId: string; reason?: string }, context) => {
    try {
      return await coreRejectOffer(data, context, { db });
    } catch (error) {
      if (error instanceof Error && error.message.includes(':')) {
        const [code, msg] = error.message.split(':');
        throw new functions.https.HttpsError(code as any, msg);
      }
      throw error;
    }
  }));

// ============================================================================
// MERCHANT COMPLIANCE MONITORING
// Qatar Spec: Each merchant must create at least 5 offers per calendar month
// ============================================================================

/**
 * checkMerchantCompliance - Scheduled function to check merchant monthly quota
 * DISABLED: Requires Cloud Scheduler API
 * Uncomment and redeploy after enabling: https://console.cloud.google.com/apis/library/cloudscheduler.googleapis.com
 */
// export const checkMerchantCompliance = functions
//   .region('us-central1')
//   .runWith({
//     memory: '512MB',
//     timeoutSeconds: 300
//   })
//   .pubsub.schedule('0 1 * * *')
//   .timeZone('UTC')
//   .onRun(async (context) => {
//     return coreCheckMerchantCompliance({ db });
//   });

/**
 * getMerchantComplianceStatus - Get compliance status for dashboard
 */
export const getMerchantComplianceStatus = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    maxInstances: 5
  })
  .https.onCall(async (data, context) => {
    // Verify admin authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const adminDoc = await db.collection('admins').doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    return coreGetMerchantComplianceStatus({ db });
  });

// ============================================================================
// PRODUCTION READY: Points Engine V2
// ============================================================================

/**
 * processPointsEarning - Atomic points earning with idempotency
 * Replaces awardPoints with transaction-safe implementation
 */
export const earnPoints = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('earnPoints', async (data, context) => {
    // Validate and rate limit
    const validated = await validateAndRateLimit(
      data,
      context,
      ProcessPointsEarningSchema,
      'earnPoints'
    );

    // Check if validation failed
    if (isValidationError(validated)) {
      throw new functions.https.HttpsError(
        validated.code,
        validated.error,
        validated.details
      );
    }

    // Process with validated data
    return processPointsEarning(validated, context, { db });
  }));

/**
 * redeemPoints - Atomic points redemption with QR validation
 */
export const redeemPoints = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('redeemPoints', async (data, context) => {
    // Validate and rate limit
    const validated = await validateAndRateLimit(
      data,
      context,
      ProcessRedemptionSchema,
      'redeemPoints'
    );

    // Check if validation failed
    if (isValidationError(validated)) {
      throw new functions.https.HttpsError(
        validated.code,
        validated.error,
        validated.details
      );
    }

    // Process with validated data
    return processRedemption(validated, context, { db });
  }));

/**
 * getPointsBalance - Get customer points balance with breakdown
 */
export const getBalance = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 20
  })
  .https.onCall(monitorFunction('getBalance', async (data, context) => {
    return getPointsBalance(data, context, { db });
  }));

// ============================================================================
// PRODUCTION READY: Offers Engine
// ============================================================================

/**
 * createOffer - Create new offer with validation
 */
export const createNewOffer = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('createNewOffer', async (data, context) => {
    // Validate and rate limit
    const validated = await validateAndRateLimit(
      data,
      context,
      CreateOfferSchema,
      'createOffer'
    );

    // Check if validation failed
    if (isValidationError(validated)) {
      throw new functions.https.HttpsError(
        validated.code,
        validated.error,
        validated.details
      );
    }

    // Process with validated data
    return createOffer(validated, context, { db });
  }));

/**
 * updateOfferStatus - Update offer status with workflow validation
 */
export const updateStatus = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('updateStatus', async (data, context) => {
    return updateOfferStatus(data, context, { db });
  }));

/**
 * expireOffers - Manual trigger to mark expired offers
 * (Scheduled version disabled until Cloud Scheduler API enabled)
 */
export const expireOffers = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 300,
    minInstances: 0,
    maxInstances: 1
  })
  .https.onCall(monitorFunction('expireOffers', async (data, context) => {
    // Admin-only
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const adminDoc = await db.collection('admins').doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    return handleOfferExpiration({ db });
  }));

/**
 * getOfferStats - Get aggregated offer statistics
 */
export const getOfferStats = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('getOfferStats', async (data, context) => {
    return aggregateOfferStats(data, context, { db });
  }));

// ============================================================================
// V3: Offer Edit & Cancel Functions
// ============================================================================

/**
 * editOfferCallable - Merchant edits offer details
 */
export const editOfferCallable = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('editOfferCallable', async (data, context) => {
    return editOffer(data, context, { db });
  }));

/**
 * cancelOfferCallable - Merchant or admin cancels offer
 */
export const cancelOfferCallable = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('cancelOfferCallable', async (data, context) => {
    return cancelOffer(data, context, { db });
  }));

/**
 * getOfferEditHistoryCallable - Retrieve edit history for an offer
 */
export const getOfferEditHistoryCallable = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('getOfferEditHistoryCallable', async (data, context) => {
    return getOfferEditHistory(data, context, { db });
  }));

// ============================================================================
// PHASE 3: Automation, Notifications, and Compliance
// ============================================================================

// Notification service functions (callable + triggered)
export {
  registerFCMToken,
  unregisterFCMToken,
  notifyRedemptionSuccess,
  sendBatchNotification,
} from './phase3Notifications';

// ============================================================================
// V3: Points Expiration & Transfer
// ============================================================================

import { expirePoints as coreExpirePoints, transferPoints as coreTransferPoints } from './core/points';

/**
 * expirePointsScheduled - Daily scheduler to expire old points
 * Runs at 4 AM Lebanon time (UTC+2/+3 depending on DST)
 */
export const expirePointsScheduled = functions
  .region('us-central1')
  .pubsub.schedule('0 4 * * *')
  .timeZone('Asia/Beirut')
  .onRun(monitorFunction('expirePointsScheduled', async () => {
    Logger.info('Starting scheduled points expiration');
    const result = await coreExpirePoints({ dryRun: false }, { auth: { uid: 'system' } }, { db });
    Logger.info('Scheduled points expiration complete', result);
    return null;
  }));

/**
 * expirePointsManual - Manual callable for testing expiration logic
 */
export const expirePointsManual = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 300,
    minInstances: 0,
    maxInstances: 1
  })
  .https.onCall(monitorFunction('expirePointsManual', async (data, context) => {
    // Admin-only
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const adminDoc = await db.collection('admins').doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    return coreExpirePoints(data, context, { db });
  }));

/**
 * transferPointsCallable - Admin-only points transfer between customers
 */
export const transferPointsCallable = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 5
  })
  .https.onCall(monitorFunction('transferPointsCallable', async (data, context) => {
    // Admin-only
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const adminDoc = await db.collection('admins').doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    return coreTransferPoints(data, context, { db });
  }));

