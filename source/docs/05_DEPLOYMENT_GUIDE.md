# Urban Points Lebanon - Deployment Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Development Setup](#local-development-setup)
3. [Firebase Deployment](#firebase-deployment)
4. [Mobile App Builds](#mobile-app-builds)
5. [Environment Configuration](#environment-configuration)
6. [Production Deployment](#production-deployment)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

#### For Backend Development
- **Node.js**: v20.x or higher
- **npm**: v10.x or higher
- **Firebase CLI**: v14.20.0 or higher
  ```bash
  npm install -g firebase-tools
  ```
- **Git**: Latest version

#### For Mobile Development
- **Flutter**: 3.35.4 (LOCKED version)
- **Dart**: 3.9.2 (LOCKED version)
- **Android SDK**: API Level 34 (Android 14)
- **Java JDK**: OpenJDK 17.0.2

#### For Web Development
- Any modern web browser
- Basic HTTP server (Python 3 or Node.js http-server)

### Firebase Project Setup

1. **Create Firebase Project** (if not exists):
   - Go to https://console.firebase.google.com/
   - Create new project: `urbangenspark`
   - Enable Google Analytics (optional)

2. **Enable Firebase Services**:
   - **Authentication**: Enable Email/Password and Phone authentication
   - **Firestore Database**: Create database in production mode
   - **Cloud Functions**: Enable Cloud Functions for Firebase
   - **Cloud Storage**: Enable Cloud Storage
   - **Hosting**: Enable Firebase Hosting
   - **Cloud Messaging**: Enable FCM for push notifications

3. **Project Configuration**:
   - Project ID: `urbangenspark`
   - Project Number: `573269413177`
   - Region: `us-central1` (default)

---

## Local Development Setup

### Backend Setup (Firebase Cloud Functions)

```bash
# Navigate to backend directory
cd backend/firebase-functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Run tests
npm test

# Start local emulator (optional)
firebase emulators:start --only functions,firestore
```

### REST API Setup (Optional/Legacy)

```bash
# Navigate to REST API directory
cd backend/rest-api

# Copy environment template
cp .env.example .env

# Edit .env with your database credentials
nano .env

# Install dependencies
npm install

# Build TypeScript
npm run build

# Start development server
npm run dev

# Or start production server
npm start
```

### Mobile App Setup (Customer/Merchant/Admin)

```bash
# Navigate to any mobile app directory
cd apps/mobile-customer  # or mobile-merchant

# Install Flutter dependencies
flutter pub get

# Run code generation (if using build_runner)
flutter pub run build_runner build

# Check for issues
flutter doctor

# Run app on connected device/emulator
flutter run

# Or run on web (for testing)
flutter run -d chrome
```

### Web Admin Setup

```bash
# Navigate to web admin directory
cd apps/web-admin

# Option 1: Serve with Python
python3 -m http.server 8080

# Option 2: Serve with Node.js
npx http-server -p 8080

# Access at http://localhost:8080
```

---

## Firebase Deployment

### One-Command Deployment

The easiest way to deploy everything to Firebase:

```bash
# From project root
cd scripts

# Configure environment variables
./configure_firebase_env.sh

# Deploy everything
./deploy_production.sh

# Verify deployment
./verify_deployment.sh
```

### Manual Step-by-Step Deployment

#### 1. Authenticate Firebase CLI

```bash
firebase login

# List projects to confirm access
firebase projects:list

# Select project
firebase use urbangenspark
```

#### 2. Configure Environment Variables

```bash
# Auto-generate HMAC secret (32-byte base64)
firebase functions:config:set security.hmac_secret="$(openssl rand -base64 32)"

# Subscription pricing
firebase functions:config:set \
  subscription.silver_price="4.99" \
  subscription.gold_price="9.99"

# Points economy
firebase functions:config:set \
  points.referrer_bonus="500" \
  points.referee_bonus="100"

# Payment gateways (add your keys)
firebase functions:config:set \
  omt.api_key="YOUR_OMT_API_KEY" \
  omt.merchant_id="YOUR_OMT_MERCHANT_ID" \
  whish.api_key="YOUR_WHISH_API_KEY" \
  whish.merchant_id="YOUR_WHISH_MERCHANT_ID" \
  stripe.secret_key="YOUR_STRIPE_SECRET_KEY" \
  stripe.webhook_secret="YOUR_STRIPE_WEBHOOK_SECRET"

# Verify configuration
firebase functions:config:get
```

#### 3. Build Cloud Functions

```bash
cd backend/firebase-functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Run tests (recommended)
npm test

# Ensure no errors in build output
```

#### 4. Deploy Firestore Rules

```bash
# From project root
firebase deploy --only firestore:rules --project urbangenspark

# Verify rules deployed successfully
firebase firestore:rules:list --project urbangenspark
```

#### 5. Deploy Firestore Indexes

```bash
firebase deploy --only firestore:indexes --project urbangenspark

# Monitor index build progress in Firebase Console
# Go to: https://console.firebase.google.com/project/urbangenspark/firestore/indexes
```

#### 6. Deploy Cloud Functions

```bash
# Deploy all functions
firebase deploy --only functions --project urbangenspark

# Or deploy specific functions
firebase deploy --only functions:generateSecureQRToken,functions:validateRedemption --project urbangenspark

# Monitor deployment progress
# Deployment usually takes 3-5 minutes for all functions
```

#### 7. Deploy Web Admin (Firebase Hosting)

```bash
# Prepare web admin for deployment
cd apps/web-admin

# Deploy to Firebase Hosting
firebase deploy --only hosting:admin --project urbangenspark

# Access at: https://urbangenspark.web.app
```

---

## Mobile App Builds

### Android APK Build (Customer App)

```bash
cd apps/mobile-customer

# Clean previous builds
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# APK location: build/app/outputs/flutter-apk/app-release.apk

# Test APK on device
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (AAB) for Play Store

```bash
# Build AAB
flutter build appbundle --release

# AAB location: build/app/outputs/bundle/release/app-release.aab

# Upload to Google Play Console
```

### iOS Build (requires macOS)

```bash
cd apps/mobile-customer

# Clean previous builds
flutter clean
flutter pub get

# Build iOS release
flutter build ios --release

# Open Xcode for signing and archiving
open ios/Runner.xcworkspace

# Archive and submit to App Store
```

### Repeat for Merchant and Admin Apps

```bash
# Merchant app
cd apps/mobile-merchant
flutter build apk --release

# Admin app
cd apps/mobile-admin
flutter build apk --release
```

---

## Environment Configuration

### Firebase Functions Config (.env equivalent)

Firebase Functions use `firebase functions:config:set` instead of `.env` files.

**Required Variables**:

```bash
# Security
security.hmac_secret="<32-byte-base64-string>"

# Subscription Pricing
subscription.silver_price="4.99"
subscription.gold_price="9.99"

# Points Economy
points.referrer_bonus="500"
points.referee_bonus="100"

# Redemption Limits
redemption.max_per_user="1"
redemption.max_total="100"
```

**Optional Variables** (manual configuration required):

```bash
# OMT Payment Gateway
omt.api_key="<your-omt-api-key>"
omt.merchant_id="<your-omt-merchant-id>"

# Whish Money Payment Gateway
whish.api_key="<your-whish-api-key>"
whish.merchant_id="<your-whish-merchant-id>"

# Stripe Payment Gateway
stripe.secret_key="<your-stripe-secret-key>"
stripe.webhook_secret="<your-stripe-webhook-secret>"

# Slack Notifications (optional)
slack.webhook_url="<your-slack-webhook-url>"
```

### Mobile App Configuration (firebase_options.dart)

Each mobile app needs a `firebase_options.dart` file generated:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Navigate to app directory
cd apps/mobile-customer

# Generate firebase_options.dart
flutterfire configure \
  --project=urbangenspark \
  --platforms=android,ios,web \
  --out=lib/firebase_options.dart

# This creates platform-specific Firebase configuration
```

### REST API Configuration (.env)

If using the REST API backend:

```bash
cd backend/rest-api

# Create .env from template
cp .env.example .env

# Edit .env
nano .env
```

**Required .env Variables**:

```env
# Server
PORT=3000
NODE_ENV=production

# Database
DB_HOST=your-postgres-host
DB_PORT=5432
DB_NAME=urban_points_lebanon
DB_USER=your-db-user
DB_PASSWORD=your-db-password

# JWT
JWT_SECRET=your-secure-random-string
JWT_EXPIRY=7d

# CORS
CORS_ORIGIN=https://your-domain.com

# Rate Limiting
RATE_LIMIT_WINDOW=15m
RATE_LIMIT_MAX_REQUESTS=100
```

---

## Production Deployment

### Pre-Deployment Checklist

- [ ] All tests passing (`npm test` in backend/firebase-functions)
- [ ] Code reviewed and approved
- [ ] Environment variables configured
- [ ] Firestore rules updated
- [ ] Firestore indexes created
- [ ] Payment gateway credentials configured
- [ ] Firebase budget limits set (to prevent unexpected charges)
- [ ] Monitoring and alerting configured
- [ ] Backup strategy in place

### Deployment Steps

#### 1. Deploy Backend (Firebase)

```bash
# From project root
cd scripts

# Run full deployment
./configure_firebase_env.sh  # Configure environment
./deploy_production.sh        # Deploy everything
./verify_deployment.sh        # Verify deployment

# Expected time: 8-12 minutes
```

#### 2. Deploy Mobile Apps

**Customer App**:
```bash
cd apps/mobile-customer
flutter build apk --release --split-per-abi
# Or for Play Store:
flutter build appbundle --release

# Upload to Google Play Console
```

**Merchant App**:
```bash
cd apps/mobile-merchant
flutter build apk --release --split-per-abi
# Distribute to merchants
```

**Admin App**:
```bash
cd apps/mobile-admin
flutter build apk --release
# Distribute to admin staff
```

#### 3. Deploy Web Admin

```bash
firebase deploy --only hosting:admin --project urbangenspark

# Access at: https://urbangenspark.web.app
```

#### 4. Configure Payment Webhooks

See `docs/WEBHOOK_CONFIGURATION.md` for detailed webhook setup.

**OMT + Whish Money**:
- Webhook URL: `https://us-central1-urbangenspark.cloudfunctions.net/handlePaymentWebhook`
- Events: payment_success, payment_failed, payment_refunded

**Stripe**:
- Webhook URL: `https://us-central1-urbangenspark.cloudfunctions.net/handleStripeWebhook`
- Events: payment_intent.succeeded, charge.refunded, etc.

#### 5. Post-Deployment Verification

```bash
# Run verification script
cd scripts
./verify_deployment.sh

# Check Cloud Functions logs
firebase functions:log --project urbangenspark

# Test critical flows manually:
# - User signup
# - Offer redemption
# - Subscription purchase
```

---

## Troubleshooting

### Common Issues

#### 1. Firebase CLI Authentication Issues

**Error**: `Error: Authentication Error: Your credentials are no longer valid`

**Solution**:
```bash
firebase logout
firebase login
firebase use urbangenspark
```

#### 2. Cloud Functions Build Errors

**Error**: `Build failed: TypeScript compilation errors`

**Solution**:
```bash
cd backend/firebase-functions

# Check for TypeScript errors
npm run build

# Fix any reported errors
# Common issues:
# - Missing imports
# - Type mismatches
# - Unused variables

# Run linter
npm run lint

# Fix automatically if possible
npm run lint -- --fix
```

#### 3. Firestore Rules Deployment Fails

**Error**: `Error updating rules: Invalid rules syntax`

**Solution**:
```bash
# Validate rules locally
firebase firestore:rules:list --project urbangenspark

# Check rules file syntax
cat infra/firestore.rules

# Common issues:
# - Missing semicolons
# - Incorrect function syntax
# - Malformed match statements
```

#### 4. Mobile App Build Errors

**Error**: `Flutter build fails with dependency conflicts`

**Solution**:
```bash
# Clean Flutter cache
flutter clean

# Remove old dependencies
rm -rf pubspec.lock
rm -rf .dart_tool

# Reinstall dependencies
flutter pub get

# If still failing, check Flutter version
flutter --version  # Should be 3.35.4

# Downgrade if necessary
flutter downgrade 3.35.4
```

#### 5. Firebase Functions Timeout

**Error**: `Function execution timeout after 60s`

**Solution**:
```bash
# Increase timeout in function configuration
# Edit backend/firebase-functions/src/index.ts

export const yourFunction = functions
  .runWith({
    timeoutSeconds: 300,  // Increase to 5 minutes
    memory: '512MB'       // Increase memory if needed
  })
  .https.onCall(async (data, context) => {
    // Function implementation
  });
```

#### 6. CORS Issues in Web App

**Error**: `Access to fetch blocked by CORS policy`

**Solution**:
```bash
# Ensure Cloud Functions allow CORS
# Cloud Functions should already handle CORS
# If using custom domain, add to Firebase Hosting configuration

# In firebase.json:
{
  "hosting": {
    "headers": [
      {
        "source": "**",
        "headers": [
          {
            "key": "Access-Control-Allow-Origin",
            "value": "*"
          }
        ]
      }
    ]
  }
}
```

---

## Monitoring and Maintenance

### Firebase Console Dashboards

- **Functions**: https://console.firebase.google.com/project/urbangenspark/functions
- **Firestore**: https://console.firebase.google.com/project/urbangenspark/firestore
- **Authentication**: https://console.firebase.google.com/project/urbangenspark/authentication
- **Hosting**: https://console.firebase.google.com/project/urbangenspark/hosting
- **Analytics**: https://console.firebase.google.com/project/urbangenspark/analytics

### Log Monitoring

```bash
# View all Cloud Functions logs
firebase functions:log --project urbangenspark

# View specific function logs
firebase functions:log --only generateSecureQRToken --project urbangenspark

# Stream logs in real-time
firebase functions:log --project urbangenspark --follow

# Filter by severity
firebase functions:log --project urbangenspark --level error
```

### Performance Monitoring

- Enable Firebase Performance Monitoring in mobile apps
- Monitor function execution time and error rates
- Set up alerting for critical issues

---

## Backup and Disaster Recovery

### Firestore Backups

```bash
# Manual backup
firebase firestore:export gs://urbangenspark.appspot.com/backups/$(date +%Y%m%d)

# Restore from backup
firebase firestore:import gs://urbangenspark.appspot.com/backups/20250101
```

### Automated Backups (Scheduled Function)

Create a scheduled Cloud Function to backup Firestore daily:

```typescript
export const dailyBackup = functions
  .runWith({ timeoutSeconds: 540 })
  .pubsub.schedule('every day 02:00')
  .onRun(async (context) => {
    const admin = require('firebase-admin');
    const client = new admin.firestore.v1.FirestoreAdminClient();
    
    const bucket = 'gs://urbangenspark.appspot.com/backups';
    const timestamp = new Date().toISOString().split('T')[0];
    
    await client.exportDocuments({
      name: client.databasePath('urbangenspark', '(default)'),
      outputUriPrefix: `${bucket}/${timestamp}`,
      collectionIds: [] // Export all collections
    });
  });
```

---

## Security Best Practices

1. **Never commit secrets**: Use Firebase Functions config or environment variables
2. **Rotate credentials regularly**: Change API keys and secrets periodically
3. **Monitor access logs**: Review audit logs for suspicious activity
4. **Use Firestore Security Rules**: Enforce authorization at database level
5. **Rate limit APIs**: Prevent abuse with rate limiting
6. **Keep dependencies updated**: Regularly update npm packages (but respect version locks)

---

**Document Version**: 1.0
**Last Updated**: November 2025
**Target Audience**: DevOps engineers, deployment teams
