# Required Environment Variables / Secrets

Set these secrets in your CI environment (GitHub Actions secrets) and for local deploys via `firebase functions:config:set` or your secret manager.

- **STRIPE_SECRET_KEY**: Full Stripe secret key (sk_live_... or sk_test_...). Required for payment processing.
- **STRIPE_WEBHOOK_SECRET**: Webhook signing secret for Stripe.
- **FIREBASE_SERVICE_ACCOUNT**: Service account JSON (used only in secure CI; do not commit to repo).
- **FIREBASE_PROJECT**: Firebase project id used for deploy commands.
- **QR_TOKEN_SECRET**: Secret used for QR token signing.
- **API_JWT_SECRET**: JWT signing secret for REST API.

If a gate requires a secret and it is not present, the autopilot will report which secret is missing and fail the run. Do NOT store secrets in repository files.
# Environment Variables (names only)
This file lists required environment variable NAMES. Do not commit values.

## Source
- REQUIRED_ENVS.md exists; this doc is the canonical names-only list.

## Keys
- `152`
- `153`
- `202`
- `203`
- `216`
- `276`
- `3000`
- `ALLOW_STRIPE_TEST_KEYS`
- `API`
- `API_RATE_LIMIT_`
- `API_RATE_LIMIT_MAX_REQUESTS`
- `API_RATE_LIMIT_WINDOW_MS`
- `BLOCKER`
- `CORS_ORIGIN`
- `COUNTRY_CODE`
- `DATABASE_URL`
- `DECISION`
- `FAIL`
- `FINAL_GATE`
- `FUNCTIONS_EMULATOR`
- `GCLOUD_PROJECT`
- `HIGH`
- `JWT`
- `JWT_SECRET`
- `L12`
- `L152`
- `L153`
- `L16`
- `L202`
- `L203`
- `L21`
- `L216`
- `L22`
- `L24`
- `L25`
- `L276`
- `L31`
- `L37`
- `L39`
- `L50`
- `L54`
- `L58`
- `L59`
- `L60`
- `L70`
- `L805`
- `L809`
- `L85`
- `L87`
- `LOG_LEVEL`
- `NEXT_PUBLIC_`
- `NODE_ENV`
- `NOT`
- `NOT_REQUIRED`
- `OPTIONAL`
- `PAYMENTS_ENABLED`
- `PORT`
- `QR_TOKEN_SECRET`
- `REQUIRED`
- `REST`
- `RUNTIME`
- `SENTRY_DSN`
- `SMS`
- `STOP`
- `STRIPE_ENABLED`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `TIMEZONE`
- `TWILIO_`
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_PHONE_NUMBER`
