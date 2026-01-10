# APP MAP AND BASELINE SUMMARY

Generated: $(date)

---

## System Map

- Mobile Apps (Flutter, Dart 3.9.2)
  - Admin: source/apps/mobile-admin
  - Customer: source/apps/mobile-customer
  - Merchant: source/apps/mobile-merchant
- Web Admin (Next.js 16)
  - Dashboard: source/apps/web-admin
- Backend
  - Firebase Functions (TypeScript, Node 20): source/backend/firebase-functions
  - REST API (Express/TypeScript, Node >=18): source/backend/rest-api
- Infrastructure
  - Firebase project configs: source/firebase.json
  - Emulator targets: Firestore 127.0.0.1:8080; Auth 127.0.0.1:9099

---

## Build and Test Commands (per component)

- Backend: Firebase Functions
  - Setup: npm ci
  - Build: npm run build
  - Tests (CI): FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=urbangenspark-test GOOGLE_CLOUD_PROJECT=urbangenspark-test npm run test:ci
- Backend: REST API
  - Setup: npm ci
  - Build: npm run build
  - Tests: npm test
- Web Admin (Next.js)
  - Setup: npm ci
  - Build: npm run build
  - Lint: npm run lint
- Mobile Apps (Flutter)
  - Setup: flutter pub get
  - Static checks: flutter analyze
  - Tests: flutter test

Notes:
- Emulator host must be IPv4 (127.0.0.1) for tests.
- Node 18+ required; Firebase Functions uses Node 20 engines.

---

## Definition of Done (Baseline)

Derived from CTO memo (docs/CTO_HANDOVER/04_decision_memo/cto_decision.md):
- All 15 Cloud Functions deployed and tested
- Mobile apps earn/redeem points end-to-end
- Stripe payments operational in test mode
- 40+ tests passing with ~80% coverage
- Rate limiting and input validation deployed
- CI/CD pipeline configured
- Soft launch with 10–50 test users

---

## Current Gaps (from forensic package)

- Deploy blocked by permissions (auth/perm errors in dry-run)
- Stripe secrets not configured; webhooks not deployed/registered
- Mobile apps missing backend integration for earn/redeem/getBalance
- Tests at ~15% coverage; emulators required
- Admin web app appears skeletal/placeholder

---

## Fullstack Gate Plan (tools/fullstack_gate.sh)

- Step 1: env_gate (ports, Node/Java, emulator host normalization)
- Step 2: phase3_gate (repo checks)
- Step 3: Backend Functions build + tests (with emulator)
- Step 4: REST API build + tests
- Step 5: Web admin build + lint
- Step 6: Flutter apps analyze + tests (skip gracefully if Flutter missing)
- Step 7: Deploy dry-run (optional; SKIPPED when no credentials)
- Evidence: docs/parity/evidence/fullstack/<timestamp>/ with paired /tmp logs
- Status: status.txt and meta.json include per-step exits and deploy_mode
