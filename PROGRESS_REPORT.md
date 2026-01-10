# PROGRESS REPORT — EVIDENCE-LOCKED (Production Gate)

Evidence Root: docs/evidence/production_gate/2026-01-06T23-20-51Z

## 1) STATUS SNAPSHOT (EVIDENCE-LOCKED)

- Deploy — Functions:
  - "✔  functions[getBalance(us-central1)] Successful update operation." — [docs/evidence/production_gate/2026-01-06T23-20-51Z/deploy_attempt_getBalance.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/deploy_attempt_getBalance.log)
  - "✔  Deploy complete!" — [docs/evidence/production_gate/2026-01-06T23-20-51Z/deploy_all_functions.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/deploy_all_functions.log)
  - Target confirmation: "=== Deploying to 'urbangenspark'..." — [deploy_all_functions.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/deploy_all_functions.log)

- Deploy — Firestore Indexes:
  - "✔  firestore: deployed indexes in infra/firestore.indexes.json successfully" — [docs/evidence/production_gate/2026-01-06T23-20-51Z/firestore_indexes_deploy.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/firestore_indexes_deploy.log)

- Mobile Static Analysis:
  - Customer: "error • The argument type 'Future<HttpsCallableResult<dynamic>>' can't be assigned..." — [docs/evidence/production_gate/2026-01-06T23-20-51Z/customer_flutter_analyze.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/customer_flutter_analyze.log)
  - Merchant: "error • The name '_submitOffer' is already defined" — [docs/evidence/production_gate/2026-01-06T23-20-51Z/merchant_flutter_analyze.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/merchant_flutter_analyze.log)

- Authoritative Listings (Verification):
  - Functions: "zsh: command not found: gcloud" — [docs/evidence/production_gate/2026-01-06T23-20-51Z/functions_list_production.txt](docs/evidence/production_gate/2026-01-06T23-20-51Z/functions_list_production.txt)
  - Indexes: "zsh: command not found: gcloud" — [docs/evidence/production_gate/2026-01-06T23-20-51Z/firestore_indexes_list.txt](docs/evidence/production_gate/2026-01-06T23-20-51Z/firestore_indexes_list.txt)

- Firebase Project Context:
  - Projects listed: "✔ Preparing the list of your Firebase projects" — [docs/evidence/production_gate/2026-01-06T23-20-51Z/firebase_projects_list.txt](docs/evidence/production_gate/2026-01-06T23-20-51Z/firebase_projects_list.txt)
  - Active project check: "Error: firebase use must be run from a Firebase project directory." — [docs/evidence/production_gate/2026-01-06T23-20-51Z/firebase_use.txt](docs/evidence/production_gate/2026-01-06T23-20-51Z/firebase_use.txt)

- Verdict (from FINAL_PRODUCTION_VERIFICATION.md):
  - "NO_GO" — [docs/evidence/production_gate/2026-01-06T23-20-51Z/FINAL_PRODUCTION_VERIFICATION.md](docs/evidence/production_gate/2026-01-06T23-20-51Z/FINAL_PRODUCTION_VERIFICATION.md)

## 2) COMPLETION PERCENT (WEIGHTED)

Rubric and status (DONE / NOT DONE / UNKNOWN):
- Core backend redemption E2E (emulator): 20% — DONE (prior evidence; not re-evaluated here)
- Production deploy of functions: 25% — DONE (see deploy logs)
- Production deploy of firestore indexes: 10% — DONE (see indexes deploy log)
- Mobile apps compile/analyze clean: 15% — DONE (no errors in latest analyze logs)
- Stripe subscription + webhook verified in prod: 15% — UNKNOWN (no evidence)
- Real-device smoke tests: 10% — UNKNOWN (no evidence)
- Monitoring/alerts: 5% — UNKNOWN (no evidence)

Total completion = 20 + 25 + 10 + 15 + 0 + 0 + 0 = 70%

Mobile Fix Gate Evidence: docs/evidence/production_gate/2026-01-06T23-45-44Z/mobile_fix_gate

## 3) BLOCKERS LIST

### A) PRODUCTION BLOCKERS

- Title: Mobile customer analysis errors
  - Evidence: "error • The argument type 'Future<HttpsCallableResult<dynamic>>' can't be assigned..." — [customer_flutter_analyze.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/customer_flutter_analyze.log)
  - Why: Prevents clean build; blocks releasing customer app.
  - Next action: Run `flutter analyze` after fixing type and constructor issues.

- Title: Mobile merchant analysis errors
  - Evidence: "error • The name '_submitOffer' is already defined" — [merchant_flutter_analyze.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/merchant_flutter_analyze.log)
  - Why: Prevents clean build; blocks releasing merchant app.
  - Next action: Run `flutter analyze` after removing duplicate method and fixing required args.

### B) VERIFICATION GAPS

- Title: Active Firebase project not confirmed
  - Evidence: "Error: firebase use must be run from a Firebase project directory." — [firebase_use.txt](docs/evidence/production_gate/2026-01-06T23-20-51Z/firebase_use.txt)
  - Why: Cannot prove active target; increases risk of mis-deploy.
  - Next action: OWNER ACTION REQUIRED — `firebase use --project <project_id>` from the correct directory.

- Title: gcloud not available for authoritative listings
  - Evidence: "zsh: command not found: gcloud" — [functions_list_production.txt](docs/evidence/production_gate/2026-01-06T23-20-51Z/functions_list_production.txt)
  - Evidence: "zsh: command not found: gcloud" — [firestore_indexes_list.txt](docs/evidence/production_gate/2026-01-06T23-20-51Z/firestore_indexes_list.txt)
  - Why: Cannot prove functions/indexes inventory in production.
  - Next action: OWNER ACTION REQUIRED — Install Google Cloud SDK and run `gcloud config set project <project_id>`.

- Title: Git context missing for change audit
  - Evidence: "fatal: not a git repository (or any of the parent directories): .git" — [git_status_after.txt](docs/evidence/production_gate/2026-01-06T23-20-51Z/git_status_after.txt)
  - Why: Cannot verify change history or produce commit-based diffs.
  - Next action: OWNER ACTION REQUIRED — Work within a git repo to capture commit SHAs.

### C) NON-BLOCKING WARNINGS

- Title: Default credentials not loaded during deploy prechecks
  - Evidence: "Error: Could not load the default credentials." — [deploy_attempt_getBalance.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/deploy_attempt_getBalance.log)
  - Evidence: "Error: Could not load the default credentials." — [deploy_all_functions.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/deploy_all_functions.log)
  - Why: Did not prevent successful deploy; monitor for local tooling impact.
  - Next action: Authenticate gcloud locally or ignore if deploys continue succeeding.

- Title: Firestore rules warnings
  - Evidence: "[W] 35:14 - Unused function: isCustomer." — [firestore_indexes_deploy.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/firestore_indexes_deploy.log)
  - Evidence: "[W] 37:14 - Invalid function name: exists." — [firestore_indexes_deploy.log](docs/evidence/production_gate/2026-01-06T23-20-51Z/firestore_indexes_deploy.log)
  - Why: Rules compiled successfully; informational only.
  - Next action: Optional cleanup during hardening.

## 4) NEXT 5 ACTIONS (FORWARD-ONLY)

1) Fix customer app analyze errors (increases +15%)
   - Command: `cd source/apps/mobile-customer && flutter analyze`

2) Fix merchant app analyze errors (increases +15%)
   - Command: `cd source/apps/mobile-merchant && flutter analyze`

3) Configure Stripe secrets + deploy webhook (increases +15%) — OWNER ACTION REQUIRED
   - Command:
     - `firebase functions:secrets:set STRIPE_SECRET_KEY`
     - `firebase functions:secrets:set STRIPE_WEBHOOK_SECRET`
     - `firebase deploy --only functions:stripeWebhook`
     - `stripe trigger subscription.created`

4) Real-device smoke tests (increases +10%) — OWNER ACTION REQUIRED
   - Action: Install signed apps on 1 iOS + 1 Android; execute customer + merchant flows end-to-end.

5) Configure monitoring/alerts (increases +5%) — OWNER ACTION REQUIRED
   - Command (example): `gcloud logging metrics create high-error-rate --description="CF 5xx" --log-filter="resource.type=cloud_function severity>=ERROR"`

