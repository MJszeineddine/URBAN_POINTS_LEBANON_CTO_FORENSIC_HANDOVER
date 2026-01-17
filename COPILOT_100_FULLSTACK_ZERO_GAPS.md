# Urban Points Lebanon — Copilot Master Completion File (100% Full-Stack, 0 Gaps)
You are GitHub Copilot running INSIDE this repository.

## NON-NEGOTIABLE MISSION
Bring the project to TRUE production-ready status with **0 gaps**, **full-stack**, using **CODE ONLY** as the source of truth.
Surfaces in scope:
- ✅ Flutter: `source/apps/mobile-customer`
- ✅ Flutter: `source/apps/mobile-merchant`
- ✅ Web Admin (Next.js): `source/apps/web-admin`
- ✅ Backend Functions: `source/backend/firebase-functions`
- ✅ Backend REST API: `source/backend/rest-api`
Out of scope:
- ❌ Any “mobile admin” app. If it exists partially or was referenced: remove/ignore it and ensure no dangling references.

You must:
1) Audit current repo state (code only) and derive a strict backlog from code.
2) Implement everything missing end-to-end.
3) Add hard gates so “false completion” becomes impossible.
4) Produce evidence artifacts on disk proving completion.

---

## ABSOLUTE RULES (EVIDENCE > CLAIMS)
- You are forbidden from saying “done/complete/finished/100%” unless all gates pass and evidence files exist on disk.
- Do NOT use PDFs, chats, roadmaps, or assumptions as truth. **Only code.**
- Every implemented feature must have:
  - Frontend anchors (routes/screens/components/services)
  - Backend anchors (callables/endpoints/collections/rules)
  - Tests or smoke checks
- If external credentials are required (Twilio, Stripe, Firebase deploy), create a `docs/BLOCKER_<NAME>.md` and STOP. No guessing.
- If a feature is “not required” you MUST remove it completely (code + routes + docs) so it is not a gap. No “planned”.

---

## PRIMARY ARTIFACTS YOU MUST MAINTAIN
Create/Update these files during work:
1) `spec/requirements.yaml`
   - The ONLY source of truth for completion.
   - Every requirement must be traceable to code anchors.
   - status: READY | PARTIAL | MISSING | BLOCKED
2) `docs/CTO_GAP_AUDIT.md`
   - Human report: what was missing and what you fixed, with anchors and evidence references.
3) `docs/PM_BACKLOG.md`
   - Ordered tasks (what you executed), each with acceptance criteria + evidence.
4) `tools/gates/cto_verify.py`
   - Hard gate that fails if any requirement not READY (except BLOCKED with blocker doc).
5) Evidence folder: `local-ci/verification/`
   - Must include logs + JSON outputs and test results.

---

## STEP 0 — HARD DISCOVERY (NO SKIPPING)
1) Create `local-ci/verification/` and write `surface_map.json` with all app roots found by scanning for:
   - Flutter: `pubspec.yaml` + `lib/main.dart`
   - Next.js/web: `package.json` + `pages/` or `src/`
   - Backend: `source/backend/**`
2) Confirm these exact surfaces exist:
   - `source/apps/mobile-customer`
   - `source/apps/mobile-merchant`
   - `source/apps/web-admin`
   - `source/backend/firebase-functions`
   - `source/backend/rest-api`
If anything is missing → write it in `docs/CTO_GAP_AUDIT.md` and create a backlog item.

---

## STEP 1 — BUILD REQUIREMENTS FROM CODE (NOT FROM DOCS)
You must generate `spec/requirements.yaml` by reading code and extracting requirements from *what the project intends to do based on existing modules*:
- Enumerate screens/routes/features in each app.
- Enumerate backend callables/endpoints/triggers/schedules.
- Enumerate Firestore collections implied by code.
- Enumerate admin actions implied by web-admin pages.
- Then classify each requirement as:
  - READY if wired end-to-end + no placeholders + passes tests
  - PARTIAL if missing wiring/backend/UI or has TODO/mock
  - MISSING if no implementation exists

IMPORTANT:
- Anything “exported” in backend but not referenced by any client must be either:
  A) integrated properly, OR
  B) deleted (if truly unnecessary) with safety review.

---

## STEP 2 — “0 GAPS” COMPLETION TARGETS (MANDATORY)
From current repo signals, you MUST ensure these are fully READY end-to-end (or removed cleanly):

### A) AUTH — WhatsApp OTP (Customer + Merchant)
Goal: Phone verification via WhatsApp OTP (Twilio or provider already used in backend).
Must include:
- send OTP via WhatsApp
- verify OTP
- secure storage (TTL), attempt limits, rate limiting
- audit logs for send/verify
- error handling UX
- tests with mocked provider

Client integration:
- Customer app auth UI must call backend OTP functions.
- Merchant app auth UI must call backend OTP functions.
- If email/google auth exists, decide:
  - Keep as secondary login, OR
  - Remove completely. But NO ambiguity. Must be coherent and secure.

### B) DEEP LINKS + NOTIFICATIONS
- Configure deep link handling in both Flutter apps.
- Notifications must open exact screens with payload (offer detail, wallet, redemption status, etc.).
- Add tests/smoke scripts for deep link parsing.

### C) REDEMPTION FLOW (Customer ↔ Merchant ↔ Backend)
- Customer generates QR token securely (TTL).
- Merchant scans QR and validates redemption with anti-replay protections.
- Redemption recorded server-side with audit logs.
- Customer sees redemption history and confirmations.
- Merchant sees redemption logs/history and export if relevant.

### D) POINTS SYSTEM (Wallet, history, expiration, adjustments)
- Customer wallet: balance, transaction history, expiration banner
- Backend: expiration logic reliable (scheduled jobs)
- Admin Web: points adjustment UI (transfer/adjust/expire) if backend supports it
- Security rules ensure only authorized roles can adjust/expire

### E) WEB ADMIN — Must be “operational admin” not “viewer”
Must include working UI for:
- Admin auth + RBAC
- Merchants: approve/suspend, profile review
- Offers: approve/reject/disable + audit trail view
- Users: search + ban/unban + anonymize/delete/export if supported
- Redemptions: audit log viewer + fraud signals + token revocation if supported
- Campaigns: push campaign compose/send/stats if backend exists
- Payments: manual payment verification workflows (and Stripe pages if present)
If backend supports a feature and admin has no UI → that is a gap → implement UI.

### F) GDPR / COMPLIANCE
- Add a Settings/Compliance UI in customer app for export/delete/anonymize if backend exists.
- Admin compliance tools if backend supports.
- Ensure data deletion/anonymization is real, not stubbed.

### G) SECURITY + DATA INTEGRITY
- Replace any direct Firestore writes for privileged flows with backend callables (example: FCM tokens).
- Ensure Firestore rules exist and match access patterns.
- Ensure indexes required by queries exist (and document them).

### H) REMOVE PLACEHOLDERS / MOCKS
- Search and eliminate placeholders/mocks in critical paths
- Example: analytics functions containing mock data must be fixed or removed

---

## STEP 3 — IMPLEMENTATION ORDER (DO NOT REORDER)
1) Fix build/lint/test baselines for each surface (so gates can run).
2) WhatsApp OTP end-to-end (backend + both apps).
3) Deep link handling + notification routing (both apps).
4) Redemption end-to-end (QR + scan + server validation + logs + history UI).
5) Admin Web operational coverage (campaigns, fraud, redemptions, points adjustments, payments).
6) GDPR UI + backend wiring.
7) Security hardening + rules/index alignment.
8) Remove unused orphan backend exports OR integrate them with UI.
9) Final polish: consistent error handling, loading states, empty states.

---

## STEP 4 — HARD GATES (MAKE FALSE PASS IMPOSSIBLE)
You MUST implement `tools/gates/cto_verify.py` to do all of the following:
- Parse `spec/requirements.yaml` and FAIL if any requirement is not READY (except BLOCKED with matching docs/BLOCKER_*.md).
- Verify each requirement has non-empty anchors.
- Verify routes exist for UI-marked features.
- Verify backend exports referenced by clients exist and are callable.
- Verify there are no TODO/mock/placeholder in critical modules (configurable allowlist).
- Verify test commands were executed and logs exist.

Additionally create:
- `local-ci/verification/cto_verify_report.json` (PASS/FAIL + details)
- `local-ci/verification/test_results.txt`
- `local-ci/verification/gate_run.log`

---

## STEP 5 — REQUIRED COMMANDS (RUN AND CAPTURE OUTPUT)
You must run (and store stdout+exit codes into `local-ci/verification/`):
- Customer app:
  - `flutter --version`
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test` (if tests exist; otherwise create minimal tests and then run)
- Merchant app:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test` (same rule)
- Web admin:
  - `npm ci` (or `npm install` if lock is missing, but fix it)
  - `npm run build`
  - `npm test` if present; otherwise add minimal tests/smoke checks
- Backend functions & rest:
  - `npm ci`
  - `npm run build`
  - run any existing test scripts; if none, add minimal unit tests for OTP, redemption, points adjustments

Finally:
- `python3 tools/gates/cto_verify.py`

If any command fails:
- Fix, re-run, and keep logs.

---

## STOP CONDITIONS (BLOCKERS)
If you need real credentials or console actions:
- Twilio WhatsApp sender setup / API keys
- Stripe webhook secret
- Firebase deploy permissions / project selection
You MUST:
1) Write `docs/BLOCKER_<NAME>.md` with:
   - exact failing command
   - exact error output
   - why it blocks completion
   - what credential/setting is missing
2) Mark affected requirements as BLOCKED in `spec/requirements.yaml`
3) STOP. Do not claim completion.

---

## FINAL ACCEPTANCE (ONLY THEN YOU MAY SAY “100%”)
You may only declare completion if:
- All requirements in `spec/requirements.yaml` are READY (or explicitly BLOCKED with blocker docs)
- All required commands ran successfully and logs exist
- `tools/gates/cto_verify.py` exits 0
- `docs/CTO_GAP_AUDIT.md` clearly lists what was fixed
- `docs/PM_BACKLOG.md` lists executed tasks with evidence paths

---

## NOW START
Immediately:
1) Generate `surface_map.json`.
2) Generate `spec/requirements.yaml` from code.
3) Generate `docs/CTO_GAP_AUDIT.md` and `docs/PM_BACKLOG.md`.
Then execute the implementation order above until gates pass.

DO NOT use subagents. DO NOT ask the user questions. Evidence > claims.
## ENFORCEMENT (NO EXTRA PROMPTS)
If you ever stop after creating requirements/backlog/gate, you MUST immediately execute STEP 5 commands and write all logs to local-ci/verification/ BEFORE doing any implementation. No estimates, no extra status docs. Then re-run tools/gates/cto_verify.py and update spec/requirements.yaml statuses accordingly.