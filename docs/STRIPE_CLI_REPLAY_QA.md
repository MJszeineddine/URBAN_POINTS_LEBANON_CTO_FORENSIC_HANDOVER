# Stripe CLI Replay QA Checklist

## What This Gate Validates ✅

### Infrastructure & Deployment
- ✅ Firebase CLI is installed and authenticated
- ✅ Firebase project (urbangenspark) is accessible
- ✅ All required Cloud Functions are deployed:
  - createCheckoutSession
  - createBillingPortalSession
  - stripeWebhook
  - initiatePaymentCallable

### Stripe Integration
- ✅ Stripe CLI is installed and authenticated
- ✅ Stripe webhook endpoint is reachable (Cloud Function URL)
- ✅ Stripe CLI can forward webhook events to the deployed endpoint
- ✅ Webhook events can be triggered successfully:
  - checkout.session.completed
  - customer.subscription.created
  - invoice.payment_succeeded

### Evidence Collection
- ✅ All command outputs captured to evidence logs
- ✅ SHA256 checksums generated for evidence integrity
- ✅ Non-PTY safe execution (no hanging, timeouts enforced)

## What This Gate Does NOT Validate ❌

### Application Logic
- ❌ Does NOT verify Firestore document updates (manual check required)
- ❌ Does NOT test actual payment processing (uses Stripe test events)
- ❌ Does NOT verify mobile app billing screens
- ❌ Does NOT test end-to-end user flows
- ❌ Does NOT validate Stripe product/price configuration

### Security & Production Readiness
- ❌ Does NOT verify Stripe webhook signature validation in function code
- ❌ Does NOT test production Stripe keys (uses test mode)
- ❌ Does NOT verify idempotency handling
- ❌ Does NOT test error recovery or retry logic

### Data Verification
- ❌ Does NOT automatically query Firestore (requires Firebase Admin SDK setup)
- ❌ Does NOT verify specific subscription data fields
- ❌ Does NOT validate user billing document structure

## Expected Verdicts

### GO ✅
- All functions deployed
- Stripe CLI available and authenticated
- All webhook events triggered successfully
- Webhook delivery confirmed (200 responses in logs)

### PARTIAL_GO ⚠️
- Functions deployed and webhooks triggered
- Delivery may have succeeded but requires manual Firestore verification
- This is the typical verdict - manual checks needed

### NO_GO ❌
- Missing prerequisites (Firebase CLI, Stripe CLI, Node)
- Authentication failures
- Missing deployed functions
- Critical errors during webhook delivery

## Manual Verification Steps

After gate completes with GO or PARTIAL_GO:

1. **Check Firestore Console**
   ```
   https://console.firebase.google.com/project/urbangenspark/firestore
   ```
   Navigate to: `users/{test_uid}/billing/subscription`
   
   Verify fields updated by webhook:
   - status (should be 'active' or similar)
   - subscriptionId
   - customerId
   - priceId
   - currentPeriodEnd

2. **Review Stripe Dashboard**
   ```
   https://dashboard.stripe.com/test/events
   ```
   Verify the triggered events appear in the events log

3. **Check Cloud Functions Logs**
   ```bash
   firebase functions:log --project urbangenspark --only stripeWebhook
   ```
   Look for successful webhook processing logs

## Troubleshooting

### "Stripe CLI not found"
```bash
brew install stripe/stripe-cli/stripe
stripe login
```

### "Firebase CLI not found"
```bash
npm install -g firebase-tools
firebase login
```

### "Functions not deployed"
```bash
cd source/backend/firebase-functions
firebase deploy --only functions --project urbangenspark
```

### "Stripe listen failed to start"
- Check: `stripe login` authentication status
- Verify network connectivity
- Check if another stripe listen process is running

### "Webhook delivery errors"
- Review: `stripe_listen.err.log` in evidence folder
- Check Cloud Function logs for errors
- Verify webhook endpoint URL is correct
- Ensure Cloud Function has public access (or proper authentication)

## Evidence Files

After running the gate, find evidence at:
```
docs/evidence/production_gate/<UTC_TS>/stripe_cli_replay_gate/
```

Key files:
- `FINAL_STRIPE_CLI_REPLAY_GATE.md` - Verdict summary
- `EXECUTION_LOG.md` - Detailed step-by-step log
- `stripe_listen.out.log` - Webhook delivery confirmations
- `stripe_trigger_*.out.log` - Event trigger results
- `firebase_functions_list.out.log` - Deployed functions inventory
- `SHA256SUMS.txt` - Evidence integrity checksums

## Integration with CI/CD

This gate can be integrated into deployment pipelines:

```bash
#!/bin/bash
# After deploying functions
/bin/bash tools/run_stripe_cli_replay_gate_wrapper.sh
if [ $? -eq 0 ]; then
  echo "✅ Stripe integration verified"
else
  echo "❌ Stripe integration failed"
  exit 1
fi
```

## Limitations

- Requires Stripe CLI installed locally (not in CI environments by default)
- Uses Stripe test mode only
- Cannot verify production webhook signing secrets
- Firestore verification is manual (not automated)
- Does not test actual payment flows with real cards
