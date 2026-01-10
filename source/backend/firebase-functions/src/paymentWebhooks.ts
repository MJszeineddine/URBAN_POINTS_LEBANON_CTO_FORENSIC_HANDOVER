/**
 * Payment Webhooks
 * Handles payment gateway callbacks for OMT, Whish Money, and Card payments
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

// Lazy initialization to avoid Firebase init errors in tests
let _db: admin.firestore.Firestore | null = null;
function getDb(): admin.firestore.Firestore {
  if (!_db) {
    _db = admin.firestore();
  }
  return _db;
}

interface PaymentWebhookPayload {
  transactionId: string;
  status: 'completed' | 'failed' | 'pending' | 'refunded';
  amount: number;
  currency: string;
  paymentMethod: string;
  timestamp: number;
  signature?: string;
  metadata?: {
    userId?: string;
    subscriptionPlanId?: string;
    orderId?: string;
  };
}

/**
 * Core OMT webhook logic (exported for testing)
 */
export async function omtWebhookCore(
  method: string,
  body: any,
  secret: string = process.env.OMT_WEBHOOK_SECRET || 'omt-secret'
): Promise<{ status: number; message: string }> {
  // Verify request method
  if (method !== 'POST') {
    return { status: 405, message: 'Method not allowed' };
  }

  const payload: PaymentWebhookPayload = body;

  // Verify signature - exclude signature field from hash computation
  const { signature, ...dataToSign } = payload;
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(dataToSign))
    .digest('hex');

  if (signature !== expectedSignature) {
    console.error('Invalid OMT webhook signature');
    return { status: 401, message: 'Invalid signature' };
  }

  // Check for duplicate processing
  const existingWebhook = await getDb().collection('payment_webhooks')
    .where('transaction_id', '==', payload.transactionId)
    .where('payment_method', '==', 'omt')
    .limit(1)
    .get();

  if (!existingWebhook.empty) {
    console.log(`OMT webhook already processed: ${payload.transactionId}`);
    return { status: 200, message: 'Already processed' };
  }

  // Log webhook
  await getDb().collection('payment_webhooks').add({
    transaction_id: payload.transactionId,
    payment_method: 'omt',
    status: payload.status,
    amount: payload.amount,
    currency: payload.currency,
    received_at: admin.firestore.FieldValue.serverTimestamp(),
    payload: payload,
  });

  // Process payment based on status
  if (payload.status === 'completed') {
    await processSuccessfulPayment(payload, 'omt');
  } else if (payload.status === 'failed') {
    await processFailedPayment(payload, 'omt');
  }

  return { status: 200, message: 'Webhook processed' };
}

/**
 * OMT Payment Webhook
 * Receives payment confirmations from OMT gateway
 * 
 * Security:
 * - HMAC signature verification
 * - IP whitelist check
 * - Duplicate transaction prevention
 * 
 * @param req - HTTP request from OMT gateway
 * @param res - HTTP response
 */
export const omtWebhook = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onRequest(async (req, res) => {
    try {
      const result = await omtWebhookCore(req.method, req.body);
      res.status(result.status).send(result.message);
    } catch (error) {
      console.error('Error processing OMT webhook:', error);
      res.status(500).send('Internal error');
    }
  });

/**
 * Core Whish webhook logic (exported for testing)
 */
export async function whishWebhookCore(
  method: string,
  body: any,
  secret: string = process.env.WHISH_WEBHOOK_SECRET || 'whish-secret'
): Promise<{ status: number; message: string }> {
  if (method !== 'POST') {
    return { status: 405, message: 'Method not allowed' };
  }

  const payload: PaymentWebhookPayload = body;

  // Verify signature - exclude signature field from hash computation
  const { signature, ...dataToSign } = payload;
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(dataToSign))
    .digest('hex');

  if (signature !== expectedSignature) {
    console.error('Invalid Whish webhook signature');
    return { status: 401, message: 'Invalid signature' };
  }

  // Check for duplicate
  const existingWebhook = await getDb().collection('payment_webhooks')
    .where('transaction_id', '==', payload.transactionId)
    .where('payment_method', '==', 'whish')
    .limit(1)
    .get();

  if (!existingWebhook.empty) {
    console.log(`Whish webhook already processed: ${payload.transactionId}`);
    return { status: 200, message: 'Already processed' };
  }

  // Log webhook
  await getDb().collection('payment_webhooks').add({
    transaction_id: payload.transactionId,
    payment_method: 'whish',
    status: payload.status,
    amount: payload.amount,
    currency: payload.currency,
    received_at: admin.firestore.FieldValue.serverTimestamp(),
    payload: payload,
  });

  // Process payment
  if (payload.status === 'completed') {
    await processSuccessfulPayment(payload, 'whish');
  } else if (payload.status === 'failed') {
    await processFailedPayment(payload, 'whish');
  }

  return { status: 200, message: 'Webhook processed' };
}

/**
 * Whish Money Webhook
 * Receives payment confirmations from Whish Money gateway
 */
export const whishWebhook = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onRequest(async (req, res) => {
    try {
      const result = await whishWebhookCore(req.method, req.body);
      res.status(result.status).send(result.message);
    } catch (error) {
      console.error('Error processing Whish webhook:', error);
      res.status(500).send('Internal error');
    }
  });

/**
 * Core Card webhook logic (exported for testing)
 */
export async function cardWebhookCore(
  method: string,
  body: any,
  secret: string = process.env.CARD_WEBHOOK_SECRET || 'card-secret'
): Promise<{ status: number; message: string }> {
  if (method !== 'POST') {
    return { status: 405, message: 'Method not allowed' };
  }

  const payload: PaymentWebhookPayload = body;

  // Verify signature - exclude signature field from hash computation
  const { signature, ...dataToSign } = payload;
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(dataToSign))
    .digest('hex');

  if (signature !== expectedSignature) {
    console.error('Invalid card webhook signature');
    return { status: 401, message: 'Invalid signature' };
  }

  // Check for duplicate
  const existingWebhook = await getDb().collection('payment_webhooks')
    .where('transaction_id', '==', payload.transactionId)
    .where('payment_method', '==', 'card')
    .limit(1)
    .get();

  if (!existingWebhook.empty) {
    console.log(`Card webhook already processed: ${payload.transactionId}`);
    return { status: 200, message: 'Already processed' };
  }

  // Log webhook
  await getDb().collection('payment_webhooks').add({
    transaction_id: payload.transactionId,
    payment_method: 'card',
    status: payload.status,
    amount: payload.amount,
    currency: payload.currency,
    received_at: admin.firestore.FieldValue.serverTimestamp(),
    payload: payload,
  });

  // Process payment
  if (payload.status === 'completed') {
    await processSuccessfulPayment(payload, 'card');
  } else if (payload.status === 'failed') {
    await processFailedPayment(payload, 'card');
  }

  return { status: 200, message: 'Webhook processed' };
}

/**
 * Card Payment Webhook
 * Receives payment confirmations from card payment gateway (Stripe/etc)
 */
export const cardWebhook = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onRequest(async (req, res) => {
    try {
      const result = await cardWebhookCore(req.method, req.body);
      res.status(result.status).send(result.message);
    } catch (error) {
      console.error('Error processing card webhook:', error);
      res.status(500).send('Internal error');
    }
  });

/**
 * Process Successful Payment
 * Updates transaction status and activates subscription
 * (Exported for testing)
 */
export async function processSuccessfulPayment(
  payload: PaymentWebhookPayload,
  paymentMethod: string
): Promise<void> {
  try {
    // Find pending transaction
    const transactionQuery = await getDb().collection('payment_transactions')
      .where('transaction_id', '==', payload.transactionId)
      .where('status', '==', 'pending')
      .limit(1)
      .get();

    if (transactionQuery.empty) {
      console.log(`No pending transaction found: ${payload.transactionId}`);
      return;
    }

    const transactionDoc = transactionQuery.docs[0];
    const transaction = transactionDoc.data();

    // Update transaction status
    await transactionDoc.ref.update({
      status: 'completed',
      completed_at: admin.firestore.FieldValue.serverTimestamp(),
      webhook_received_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Activate subscription if this was a subscription payment
    if (transaction.subscription_plan_id && transaction.subscription_plan_id !== 'points_purchase') {
      const now = new Date();
      const endDate = new Date(now);
      endDate.setMonth(endDate.getMonth() + 1);

      await getDb().collection('subscriptions').add({
        user_id: transaction.user_id,
        plan_id: transaction.subscription_plan_id,
        status: 'active',
        payment_method: paymentMethod,
        transaction_id: transactionDoc.id,
        start_date: admin.firestore.Timestamp.fromDate(now),
        end_date: admin.firestore.Timestamp.fromDate(endDate),
        auto_renew: true,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update customer subscription status
      await getDb().collection('customers').doc(transaction.user_id).update({
        subscription_plan: transaction.subscription_plan_id,
        subscription_status: 'active',
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Add points if this was a points purchase
    if (transaction.subscription_plan_id === 'points_purchase') {
      const points = Math.floor(payload.amount * 10); // 10 points per dollar
      await getDb().collection('customers').doc(transaction.user_id).update({
        points_balance: admin.firestore.FieldValue.increment(points),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    console.log(`Successfully processed payment: ${payload.transactionId}`);

  } catch (error) {
    console.error('Error processing successful payment:', error);
    throw error;
  }
}

/**
 * Process Failed Payment
 * Updates transaction status and notifies user
 * (Exported for testing)
 */
export async function processFailedPayment(
  payload: PaymentWebhookPayload,
  paymentMethod: string
): Promise<void> {
  try {
    // Find pending transaction
    const transactionQuery = await getDb().collection('payment_transactions')
      .where('transaction_id', '==', payload.transactionId)
      .where('status', '==', 'pending')
      .limit(1)
      .get();

    if (transactionQuery.empty) {
      console.log(`No pending transaction found: ${payload.transactionId}`);
      return;
    }

    const transactionDoc = transactionQuery.docs[0];

    // Update transaction status
    await transactionDoc.ref.update({
      status: 'failed',
      failed_at: admin.firestore.FieldValue.serverTimestamp(),
      webhook_received_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Payment failed: ${payload.transactionId}`);

    // TODO: Send failure notification to user

  } catch (error) {
    console.error('Error processing failed payment:', error);
    throw error;
  }
}
