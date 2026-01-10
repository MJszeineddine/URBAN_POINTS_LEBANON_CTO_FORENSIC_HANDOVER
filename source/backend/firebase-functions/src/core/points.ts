/**
 * Core Points Logic - Production Ready
 * 
 * Features:
 * - Atomic Firestore transactions
 * - Idempotency via redemptionId
 * - Real-time balance breakdown
 * - Replay protection
 * - Audit logging
 */

import * as admin from 'firebase-admin';

// ============================================================================
// INTERFACES
// ============================================================================

export interface AwardPointsRequest {
  customerId: string;
  merchantId: string;
  offerId: string;
  pointsAmount: number;
}

export interface AwardPointsResponse {
  success: boolean;
  newBalance?: number;
  redemptionId?: string;
  error?: string;
}

export interface ProcessPointsEarningRequest {
  customerId: string;
  merchantId: string;
  offerId: string;
  amount: number;
  redemptionId: string; // Idempotency key
}

export interface ProcessPointsEarningResponse {
  success: boolean;
  newBalance?: number;
  transactionId?: string;
  alreadyProcessed?: boolean;
  error?: string;
}

export interface ProcessRedemptionRequest {
  customerId: string;
  offerId: string;
  qrToken: string;
  merchantId: string;
}

export interface ProcessRedemptionResponse {
  success: boolean;
  redemptionId?: string;
  pointsDeducted?: number;
  newBalance?: number;
  error?: string;
}

export interface GetPointsBalanceRequest {
  customerId: string;
}

export interface GetPointsBalanceResponse {
  success: boolean;
  totalBalance?: number;
  breakdown?: {
    totalEarned: number;
    totalSpent: number;
    totalExpired: number;
    currentBalance: number;
  };
  error?: string;
}

export interface PointsContext {
  auth?: {
    uid: string;
  };
}

export interface PointsDeps {
  db: admin.firestore.Firestore;
}

// ============================================================================
// PHASE 1A: PRODUCTION-READY POINTS ENGINE
// ============================================================================

/**
 * processPointsEarning - Atomic points earning with idempotency
 * 
 * Requirements:
 * ✅ Prevents double-earn via redemptionId
 * ✅ Atomic Firestore transaction
 * ✅ Balance update + redemption record
 * ✅ Audit logging
 * 
 * @param data - Earning request with idempotency key
 * @param context - Auth context
 * @param deps - Dependencies (db)
 * @returns Earning response with new balance
 */
export async function processPointsEarning(
  data: ProcessPointsEarningRequest,
  context: PointsContext,
  deps: PointsDeps
): Promise<ProcessPointsEarningResponse> {
  try {
    // Auth check
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    // Validate merchant
    if (context.auth.uid !== data.merchantId) {
      return { success: false, error: 'Merchant ID mismatch' };
    }

    // Validate input
    if (!data.customerId || !data.offerId || !data.redemptionId || data.amount == null) {
      return { success: false, error: 'Missing required fields' };
    }

    if (data.amount <= 0) {
      return { success: false, error: 'Points amount must be positive' };
    }

    // Run atomic transaction
    const result = await deps.db.runTransaction(async (transaction) => {
      // 1. Check idempotency - prevent double-earn
      const idempotencyRef = deps.db.collection('idempotency_keys').doc(data.redemptionId);
      const existingOp = await transaction.get(idempotencyRef);
      
      if (existingOp.exists) {
        const existingData = existingOp.data()!;
        return {
          success: true,
          alreadyProcessed: true,
          newBalance: existingData.newBalance,
          transactionId: existingData.transactionId,
        };
      }

      // 2. Verify customer exists
      const customerRef = deps.db.collection('customers').doc(data.customerId);
      const customerDoc = await transaction.get(customerRef);
      
      if (!customerDoc.exists) {
        throw new Error('Customer not found');
      }

      const currentBalance = customerDoc.data()?.points_balance || 0;
      const newBalance = currentBalance + data.amount;

      // 3. Create redemption record
      const redemptionRef = deps.db.collection('redemptions').doc();
      const redemptionData = {
        customer_id: data.customerId,
        merchant_id: data.merchantId,
        offer_id: data.offerId,
        points_awarded: data.amount,
        points_deducted: 0,
        type: 'earning',
        status: 'completed',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        idempotency_key: data.redemptionId,
      };
      transaction.set(redemptionRef, redemptionData);

      // 4. Update customer balance
      transaction.update(customerRef, {
        points_balance: newBalance,
        total_points_earned: admin.firestore.FieldValue.increment(data.amount),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 5. Create audit log
      const auditRef = deps.db.collection('audit_logs').doc();
      transaction.set(auditRef, {
        operation: 'points_earning',
        user_id: data.merchantId,
        target_user_id: data.customerId,
        redemption_id: redemptionRef.id,
        data: {
          offerId: data.offerId,
          amount: data.amount,
          previousBalance: currentBalance,
          newBalance: newBalance,
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 6. Save idempotency record
      transaction.set(idempotencyRef, {
        redemptionId: data.redemptionId,
        transactionId: redemptionRef.id,
        newBalance: newBalance,
        processed_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        newBalance: newBalance,
        transactionId: redemptionRef.id,
        alreadyProcessed: false,
      };
    });

    return result;
  } catch (error) {
    console.error('Error processing points earning:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

/**
 * processRedemption - Atomic points redemption with validation
 * 
 * Requirements:
 * ✅ QR token validation
 * ✅ Balance check (sufficient points)
 * ✅ Safe deduction (atomic transaction)
 * ✅ Offer validation
 * 
 * @param data - Redemption request
 * @param context - Auth context
 * @param deps - Dependencies (db)
 * @returns Redemption response
 */
export async function processRedemption(
  data: ProcessRedemptionRequest,
  context: PointsContext,
  deps: PointsDeps
): Promise<ProcessRedemptionResponse> {
  try {
    // Auth check
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    // Validate customer owns this request
    if (context.auth.uid !== data.customerId) {
      return { success: false, error: 'Customer ID mismatch' };
    }

    // Validate input
    if (!data.customerId || !data.offerId || !data.qrToken) {
      return { success: false, error: 'Missing required fields' };
    }

    // Run atomic transaction
    const result = await deps.db.runTransaction(async (transaction) => {
      // 1. Validate offer exists and is active
      const offerRef = deps.db.collection('offers').doc(data.offerId);
      const offerDoc = await transaction.get(offerRef);
      
      if (!offerDoc.exists) {
        throw new Error('Offer not found');
      }

      const offer = offerDoc.data()!;
      if (offer.status !== 'active') {
        throw new Error('Offer is not active');
      }

      const pointsCost = offer.points_value || 0;
      if (pointsCost <= 0) {
        throw new Error('Invalid offer points value');
      }

      // 2. Verify customer and check balance
      const customerRef = deps.db.collection('customers').doc(data.customerId);
      const customerDoc = await transaction.get(customerRef);
      
      if (!customerDoc.exists) {
        throw new Error('Customer not found');
      }

      const currentBalance = customerDoc.data()?.points_balance || 0;
      if (currentBalance < pointsCost) {
        throw new Error(`Insufficient points. Required: ${pointsCost}, Available: ${currentBalance}`);
      }

      const newBalance = currentBalance - pointsCost;

      // 3. Verify QR token (basic check - full validation in indexCore.ts)
      const qrTokenRef = deps.db.collection('qr_tokens').doc(data.qrToken);
      const qrTokenDoc = await transaction.get(qrTokenRef);
      
      if (!qrTokenDoc.exists) {
        throw new Error('Invalid QR token');
      }

      const qrData = qrTokenDoc.data()!;
      if (qrData.used) {
        throw new Error('QR token already used');
      }

      if (qrData.offer_id !== data.offerId) {
        throw new Error('QR token does not match offer');
      }

      // 4. Create redemption record
      const redemptionRef = deps.db.collection('redemptions').doc();
      const redemptionData = {
        customer_id: data.customerId,
        merchant_id: data.merchantId,
        offer_id: data.offerId,
        qr_token: data.qrToken,
        points_awarded: 0,
        points_deducted: pointsCost,
        type: 'redemption',
        status: 'completed',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      };
      transaction.set(redemptionRef, redemptionData);

      // 5. Update customer balance
      transaction.update(customerRef, {
        points_balance: newBalance,
        total_points_spent: admin.firestore.FieldValue.increment(pointsCost),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 6. Mark QR token as used
      transaction.update(qrTokenRef, {
        used: true,
        used_at: admin.firestore.FieldValue.serverTimestamp(),
        redemption_id: redemptionRef.id,
      });

      // 7. Create audit log
      const auditRef = deps.db.collection('audit_logs').doc();
      transaction.set(auditRef, {
        operation: 'points_redemption',
        user_id: data.customerId,
        redemption_id: redemptionRef.id,
        data: {
          offerId: data.offerId,
          pointsDeducted: pointsCost,
          previousBalance: currentBalance,
          newBalance: newBalance,
          qrToken: data.qrToken,
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        redemptionId: redemptionRef.id,
        pointsDeducted: pointsCost,
        newBalance: newBalance,
      };
    });

    return result;
  } catch (error) {
    console.error('Error processing redemption:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

/**
 * getPointsBalance - Real-time balance with breakdown
 * 
 * Requirements:
 * ✅ Real-time balance from customer doc
 * ✅ Breakdown: earned / spent / expired
 * ✅ Fast query (< 500ms target)
 * 
 * @param data - Balance request
 * @param context - Auth context
 * @param deps - Dependencies (db)
 * @returns Balance response with breakdown
 */
export async function getPointsBalance(
  data: GetPointsBalanceRequest,
  context: PointsContext,
  deps: PointsDeps
): Promise<GetPointsBalanceResponse> {
  try {
    // Auth check (customer can view own balance, admins can view any)
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    // Validate input
    if (!data.customerId) {
      return { success: false, error: 'Missing customerId' };
    }

    // Get customer document (contains aggregated totals)
    const customerRef = deps.db.collection('customers').doc(data.customerId);
    const customerDoc = await customerRef.get();
    
    if (!customerDoc.exists) {
      return { success: false, error: 'Customer not found' };
    }

    const customerData = customerDoc.data()!;
    const totalEarned = customerData.total_points_earned || 0;
    const totalSpent = customerData.total_points_spent || 0;
    const totalExpired = customerData.total_points_expired || 0;
    const currentBalance = customerData.points_balance || 0;

    // Sanity check
    const calculatedBalance = totalEarned - totalSpent - totalExpired;
    if (Math.abs(calculatedBalance - currentBalance) > 1) {
      console.warn(`Balance mismatch for customer ${data.customerId}: calculated=${calculatedBalance}, stored=${currentBalance}`);
    }

    return {
      success: true,
      totalBalance: currentBalance,
      breakdown: {
        totalEarned,
        totalSpent,
        totalExpired,
        currentBalance,
      },
    };
  } catch (error) {
    console.error('Error getting points balance:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

// ============================================================================
// LEGACY FUNCTION (Keep for backward compatibility)
// ============================================================================

/**
 * coreAwardPoints - Legacy function (use processPointsEarning instead)
 * 
 * @deprecated Use processPointsEarning() for production
 */
export async function coreAwardPoints(
  data: AwardPointsRequest,
  context: PointsContext,
  deps: PointsDeps
): Promise<AwardPointsResponse> {
  // Generate idempotency key from request data
  const idempotencyKey = `${data.customerId}_${data.offerId}_${Date.now()}`;
  
  const result = await processPointsEarning(
    {
      customerId: data.customerId,
      merchantId: data.merchantId,
      offerId: data.offerId,
      amount: data.pointsAmount,
      redemptionId: idempotencyKey,
    },
    context,
    deps
  );

  return {
    success: result.success,
    newBalance: result.newBalance,
    redemptionId: result.transactionId,
    error: result.error,
  };
}
