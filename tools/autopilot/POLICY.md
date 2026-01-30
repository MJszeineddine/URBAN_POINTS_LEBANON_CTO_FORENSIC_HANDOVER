# Autopilot Release Loop Policy

## Definition of Done (DoD)
- All gates exit with code 0 (strict).
- Evidence bundle generated under `local-ci/verification/autopilot/LATEST/`.
- Final report `reports/AUTOPILOT_FINAL_REPORT.md` present and accurate.
- `STATUS.md` updated automatically with verdict and gate statuses.

## Gates and Commands
1. required-files
   - Verify existence of `firebase.json`, `firestore.rules`, `storage.rules`, `.github/workflows/*.yml`.
2. security-scan
   - ripgrep patterns: `sk_live_`, `sk_test_`, `serviceAccount`, tracked `.env` files, private keys (`*.pem`, `*.p12`, `*.key`).
   - Allowlist: PUBLIC Firebase web API keys (`AIza...`), documented placeholders.
   - Exclusions: `local-ci/**`, `tools/**`, `**/reports/**`.
3. backend REST API
   - `cd source/backend/rest-api && npm ci && npm test`.
4. firebase-functions
   - `cd source/backend/firebase-functions && npm ci && npm test`.
5. web-admin
   - `cd source/apps/web-admin && npm ci && npm test` (or `npm run build` if tests not configured; record which).
6. mobile-customer
   - `cd source/apps/mobile-customer && flutter --version && flutter pub get && flutter analyze && flutter build apk --debug`.
7. mobile-merchant
   - `cd source/apps/mobile-merchant && flutter --version && flutter pub get && flutter analyze && flutter build apk --debug`.

## Fail Conditions
- Any gate exit code != 0 is FAIL.
- Security scan finds disallowed patterns in code (not docs) or tracked secrets.
- Missing required files.

## Evidence Bundle Layout
- `inventory/`: timestamp (Asia/Beirut), git commit/status before/after, tracked files snapshot.
- `logs/`: stdout/stderr logs per gate.
- `security/`: `security_scan.log`.
- `reports/`: `AUTOPILOT_FINAL_REPORT.md`.
- `proof/`: `SHA256SUMS.txt` for all evidence files.

## Iteration Cap
- Up to 5 retries fixing failures; if still failing, produce NO-GO with blockers.

## Output Requirements
- Print final verdict (GO/NO-GO).
- Print table of gates with exit codes.
- Print paths to report and evidence.
- Print first 60 lines of `AUTOPILOT_FINAL_REPORT.md` and first 40 lines of `SHA256SUMS.txt`.
