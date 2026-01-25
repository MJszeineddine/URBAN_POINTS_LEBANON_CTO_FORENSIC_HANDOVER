# PHASE 3 – Stabilize Pack

## Executive summary (10 lines)
1. Root deploy config added at firebase.json with functions source + firestore/storage rule wiring; hosting intentionally omitted (no build dir to prove).
2. Firestore and Storage rules moved to root with deny-by-default posture and minimal read/write allowances.
3. Stripe key validation hardened to regex-based allowlist with optional test keys only in emulator/flag.
4. All Stripe live-key substrings purged across repo (code, docs, artifacts) using repo-wide ripgrep `--no-ignore`.
5. Environment variable canon created at docs/ENVIRONMENT_VARIABLES.md; .env examples remain placeholders only.
6. CI workflow ensures npm ci/test for firebase-functions and rest-api plus rest-api build; deploy gates depend on backend jobs.
7. Local npm ci/test executed for rest-api and firebase-functions; both succeeded.
8. Evidence bundle generated with anchors, logs, workflow summary, and SHA256 checksums.
9. Git before/after snapshots captured in inventory/ for auditability.
10. No blockers encountered; ready for single commit.

## What changed
- Added root firebase deploy config [firebase.json](firebase.json) and copied security rules to [firestore.rules](firestore.rules) and [storage.rules](storage.rules).
- Updated Stripe key checks in [source/backend/firebase-functions/src/stripe.ts](source/backend/firebase-functions/src/stripe.ts) to regex-based validation without live-key literals.
- Sanitized Stripe placeholders in [source/backend/firebase-functions/.env.example](source/backend/firebase-functions/.env.example) and created canonical env list at [docs/ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md).
- CI pipeline expanded: rest-api job now runs npm ci, lint, test, and build; backend functions unchanged but captured in summary [local-ci/verification/stabilize_pack/LATEST/ci/workflow_summary.md](local-ci/verification/stabilize_pack/LATEST/ci/workflow_summary.md).
- Evidence artifacts indexed in [local-ci/verification/stabilize_pack/LATEST/PROOF_INDEX.md](local-ci/verification/stabilize_pack/LATEST/PROOF_INDEX.md); checksums at [local-ci/verification/stabilize_pack/LATEST/SHA256SUMS.txt](local-ci/verification/stabilize_pack/LATEST/SHA256SUMS.txt).

## Security posture (rules)
- Firestore: deny-by-default; user/merchant scoped reads; server-only writes for tokens/redemptions/idempotency/audit/logs/otp; admin-only for admin registry, push campaigns, system alerts; public offer reads limited to active/approved; merchant updates constrained to own offers.
- Storage: deny-by-default; public path read-only; uploads limited to authenticated owner under uploads/{userId}, <10MB, image content type.

## Stripe safety
- Ripgrep `rg --no-ignore` for Stripe live-key prefix returns no matches (post-sanitization).
- Key validation uses `STRIPE_KEY_PATTERN` with optional test keys only when `ALLOW_STRIPE_TEST_KEYS=1` or emulator; live/test key literals removed from code and docs.

## CI summary
- firebase-functions job: npm ci → lint → npm test (emulator env vars) → npm run build.
- rest-api job: npm ci → lint → npm test --passWithNoTests → npm run build; deploy-staging waits on backend jobs and mobile jobs.

## Local test results
- source/backend/rest-api: npm ci && npm test — exit 0 (log [local-ci/verification/stabilize_pack/LATEST/tests/rest-api_test.log](local-ci/verification/stabilize_pack/LATEST/tests/rest-api_test.log)).
- source/backend/firebase-functions: npm ci && npm test — exit 0 (log [local-ci/verification/stabilize_pack/LATEST/tests/firebase-functions_test.log](local-ci/verification/stabilize_pack/LATEST/tests/firebase-functions_test.log)).

## Remaining blockers
- None. Ready for commit.
