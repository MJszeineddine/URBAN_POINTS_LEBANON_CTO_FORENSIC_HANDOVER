# Incident Response Runbook

This runbook provides concrete steps to diagnose, mitigate, and recover from incidents in Urban Points Lebanon.

## Quick Links
- Firebase Console (Functions): https://console.firebase.google.com/project/urbangenspark/functions
- Firebase Console (Firestore): https://console.firebase.google.com/project/urbangenspark/firestore
- Firebase Logs (Functions): https://console.firebase.google.com/project/urbangenspark/logs

## Check Functions Logs
- CLI (requires firebase-tools):
  - View recent logs:
    ```sh
    cd source/backend/firebase-functions
    npm run logs
    ```
  - Tail logs by function via Google Cloud CLI:
    ```sh
    gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=<FUNCTION_NAME>" --limit=50 --format=json
    ```

## Redeploy Functions
```sh
cd source/backend/firebase-functions
npm ci
npm run build
npm run deploy
```

## Rollback Functions
- If you maintain releases via git tags or keep previous build artifacts, redeploy a known-good commit:
```sh
cd source/backend/firebase-functions
# checkout previous commit/tag
git checkout <KNOWN_GOOD_TAG_OR_COMMIT>
npm ci
npm run build
npm run deploy
```
- Alternatively, use Firebase Console → Functions → select previous version and redeploy.

## Verify Core Flows Quickly
- Generate QR Token:
  - Trigger client flow in mobile app or call callable `generateSecureQRToken` via emulator with test data.
- Validate Redemption:
  - Use merchant app's QR scan and PIN validation paths.
- Points Balance:
  - Call `getBalance` for a known test user.
- Offers Listing:
  - Mobile apps display current offers; confirm Firestore collections are readable.

## On Error Handling & Monitoring
- Ensure Sentry DSN is set to activate error tracking; without DSN, monitoring is limited to console logs.
- Review structured logs from `logger.ts` (JSON entries) for consistent error context.

## Escalation
- If critical flow is down ≥15 minutes:
  - Assign incident commander.
  - Create a war room.
  - Document timeline and actions.
  - Post-mortem within 48 hours.
