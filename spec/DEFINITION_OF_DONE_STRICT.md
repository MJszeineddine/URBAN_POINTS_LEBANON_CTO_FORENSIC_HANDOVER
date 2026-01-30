# Definition of Done - STRICT Gate System

**Date:** 2026-01-27  
**Purpose:** Non-cheatable, evidence-based repo readiness validation  
**Target:** Urban Points Lebanon - CTO Forensic Handover

---

## REPO_VERDICT Logic

**VERDICT = "GO"** if and only if ALL conditions hold:
1. **Callable Parity** (Gate A): `callable_parity.missing[]` is EMPTY
2. **Backend Callable Detection** (Gate A): Backend scan used TypeScript AST mode (`backend_mode == "ts-ast"`)
3. **Firestore Rules** (Gate B): Rules file valid AND deny-by-default catch-all EXISTS
4. **Config Canonicalization** (Gate B): Root `firebase.json` and `firestore.rules` exist
5. **Build Gates** (Gate C): All required gates PASSED (not skipped)
   - Firebase Functions: `npm ci && npm run build && npm run lint` → exit code 0
   - Web Admin: `npm ci && npm run build && npm run lint` → exit code 0
   - Flutter Customer: `flutter pub get && flutter analyze` → exit code 0 (flutter test if exists)
   - Flutter Merchant: `flutter pub get && flutter analyze` → exit code 0 (flutter test if exists)
6. **Evidence Complete** (Gate D): All required JSON/log files exist, non-empty
7. **No Internal Blockers** (Gate E): `FINAL_SUMMARY.internal_blockers[]` is EMPTY

**VERDICT = "NO-GO"** if:
- Any of the above conditions fail, UNLESS the failure is ONLY due to external blockers (missing tools, not logged in, missing secrets)
- External blockers are: node/npm/flutter/firebase-cli missing, Firebase project not configured, env secrets missing, iOS/Android signing keys missing
- Each external blocker MUST be backed by a log file path proving the failure

---

## Gate Definitions

### Gate A: Callable Parity (STRICT)

**Objective:** Ensure all client-side callable invocations have matching backend export definitions.

**Client Scan Coverage:**
- File extensions: `.dart`, `.ts`, `.tsx`, `.js`, `.jsx`
- Patterns to detect:
  - Dart: `httpsCallable('NAME')`, `FirebaseFunctions.instance.httpsCallable('NAME')`
  - TypeScript/JavaScript: `httpsCallable(functions, 'NAME')`, `httpsCallable('NAME')`, `functions.httpsCallable('NAME')`
- Exclude: `node_modules/`, `.next/`, `dist/`, `.git/`, `build/`

**Backend Scan Coverage (STRICT):**
- REQUIRED MODE: TypeScript AST parsing of `src/backend/firebase-functions/src/**/*.ts`
- Parse AST to detect actual onCall handlers:
  ```typescript
  export const NAME = onCall(...)
  export const NAME = https.onCall(...)
  export const NAME = onCall({...}, handler)
  export const NAME = functions.https.onCall(...)
  export const NAME = functions.v2.https.onCall(...)
  export { NAME } from './file'  // Follow re-exports recursively
  ```
- Fallback mode (REGEX): Only if TypeScript module unavailable; conservative scan of `src/**/*.ts` for `onCall` assignments
- **Fallback triggers NO-GO verdict** unless `missing[]` is empty and fallback is justified as external blocker

**Pass Criteria:**
- `missing[] = []` (empty)
- `client_used.count >= 10` (scan non-trivial)
- `backend_callables.count >= 10` (backend non-trivial)
- `backend_mode == "ts-ast"` (AST parsing, not regex fallback)

**Fail Examples:**
- Client calls `getPoints()` but backend has no `getPoints` export → INTERNAL blocker
- Backend scan falls back to regex due to no TypeScript → NO-GO with external blocker note

---

### Gate B: Firestore Rules & Config (STRICT)

**Objective:** Ensure Firestore rules are syntactically valid, have deny-by-default, and configs are canonicalized.

**Rules Validation:**
- File: Must exist at repo root (`firestore.rules`)
- Syntax: Balanced braces, valid rule statements
- Deny-by-default catch-all MUST exist:
  ```
  match /{document=**} {
    allow read, write: if false;
  }
  ```
- If catch-all missing → INTERNAL blocker
- If file missing → INTERNAL blocker

**Config Canonicalization:**
- Canonical: Root `firebase.json`, root `firestore.rules`
- Scan entire repo for duplicates: `firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`
- Duplicates found in non-root (e.g., `source/firebase.json`) → WARNING (documented in `config_duplicates.json`) but NOT blocking
- Missing root canonical → INTERNAL blocker

**Pass Criteria:**
- `firestore_rules_check.valid == true`
- `firestore_rules_check.has_deny_catch_all == true`
- `config_check.canonical_exists == true` (root firebase.json/firestore.rules)

---

### Gate C: Build Gates (STRICT)

**Objective:** All projects must compile, lint, and be ready for deployment.

**Firebase Functions:**
- Path: Auto-detect `package.json` with `"firebase-functions"` dependency, or `source/backend/firebase-functions/`
- Commands (in order):
  1. `npm ci --legacy-peer-deps` (clean install)
  2. `npm run build` (compile)
  3. `npm run lint` (style check)
- All must return exit code 0
- Skip only if node/npm missing → EXTERNAL blocker

**Web Admin (Next.js):**
- Path: Auto-detect `package.json` with `"next"` dependency under `source/apps`, or `source/apps/web-admin/`
- Commands:
  1. `npm ci --legacy-peer-deps`
  2. `npm run build`
  3. `npm run lint` (if script exists)
- Skip only if node/npm missing → EXTERNAL blocker

**Flutter Customer:**
- Path: `pubspec.yaml` containing `sdk: flutter` under `source/apps/mobile-customer/`
- Commands:
  1. `flutter pub get`
  2. `flutter analyze`
  3. `flutter test` (if `test/` directory exists)
- Skip only if flutter missing → EXTERNAL blocker

**Flutter Merchant:**
- Path: `pubspec.yaml` under `source/apps/mobile-merchant/`
- Commands: Same as customer
- Skip only if flutter missing → EXTERNAL blocker

**Pass Criteria:**
- All discovered workspaces PASSED required commands (exit code 0)
- NO skipped gates unless tool unavailable (external)
- All build logs captured in `logs/`

**Fail Examples:**
- TypeScript compilation error in functions → INTERNAL blocker, must fix code
- Flutter test fails → INTERNAL blocker, must fix test or code
- npm missing → EXTERNAL blocker, NO-GO justified

---

### Gate D: Evidence Bundle (STRICT)

**Objective:** All required artifacts exist and are properly populated.

**Required Files (must exist, non-empty):**
- `FINAL_SUMMARY.json` (contains verdict, blockers, counts)
- `FINAL_REPORT.md` (human readable, all gates listed)
- `callable_parity.json` (client_used, backend_callables, missing, scan_coverage)
- `firestore_rules_check.json` (valid, has_deny_catch_all, errors)
- `config_duplicates.json` (list of duplicates, canonical path, warnings)
- `gates.json` (entry for each gate: cmd, exit_code, log_file)
- `git-HEAD.txt` (current commit SHA)
- `git-log-1.txt` (last commit message)
- `git-status.txt` (staged/unstaged changes)
- `git-diff.patch` (diff of changes)
- `logs/*` (individual log files for each command)

**Pass Criteria:**
- All files present
- No zero-byte files
- JSON files parse without error
- Verdict recorded in FINAL_SUMMARY.json

---

### Gate E: Internal Blockers (STRICT)

**Objective:** No code-level issues remain; all discoverable problems are fixed.

**Blockers Classification:**
- **INTERNAL:** Code issue fixable by Copilot (missing callable, rule syntax, lint error, missing export, build error)
- **EXTERNAL:** Environment/toolchain (node/flutter missing, firebase not logged in, secrets not set, signing keys missing)

**Pass Criteria:**
- `FINAL_SUMMARY.internal_blockers[]` is EMPTY

---

## Execution Rules

1. **Evidence Truth:** Only on-disk evidence counts. Logs prove all claims.
2. **One Prompt:** No follow-ups. Fixes must happen within this execution.
3. **Reproducibility:** All commands logged; anyone can re-run gate runner and verify verdict.
4. **No Cheating:** Skip logic only for external blockers; no "pretending" gates passed.
5. **Loop Until Done:** If INTERNAL blockers found, fix and re-run within same execution.

---

## Success Criteria

- Branch: `release/dod-one-shot-strict`
- FINAL_SUMMARY.json: `repo_verdict: "GO"` OR justified `"NO-GO"` with external blockers only
- All code changes committed
- COPILOT_FINAL_MESSAGE.txt on disk in evidence dir
