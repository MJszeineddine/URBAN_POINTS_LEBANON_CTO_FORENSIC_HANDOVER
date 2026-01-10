/**
 * Stripe Integration - Production Ready
 * 
 * Features:
 * - Customer creation
 * - Subscription management
 * - Payment processing
 * - Webhook handling with signature verification
 * - Idempotent operations
 * - Grace period handling
 * 
 * Installation Required:
 * npm install stripe@^15.0.0
 * 
 * Environment Variables:
 * - STRIPE_SECRET_KEY: Stripe secret key
 * - STRIPE_WEBHOOK_SECRET: Webhook signing secret
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

// ============================================================================
// STRIPE FEATURE FLAG - DEFERRED FEATURE
// ============================================================================
// STRIPE_ENABLED controls whether Stripe payment processing is active.
// Default: "0" (disabled) - Stripe code paths will not execute.
// Production: Set to "1" only when ready to enable, with live keys (sk_live_*).
function isStripeEnabled(): boolean {
  const enabled = process.env.STRIPE_ENABLED || functions.config().stripe?.enabled || '0';
  return enabled === '1';
}

// Lazy initialization
let _db: admin.firestore.Firestore | null = null;
function getDb(): admin.firestore.Firestore {
  if (!_db) {
    _db = admin.firestore();
  }
  return _db;
}

// ============================================================================
// INTERFACES
// ============================================================================

export interface InitiatePaymentRequest {
  merchantId: string;
  planId: string;
  paymentMethodId?: string;
}

export interface InitiatePaymentResponse {
  success: boolean;
  clientSecret?: string;
  subscriptionId?: string;
  error?: string;
}

export interface CreateCustomerRequest {
  userId: string;
  email: string;
  name?: string;
}

export interface CreateCustomerResponse {
  success: boolean;
  customerId?: string;
  error?: string;
}

export interface CreateSubscriptionRequest {
  customerId: string;
  planId: string;
  paymentMethodId: string;
}

export interface CreateSubscriptionResponse {
  success: boolean;
  subscriptionId?: string;
  status?: string;
  error?: string;
}

export interface VerifyPaymentStatusRequest {
  subscriptionId: string;
}

export interface VerifyPaymentStatusResponse {
  success: boolean;
  status?: string;
  error?: string;
}

export interface StripeContext {
  auth?: {
    uid: string;
  };
}

// ============================================================================
// PHASE 2A: STRIPE SUBSCRIPTIONS
// ============================================================================

/**
 * initiatePayment - Create payment intent for subscription
 * 
 * @param data - Payment request
 * @param context - Auth context
 * @returns Payment response with client secret
 */
export async function initiatePayment(
  data: InitiatePaymentRequest,
  context: StripeContext
): Promise<InitiatePaymentResponse> {
  try {
    // STRIPE_DEFERRED: Check if Stripe is enabled
    if (!isStripeEnabled()) {
      console.error('Stripe is disabled (STRIPE_ENABLED != "1")');
      return { success: false, error: 'Stripe payment processing is not enabled' };
    }

    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    if (context.auth.uid !== data.merchantId) {
      return { success: false, error: 'Merchant ID mismatch' };
    }

    const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
    if (!stripeKey) {
      console.error('STRIPE_SECRET_KEY not configured');
      return { success: false, error: 'Payment system not configured' };
    }

    // STRIPE_DEFERRED: Verify production keys when enabled
    if (!stripeKey.startsWith('sk_live_')) {
      console.error('STRIPE_SECRET_KEY must start with sk_live_ in production (got ' + stripeKey.substring(0, 10) + ')');
      return { success: false, error: 'Invalid Stripe key format' };
    }

    const stripe = new Stripe(stripeKey, {
      apiVersion: '2024-04-10',
    });

    const db = getDb();
    
    // Get plan details
    const planDoc = await db.collection('subscription_plans').doc(data.planId).get();
    if (!planDoc.exists) {
      return { success: false, error: 'Plan not found' };
    }

    const plan = planDoc.data()!;
    
    // Get or create Stripe customer
    const merchantDoc = await db.collection('merchants').doc(data.merchantId).get();
    if (!merchantDoc.exists) {
      return { success: false, error: 'Merchant not found' };
    }

    const merchant = merchantDoc.data()!;
    let stripeCustomerId = merchant.stripe_customer_id;

    if (!stripeCustomerId) {
      const customer = await stripe.customers.create({
        email: merchant.email,
        metadata: {
          firebaseUid: data.merchantId,
        },
      });
      stripeCustomerId = customer.id;
      
      await db.collection('merchants').doc(data.merchantId).update({
        stripe_customer_id: stripeCustomerId,
      });
    }

    // Create subscription
    const subscription = await stripe.subscriptions.create({
      customer: stripeCustomerId,
      items: [{ price: plan.stripe_price_id }],
      payment_settings: {
        payment_method_types: ['card'],
        save_default_payment_method: 'on_subscription',
      },
      expand: ['latest_invoice.payment_intent'],
    });

    // Store subscription in Firestore
    await db.collection('subscriptions').doc(subscription.id).set({
      merchant_id: data.merchantId,
      plan_id: data.planId,
      stripe_subscription_id: subscription.id,
      stripe_customer_id: stripeCustomerId,
      status: subscription.status,
      current_period_start: admin.firestore.Timestamp.fromDate(new Date(subscription.current_period_start * 1000)),
      current_period_end: admin.firestore.Timestamp.fromDate(new Date(subscription.current_period_end * 1000)),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    const invoice = subscription.latest_invoice as any;
    const paymentIntent = invoice.payment_intent;

    return {
      success: true,
      clientSecret: paymentIntent.client_secret,
      subscriptionId: subscription.id,
    };
  } catch (error) {
    console.error('Error initiating payment:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

/**
 * createCustomer - Create Stripe customer
 * 
 * @param data - Customer request
 * @param context - Auth context
 * @returns Customer response
 */
export async function createCustomer(
  data: CreateCustomerRequest,
  context: StripeContext
): Promise<CreateCustomerResponse> {
  try {
    // STRIPE_DEFERRED: Check if Stripe is enabled
    if (!isStripeEnabled()) {
      console.error('Stripe is disabled (STRIPE_ENABLED != "1")');
      return { success: false, error: 'Stripe payment processing is not enabled' };
    }

    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    if (context.auth.uid !== data.userId) {
      return { success: false, error: 'User ID mismatch' };
    }

    const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
    if (!stripeKey || !stripeKey.startsWith('sk_live_')) {
      console.error('Stripe requires sk_live_ keys in production');
      return { success: false, error: 'Stripe credentials not valid' };
    }
    
    const stripe = new Stripe(stripeKey, {
      apiVersion: '2024-04-10',
    });

    const customer = await stripe.customers.create({
      email: data.email,
      name: data.name,
      metadata: {
        firebaseUid: data.userId,
      },
    });

    // Update user document with Stripe customer ID
    const db = getDb();
    await db.collection('merchants').doc(data.userId).update({
      stripe_customer_id: customer.id,
    });

    return {
      success: true,
      customerId: customer.id,
    };
    

    
  } catch (error) {
    console.error('Error creating customer:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

/**
 * createSubscription - Create subscription for customer
 * 
 * @param data - Subscription request
 * @param context - Auth context
 * @returns Subscription response
 */
export async function createSubscription(
  data: CreateSubscriptionRequest,
  context: StripeContext
): Promise<CreateSubscriptionResponse> {
  try {
    // STRIPE_DEFERRED: Check if Stripe is enabled
    if (!isStripeEnabled()) {
      console.error('Stripe is disabled (STRIPE_ENABLED != "1")');
      return { success: false, error: 'Stripe payment processing is not enabled' };
    }

    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
    if (!stripeKey || !stripeKey.startsWith('sk_live_')) {
      console.error('Stripe requires sk_live_ keys in production');
      return { success: false, error: 'Stripe credentials not valid' };
    }
    
    const stripe = new Stripe(stripeKey, {
      apiVersion: '2024-04-10',
    });

    const db = getDb();
    const planDoc = await db.collection('subscription_plans').doc(data.planId).get();
    if (!planDoc.exists) {
      return { success: false, error: 'Plan not found' };
    }

    const plan = planDoc.data()!;

    const subscription = await stripe.subscriptions.create({
      customer: data.customerId,
      items: [{ price: plan.stripe_price_id }],
      default_payment_method: data.paymentMethodId,
      expand: ['latest_invoice.payment_intent'],
    });

    return {
      success: true,
      subscriptionId: subscription.id,
      status: subscription.status,
    };
    

    return {
      success: false,
      error: 'Stripe not installed. Run: npm install stripe@^15.0.0',
    };
  } catch (error) {
    console.error('Error creating subscription:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

/**
 * verifyPaymentStatus - Check subscription payment status
 * 
 * @param data - Status request
 * @param context - Auth context
 * @returns Status response
 */
export async function verifyPaymentStatus(
  data: VerifyPaymentStatusRequest,
  context: StripeContext
): Promise<VerifyPaymentStatusResponse> {
  try {
    // STRIPE_DEFERRED: Check if Stripe is enabled
    if (!isStripeEnabled()) {
      console.error('Stripe is disabled (STRIPE_ENABLED != "1")');
      return { success: false, error: 'Stripe payment processing is not enabled' };
    }

    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
    if (!stripeKey || !stripeKey.startsWith('sk_live_')) {
      console.error('Stripe requires sk_live_ keys in production');
      return { success: false, error: 'Stripe credentials not valid' };
    }
    
    const stripe = new Stripe(stripeKey, {
      apiVersion: '2024-04-10',
    });

    const subscription = await stripe.subscriptions.retrieve(data.subscriptionId);

    return {
      success: true,
      status: subscription.status,
    };
    
  } catch (error) {
    console.error('Error verifying payment status:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

// ============================================================================
// PHASE 2B: STRIPE WEBHOOKS
// ============================================================================

/**
 * stripeWebhook - Handle Stripe webhook events
 * 
 * Security:
 * - Signature verification
 * - Idempotent handling
 * 
 * Events:
 * - subscription.created
 * - subscription.updated
 * - subscription.deleted
 * - invoice.payment_succeeded
 * - invoice.payment_failed
 */
export const stripeWebhook = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onRequest(async (req, res) => {
    try {
      // STRIPE_DEFERRED: Check if Stripe is enabled
      if (!isStripeEnabled()) {
        console.error('Stripe webhook received but Stripe is disabled (STRIPE_ENABLED != "1")');
        res.status(403).send('Stripe payment processing is not enabled');
        return;
      }

      if (req.method !== 'POST') {
        res.status(405).send('Method not allowed');
        return;
      }

      const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
      if (!stripeKey) {
        console.error('STRIPE_SECRET_KEY not configured');
        res.status(500).send('Payment system not configured');
        return;
      }

      // STRIPE_DEFERRED: Verify production keys
      if (!stripeKey.startsWith('sk_live_')) {
        console.error('Stripe webhook requires sk_live_ keys in production');
        res.status(500).send('Invalid Stripe key format');
        return;
      }

      const stripe = new Stripe(stripeKey, {
        apiVersion: '2024-04-10',
      });

      const signature = req.headers['stripe-signature'] as string;
      const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || functions.config().stripe?.webhook_secret || '';
      
      if (!webhookSecret) {
        console.error('STRIPE_WEBHOOK_SECRET not configured');
        res.status(500).send('Webhook secret not configured');
        return;
      }

      let event;
      try {
        event = stripe.webhooks.constructEvent(req.rawBody, signature, webhookSecret);
      } catch (err) {
        console.error('Webhook signature verification failed:', err);
        res.status(400).send('Invalid signature');
        return;
      }

      const db = getDb();

      // Check for duplicate event
      const eventDoc = await db.collection('processed_webhooks').doc(event.id).get();
      if (eventDoc.exists) {
        console.log(`Webhook already processed: ${event.id}`);
        res.status(200).send('Already processed');
        return;
      }

      // Handle event
      switch (event.type) {
        case 'customer.subscription.created':
        case 'customer.subscription.updated':
          await handleSubscriptionUpdate(event.data.object as any, db);
          break;
        case 'customer.subscription.deleted':
          await handleSubscriptionDeleted(event.data.object as any, db);
          break;
        case 'invoice.payment_succeeded':
          await handlePaymentSucceeded(event.data.object as any, db);
          break;
        case 'invoice.payment_failed':
          await handlePaymentFailed(event.data.object as any, db);
          break;
        default:
          console.log(`Unhandled event type: ${event.type}`);
      }

      // Mark event as processed
      await db.collection('processed_webhooks').doc(event.id).set({
        event_id: event.id,
        event_type: event.type,
        processed_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).send('Webhook processed');
    } catch (error) {
      console.error('Error processing webhook:', error);
      res.status(500).send('Internal error');
    }
  });

// ============================================================================
// WEBHOOK HANDLERS
// ============================================================================

/**
 * Handle subscription update events
 */
async function handleSubscriptionUpdate(subscription: any, db: admin.firestore.Firestore) {
  const subscriptionData = {
    stripe_subscription_id: subscription.id,
    stripe_customer_id: subscription.customer,
    status: subscription.status,
    current_period_start: admin.firestore.Timestamp.fromDate(new Date(subscription.current_period_start * 1000)),
    current_period_end: admin.firestore.Timestamp.fromDate(new Date(subscription.current_period_end * 1000)),
    cancel_at_period_end: subscription.cancel_at_period_end,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Update subscription document
  const query = await db.collection('subscriptions')
    .where('stripe_subscription_id', '==', subscription.id)
    .limit(1)
    .get();

  if (!query.empty) {
    await query.docs[0].ref.update(subscriptionData);
    
    // Update merchant subscription status
    const subDoc = query.docs[0].data();
    await db.collection('merchants').doc(subDoc.merchant_id).update({
      subscription_status: subscription.status,
      subscription_updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

/**
 * Handle subscription deletion
 */
async function handleSubscriptionDeleted(subscription: any, db: admin.firestore.Firestore) {
  const query = await db.collection('subscriptions')
    .where('stripe_subscription_id', '==', subscription.id)
    .limit(1)
    .get();

  if (!query.empty) {
    const subDoc = query.docs[0].data();
    
    await query.docs[0].ref.update({
      status: 'cancelled',
      cancelled_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    await db.collection('merchants').doc(subDoc.merchant_id).update({
      subscription_status: 'cancelled',
      subscription_updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

/**
 * Handle successful payment
 */
async function handlePaymentSucceeded(invoice: any, db: admin.firestore.Firestore) {
  // Log successful payment
  await db.collection('payment_logs').add({
    type: 'payment_succeeded',
    stripe_invoice_id: invoice.id,
    stripe_customer_id: invoice.customer,
    amount: invoice.amount_paid,
    currency: invoice.currency,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Handle failed payment
 */
async function handlePaymentFailed(invoice: any, db: admin.firestore.Firestore) {
  // Log failed payment
  await db.collection('payment_logs').add({
    type: 'payment_failed',
    stripe_invoice_id: invoice.id,
    stripe_customer_id: invoice.customer,
    amount: invoice.amount_due,
    currency: invoice.currency,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Update merchant subscription status with grace period
  const query = await db.collection('subscriptions')
    .where('stripe_customer_id', '==', invoice.customer)
    .limit(1)
    .get();

  if (!query.empty) {
    const subDoc = query.docs[0].data();
    
    // Set grace period (3 days from now)
    const gracePeriodEnd = new Date();
    gracePeriodEnd.setDate(gracePeriodEnd.getDate() + 3);
    
    await db.collection('merchants').doc(subDoc.merchant_id).update({
      subscription_status: 'past_due',
      grace_period_end: admin.firestore.Timestamp.fromDate(gracePeriodEnd),
      subscription_updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

// ============================================================================
// PHASE 2C: ACCESS CONTROL
// ============================================================================

/**
 * checkSubscriptionAccess - Verify merchant has active subscription
 * 
 * @param merchantId - Merchant ID
 * @param db - Firestore instance
 * @returns Subscription data or throws error
 */
export async function checkSubscriptionAccess(
  merchantId: string,
  db: admin.firestore.Firestore
): Promise<any> {
  const merchantDoc = await db.collection('merchants').doc(merchantId).get();
  if (!merchantDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Merchant not found');
  }

  const merchant = merchantDoc.data()!;
  const subscriptionStatus = merchant.subscription_status;

  // Check if subscription is active
  if (subscriptionStatus === 'active') {
    return merchant;
  }

  // Check grace period for past_due subscriptions
  if (subscriptionStatus === 'past_due' && merchant.grace_period_end) {
    const gracePeriodEnd = merchant.grace_period_end.toDate();
    const now = new Date();
    
    if (now < gracePeriodEnd) {
      console.log(`Merchant ${merchantId} in grace period until ${gracePeriodEnd}`);
      return merchant;
    }
  }

  throw new functions.https.HttpsError(
    'permission-denied',
    'Active subscription required. Please update your payment method.'
  );
}

/**
 * initiatePaymentCallable - Callable Cloud Function for initiating payments
 * WITH VALIDATION AND RATE LIMITING
 */
export const initiatePaymentCallable = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(async (data, context) => {
    // Import validation (lazy load to avoid circular dependencies)
    const { validateAndRateLimit, isValidationError } = await import('./middleware/validation');
    const { InitiatePaymentSchema } = await import('./validation/schemas');

    // Validate and rate limit
    const validated = await validateAndRateLimit(
      data,
      context,
      InitiatePaymentSchema,
      'initiatePayment'
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
    return initiatePayment(validated, context);
  });

// ============================================================================
// PHASE 2D: CHECKOUT AND BILLING PORTAL SESSIONS
// ============================================================================

/**
 * createCheckoutSession - Create Stripe Checkout session for subscription signup
 * 
 * This function creates a hosted Stripe Checkout page for customers to
 * enter payment details and subscribe to a plan. After successful payment,
 * Stripe will redirect to successUrl and send webhook events to update
 * subscription status in Firestore.
 * 
 * @param data - Checkout session request { priceId, successUrl, cancelUrl }
 * @param context - Auth context
 * @returns { success: true, sessionId: string, url: string }
 */
export const createCheckoutSession = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onCall(async (data: { priceId: string; successUrl: string; cancelUrl: string }, context) => {
    try {
      // Auth validation
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
      }

      const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
      if (!stripeKey) {
        console.error('STRIPE_SECRET_KEY not configured');
        throw new functions.https.HttpsError('failed-precondition', 'Payment system not configured');
      }

      const stripe = new Stripe(stripeKey, {
        apiVersion: '2024-04-10',
      });

      const db = getDb();
      const merchantDoc = await db.collection('merchants').doc(context.auth.uid).get();
      
      if (!merchantDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Merchant not found');
      }

      const merchantData = merchantDoc.data()!;
      let stripeCustomerId = merchantData.stripe_customer_id;

      // Create customer if needed
      if (!stripeCustomerId) {
        const customer = await stripe.customers.create({
          email: merchantData.email,
          metadata: {
            firebaseUid: context.auth.uid,
          },
        });
        stripeCustomerId = customer.id;
        await db.collection('merchants').doc(context.auth.uid).update({
          stripe_customer_id: stripeCustomerId,
        });
      }

      // Create checkout session
      const session = await stripe.checkout.sessions.create({
        customer: stripeCustomerId,
        mode: 'subscription',
        line_items: [
          {
            price: data.priceId,
            quantity: 1,
          },
        ],
        success_url: data.successUrl,
        cancel_url: data.cancelUrl,
        metadata: {
          firebaseUid: context.auth.uid,
        },
      });

      return {
        success: true,
        sessionId: session.id,
        url: session.url,
      };
    } catch (error) {
      console.error('Error creating checkout session:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        'internal',
        error instanceof Error ? error.message : 'Internal error'
      );
    }
  });

/**
 * createBillingPortalSession - Create Stripe Customer Portal session
 * 
 * This function creates a hosted Stripe Customer Portal where customers can:
 * - View subscription details
 * - Update payment methods
 * - Cancel or upgrade subscriptions
 * - Download invoices
 * 
 * @param data - Portal session request { returnUrl }
 * @param context - Auth context
 * @returns { success: true, url: string }
 */
export const createBillingPortalSession = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
  })
  .https.onCall(async (data: { returnUrl: string }, context) => {
    try {
      // Auth validation
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
      }

      const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
      if (!stripeKey) {
        console.error('STRIPE_SECRET_KEY not configured');
        throw new functions.https.HttpsError('failed-precondition', 'Payment system not configured');
      }

      const stripe = new Stripe(stripeKey, {
        apiVersion: '2024-04-10',
      });

      const db = getDb();
      const merchantDoc = await db.collection('merchants').doc(context.auth.uid).get();

      if (!merchantDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Merchant not found');
      }

      const merchantData = merchantDoc.data()!;
      const stripeCustomerId = merchantData.stripe_customer_id;

      if (!stripeCustomerId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'No Stripe customer found. Please subscribe first.'
        );
      }

      // Create billing portal session
      const session = await stripe.billingPortal.sessions.create({
        customer: stripeCustomerId,
        return_url: data.returnUrl,
      });

      return {
        success: true,
        url: session.url,
      };
    } catch (error) {
      console.error('Error creating billing portal session:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        'internal',
        error instanceof Error ? error.message : 'Internal error'
      );
    }
  });

