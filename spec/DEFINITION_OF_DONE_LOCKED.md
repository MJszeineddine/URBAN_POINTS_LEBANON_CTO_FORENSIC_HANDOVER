# Definition of Done - LOCKED (Non-Cheatable)

**Date:** 2026-01-28  
**Purpose:** Final, non-negotiable repo readiness gate  
**Enforcer:** Independent verifier script (verify_evidence_locked.py)

---

## REPO_VERDICT Logic (HARD RULES)

**VERDICT = "GO"** if and only if **ALL** conditions hold:

### Gate A: Callable Parity (STRICT - NO FALLBACK)
- `callable_parity.missing[]` = empty (0 missing callables)
- `backend_scan_mode` = `"ts-ast"` (MUST use TypeScript AST, NOT regex fallback)
- If TypeScript not available: EXTERNAL blocker → NO-GO
- If regex fallback used: DOWNGRADE to NO-GO (no exceptions)

### Gate B: Firebase Functions Build (STRICT)
- `npm ci --legacy-peer-deps` → exit code 0
- `npm run build` → exit code 0
- `npm run lint` → exit code 0 (NOT optional)
- If any fails: INTERNAL blocker → NO-GO

### Gate C: Web Admin Build (STRICT)
- `npm ci --legacy-peer-deps` → exit code 0
- `npm run build` → exit code 0
- `npm run lint` → exit code 0 (NOT optional)
- If any fails: INTERNAL blocker → NO-GO

### Gate D: Flutter Customer (STRICT)
- `flutter pub get` → exit code 0
- `flutter analyze` → exit code 0 (NO "info warnings only")
- If any fails: INTERNAL blocker → NO-GO

### Gate E: Flutter Merchant (STRICT)
- `flutter pub get` → exit code 0
- `flutter analyze` → exit code 0 (NO "info warnings only")
- If any fails: INTERNAL blocker → NO-GO

### Gate F: Firestore Rules (STRICT)
- `firestore_rules_check.valid` = true
- `firestore_rules_check.has_deny_catch_all` = true
- Rules file exists at repo root
- If any fails: INTERNAL blocker → NO-GO

### Gate G: Config Canonicalization (STRICT)
- `firebase.json` exists at repo root
- `firestore.rules` exists at repo root
- Duplicates documented (not blocking, but logged)

### Gate H: Evidence Complete (STRICT)
- All required JSON files exist and non-empty
- All build logs captured
- Git snapshots captured
- Verifier confirms all artifacts present

---

## Independent Verifier

**Script:** `tools/verify_evidence_locked.py`

**Input:** Evidence directory path

**Output:**
- `GO` (exit 0) → all gates PASSED
- `NO-GO` (exit 2) → one or more gates FAILED

**Checks (NO EXCEPTIONS):**
1. gates.json: every required gate has `"passed": true` AND `exit_code == 0`
2. callable_parity.json: `missing[]` empty AND `backend_scan_mode == "ts-ast"`
3. firestore_rules_check.json: `valid == true`
4. config_duplicates.json: root canonical exists
5. All artifact files exist, non-empty, valid JSON
6. No relaxed logic: if lint/analyze in gates.json shows `exit_code != 0`, verdict is NO-GO

**THIS SCRIPT IS LOCKED AND CANNOT BE EDITED MID-RUN TO RELAX CHECKS.**

---

## Gate Runner

**Script:** `tools/dod_gate_runner_locked.py`

**Responsibilities:**
1. Ensure TypeScript is available in functions workspace (add to package.json if missing, run `npm ci`)
2. Run AST-based callable scanner (via `tools/_callable_ast_scan.js`)
   - If AST scan fails: mark EXTERNAL blocker, NO-GO
3. Execute all build gates (no skipping, no "optional")
4. Capture evidence (JSON + logs)
5. Call independent verifier at the end
6. Write FINAL_SUMMARY.json based on verifier result ONLY

---

## Internal vs External Blockers

**INTERNAL (Copilot must fix):**
- Missing callable implementations
- Build/lint/analyze errors in code
- Firestore rules syntax/structure errors
- Config file issues (missing root canonical, broken symlinks)

**EXTERNAL (Cannot fix, blocks GO):**
- Node/npm not installed (but TypeScript missing in workspace is INTERNAL)
- Flutter CLI not installed
- Firebase CLI not logged in
- Missing Firebase project configuration
- Missing signing keys (iOS/Android)
- Missing secrets/environment variables needed to build

---

## No Compromises

- Lint/analyze failures = INTERNAL blocker (must fix code)
- Flutter analyze "info" level = still counts as failure (fix the code)
- Regex fallback = EXTERNAL blocker → NO-GO (no AST available)
- Optional gates = DO NOT EXIST (all gates required)

---

## Success Criteria

- Branch: `release/dod-locked`
- FINAL_SUMMARY.json: `repo_verdict: "GO"` as determined by verifier
- All code changes committed (if GO)
- COPILOT_FINAL_MESSAGE.txt on disk with evidence path
