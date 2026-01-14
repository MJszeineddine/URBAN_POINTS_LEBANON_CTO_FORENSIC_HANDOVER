# Backend Inventory (source-of-truth)

- Functions core: READY/PARTIAL mix across callables/triggers in [source/backend/firebase-functions/src/index.ts](source/backend/firebase-functions/src/index.ts)
  - Auth (READY): onUserCreate, getUserProfile, setCustomClaims, verifyEmailComplete in [source/backend/firebase-functions/src/auth.ts](source/backend/firebase-functions/src/auth.ts)
  - QR/PIN (PARTIAL): generateSecureQRToken, validatePIN, validateRedemption; depends on QR_TOKEN_SECRET and active subscription; rate limits in [source/backend/firebase-functions/src/core/qr.ts](source/backend/firebase-functions/src/core/qr.ts)
  - Points (READY): earnPoints, redeemPoints, getBalance backed by transactional helpers in [source/backend/firebase-functions/src/core/points.ts](source/backend/firebase-functions/src/core/points.ts)
  - Offers (READY): createNewOffer, updateStatus, approveOffer, rejectOffer, expireOffers, getOfferStats, getOffersByLocationFunc; state machine in [source/backend/firebase-functions/src/core/offers.ts](source/backend/firebase-functions/src/core/offers.ts)
  - Compliance/Reporting (READY): calculateDailyStats, getMerchantComplianceStatus plus scheduler enforceMerchantCompliance in [source/backend/firebase-functions/src/phase3Scheduler.ts](source/backend/firebase-functions/src/phase3Scheduler.ts)
  - Notifications (PARTIAL): register/unregister FCM tokens, notifyRedemptionSuccess trigger, notifyOfferStatusChange trigger in [source/backend/firebase-functions/src/phase3Notifications.ts](source/backend/firebase-functions/src/phase3Notifications.ts) and [source/backend/firebase-functions/src/phase3Scheduler.ts](source/backend/firebase-functions/src/phase3Scheduler.ts)
  - Maintenance jobs (READY): cleanupExpiredQRTokens, sendPointsExpiryWarnings in [source/backend/firebase-functions/src/phase3Scheduler.ts](source/backend/firebase-functions/src/phase3Scheduler.ts)
  - Payments/Stripe (PARTIAL): initiatePaymentCallable, createCheckoutSession, createBillingPortalSession, stripeWebhook; STRIPE_ENABLED feature flag; keys must be sk_live_* per [source/backend/firebase-functions/src/index.ts](source/backend/firebase-functions/src/index.ts)
  - Push campaigns (BLOCKED): processScheduledCampaigns set to null, scheduleCampaign callable present but scheduler disabled in [source/backend/firebase-functions/src/pushCampaigns.ts](source/backend/firebase-functions/src/pushCampaigns.ts)
- REST API (PARTIAL): Express server with auth/offers/vouchers/gifts under /api in [source/backend/rest-api/src/server.ts](source/backend/rest-api/src/server.ts); relies on Postgres schema and SQL functions not present in repo.
- Firebase project config (READY): build/lint predeploy and emulator setup in [source/firebase.json](source/firebase.json); functions runtime Node 20 via package.json engines.
- Tools/Gates (INFO): release/deploy gates and scripts in tools/*.sh exist but CI wiring not in repo; see e.g. [tools/final_release_gate.sh](tools/final_release_gate.sh).
