# Integration Test Scenarios (Journey Packs)

All scenarios require pack artifacts:
- RUN.log (timestamped steps)
- UI evidence (screenshots/video)
- manifest.json (sha256 of artifacts)
- verdict.json (GO/NO-GO)

## Scenarios

1) Customer Sign-In (Firebase Auth)
- Steps: launch → sign-in → landing
- Evidence path: local-ci/verification/e2e_journeys/customer_sign_in/

2) Earn Points on Purchase
- Steps: create basket → pay → points credited
- Evidence path: local-ci/verification/e2e_journeys/earn_points_purchase/

3) Redeem Points at Merchant
- Steps: sign-in merchant → scan/confirm → points deducted
- Evidence path: local-ci/verification/e2e_journeys/redeem_points_merchant/

4) Admin: Create Points Campaign (Web Admin)
- Steps: admin login → create campaign → publish → visible in mobile
- Evidence path: local-ci/verification/e2e_journeys/admin_create_campaign/

5) Fraud/Risk: Rate Limiting
- Steps: rapid requests → observe 429s or guard triggers
- Evidence path: local-ci/verification/e2e_journeys/fraud_rate_limit/

6) Payments: Stripe Flow (if enabled)
- Steps: customer pay → Stripe intents → success → points credited
- Evidence path: local-ci/verification/e2e_journeys/stripe_payment_flow/

Acceptance: At least five completed journey packs that satisfy the artifact requirements.
