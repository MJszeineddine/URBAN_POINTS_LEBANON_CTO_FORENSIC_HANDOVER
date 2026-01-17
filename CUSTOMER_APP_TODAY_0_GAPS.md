# CUSTOMER_APP_TODAY_0_GAPS.md
You are GitHub Copilot running INSIDE this repository.

MISSION (TODAY):
Finish the **Customer App full-stack** to 0 gaps (production-ready by code + gates).
Scope:
- Flutter Customer: source/apps/mobile-customer
- Backend Functions used by customer: source/backend/firebase-functions
- (Web-admin + merchant out of scope TODAY except where required for customer callables)
Non-negotiable:
- Evidence > claims. You are FORBIDDEN from saying "done/complete/ready/100%" unless the gate exits 0.

ABSOLUTE RULES:
- Do not trust docs/CUSTOMER_APP_TODAY_INPUTS.md as truth if it claims READY without gate evidence.
- Only code + tools/gates/cto_verify.py decides.
- Do not write time estimates.
- Do not create extra instruction docs. Only:
  - create/modify actual code files
  - update spec/requirements.yaml statuses ONLY after real code is implemented
  - update local-ci/verification logs and cto_verify_report.json by re-running gate

-----------------------------------------
STEP 0 — REALITY CHECK (CUSTOMER ONLY)
-----------------------------------------
0.1 Read local-ci/verification/cto_verify_report.json and extract ONLY failing requirements that:
- id starts with "CUST-" OR
- have frontend_anchors under source/apps/mobile-customer

0.2 Create/Update this file (as evidence inventory only, not an instruction doc):
- local-ci/verification/customer_today_failures.json
Schema:
{
  "generated_at": "...",
  "customer_failures": [
    { "id": "...", "status": "...", "why": "...", "frontend_anchors": [...], "backend_anchors": [...] }
  ]
}

0.3 Hard rule:
- If any customer requirement is marked READY but has missing/weak anchors or no real implementation, downgrade to PARTIAL immediately (do not lie).

-----------------------------------------
STEP 1 — ROUTES + MISSING SCREENS (NO GAPS)
-----------------------------------------
Goal: ensure every required screen exists and is reachable.

1.1 Create missing screens (if they do not exist):
A) Favorites:
- Create: source/apps/mobile-customer/lib/screens/favorites_screen.dart
  Requirements:
  - reads favorites from Firestore at users/{uid}/favorites (or the existing schema used by _toggleFavorite)
  - displays list with tap -> opens OfferDetailScreen
  - supports unfavorite

B) Redemption Confirmation:
- Create: source/apps/mobile-customer/lib/screens/redemption/redemption_confirmation_screen.dart
  Requirements:
  - takes args: redemptionId (and optional status/details)
  - calls backend callable confirmRedemption if needed to fetch final details
  - shows offer title, merchant name, points earned, timestamp, status
  - success/failure UI

C) Redemption History:
- Create: source/apps/mobile-customer/lib/screens/redemption/redemption_history_screen.dart
  Requirements:
  - queries redemptions for current user
  - shows list with status + merchant/offer + points + timestamp
  - tap item -> opens RedemptionConfirmationScreen for details

1.2 Wire routes in source/apps/mobile-customer/lib/main.dart:
- Add named routes:
  /favorites -> FavoritesScreen
  /redemption_history -> RedemptionHistoryScreen
- Ensure navigation exists from UI (home/profile/settings) to these routes:
  - Favorites entry point (e.g., in profile tab or app bar)
  - Redemption history entry point (e.g., in wallet/points screen)

1.3 Add minimal widget tests (create if missing):
- source/apps/mobile-customer/test/screens/favorites_screen_test.dart
- source/apps/mobile-customer/test/screens/redemption_history_screen_test.dart
- source/apps/mobile-customer/test/screens/redemption_confirmation_screen_test.dart
Tests must:
- render screen with mocked dependencies (Firebase mocked)
- verify main UI elements exist

-----------------------------------------
STEP 2 — GDPR UI WIRING (BACKEND EXISTS, UI MISSING)
-----------------------------------------
Goal: Wire existing privacy callables to Settings screen.

2.1 Implement in:
- source/apps/mobile-customer/lib/screens/settings_screen.dart

Add 2 actions:
A) Export My Data
- Calls backend callable exportUserData (firebase functions)
- Shows loading + success dialog
- Stores JSON locally OR shares (use share_plus if already in deps; if not, add minimal local save to temp dir with path_provider)

B) Delete Account
- Strong confirmation dialog
- Calls backend callable deleteUserData
- On success: signs out and routes to onboarding/login

Important:
- Do NOT invent "password re-entry" unless the current auth provider supports it.
- Use a safe re-auth mechanism that matches current code:
  - If Firebase email/password exists, then reauth with password
  - Otherwise require a second confirmation step + recent sign-in check + OTP re-verify if supported
- Whatever you do must be implementable with existing auth stack.

2.2 Tests:
- source/apps/mobile-customer/test/screens/settings_gdpr_test.dart
Must verify:
- buttons exist
- calling export triggers function call
- calling delete triggers function call

-----------------------------------------
STEP 3 — DEEP LINKS + NOTIFICATION TAP ROUTING (CUSTOMER)
-----------------------------------------
Goal: When user taps a notification or opens a deep link, app routes correctly (cold + warm).

3.1 Implement deep link service:
- Create: source/apps/mobile-customer/lib/services/deep_link_service.dart
Responsibilities:
- parse URLs like:
  uppoints://offer/<id>
  uppoints://redemption/<id>
  uppoints://points
- expose method: handleUri(Uri uri, BuildContext context)

3.2 Platform configs:
- iOS: source/apps/mobile-customer/ios/Runner/Info.plist
  Add URL scheme "uppoints"
- Android: source/apps/mobile-customer/android/app/src/main/AndroidManifest.xml
  Add intent-filter for scheme "uppoints"

3.3 Wire in main.dart:
- On app start, listen to initial link + stream (uni_links if used; otherwise implement minimal deep link handling available in current deps).
- For FCM notification tap:
  - Replace any hardcoded Navigator.push with routing that maps payload -> same destinations.
  - Must handle:
    - offer detail
    - redemption detail/history
    - wallet/points

3.4 Tests:
- source/apps/mobile-customer/test/services/deep_link_service_test.dart
Must verify:
- URL parsing routes to expected screen builders.

-----------------------------------------
STEP 4 — OFFERS SEARCH + FILTERS (FULL-STACK)
-----------------------------------------
Goal: Stop pretending client-side filter is "ready". Implement backend callables and wire UI.

4.1 Backend (firebase-functions):
In source/backend/firebase-functions/src/core/offers.ts
Implement callables (if missing):
- searchOffers({ query })
- getFilteredOffers({ category?, location?, minPoints?, maxPoints?, query? })

Implementation constraints (no external SaaS):
- Use Firestore queries with reasonable limitations:
  - For query: store/search against normalized fields (e.g., titleLower) with range query prefix matching
  - For filters: apply where clauses and orderBy with required indexes
- If indexes are required:
  - Add/create firestore.indexes.json at repo root OR the correct backend folder standard used by this repo.
  - If the repo truly has no Firebase config files and you cannot determine correct location, create docs/BLOCKER_FIRESTORE_INDEXES.md and mark requirements BLOCKED. (No guessing.)

4.2 Customer UI wiring:
In source/apps/mobile-customer/lib/screens/offers_list_screen.dart
- Replace local-only search/filter with calls to the backend callables.
- Add loading/empty/error states.

4.3 Tests:
Backend:
- source/backend/firebase-functions/src/core/offers.test.ts (or existing test folder standard)
Customer:
- source/apps/mobile-customer/test/screens/offers_search_filter_test.dart

-----------------------------------------
STEP 5 — REDEMPTION "CUSTOMER SIDE" COMPLETION
-----------------------------------------
Goal: customer gets confirmed outcome and history.

5.1 Ensure customer flow:
- QR generation exists (qr_generation_screen.dart). Keep it.
- After merchant validates/consumes QR, customer must see confirmation:
  - Use RedemptionConfirmationScreen + confirmRedemption callable.

5.2 If confirmRedemption callable exists but returns insufficient details:
- extend it safely in backend core/qr.ts to return needed fields:
  redemptionId, status, offerId, merchantId, pointsEarned, createdAt
- ensure access control: only the redemption's user can read their redemption

5.3 Tests:
- customer redemption confirmation/history tests already required above
- backend qr confirmation unit tests (if missing)

-----------------------------------------
STEP 6 — CUSTOMER TEST BASELINE (NO FAKE "READY")
-----------------------------------------
6.1 Ensure flutter test runs real tests (not only dummy):
- Create/expand tests to cover:
  - Favorites
  - Redemption history + confirmation
  - GDPR actions
  - Deep link parsing
  - Offers search/filter wiring (mock functions)

6.2 Do NOT enforce code coverage % if toolchain not present.
Instead: require that all created tests run and pass.

-----------------------------------------
STEP 7 — UPDATE REQUIREMENTS (TRUTHFUL ONLY)
-----------------------------------------
7.1 Edit spec/requirements.yaml:
- For each customer requirement you actually completed end-to-end, set status to READY.
- If partially done, keep PARTIAL.
- If blocked by missing Firebase config files / deploy-only credentials:
  - create docs/BLOCKER_<NAME>.md
  - set status to BLOCKED
- Never leave a READY requirement with empty anchors.

-----------------------------------------
STEP 8 — EVIDENCE RUN (MANDATORY)
-----------------------------------------
Run and capture logs (append exit codes):
Customer:
- cd source/apps/mobile-customer
- flutter pub get
- flutter analyze
- flutter test

Backend:
- cd source/backend/firebase-functions
- npm ci
- npm run build
- npm test

Then:
- cd repo root
- python3 tools/gates/cto_verify.py 2>&1 | tee local-ci/verification/gate_run.log

Write/confirm these files exist and are non-empty:
- local-ci/verification/customer_app_test.log (update/create)
- local-ci/verification/backend_functions_test.log (update/create)
- local-ci/verification/cto_verify_report.json

If gate fails:
- fix and rerun. No claims.

-----------------------------------------
STOP / OUTPUT REQUIREMENT
-----------------------------------------
When you finish, output ONLY:
- the final gate summary lines
- confirmation that CHECK 1 customer requirements are all READY/BLOCKED
- paths to the evidence logs and cto_verify_report.json

DO NOT mention time estimates.
DO NOT claim 100% unless gate exits 0.
