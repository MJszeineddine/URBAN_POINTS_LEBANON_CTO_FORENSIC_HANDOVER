# Urban Points Lebanon - Production Configuration Guide

**Last Updated:** 2026-01-03  
**Repository:** `/home/user/urbanpoints-lebanon-complete-ecosystem`  
**Deployment Target:** Firebase Functions v2 + Firestore

---

## 📋 Table of Contents

1. [Environment Variables Overview](#environment-variables-overview)
2. [Critical Security Secrets](#critical-security-secrets)
3. [Payment Gateway Configuration](#payment-gateway-configuration)
4. [SMS & Notifications](#sms--notifications)
5. [Deployment Methods](#deployment-methods)
6. [Local Development Setup](#local-development-setup)
7. [Production Deployment Checklist](#production-deployment-checklist)
8. [Security Best Practices](#security-best-practices)

---

## Environment Variables Overview

### Where They're Used

**Backend Functions:** `backend/firebase-functions/src/`
- **QR Generation:** `src/index.ts` - Secure token generation
- **Payment Webhooks:** `src/paymentWebhooks.ts` - OMT, Whish, Card webhooks
- **SMS Gateway:** `src/sms.ts` - Twilio SMS API

### Configuration Files

| File | Purpose | Git Status |
|------|---------|------------|
| `.env` | Local development secrets | ❌ Gitignored |
| `.env.example` | Template with placeholders | ✅ Committed |
| `.env.deployment` | Deployment reference (legacy) | ⚠️ May contain real secrets - check! |

---

## Critical Security Secrets

### 1. QR_TOKEN_SECRET
**Usage:** Secure QR code generation and validation for customer redemptions

**Required:** ✅ CRITICAL - App will fail without this

**Generation:**
```bash
# Generate a secure 64-character hex string
openssl rand -hex 32
```

**Example Output:**
```
13959d551679eb7b8ba6549cb5351ae3e1a3d10a2d457eeb1bd2f303b9cd779a
```

**Where Used:**
- `src/index.ts:47` - Validation check
- `src/index.ts:53` - QR token generation
- `src/index.ts:60` - Fallback with warning

**Production Setup:**
```bash
# Firebase Console
QR_TOKEN_SECRET=13959d551679eb7b8ba6549cb5351ae3e1a3d10a2d457eeb1bd2f303b9cd779a

# gcloud CLI
gcloud functions deploy generateSecureQRToken \
  --set-env-vars QR_TOKEN_SECRET=YOUR_SECRET_HERE
```

---

## Payment Gateway Configuration

### OMT (Lebanese Payment Provider)

**Variables:**
- `OMT_API_KEY` - API authentication key
- `OMT_WEBHOOK_SECRET` - Webhook signature validation (default: `omt-secret`)
- `OMT_MERCHANT_ID` - Merchant account identifier

**Where Used:** `src/paymentWebhooks.ts`

**Setup Steps:**
1. Register merchant account with OMT Lebanon
2. Obtain API credentials from merchant portal
3. Configure webhook URL: `https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/omtWebhook`
4. Set webhook secret in both OMT portal and Firebase config

---

### Whish Money (Lebanese Payment Provider)

**Variables:**
- `WHISH_API_KEY` - API authentication key
- `WHISH_WEBHOOK_SECRET` - Webhook signature validation (default: `whish-secret`)
- `WHISH_MERCHANT_ID` - Merchant account identifier

**Where Used:** `src/paymentWebhooks.ts`

**Setup Steps:**
1. Register merchant account with Whish Money
2. Obtain API credentials from merchant portal
3. Configure webhook URL: `https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/wishWebhook`
4. Set webhook secret in both Whish portal and Firebase config

---

### Card Payment Gateway

**Variables:**
- `CARD_WEBHOOK_SECRET` - Webhook signature validation (default: `card-secret`)

**Where Used:** `src/paymentWebhooks.ts`

---

### Stripe (International Payments)

**Variables:**
- `STRIPE_SECRET_KEY` - Stripe API secret key (starts with `sk_test_` or `sk-live-`)
- `STRIPE_WEBHOOK_SECRET` - Webhook endpoint secret (starts with `whsec_`)

**Setup Steps:**
1. Create Stripe account at https://dashboard.stripe.com
2. Get test/live secret keys from API keys section
3. Create webhook endpoint for your Cloud Function URL
4. Configure webhook to listen for `payment_intent.succeeded` events

---

## SMS & Notifications

### Twilio SMS Gateway

**Variables:**
- `TWILIO_ACCOUNT_SID` - Twilio account identifier
- `TWILIO_AUTH_TOKEN` - Twilio API authentication token
- `TWILIO_PHONE_NUMBER` - Sender phone number (e.g., `+15551234567`)

**Where Used:** `src/sms.ts:154`

**Setup Steps:**
1. Create Twilio account at https://www.twilio.com/console
2. Purchase a phone number with SMS capabilities
3. Get Account SID and Auth Token from Twilio Console
4. Test SMS sending in development before production deployment

---

### Slack Monitoring Webhooks

**Variables:**
- `SLACK_WEBHOOK_URL` - Incoming webhook URL for error notifications

**Setup Steps:**
1. Create Slack app at https://api.slack.com/apps
2. Enable Incoming Webhooks
3. Add webhook to workspace
4. Copy webhook URL (format: `https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX`)

**Usage:** Send production error alerts to Slack channel

---

## Deployment Methods

### Method 1: Firebase Console (Recommended for Production)

**Steps:**
1. Go to: https://console.firebase.google.com/project/YOUR_PROJECT/functions/config
2. Click **Environment variables**
3. Add each variable:
   - Name: `QR_TOKEN_SECRET`
   - Value: `your_generated_secret_here`
   - Visibility: **Secret** (encrypted at rest)
4. Repeat for all required variables
5. Deploy functions: `firebase deploy --only functions`

**Advantages:**
- ✅ Encrypted at rest
- ✅ Audit logging
- ✅ Easy secret rotation
- ✅ Team access control

---

### Method 2: gcloud CLI Deployment

**Single Variable:**
```bash
gcloud functions deploy FUNCTION_NAME \
  --set-env-vars QR_TOKEN_SECRET=your_secret_here
```

**Multiple Variables:**
```bash
gcloud functions deploy generateSecureQRToken \
  --set-env-vars \
    QR_TOKEN_SECRET=your_qr_secret,\
    OMT_API_KEY=your_omt_key,\
    TWILIO_ACCOUNT_SID=your_twilio_sid,\
    TWILIO_AUTH_TOKEN=your_twilio_token
```

---

### Method 3: Firebase CLI with Secrets

**For Firebase Functions v2 (2nd gen):**
```bash
# Create secrets
firebase functions:secrets:set QR_TOKEN_SECRET
# (Enter value when prompted)

# Deploy with secrets
firebase deploy --only functions
```

**Advantages:**
- ✅ Integrates with Google Secret Manager
- ✅ Automatic encryption
- ✅ Version history

---

## Local Development Setup

### Step 1: Create .env File

```bash
cd backend/firebase-functions
cp .env.example .env
```

### Step 2: Fill in Development Values

**Minimal Working Config:**
```bash
# .env (development)
QR_TOKEN_SECRET=dev-secret-123-REPLACE-IN-PROD
FUNCTIONS_EMULATOR=true
FIRESTORE_EMULATOR_HOST=localhost:8080

# Optional for testing
OMT_WEBHOOK_SECRET=dev-omt-secret
WHISH_WEBHOOK_SECRET=dev-whish-secret
CARD_WEBHOOK_SECRET=dev-card-secret
```

### Step 3: Start Emulators

```bash
# Terminal 1: Start Firebase Emulators
cd /home/user/urbanpoints-lebanon-complete-ecosystem
firebase emulators:start

# Terminal 2: Run tests
cd backend/firebase-functions
npm test
```

### Environment Detection

The code automatically detects emulator mode:
```typescript
// src/obsTestHook.ts
const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
```

---

## Production Deployment Checklist

### Pre-Deployment

- [ ] **Generate Strong QR_TOKEN_SECRET**
  ```bash
  openssl rand -hex 32
  ```

- [ ] **Verify .gitignore Includes .env**
  ```bash
  grep "^\.env$" .gitignore
  ```

- [ ] **Audit Existing .env Files for Secrets**
  ```bash
  find . -name ".env*" -type f | xargs grep -l "PLACEHOLDER"
  ```

- [ ] **Set All Required Variables in Firebase Console**
  - QR_TOKEN_SECRET ✅
  - OMT_API_KEY (if using OMT)
  - WHISH_API_KEY (if using Whish)
  - TWILIO credentials (if using SMS)
  - SLACK_WEBHOOK_URL (for monitoring)

- [ ] **Test Payment Webhooks in Staging**
  - OMT webhook signature validation
  - Whish webhook signature validation
  - Card payment webhook

- [ ] **Run Full Test Suite**
  ```bash
  cd backend/firebase-functions
  npm test
  ```

### Deployment Commands

```bash
# 1. Build and test locally
cd backend/firebase-functions
npm run build
npm test

# 2. Deploy to Firebase
firebase deploy --only functions

# 3. Verify deployment
firebase functions:log --limit 50

# 4. Test production endpoints
curl -X POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/generateSecureQRToken \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

### Post-Deployment

- [ ] **Verify Functions Are Running**
  ```bash
  firebase functions:list
  ```

- [ ] **Check Logs for Errors**
  ```bash
  firebase functions:log --limit 100
  ```

- [ ] **Test QR Generation**
  - Generate QR code in customer app
  - Verify redemption flow works

- [ ] **Test Payment Flow**
  - Process test transaction through OMT/Whish
  - Verify webhook received
  - Check customer points updated

- [ ] **Monitor Slack Alerts**
  - Confirm error notifications work
  - Check alert message formatting

---

## Security Best Practices

### ✅ DO

1. **Use Strong Secrets**
   - Minimum 32 characters
   - Random hex strings: `openssl rand -hex 32`
   - Unique per environment (dev, staging, prod)

2. **Rotate Secrets Regularly**
   - QR_TOKEN_SECRET: Every 90 days
   - API keys: When team members leave
   - Webhook secrets: After suspected compromise

3. **Encrypt at Rest**
   - Use Firebase Secrets Manager
   - Enable Google Secret Manager integration
   - Never store plaintext in Cloud Storage

4. **Audit Access**
   - Review Firebase IAM permissions quarterly
   - Log all secret access attempts
   - Use service accounts for CI/CD

5. **Test in Staging First**
   - Separate Firebase projects for dev/staging/prod
   - Different API keys per environment
   - Test secret rotation process before prod

### ❌ DON'T

1. **Never Commit Secrets to Git**
   - ❌ `.env` with real values
   - ❌ Hard-coded API keys in source
   - ❌ Secrets in comments or documentation

2. **Don't Share Secrets via Unsecure Channels**
   - ❌ Slack messages
   - ❌ Email
   - ❌ Unencrypted file shares
   - ✅ Use 1Password, HashiCorp Vault, or Firebase Secrets

3. **Don't Reuse Secrets Across Environments**
   - ❌ Same QR_TOKEN_SECRET for dev and prod
   - ❌ Production API keys in local .env

4. **Don't Log Secrets**
   - ❌ `console.log(process.env.QR_TOKEN_SECRET)`
   - ❌ Logging webhook payloads with secrets
   - ✅ Redact sensitive values in logs

---

## Troubleshooting

### Error: "QR_TOKEN_SECRET is not set"

**Cause:** Missing environment variable in production

**Fix:**
1. Set variable in Firebase Console
2. Redeploy function: `firebase deploy --only functions`
3. Verify: `firebase functions:config:get`

---

### Error: "OMT webhook signature validation failed"

**Cause:** Mismatch between OMT portal secret and Firebase config

**Fix:**
1. Check OMT merchant portal webhook configuration
2. Update Firebase config to match
3. Test with curl:
   ```bash
   curl -X POST YOUR_WEBHOOK_URL \
     -H "X-OMT-Signature: test-signature" \
     -d '{"test": true}'
   ```

---

### Error: "Twilio authentication failed"

**Cause:** Invalid TWILIO_ACCOUNT_SID or TWILIO_AUTH_TOKEN

**Fix:**
1. Verify credentials in Twilio Console: https://www.twilio.com/console
2. Check phone number format: `+15551234567` (include country code)
3. Test API connection:
   ```bash
   curl -X POST https://api.twilio.com/2010-04-01/Accounts/YOUR_SID/Messages.json \
     --data-urlencode "To=+15555555555" \
     --data-urlencode "From=+15551234567" \
     --data-urlencode "Body=Test" \
     -u YOUR_SID:YOUR_AUTH_TOKEN
   ```

---

## Contact & Support

**Project Repository:** `urbanpoints-lebanon-complete-ecosystem`  
**Firebase Project:** Check `.firebaserc` for project ID  
**Documentation:** `/docs`  
**Issue Tracking:** (Add your issue tracker URL)

---

**END OF PRODUCTION CONFIGURATION GUIDE**
