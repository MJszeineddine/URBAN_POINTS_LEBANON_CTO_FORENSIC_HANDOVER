// Stripe Webhook Handler
import * as functions from 'firebase-functions';
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '', {});

export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'] as string;
  
  try {
    const event = stripe.webhooks.constructEvent(
      req.rawBody,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET || ''
    );
    // Reference event to satisfy TS and allow future handling
    const type = (event as any).type;
    switch (type) {
      default:
        break;
    }

    // Handle webhook event
    res.json({ received: true });
  } catch (err) {
    res.status(400).send(`Webhook Error: ${err}`);
  }
});

export const stripeWebhookHandler = async (data: any) => ({
  processed: true,
});
