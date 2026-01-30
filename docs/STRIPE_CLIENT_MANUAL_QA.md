# Stripe Client Manual QA

## Preconditions
- Signed in with a valid test user
- Reliable internet connection
- Backend deployed; Stripe products/prices configured and mapped in Functions

## Customer App Flow
- Navigate: Settings → Billing
- Tap: Subscribe
- Expected: External browser opens Stripe Checkout
- Complete the checkout, then return to the app
- App listens to Firestore `users/{uid}/billing/subscription` and updates status automatically

## Merchant App Flow
- Navigate: Profile/Settings → Billing
- Tap: Manage Billing
- Expected: External browser opens Stripe Customer Portal
- Return to the app; billing status updates from Firestore stream

## Success Criteria
- Status shows Active
- Next renewal date appears if available

## Troubleshooting
- If status doesn’t update immediately, wait 30–90s (webhook processing)
- Tap Refresh on the Billing screen to re-pull state
