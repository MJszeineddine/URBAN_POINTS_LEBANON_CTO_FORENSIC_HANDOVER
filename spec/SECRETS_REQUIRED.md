# Staging Secrets Required

This project requires the following secrets to run staging gates. Do not commit real values.

## Server-side env vars (from code discovery)
- DATABASE_URL
- JWT_SECRET
- CORS_ORIGIN
- API_RATE_LIMIT_WINDOW_MS
- API_RATE_LIMIT_MAX_REQUESTS
- PORT
- STRIPE_SECRET_KEY
- STRIPE_WEBHOOK_SECRET
- SENTRY_DSN
- TWILIO_ACCOUNT_SID
- TWILIO_AUTH_TOKEN
- WHATSAPP_NUMBER
- QR_TOKEN_SECRET

Provide these via `.env.staging` at repo root or `source/backend/rest-api/.env.staging`.

## Firebase Functions runtime config
Functions use `functions.config()` in places. Set config on the staging project:

```bash
firebase functions:config:set \
  stripe.secret_key="<STRIPE_SECRET_KEY>" \
  stripe.webhook_secret="<STRIPE_WEBHOOK_SECRET>" \
  secrets.qr_token_secret="<QR_TOKEN_SECRET>" \
  sentry.dsn="<SENTRY_DSN>" \
  twilio.account_sid="<TWILIO_ACCOUNT_SID>" \
  twilio.auth_token="<TWILIO_AUTH_TOKEN>" \
  whatsapp.number="<WHATSAPP_NUMBER>"

firebase functions:config:get > source/backend/firebase-functions/.runtimeconfig.json
```

Do not paste passwords in chat. Prefer service accounts and secret managers.
