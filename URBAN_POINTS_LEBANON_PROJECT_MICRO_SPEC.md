# URBAN POINTS LEBANON — PROJECT MICRO SPEC (EVIDENCE-BASED)

**Date:** 2026-01-24 (Asia/Beirut)

**Sources used (evidence files):**
- `/mnt/data/CURRENT_STATE.md`
- `/mnt/data/FORENSIC_REPORT_FULL_PROJECT.md`
- `/mnt/data/FORENSIC_INDEX.md`
- `/mnt/data/FORENSIC_SUMMARY.txt`
- `/mnt/data/FINAL_GATE.txt`

---

## 1) Executive Summary (What Exists + What Blocks Staging Deploy)

This repo contains a **full-stack loyalty/points system** with:
- **2 Flutter apps** (customer + merchant)
- **1 Next.js web admin**
- **Backend** (Firebase Functions + REST API)

Current state is **“works locally for some parts”** but **NOT proven “staging deploy = PASS”** yet because **environment + emulator/credentials gates are not fully satisfied**.

---

## 2) Repo Components (Exact Locations)

**Mobile (Flutter)**
- Customer app: `source/apps/mobile-customer`
- Merchant app: `source/apps/mobile-merchant`

**Web Admin (Next.js)**
- Admin web: `source/apps/web-admin`

**Backend**
- Firebase Functions: `source/backend/firebase-functions`
- REST API: `source/backend/rest-api`

**Infra**
- Firebase config: `source/infra`

---

## 3) Backend (What Exists)

Backend contains:
- Firebase Cloud Functions (TypeScript) for core platform actions (auth/points/offers/notifications + Stripe artifacts exist in codebase)
- REST API service (TypeScript) under `source/backend/rest-api`

Evidence files referenced in CURRENT_STATE include:
- `source/backend/firebase-functions/src/index.ts`
- `source/backend/rest-api/src/server.ts`
- `source/backend/firebase-functions/src/auth.ts`
- `source/backend/firebase-functions/src/fcm.ts`
- `source/backend/firebase-functions/src/stripe.ts`
- `source/backend/firebase-functions/src/middleware/validation.ts`

---

## 4) Gates Run (Evidence)

A “current state” gate run already exists (artifacts on disk) and shows **PARTIAL_PASS** (not full PASS for staging deploy).

Evidence artifacts path:
- `local-ci/verification/current_state/LATEST/`

What was executed (logged):
- Flutter presence check: `flutter --version`
- Flutter static analysis:
  - `source/apps/mobile-customer` → `flutter analyze`
  - `source/apps/mobile-merchant` → `flutter analyze`
- Node/NPM presence check: `node -v && npm -v`
- Backend + web installs/build/tests attempted with logs captured:
  - `source/backend/firebase-functions` → `npm test`
  - `source/backend/rest-api` → `npm test`
  - `source/apps/web-admin` → `npm install` and `npm run build`

Gate summary evidence file:
- `local-ci/verification/current_state/LATEST/gates/GATE_SUMMARY.json`

---

## 5) Blockers (What Prevents Staging Deploy = PASS)

**Staging deploy cannot be called PASS** until these are satisfied with evidence artifacts (logs + deploy targets):

1) **Environment variables**
   - `.env` must be created from templates and validated by gate scripts
   - Missing env = hard blocker

2) **Firebase project configuration / credentials**
   - Project ID + correct Firebase config must exist for staging
   - Missing credentials = hard blocker

3) **Firebase Functions test gate**
   - Evidence indicates functions tests may fail without emulator / env wiring
   - Must make a deterministic emulator-based test pass OR replace the gate with a correct “smoke test” that does not lie

4) **Stripe keys**
   - If Stripe functions exist, staging deploy requires test keys configured (do not guess)

5) **Database (if REST API depends on DB)**
   - If REST API expects Postgres or connection strings, staging needs a real staging DB or a controlled local docker test gate
   - Missing DB wiring = hard blocker

---

## 6) What You Must NOT Rebuild (Preserve Existing Work)

Do NOT rewrite/rebuild these components; they already exist:
- Flutter apps structure + main entrypoints exist
- Web admin pages exist
- Firebase functions + REST API scaffolding exists
- There is already a working “evidence output pattern” under `local-ci/verification/*`

Only do minimal changes to:
- Fix gates
- Add missing config templates
- Add emulator configs / scripts
- Add staging deploy scripts
- Produce PASS evidence artifacts

---

## 7) Staging Deploy Definition of Done (DoD)

Staging deploy is considered **DONE** only if ALL are true:

1) **Build gates PASS**
   - Web admin builds successfully
   - Both Flutter apps pass `flutter analyze` (and build gate if added)

2) **Unit tests / validation gates PASS**
   - Firebase functions tests PASS (or a verified emulator smoke test gate replaces invalid tests)
   - REST API tests PASS (or a verified smoke test gate)

3) **Smoke tests PASS**
   - At minimum: authenticated ping + critical endpoints smoke (backend) and a basic page render (web)

4) **Deploy staging PASS**
   - Backend deployed to staging target (Firebase project or equivalent)
   - Web deployed to staging (Firebase hosting or equivalent)
   - Evidence artifacts saved: logs + links/IDs

5) **Artifacts exist**
   - A single folder containing logs + summaries with **zero FAILs**

---

## 8) Minimal Execution Plan (No Rewrites, Only Close Blockers)

Target sequence:

1) **Freeze Definition**
   - Create one file that defines requirements + flows + DoD based only on existing code/screens/routes

2) **Config Normalization**
   - Validate `.env.example` files exist
   - Create a deterministic “env check” script that fails loudly if missing vars

3) **Firebase Emulator Lane**
   - Add emulator config + scripts so functions tests can run without production secrets
   - Make `npm test` (or smoke) deterministic

4) **REST API Lane**
   - Ensure REST API tests/smoke pass with either:
     - ephemeral DB (docker) OR
     - mocked adapter (only if already designed in code)

5) **Staging Deploy Lane**
   - Add scripts that deploy to a staging target (no guessing)
   - Capture evidence to `local-ci/verification/staging_gate/LATEST/`

Stop condition:
- If any secret/credential is required and missing, produce a `BLOCKER.md` with exact names and code references.

---

## 9) Forensic Metrics (Repo-Wide + Product-Code)

These numbers are copied from the forensic report (evidence), not guessed:

- Total files scanned: 148,496
- Repository size: 8.23 GB
- Product code files: 363
- Product lines of code: 81,570
- Repo-wide lines of code: 14,811,989
- Product code gate: PASS (0 read errors)
- Full repo gate: PASS (0 unreadable files)

---

## 10) Key Code Files Referenced in Evidence (Paths)

All paths below were explicitly referenced inside CURRENT_STATE evidence:

- `source/apps/mobile-customer/lib/main.dart`
- `source/apps/mobile-merchant/lib/main.dart`
- `source/apps/mobile-customer/lib/services/auth_service.dart`
- `source/apps/mobile-customer/lib/screens/qr_generation_screen.dart`
- `source/apps/mobile-merchant/lib/screens/onboarding/onboarding_screen.dart`
- `source/apps/web-admin/pages/_app.tsx`
- `source/apps/web-admin/pages/admin/merchants.tsx`
- `source/apps/web-admin/pages/admin/analytics.tsx`
- `source/backend/firebase-functions/src/index.ts`
- `source/backend/firebase-functions/src/auth.ts`
- `source/backend/firebase-functions/src/fcm.ts`
- `source/backend/firebase-functions/src/stripe.ts`
- `source/backend/firebase-functions/src/middleware/validation.ts`
- `source/backend/rest-api/src/server.ts`

---

## 11) Existing Gate Artifacts Locations (Where Evidence Lives)

From the CURRENT_STATE report, the gate artifacts live under:

- `local-ci/verification/current_state/LATEST/`
  - `reports/CURRENT_STATE.md`
  - `reports/FINAL_GATE.txt`
  - `reports/FEATURE_STATUS.json`
  - `gates/GATE_SUMMARY.json`
  - `inventory/REPO_TREE.txt`
  - `inventory/KEY_ENTRYPOINTS.txt`
  - `logs/commands.log`
  - `logs/flutter_version.log`
  - `logs/flutter_analyze_customer.log`
  - `logs/flutter_analyze_merchant.log`
  - `logs/node_version.log`
  - `logs/backend_functions_install.log`
  - `logs/firebase_functions_test.log`
  - `logs/rest_api_test.log`
  - `logs/web_admin_install.log`
  - `logs/web_admin_build.log`

---

## 12) Next Output You Want (Target Artifact Set)

The next successful step is a NEW folder with a FULL PASS staging gate run:

- `local-ci/verification/staging_gate/LATEST/`
  - `reports/FINAL_GATE.txt`  (must be PASS)
  - `gates/GATE_SUMMARY.json` (all PASS)
  - `logs/` (build/test/deploy logs, no missing commands)
  - `reports/STAGING_DEPLOY.md` (what was deployed + where)
  - `reports/ARTIFACT_LINKS.json` (URLs/IDs if applicable)

---

## 13) Non-Negotiable Constraints

- No duplicate implementations.
- Any missing secrets/config -> write a `BLOCKER.md` with exact required variables and where they are referenced; do not guess.
- No “deployment-ready” claims unless the staging gate artifacts above are produced.
