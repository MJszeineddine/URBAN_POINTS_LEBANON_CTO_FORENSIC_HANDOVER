# BLOCKER: UP-FS-008 Stripe Payments Integration

## Requirement ID
UP-FS-008 (payments_stripe)

## Status
BLOCKED

## Description
Firebase Functions include Stripe subscription checkout, billing portal, and webhook processing behind a feature flag `STRIPE_ENABLED`. Code is ready, but runtime requires live Stripe API credentials and webhook secrets not currently configured.

## Blocker Details

### Missing Environment Variables
- `STRIPE_SECRET_KEY`: Must be `sk-live-*` format for production; test key `sk_test_*` not accepted by runtime guards
- `STRIPE_WEBHOOK_SECRET`: Required by `stripeWebhook` HTTPS function to verify incoming webhook signatures
- `STRIPE_ENABLED`: Feature flag environment variable; must be set to `"1"` to enable all Stripe endpoints

### Code References
- [source/backend/firebase-functions/src/index.ts](source/backend/firebase-functions/src/index.ts): `stripeWebhook`, `initiatePaymentCallable`, `createCheckoutSession`, `createBillingPortalSession` all check `STRIPE_ENABLED` and reject calls or return 500 errors when unset or when key is not live
- [source/backend/firebase-functions/src/stripe.ts](source/backend/firebase-functions/src/stripe.ts): Stripe client instantiation and subscription logic depend on secret key

### Acceptance Criteria (Blocked)
- ❌ `STRIPE_ENABLED="1"` deployed to Firebase Functions environment
- ❌ `STRIPE_SECRET_KEY=sk-live-...` set with valid live Stripe account secret
- ❌ `STRIPE_WEBHOOK_SECRET=whsec_...` configured and matched to Stripe webhook endpoint
- ❌ Webhook endpoint URL registered in Stripe dashboard with events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`
- ❌ End-to-end subscription flow tested: checkout session → payment → webhook processing → subscription status update in Firestore

## Unblock Actions Required

1. **Obtain Stripe Live Credentials**
   - Register or activate production-mode Stripe account
   - Retrieve live secret key from Stripe dashboard (Developers > API Keys)
   - Create webhook endpoint pointing to deployed Firebase Function HTTPS URL (e.g., `https://REGION-PROJECT.cloudfunctions.net/stripeWebhook`)
   - Copy webhook signing secret from Stripe webhook configuration

2. **Configure Firebase Functions Environment**
   ```bash
   firebase functions:config:set \
     stripe.enabled="1" \
     stripe.secret_key="sk-live-..." \
     stripe.webhook_secret="whsec_..."
   # OR set via .env.production for newer runtimes
   ```

3. **Deploy Functions**
   ```bash
   cd source
   firebase deploy --only functions:stripeWebhook,functions:initiatePaymentCallable,functions:createCheckoutSession,functions:createBillingPortalSession
   ```

4. **Validate Integration**
   - Run end-to-end test creating a checkout session and completing payment via Stripe
   - Verify webhook event logged in Firestore `payment_webhooks` collection
   - Confirm subscription status reflected in `subscriptions` collection after webhook processing

## Impact
- Merchants cannot subscribe to premium plans or access subscription features
- All Stripe-related endpoints return configuration errors
- UP-FS-008 cannot transition to READY until credentials deployed and tested

## Notes
- Code implements idempotency via `payment_webhooks` collection; safe to replay webhooks
- Subscription model defined in Functions expects `monthly_basic`, `yearly_basic`, `monthly_premium`, `yearly_premium` plans
- Billing portal sessions require merchants to have `stripe_customer_id` set in Firestore `merchants` collection (automatically written by checkout flow)
- Consider setting `STRIPE_ENABLED=0` explicitly in test/staging environments to avoid accidental calls

## References
- [UP-FS-008 spec](spec/requirements.yaml#L113-L142)
- [Stripe Functions index exports](source/backend/firebase-functions/src/index.ts)
- [Stripe core logic](source/backend/firebase-functions/src/stripe.ts)
