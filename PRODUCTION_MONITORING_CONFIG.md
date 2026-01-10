# PRODUCTION MONITORING CONFIGURATION

**Project:** Urban Points Lebanon MVP  
**Firebase Project:** urbangenspark (Project #573269413177)  
**Status:** CONFIGURATION READY  
**Implementation:** PENDING DevOps Engineer

---

## MONITORING STRATEGY

**Principle:** Minimal viable monitoring for MVP launch  
**Focus Areas:**
1. Payment processing failures (Stripe webhook errors)
2. High function error rates (> 5%)
3. Critical function availability (generateSecureQRToken, validateRedemption)
4. Mobile app crash reporting (via Firebase Crashlytics - already integrated)

**Excluded from MVP:**
- Advanced analytics dashboards (use Firebase Console)
- Performance monitoring (defer to post-launch)
- Load testing alerts (defer to post-launch)
- User activity tracking (defer to post-launch)

---

## FIREBASE CRASHLYTICS (ALREADY ACTIVE)

### Status: ✅ CONFIGURED

**Evidence (Customer App):**
```dart
// source/apps/mobile-customer/lib/main.dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

**Evidence (Merchant App):**
```dart
// source/apps/mobile-merchant/lib/main.dart
await FirebaseCrashlytics.instance.setCustomKey('role', 'merchant');
```

**Access Crashes:**
- URL: https://console.firebase.google.com/project/urbangenspark/crashlytics
- View: All crashes grouped by stack trace
- Alerts: Email notifications enabled by default

**No Action Required:** Crashlytics operational.

---

## CLOUD LOGGING ALERTS (PENDING CONFIGURATION)

### 1. Payment Processing Failures

**Alert Name:** `payment-failures`  
**Trigger:** Any ERROR severity logs from `initiatePaymentCallable` or `stripeWebhook` functions  
**Notification:** Email to: `devops@urbanpoints.lb` (replace with actual email)

**Setup Command:**
```bash
# Create log-based metric
gcloud logging metrics create payment_failures \
  --project=urbangenspark \
  --description="Stripe payment processing failures" \
  --log-filter='resource.type="cloud_function"
    AND (resource.labels.function_name="initiatePaymentCallable" OR resource.labels.function_name="stripeWebhook")
    AND severity>=ERROR'

# Create alert policy
gcloud alpha monitoring policies create \
  --project=urbangenspark \
  --notification-channels=CHANNEL_ID \
  --display-name="Payment Failures Alert" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=60s \
  --condition-display-name="Payment failure detected" \
  --metric-type="logging.googleapis.com/user/payment_failures"
```

**Note:** Replace `CHANNEL_ID` with actual notification channel ID (obtain via `gcloud alpha monitoring channels list`)

---

### 2. High Error Rate Alert

**Alert Name:** `high-error-rate`  
**Trigger:** Error rate exceeds 5% across all Cloud Functions  
**Notification:** Email to: `devops@urbanpoints.lb`

**Setup Command:**
```bash
# Create log-based metric
gcloud logging metrics create high_error_rate \
  --project=urbangenspark \
  --description="Cloud Functions error rate exceeds threshold" \
  --log-filter='resource.type="cloud_function"
    AND severity>=ERROR'

# Create alert policy with rate threshold
gcloud alpha monitoring policies create \
  --project=urbangenspark \
  --notification-channels=CHANNEL_ID \
  --display-name="High Error Rate Alert" \
  --condition-threshold-value=5 \
  --condition-threshold-duration=300s \
  --condition-display-name="Error rate > 5% for 5 minutes" \
  --metric-type="logging.googleapis.com/user/high_error_rate"
```

---

### 3. Critical Function Availability

**Alert Name:** `critical-function-errors`  
**Trigger:** Any ERROR in core redemption flow functions  
**Functions Monitored:**
- `generateSecureQRToken`
- `validatePIN`
- `validateRedemption`
- `getBalance`

**Setup Command:**
```bash
# Create log-based metric
gcloud logging metrics create critical_function_errors \
  --project=urbangenspark \
  --description="Errors in critical redemption flow functions" \
  --log-filter='resource.type="cloud_function"
    AND (resource.labels.function_name="generateSecureQRToken" 
         OR resource.labels.function_name="validatePIN" 
         OR resource.labels.function_name="validateRedemption" 
         OR resource.labels.function_name="getBalance")
    AND severity>=ERROR'

# Create alert policy
gcloud alpha monitoring policies create \
  --project=urbangenspark \
  --notification-channels=CHANNEL_ID \
  --display-name="Critical Function Errors" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=60s \
  --condition-display-name="Critical function error detected" \
  --metric-type="logging.googleapis.com/user/critical_function_errors"
```

---

## SENTRY INTEGRATION (OPTIONAL - POST-MVP)

### Status: NOT CONFIGURED

**If Sentry Required:**

1. Create Sentry project at https://sentry.io
2. Obtain DSN (Data Source Name)
3. Add to mobile apps:

**Customer App:**
```yaml
# source/apps/mobile-customer/pubspec.yaml
dependencies:
  sentry_flutter: ^7.0.0
```

```dart
// source/apps/mobile-customer/lib/main.dart
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_SENTRY_DSN';
      options.environment = kDebugMode ? 'dev' : 'prod';
    },
    appRunner: () => runApp(const UrbanPointsCustomerApp()),
  );
}
```

4. Add to backend functions:

```typescript
// source/backend/firebase-functions/src/index.ts
import * as Sentry from '@sentry/node';

Sentry.init({
  dsn: 'YOUR_SENTRY_DSN',
  environment: process.env.FUNCTIONS_EMULATOR === 'true' ? 'dev' : 'prod',
});
```

**Recommendation:** Defer to post-MVP. Firebase Crashlytics sufficient for MVP launch.

---

## FIRESTORE SECURITY RULES MONITORING

### Status: ✅ DEPLOYED

**Rules Location:** `source/infra/firestore.rules`

**Monitor Rule Violations:**
```bash
# View security rule denials in logs
gcloud logging read "resource.type=firestore_database AND protoPayload.status.code=7" \
  --project=urbangenspark \
  --limit=50 \
  --format=json
```

**Alert Setup (Optional):**
```bash
gcloud logging metrics create security_rule_denials \
  --project=urbangenspark \
  --description="Firestore security rule violations" \
  --log-filter='resource.type="firestore_database"
    AND protoPayload.status.code=7'
```

---

## UPTIME MONITORING (PENDING CONFIGURATION)

### Cloud Functions Uptime Checks

**Setup via Firebase Console:**

1. Navigate to: https://console.firebase.google.com/project/urbangenspark/functions
2. Select function: `getBalance`
3. Click "Metrics" tab
4. Enable "Uptime Checks" if available

**Alternative: Use Google Cloud Monitoring API**

```bash
# Create uptime check for getBalance function
gcloud monitoring uptime create http getBalance-uptime \
  --project=urbangenspark \
  --resource-type=uptime-url \
  --host=us-central1-urbangenspark.cloudfunctions.net \
  --path=/getBalance \
  --check-interval=5m
```

**Functions to Monitor:**
- `getBalance` (customer dependency)
- `generateSecureQRToken` (redemption flow)
- `validateRedemption` (redemption flow)

---

## DASHBOARD ACCESS

### Firebase Console
- **URL:** https://console.firebase.google.com/project/urbangenspark/overview
- **Functions Logs:** https://console.firebase.google.com/project/urbangenspark/functions/logs
- **Crashlytics:** https://console.firebase.google.com/project/urbangenspark/crashlytics
- **Performance:** https://console.firebase.google.com/project/urbangenspark/performance

### Google Cloud Console
- **URL:** https://console.cloud.google.com/home/dashboard?project=urbangenspark
- **Logs Explorer:** https://console.cloud.google.com/logs/query?project=urbangenspark
- **Monitoring:** https://console.cloud.google.com/monitoring?project=urbangenspark
- **Error Reporting:** https://console.cloud.google.com/errors?project=urbangenspark

---

## ALERT NOTIFICATION CHANNELS

### Email Notifications (Required)

**Setup:**
1. Navigate to: https://console.cloud.google.com/monitoring/alerting/notifications?project=urbangenspark
2. Click "Add Notification Channel"
3. Select "Email"
4. Enter email: `devops@urbanpoints.lb` (replace with actual)
5. Save and obtain CHANNEL_ID
6. Use CHANNEL_ID in alert commands above

### Slack Notifications (Optional - Post-MVP)

**Setup:**
1. Create Slack webhook URL
2. Add notification channel:
   ```bash
   gcloud alpha monitoring channels create \
     --project=urbangenspark \
     --display-name="Urban Points Alerts" \
     --type=slack \
     --channel-labels=url=YOUR_SLACK_WEBHOOK_URL
   ```

---

## TESTING MONITORING SETUP

### 1. Test Crashlytics

**Action:**
```dart
// Add to any screen in customer app temporarily
ElevatedButton(
  onPressed: () {
    throw Exception('Test crash for monitoring');
  },
  child: const Text('Trigger Test Crash'),
),
```

**Expected:**
- Crash appears in Firebase Console > Crashlytics within 5 minutes
- Stack trace visible
- Device info visible

---

### 2. Test Cloud Logging Alert

**Action:**
```bash
# Trigger error log from Cloud Functions
firebase functions:shell
> generateSecureQRToken({ userId: 'test', offerId: 'invalid' })
```

**Expected:**
- Error appears in Logs Explorer
- Alert fires if threshold exceeded
- Email notification received

---

### 3. Test Uptime Check

**Action:**
```bash
# Call getBalance function directly
curl -H "Authorization: Bearer $(firebase auth:token)" \
  https://us-central1-urbangenspark.cloudfunctions.net/getBalance
```

**Expected:**
- Uptime check passes if function responds HTTP 200
- Alert fires if function unavailable for > 5 minutes

---

## IMPLEMENTATION CHECKLIST

**Owner:** DevOps Engineer  
**Duration:** 2 hours  
**Prerequisites:** 
- Firebase CLI installed
- Google Cloud SDK installed (`brew install google-cloud-sdk`)
- Project access configured (`gcloud config set project urbangenspark`)

### Setup Steps

- [ ] Install Google Cloud SDK (if not installed):
  ```bash
  brew install google-cloud-sdk
  gcloud auth login
  gcloud config set project urbangenspark
  ```

- [ ] Create email notification channel:
  ```bash
  gcloud alpha monitoring channels create \
    --display-name="DevOps Email" \
    --type=email \
    --channel-labels=email_address=devops@urbanpoints.lb
  ```

- [ ] Note CHANNEL_ID from output:
  ```
  CHANNEL_ID=___________________________
  ```

- [ ] Create payment failures metric and alert (use CHANNEL_ID from above)

- [ ] Create high error rate metric and alert

- [ ] Create critical function errors metric and alert

- [ ] Test alerts by triggering error in Cloud Functions

- [ ] Verify email received at devops@urbanpoints.lb

- [ ] Document alert response procedures

- [ ] Bookmark dashboard URLs for daily monitoring

---

## ALERT RESPONSE PROCEDURES

### Payment Failure Alert

**Severity:** P0 (Critical)  
**Response Time:** < 30 minutes  
**Actions:**
1. Check Stripe Dashboard for payment errors
2. Check Cloud Logging for stack trace
3. Verify Stripe webhook secrets configured
4. If Stripe API down, wait for service restoration
5. If code issue, rollback deployment
6. Notify CTO and Finance Team

---

### High Error Rate Alert

**Severity:** P1 (High)  
**Response Time:** < 1 hour  
**Actions:**
1. Check Logs Explorer for error patterns
2. Identify affected function(s)
3. Check recent deployments (rollback candidate)
4. Verify Firebase services operational
5. If sustained, consider rollback
6. Notify CTO

---

### Critical Function Error Alert

**Severity:** P0 (Critical)  
**Response Time:** < 15 minutes  
**Actions:**
1. Identify which critical function failing
2. Check Logs Explorer for error details
3. Test function manually via Firebase Console
4. If redemption flow blocked, consider emergency rollback
5. Notify CTO immediately
6. Post incident report after resolution

---

## POST-MVP ENHANCEMENTS (DEFERRED)

- Advanced performance monitoring (page load times, transaction durations)
- Custom analytics dashboards (user funnels, conversion rates)
- Automated anomaly detection (ML-based)
- Distributed tracing (Cloud Trace integration)
- Load testing alerts (response time degradation)
- Cost monitoring alerts (Cloud Billing API)

---

## SIGN-OFF

**Configuration Completed By:** ___________________________  
**Date:** ___________________________  
**Alerts Tested:** [ ] YES [ ] NO  
**Dashboard Access Verified:** [ ] YES [ ] NO  

**Approved for Production:**
- [ ] CTO Signature: ___________________________
- [ ] Date: ___________________________
