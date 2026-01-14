# Deployment Guide - Urban Points Lebanon

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Backend Deployment](#backend-deployment)
4. [Mobile App Deployment](#mobile-app-deployment)
5. [Web Admin Deployment](#web-admin-deployment)
6. [Post-Deployment Verification](#post-deployment-verification)
7. [Rollback Procedures](#rollback-procedures)

---

## Prerequisites

### Required Tools
- **Node.js**: v20.x or higher
- **npm**: v10.x or higher
- **Firebase CLI**: v13.x or higher
- **Flutter**: v3.24.0 or higher
- **gcloud CLI**: Latest version
- **Git**: v2.x or higher

### Required Access
- Firebase project owner or editor role
- Google Cloud IAM permissions:
  - `cloudfunctions.functions.create`
  - `cloudfunctions.functions.update`
  - `datastore.indexes.create`
  - `storage.buckets.create`
- App Store Connect access (for iOS)
- Google Play Console access (for Android)

### Environment Secrets
Ensure the following secrets are configured in Firebase Functions config or Secret Manager:

```bash
# Stripe
STRIPE_ENABLED=1
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx

# SMS Gateway
SMS_PROVIDER=touch  # or alfa, twilio
SMS_API_KEY=xxx

# QR Security
QR_TOKEN_SECRET=xxx

# Monitoring (optional)
SENTRY_DSN=xxx
SLACK_WEBHOOK_URL=xxx
```

---

## Environment Setup

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools@latest
firebase login
```

### 2. Initialize Firebase Project

```bash
cd source
firebase use --add

# Select project:
# - staging: staging-urbanpoints
# - production: prod-urbanpoints
```

### 3. Configure Secrets

#### Option A: Firebase Functions Config (Legacy)

```bash
firebase functions:config:set \
  stripe.enabled="1" \
  stripe.secret_key="sk_live_xxx" \
  stripe.webhook_secret="whsec_xxx" \
  sms.provider="touch" \
  sms.api_key="xxx" \
  secrets.qr_token_secret="xxx"
```

#### Option B: Google Secret Manager (Recommended)

```bash
# Enable Secret Manager API
gcloud services enable secretmanager.googleapis.com

# Create secrets
echo -n "sk_live_xxx" | gcloud secrets create stripe-secret-key --data-file=-
echo -n "whsec_xxx" | gcloud secrets create stripe-webhook-secret --data-file=-
echo -n "xxx" | gcloud secrets create sms-api-key --data-file=-
echo -n "xxx" | gcloud secrets create qr-token-secret --data-file=-

# Grant Cloud Functions access
gcloud secrets add-iam-policy-binding stripe-secret-key \
  --member="serviceAccount:${PROJECT_ID}@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## Backend Deployment

### 1. Build and Test Locally

```bash
cd source/backend/firebase-functions

# Install dependencies
npm install

# Run linter
npm run lint

# Run tests
npm test

# Build TypeScript
npm run build
```

### 2. Deploy to Staging

```bash
# Set project to staging
firebase use staging

# Deploy functions
firebase deploy --only functions

# Deploy Firestore rules and indexes
firebase deploy --only firestore:rules,firestore:indexes

# Deploy storage rules
firebase deploy --only storage
```

### 3. Deploy to Production

```bash
# Set project to production
firebase use production

# Deploy with confirmation
firebase deploy --only functions --force

# Deploy Firestore rules and indexes
firebase deploy --only firestore:rules,firestore:indexes

# Deploy storage rules
firebase deploy --only storage
```

### 4. Verify Deployment

```bash
# Check function status
firebase functions:log --limit 50

# Test critical functions
curl -X POST https://us-central1-${PROJECT_ID}.cloudfunctions.net/generateSecureQRToken \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

---

## Mobile App Deployment

### Customer App

#### Android

```bash
cd source/apps/mobile-customer

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release --flavor production

# Build App Bundle for Play Store
flutter build appbundle --release

# Output location
# build/app/outputs/bundle/productionRelease/app-production-release.aab
```

**Upload to Google Play Console:**
1. Go to https://play.google.com/console
2. Select "Urban Points Customer" app
3. Navigate to "Release" > "Production"
4. Click "Create new release"
5. Upload `app-production-release.aab`
6. Add release notes
7. Review and roll out

#### iOS

```bash
cd source/apps/mobile-customer

# Build iOS release
flutter build ios --release

# Open Xcode
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select "Any iOS Device" as target
# 2. Product > Archive
# 3. Distribute App > App Store Connect
# 4. Upload
```

**Submit to App Store:**
1. Go to https://appstoreconnect.apple.com
2. Select "Urban Points Customer" app
3. Create new version
4. Upload build from Xcode
5. Fill in app information
6. Submit for review

### Merchant App

Follow the same steps as Customer App, but use `mobile-merchant` directory.

---

## Web Admin Deployment

```bash
cd source/apps/web-admin

# Install dependencies
npm install

# Build for production
npm run build

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

**Verify deployment:**
- Visit: https://admin.urbanpoints.lb
- Test login with admin credentials
- Verify offer moderation functions

---

## Post-Deployment Verification

### 1. Smoke Tests

```bash
# Run automated smoke tests
cd tools
node final_e2e_smoke_authenticated.js
```

### 2. Manual Verification Checklist

- [ ] Customer can sign up/login
- [ ] Customer can browse offers
- [ ] Customer can generate QR code
- [ ] Merchant can create offer
- [ ] Merchant can scan QR code
- [ ] Points are awarded correctly
- [ ] Admin can approve/reject offers
- [ ] Stripe payments work (test mode first)
- [ ] Push notifications are received
- [ ] Scheduled jobs run successfully

### 3. Monitor Logs

```bash
# View recent logs
firebase functions:log --limit 100

# Watch logs in real-time
firebase functions:log --only generateSecureQRToken

# Check for errors
gcloud logging read "severity>=ERROR" --limit 50 --format json
```

### 4. Check Metrics

```bash
# View function metrics
gcloud functions describe generateSecureQRToken --region us-central1

# Check Firestore operations
gcloud monitoring time-series list \
  --filter='metric.type="firestore.googleapis.com/document/read_count"' \
  --interval-end-time=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --interval-start-time=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
```

---

## Rollback Procedures

### Backend Rollback

```bash
# List recent deployments
gcloud functions list --filter="name:*urbanpoints*"

# Rollback to previous version
firebase functions:delete FUNCTION_NAME --force
firebase deploy --only functions:FUNCTION_NAME

# Or restore from backup
gcloud firestore import gs://urbanpoints-backups/firestore-backups/TIMESTAMP
```

### Mobile App Rollback

#### Android
1. Go to Google Play Console
2. Select app > Release Management > App releases
3. Click "Manage" on the problematic release
4. Click "Stop rollout" or "Rollback"

#### iOS
1. Go to App Store Connect
2. Select app > App Store tab
3. Click "Remove from Sale" to temporarily disable
4. Submit previous version for review

### Web Admin Rollback

```bash
# Revert to previous hosting deployment
firebase hosting:clone SOURCE_SITE_ID:SOURCE_VERSION TARGET_SITE_ID

# Or redeploy previous version
git checkout PREVIOUS_COMMIT
cd source/apps/web-admin
npm run build
firebase deploy --only hosting
```

---

## Troubleshooting

### Common Issues

#### 1. Firebase Permission Denied

```bash
# Check project
firebase projects:list

# Check login
firebase login --reauth
```

#### 2. Function Deployment Timeout

```bash
# Increase timeout
firebase deploy --only functions:FUNCTION_NAME --force
```

#### 3. Firestore Index Missing

```bash
# Deploy indexes
firebase deploy --only firestore:indexes

# Check index status
gcloud firestore indexes list
```

#### 4. Stripe Webhook Not Receiving Events

- Verify webhook URL in Stripe Dashboard
- Check webhook signing secret matches config
- Test with Stripe CLI:
  ```bash
  stripe listen --forward-to https://us-central1-${PROJECT_ID}.cloudfunctions.net/stripeWebhook
  stripe trigger payment_intent.succeeded
  ```

---

## Security Checklist

Before deploying to production:

- [ ] All secrets stored in Secret Manager (not in code)
- [ ] Firestore security rules tested and deployed
- [ ] Storage security rules tested and deployed
- [ ] CORS configured for web admin
- [ ] Rate limiting enabled on functions
- [ ] Authentication required for sensitive functions
- [ ] HTTPS enforced for all endpoints
- [ ] API keys restricted to specific domains/apps
- [ ] Backup automation configured
- [ ] Monitoring and alerting configured
- [ ] Incident response plan documented

---

## Support

For deployment issues:
- Check logs: `firebase functions:log`
- Monitor: https://console.cloud.google.com/monitoring
- Documentation: `docs/`
- Incident Response: `docs/RUNBOOK_INCIDENT_RESPONSE.md`
