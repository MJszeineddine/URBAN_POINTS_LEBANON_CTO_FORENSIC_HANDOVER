/**
 * Manual Payment Processing via Whish Money & OMT
 * Handles cash-based subscriptions for Lebanese market
 * Users deposit funds at local Whish/OMT outlets, admins verify and activate subscriptions
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Lazy initialization
const getDb = () => admin.firestore();

interface RecordManualPaymentRequest {
  userId: string;
  merchantId?: string; // For merchant subscriptions
  service: 'WHISH' | 'OMT';
  amount: number;
  currency: 'LBP' | 'USD';
  receiptNumber: string;
  paidAt?: string; // ISO date string
  agentName?: string;
  agentLocation?: string;
}

interface RecordManualPaymentResponse {
  success: boolean;
  paymentId?: string;
  error?: string;
}

interface ApproveManualPaymentRequest {
  paymentId: string;
  planId: string;
}

interface ApproveManualPaymentResponse {
  success: boolean;
  subscriptionId?: string;
  error?: string;
}

interface RejectManualPaymentRequest {
  paymentId: string;
  reason: string;
}

interface RejectManualPaymentResponse {
  success: boolean;
  error?: string;
}

interface GetManualPaymentsResponse {
  success: boolean;
  payments?: any[];
  error?: string;
}

/**
 * Record Manual Payment
 * 
 * Allows authenticated users to submit manual payment receipts
 * Validates receipt number format and checks for duplicates
 * Stores payment for admin approval
 * 
 * @param data - Payment receipt details
 * @param context - Auth context
 * @returns Payment ID for tracking
 */
export const recordManualPayment = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onCall(async (data: RecordManualPaymentRequest, context): Promise<RecordManualPaymentResponse> => {
    try {
      if (!context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      // Validate required fields
      if (!data.service || !data.amount || !data.currency || !data.receiptNumber) {
        return { success: false, error: 'Missing required fields: service, amount, currency, receiptNumber' };
      }

      // Validate service
      if (!['WHISH', 'OMT'].includes(data.service)) {
        return { success: false, error: 'Service must be WHISH or OMT' };
      }

      // Validate amount
      if (data.amount <= 0) {
        return { success: false, error: 'Amount must be greater than zero' };
      }

      // Validate currency
      if (!['LBP', 'USD'].includes(data.currency)) {
        return { success: false, error: 'Currency must be LBP or USD' };
      }

      // Validate receipt number format (e.g., "WM-2024-001234" or "OMT-2024-567890")
      const receiptPattern = /^(WM|OMT)-\d{4}-\d{6}$/i;
      if (!receiptPattern.test(data.receiptNumber)) {
        return { success: false, error: 'Invalid receipt number format. Use: SERVICE-YEAR-NUMBER (e.g., WM-2024-001234)' };
      }

      // Check for duplicate receipt submission
      const existingPayment = await getDb()
        .collection('manual_payments')
        .where('receipt_number', '==', data.receiptNumber)
        .where('status', 'in', ['pending', 'approved'])
        .limit(1)
        .get();

      if (!existingPayment.empty) {
        return { success: false, error: 'Receipt number already submitted. Duplicates not allowed.' };
      }

      // Parse or use current time
      const paidAt = data.paidAt ? new Date(data.paidAt) : new Date();

      // Create payment record
      const paymentId = getDb().collection('manual_payments').doc().id;
      
      await getDb().collection('manual_payments').doc(paymentId).set({
        user_id: data.userId,
        merchant_id: data.merchantId || null,
        service: data.service,
        amount: data.amount,
        currency: data.currency,
        receipt_number: data.receiptNumber,
        agent_name: data.agentName || null,
        agent_location: data.agentLocation || null,
        paid_at: admin.firestore.Timestamp.fromDate(paidAt),
        submitted_at: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending', // pending, approved, rejected
        processed: false,
        approval_note: null,
        approved_by: null,
        approved_at: null,
        subscription_id: null,
        plan_id: null,
      });

      // Log payment submission
      await getDb().collection('audit_logs').add({
        action: 'manual_payment_submitted',
        user_id: data.userId,
        payment_id: paymentId,
        service: data.service,
        amount: data.amount,
        receipt_number: data.receiptNumber,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        paymentId,
      };

    } catch (error) {
      console.error('Error recording manual payment:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });

/**
 * Approve Manual Payment
 * 
 * Admin function to approve payment and activate subscription
 * Creates subscription record and marks payment as processed
 * 
 * @param data - Payment approval details
 * @param context - Auth context (admin only)
 * @returns Success status and subscription ID
 */
export const approveManualPayment = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onCall(async (data: ApproveManualPaymentRequest, context): Promise<ApproveManualPaymentResponse> => {
    try {
      if (!context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      // Verify admin rights
      const adminDoc = await getDb().collection('admins').doc(context.auth.uid).get();
      if (!adminDoc.exists) {
        return { success: false, error: 'Admin access required' };
      }

      if (!data.paymentId || !data.planId) {
        return { success: false, error: 'Payment ID and Plan ID required' };
      }

      // Get payment record
      const paymentDoc = await getDb().collection('manual_payments').doc(data.paymentId).get();
      if (!paymentDoc.exists) {
        return { success: false, error: 'Payment not found' };
      }

      const payment = paymentDoc.data() as any;

      if (payment.status !== 'pending') {
        return { success: false, error: `Payment already ${payment.status}` };
      }

      // Get plan details
      const planDoc = await getDb().collection('subscription_plans').doc(data.planId).get();
      if (!planDoc.exists) {
        return { success: false, error: 'Plan not found' };
      }

      const plan = planDoc.data() as any;

      // Validate amount matches plan price
      const expectedAmount = plan.price_lbp; // Assume stored in LBP
      if (payment.currency === 'LBP' && payment.amount < expectedAmount * 0.95) {
        // Allow 5% variance for currency fluctuation
        return { success: false, error: `Payment amount ${payment.amount} does not match plan price ${expectedAmount}` };
      }

      // Create subscription record
      const subscriptionId = getDb().collection('subscriptions').doc().id;
      const now = new Date();
      const endDate = new Date(now);
      endDate.setMonth(endDate.getMonth() + 1); // 1 month subscription

      await getDb().collection('subscriptions').doc(subscriptionId).set({
        user_id: payment.user_id,
        merchant_id: payment.merchant_id || null,
        plan_id: data.planId,
        payment_method: 'manual', // Track payment method
        status: 'active',
        start_date: admin.firestore.Timestamp.fromDate(now),
        end_date: admin.firestore.Timestamp.fromDate(endDate),
        is_trial: false,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        manual_payment_id: data.paymentId,
        cancelled_at: null,
      });

      // Update payment record
      await paymentDoc.ref.update({
        status: 'approved',
        processed: true,
        approved_by: context.auth.uid,
        approved_at: admin.firestore.FieldValue.serverTimestamp(),
        subscription_id: subscriptionId,
        plan_id: data.planId,
      });

      // Update user/merchant subscription status in customers or merchants collection
      const isCustomer = await getDb().collection('customers').doc(payment.user_id).get();
      if (isCustomer.exists) {
        await isCustomer.ref.update({
          subscription_status: 'active',
          subscription_plan: data.planId,
          subscription_end_date: admin.firestore.Timestamp.fromDate(endDate),
        });
      } else {
        // Check if merchant
        const isMerchant = await getDb().collection('merchants').doc(payment.user_id).get();
        if (isMerchant.exists) {
          await isMerchant.ref.update({
            subscription_status: 'active',
            subscription_plan: data.planId,
            subscription_end_date: admin.firestore.Timestamp.fromDate(endDate),
          });
        }
      }

      // Log approval
      await getDb().collection('audit_logs').add({
        action: 'manual_payment_approved',
        admin_id: context.auth.uid,
        payment_id: data.paymentId,
        subscription_id: subscriptionId,
        amount: payment.amount,
        currency: payment.currency,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        subscriptionId,
      };

    } catch (error) {
      console.error('Error approving manual payment:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });

/**
 * Reject Manual Payment
 * 
 * Admin function to reject payment submission
 * 
 * @param data - Rejection details
 * @param context - Auth context (admin only)
 * @returns Success status
 */
export const rejectManualPayment = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onCall(async (data: RejectManualPaymentRequest, context): Promise<RejectManualPaymentResponse> => {
    try {
      if (!context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      // Verify admin rights
      const adminDoc = await getDb().collection('admins').doc(context.auth.uid).get();
      if (!adminDoc.exists) {
        return { success: false, error: 'Admin access required' };
      }

      if (!data.paymentId) {
        return { success: false, error: 'Payment ID required' };
      }

      // Get payment record
      const paymentDoc = await getDb().collection('manual_payments').doc(data.paymentId).get();
      if (!paymentDoc.exists) {
        return { success: false, error: 'Payment not found' };
      }

      const payment = paymentDoc.data() as any;

      if (payment.status !== 'pending') {
        return { success: false, error: `Payment already ${payment.status}` };
      }

      // Update payment record
      await paymentDoc.ref.update({
        status: 'rejected',
        processed: true,
        approval_note: data.reason,
        approved_by: context.auth.uid,
        approved_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Log rejection
      await getDb().collection('audit_logs').add({
        action: 'manual_payment_rejected',
        admin_id: context.auth.uid,
        payment_id: data.paymentId,
        reason: data.reason,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };

    } catch (error) {
      console.error('Error rejecting manual payment:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });

/**
 * Get Pending Manual Payments
 * 
 * Admin function to fetch all pending manual payments for review
 * 
 * @param data - Unused
 * @param context - Auth context (admin only)
 * @returns List of pending payments
 */
export const getPendingManualPayments = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onCall(async (data: any, context): Promise<GetManualPaymentsResponse> => {
    try {
      if (!context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      // Verify admin rights
      const adminDoc = await getDb().collection('admins').doc(context.auth.uid).get();
      if (!adminDoc.exists) {
        return { success: false, error: 'Admin access required' };
      }

      // Get pending payments
      const pendingSnapshot = await getDb()
        .collection('manual_payments')
        .where('status', '==', 'pending')
        .orderBy('submitted_at', 'desc')
        .limit(100)
        .get();

      const payments = pendingSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));

      return {
        success: true,
        payments,
      };

    } catch (error) {
      console.error('Error getting pending manual payments:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });

/**
 * Get Manual Payment History
 * 
 * User function to fetch their manual payment submissions and status
 * 
 * @param data - Unused
 * @param context - Auth context (user)
 * @returns User's payment history
 */
export const getManualPaymentHistory = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onCall(async (data: any, context): Promise<GetManualPaymentsResponse> => {
    try {
      if (!context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      const userId = context.auth.uid;

      // Get user's payments
      const paymentsSnapshot = await getDb()
        .collection('manual_payments')
        .where('user_id', '==', userId)
        .orderBy('submitted_at', 'desc')
        .limit(50)
        .get();

      const payments = paymentsSnapshot.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          service: data.service,
          amount: data.amount,
          currency: data.currency,
          status: data.status,
          receipt_number: data.receipt_number,
          submitted_at: data.submitted_at,
          approved_at: data.approved_at,
          subscription_id: data.subscription_id,
        };
      });

      return {
        success: true,
        payments,
      };

    } catch (error) {
      console.error('Error getting manual payment history:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });
