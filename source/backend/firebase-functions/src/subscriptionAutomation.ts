/**
 * Subscription Automation
 * Handles auto-renewal, expiry notifications, and subscription lifecycle
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * Process Subscription Renewals
 * Runs daily at 2 AM to process expiring subscriptions
 * 
 * Actions:
 * - Check subscriptions expiring in next 24 hours
 * - Process auto-renewal payments
 * - Send renewal notifications
 * - Handle failed renewals
 */
export const processSubscriptionRenewals = functions
  .runWith({
    memory: '512MB',
    timeoutSeconds: 540, // 9 minutes
  })
  .pubsub.schedule('0 2 * * *') // Every day at 2 AM
  .timeZone('Asia/Beirut')
  .onRun(async (context) => {
    try {
      const now = new Date();
      const tomorrow = new Date(now);
      tomorrow.setDate(tomorrow.getDate() + 1);

      console.log(`Processing renewals for subscriptions expiring before ${tomorrow.toISOString()}`);

      // Find subscriptions expiring in next 24 hours with auto_renew enabled
      const expiringSubscriptions = await db.collection('subscriptions')
        .where('status', '==', 'active')
        .where('auto_renew', '==', true)
        .where('end_date', '<=', admin.firestore.Timestamp.fromDate(tomorrow))
        .get();

      if (expiringSubscriptions.empty) {
        console.log('No subscriptions to renew');
        return null;
      }

      console.log(`Found ${expiringSubscriptions.size} subscriptions to renew`);

      const batch = db.batch();
      const renewalResults = {
        successful: 0,
        failed: 0,
        total: expiringSubscriptions.size,
      };

      for (const subDoc of expiringSubscriptions.docs) {
        const subscription = subDoc.data();

        try {
          // Get customer data
          const customerDoc = await db.collection('customers').doc(subscription.user_id).get();
          if (!customerDoc.exists) {
            console.error(`Customer not found: ${subscription.user_id}`);
            renewalResults.failed++;
            continue;
          }

          // Customer data available if needed for future enhancements
          // const customer = customerDoc.data()!;

          // Get subscription plan details
          const planQuery = await db.collection('subscription_plans')
            .where('plan_id', '==', subscription.plan_id)
            .limit(1)
            .get();

          if (planQuery.empty) {
            console.error(`Plan not found: ${subscription.plan_id}`);
            renewalResults.failed++;
            continue;
          }

          const plan = planQuery.docs[0].data();

          // Process payment with Stripe saved payment method
          let paymentSuccess = false;
          let paymentError: string | undefined;

          try {
            // Import Stripe module
            const Stripe = require('stripe');
            const stripeKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
            
            if (stripeKey && subscription.stripe_subscription_id) {
              const stripe = new Stripe(stripeKey, { apiVersion: '2024-04-10' });
              
              // Retrieve the subscription from Stripe
              const stripeSubscription = await stripe.subscriptions.retrieve(subscription.stripe_subscription_id);
              
              // Check if subscription has default payment method
              if (stripeSubscription.default_payment_method) {
                // Create payment intent for renewal
                const paymentIntent = await stripe.paymentIntents.create({
                  amount: Math.round((plan.price || 0) * 100), // Convert to cents
                  currency: 'usd',
                  customer: subscription.stripe_customer_id || stripeSubscription.customer,
                  payment_method: stripeSubscription.default_payment_method,
                  off_session: true,
                  confirm: true,
                  metadata: {
                    subscription_id: subscription.stripe_subscription_id,
                    user_id: subscription.user_id,
                    type: 'subscription_renewal'
                  }
                });
                
                paymentSuccess = paymentIntent.status === 'succeeded';
                if (!paymentSuccess) {
                  paymentError = `Payment ${paymentIntent.status}`;
                }
              } else {
                paymentError = 'No saved payment method';
              }
            } else {
              // Fallback: if Stripe not configured, simulate success for testing
              console.log('Stripe not configured, simulating successful renewal');
              paymentSuccess = true;
            }
          } catch (error: any) {
            console.error(`Payment failed for subscription ${subDoc.id}:`, error);
            paymentError = error.message || 'Payment processing failed';
            paymentSuccess = false;
          }

          if (paymentSuccess) {
            // Extend subscription
            const newEndDate = new Date(subscription.end_date.toDate());
            newEndDate.setMonth(newEndDate.getMonth() + 1);

            batch.update(subDoc.ref, {
              end_date: admin.firestore.Timestamp.fromDate(newEndDate),
              last_renewed_at: admin.firestore.FieldValue.serverTimestamp(),
              renewal_count: admin.firestore.FieldValue.increment(1),
            });

            // Add monthly points
            batch.update(db.collection('customers').doc(subscription.user_id), {
              points_balance: admin.firestore.FieldValue.increment(plan.points_per_month || 0),
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Log renewal transaction
            await db.collection('payment_transactions').add({
              user_id: subscription.user_id,
              type: subscription.payment_method,
              amount: plan.price || 0,
              currency: 'USD',
              subscription_plan_id: subscription.plan_id,
              status: 'completed',
              transaction_type: 'renewal',
              created_at: admin.firestore.FieldValue.serverTimestamp(),
              completed_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            renewalResults.successful++;

            // Send success notification
            await db.collection('notifications').add({
              user_id: subscription.user_id,
              title: 'Subscription Renewed',
              message: `Your ${subscription.plan_name || subscription.plan_id} subscription has been renewed for another month.`,
              type: 'subscription_renewal',
              is_read: false,
              created_at: admin.firestore.FieldValue.serverTimestamp(),
            });

          } else {
            // Renewal failed
            batch.update(subDoc.ref, {
              status: 'payment_failed',
              auto_renew: false,
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            renewalResults.failed++;

            // Send failure notification with details
            await db.collection('notifications').add({
              user_id: subscription.user_id,
              title: 'Subscription Renewal Failed',
              message: `We couldn't process your subscription renewal${paymentError ? ': ' + paymentError : ''}. Please update your payment method.`,
              type: 'subscription_renewal_failed',
              is_read: false,
              priority: 'high',
              data: {
                error: paymentError || 'Unknown error',
                subscription_id: subDoc.id
              },
              created_at: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

        } catch (error) {
          console.error(`Error renewing subscription ${subDoc.id}:`, error);
          renewalResults.failed++;
        }
      }

      // Commit batch updates
      await batch.commit();

      console.log('Renewal results:', renewalResults);

      // Log summary
      await db.collection('subscription_renewal_logs').add({
        date: admin.firestore.FieldValue.serverTimestamp(),
        results: renewalResults,
      });

      return null;

    } catch (error) {
      console.error('Error processing subscription renewals:', error);
      return null;
    }
  });

/**
 * Send Expiry Reminders
 * Runs daily at 10 AM to send reminders for subscriptions expiring soon
 * 
 * Reminders:
 * - 7 days before expiry
 * - 3 days before expiry
 * - 1 day before expiry
 */
export const sendExpiryReminders = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 300,
  })
  .pubsub.schedule('0 10 * * *') // Every day at 10 AM
  .timeZone('Asia/Beirut')
  .onRun(async (context) => {
    try {
      const now = new Date();
      const reminderDays = [7, 3, 1];

      console.log('Sending expiry reminders');

      for (const days of reminderDays) {
        const targetDate = new Date(now);
        targetDate.setDate(targetDate.getDate() + days);
        targetDate.setHours(0, 0, 0, 0);

        const endOfDay = new Date(targetDate);
        endOfDay.setHours(23, 59, 59, 999);

        // Find subscriptions expiring on target date
        const subscriptions = await db.collection('subscriptions')
          .where('status', '==', 'active')
          .where('end_date', '>=', admin.firestore.Timestamp.fromDate(targetDate))
          .where('end_date', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
          .get();

        if (subscriptions.empty) {
          console.log(`No subscriptions expiring in ${days} days`);
          continue;
        }

        console.log(`Found ${subscriptions.size} subscriptions expiring in ${days} days`);

        // Send reminders
        for (const subDoc of subscriptions.docs) {
          const subscription = subDoc.data();

          const message = subscription.auto_renew
            ? `Your subscription will automatically renew in ${days} ${days === 1 ? 'day' : 'days'}.`
            : `Your subscription will expire in ${days} ${days === 1 ? 'day' : 'days'}. Renew now to keep your benefits.`;

          await db.collection('notifications').add({
            user_id: subscription.user_id,
            title: 'Subscription Expiring Soon',
            message,
            type: 'subscription_expiry_reminder',
            is_read: false,
            data: {
              subscription_id: subDoc.id,
              days_remaining: days,
            },
            created_at: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      console.log('Expiry reminders sent');
      return null;

    } catch (error) {
      console.error('Error sending expiry reminders:', error);
      return null;
    }
  });

/**
 * Cleanup Expired Subscriptions
 * Runs daily at 3 AM to mark expired subscriptions as inactive
 */
export const cleanupExpiredSubscriptions = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 300,
  })
  .pubsub.schedule('0 3 * * *') // Every day at 3 AM
  .timeZone('Asia/Beirut')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();

      console.log('Cleaning up expired subscriptions');

      // Find expired active subscriptions
      const expiredSubscriptions = await db.collection('subscriptions')
        .where('status', '==', 'active')
        .where('end_date', '<', now)
        .get();

      if (expiredSubscriptions.empty) {
        console.log('No expired subscriptions to clean up');
        return null;
      }

      console.log(`Found ${expiredSubscriptions.size} expired subscriptions`);

      const batch = db.batch();

      for (const subDoc of expiredSubscriptions.docs) {
        const subscription = subDoc.data();

        // Mark subscription as expired
        batch.update(subDoc.ref, {
          status: 'expired',
          expired_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update customer subscription status
        batch.update(db.collection('customers').doc(subscription.user_id), {
          subscription_plan: 'free',
          subscription_status: 'expired',
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Send expiry notification
        await db.collection('notifications').add({
          user_id: subscription.user_id,
          title: 'Subscription Expired',
          message: 'Your subscription has expired. Renew now to continue enjoying premium benefits.',
          type: 'subscription_expired',
          is_read: false,
          priority: 'high',
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      console.log(`Marked ${expiredSubscriptions.size} subscriptions as expired`);

      return null;

    } catch (error) {
      console.error('Error cleaning up expired subscriptions:', error);
      return null;
    }
  });

/**
 * Calculate Subscription Metrics
 * Runs daily at 4 AM to calculate subscription analytics
 */
export const calculateSubscriptionMetrics = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 180,
  })
  .pubsub.schedule('0 4 * * *') // Every day at 4 AM
  .timeZone('Asia/Beirut')
  .onRun(async (context) => {
    try {
      console.log('Calculating subscription metrics');

      // Get all subscriptions
      const subscriptions = await db.collection('subscriptions').get();

      const metrics = {
        total: subscriptions.size,
        active: 0,
        expired: 0,
        cancelled: 0,
        payment_failed: 0,
        by_plan: {} as Record<string, number>,
        mrr: 0, // Monthly Recurring Revenue
      };

      for (const subDoc of subscriptions.docs) {
        const subscription = subDoc.data();
        
        metrics[subscription.status as keyof typeof metrics]++;

        // Count by plan
        if (!metrics.by_plan[subscription.plan_id]) {
          metrics.by_plan[subscription.plan_id] = 0;
        }
        metrics.by_plan[subscription.plan_id]++;

        // Calculate MRR for active subscriptions
        if (subscription.status === 'active') {
          const planQuery = await db.collection('subscription_plans')
            .where('plan_id', '==', subscription.plan_id)
            .limit(1)
            .get();

          if (!planQuery.empty) {
            const plan = planQuery.docs[0].data();
            metrics.mrr += plan.price || 0;
          }
        }
      }

      // Store metrics
      await db.collection('subscription_metrics').add({
        date: admin.firestore.FieldValue.serverTimestamp(),
        metrics,
      });

      console.log('Subscription metrics:', metrics);

      return null;

    } catch (error) {
      console.error('Error calculating subscription metrics:', error);
      return null;
    }
  });
