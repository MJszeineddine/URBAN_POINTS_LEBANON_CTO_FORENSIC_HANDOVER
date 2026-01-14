# Data/Rules Inventory (source-of-truth)

- Firestore rules (PARTIAL): Coverage for customers, merchants, offers, redemptions, qr_tokens, rate_limits, notifications, compliance logs in [source/infra/firestore.rules](source/infra/firestore.rules); gaps for users, idempotency_keys, audit_logs, points_expiry_events used by backend; admin portal client writes will fail.
- Firestore indexes (READY): Composites for offers, redemptions, qr_tokens, subscriptions, transactions, merchants in [source/infra/firestore.indexes.json](source/infra/firestore.indexes.json); supports queries exercised by core logic.
- Collections observed in code: users, customers, merchants, offers, redemptions, qr_tokens, rate_limits, idempotency_keys, audit_logs, notifications, push_campaigns, compliance logs, points_expiry_events, payment_webhooks, otp_codes.
- Postgres (BLOCKED): REST API requires tables/functions (healthcheck, validate_redemption, etc.) not present in repo; DATABASE_URL schema undefined.
- Secrets/config dependencies: QR_TOKEN_SECRET, STRIPE_ENABLED="1", Stripe keys (sk_live_*), webhook secret, GCP project env; scheduler enablement required for campaign and maintenance jobs.
