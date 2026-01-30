# Firebase Functions Config (Staging)

Functions reference both `process.env.*` and `functions.config()`.

## 1) CLI Auth
Authenticate with Firebase CLI using a project account (avoid sharing passwords):

```bash
npm i -g firebase-tools
firebase login
firebase use <PROJECT_ID>
```

## 2) Set runtime config
```bash
firebase functions:config:set \
  stripe.secret_key="<STRIPE_SECRET_KEY>" \
  stripe.webhook_secret="<STRIPE_WEBHOOK_SECRET>" \
  secrets.qr_token_secret="<QR_TOKEN_SECRET>" \
  sentry.dsn="<SENTRY_DSN>" \
  twilio.account_sid="<TWILIO_ACCOUNT_SID>" \
  twilio.auth_token="<TWILIO_AUTH_TOKEN>" \
  whatsapp.number="<WHATSAPP_NUMBER>"

firebase functions:config:get > .runtimeconfig.json
```

## 3) Emulator (optional)
```bash
export FUNCTIONS_EMULATOR=true
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export GCLOUD_PROJECT=<PROJECT_ID>
export GOOGLE_CLOUD_PROJECT=<PROJECT_ID>
```

## 4) Notes
- Never commit real secrets. Prefer GitHub Actions/OIDC or a secrets manager.
- If STRIPE/WHATSAPP/TWILIO are disabled, stub handlers may still require config; provide dummy values.
