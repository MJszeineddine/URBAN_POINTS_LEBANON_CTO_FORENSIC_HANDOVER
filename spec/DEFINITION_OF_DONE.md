# Definition of Done (DoD) - Urban Points Lebanon

## Overview

This document defines three readiness levels for the Urban Points Lebanon project:
- **GO_RUN**: Deterministic build + local smoke tests (no credentials required)
- **GO_PROD**: Production deployment ready (requires Firebase credentials)
- **GO_QUALITY**: Full quality gates with lint/analyze/test coverage

## Readiness Levels

### GO_RUN (Minimum Viable Build)

**Purpose**: Prove the codebase builds deterministically and runs locally without credentials.

**Gates** (ALL must PASS):
- A1: Firebase Functions install (npm ci/install)
- A2: Firebase Functions build (tsc compilation)
- A3: Web Admin install (npm ci/install)
- A4: Web Admin build (Next.js production build)
- A5: Web Admin dev smoke (8s local server start)
- A6: Firebase config valid (firebase.json, firestore.rules exist at root)
- A7: Firestore rules syntax valid
- A8: Flutter Customer pub get (if Flutter available)
- A9: Flutter Customer build apk --debug (if Flutter available, SKIP if missing)
- A10: Flutter Merchant pub get (if Flutter available)
- A11: Flutter Merchant build apk --debug (if Flutter available, SKIP if missing)

**Evidence Required**:
- gates.json (all gate results with rc, cmd, duration)
- logs/<gate>.log (stdout/stderr for each gate)
- FINAL_SUMMARY.json (verdict, level achieved, blockers)
- callable_parity.json (client callable usage vs server exports)
- toolchain_report.json (node, npm, flutter versions)

**Lint/Analyze Status**: LOGGED but NOT blocking (warnings recorded in evidence)

**Blockers**:
- INTERNAL: Missing dependencies, build errors, syntax errors, callable mismatches → FIXABLE
- EXTERNAL: Missing Flutter toolchain (SKIP gates), missing credentials (not required for GO_RUN)

**Exit Code**: 0 if GO_RUN achieved, 2 if INTERNAL blockers, 3 if EXTERNAL blockers prevent GO_RUN

---

### GO_PROD (Production Deployment Ready)

**Purpose**: Prove the system can deploy to Firebase production.

**Gates** (ALL GO_RUN gates + these):
- B1: Firebase login check (firebase projects:list)
- B2: Firebase emulators start (15s smoke with firestore + functions)
- B3: Firebase deploy --only functions (dry-run or real)
- B4: Firebase deploy --only firestore:rules
- B5: Firebase deploy --only hosting (web-admin)

**Evidence Required**: (all GO_RUN evidence + these)
- firebase_login.json (project ID, user email)
- emulator_smoke.log
- deploy_functions.log
- deploy_rules.log
- deploy_hosting.log

**Lint/Analyze Status**: LOGGED but NOT blocking

**Blockers**:
- INTERNAL: Build failures, missing firebase.json config, invalid rules → FIXABLE
- EXTERNAL: Missing `.firebaserc`, no Firebase login, no project permissions, missing service account → CANNOT FIX

**Exit Code**: 0 if GO_PROD achieved, 2 if INTERNAL blockers, 3 if EXTERNAL blockers (credentials/permissions)

---

### GO_QUALITY (Full Quality Assurance)

**Purpose**: Prove code quality with deterministic lint/analyze/test.

**Gates** (ALL GO_RUN gates + these; GO_PROD optional):
- C1: Firebase Functions lint (eslint with pinned version)
- C2: Firebase Functions test (jest)
- C3: Web Admin lint (eslint 8.x with .eslintrc.cjs, NOT flat config)
- C4: Web Admin typecheck (tsc --noEmit)
- C5: Flutter Customer analyze (if Flutter available)
- C6: Flutter Customer test (if Flutter available)
- C7: Flutter Merchant analyze (if Flutter available)
- C8: Flutter Merchant test (if Flutter available)

**Evidence Required**: (all GO_RUN evidence + these)
- lint_functions.log
- test_functions.log
- lint_web_admin.log
- typecheck_web_admin.log
- analyze_flutter_customer.log
- test_flutter_customer.log
- analyze_flutter_merchant.log
- test_flutter_merchant.log

**Lint/Analyze Status**: BLOCKING (all must pass with rc 0 or warnings only, no errors)

**Blockers**:
- INTERNAL: Lint errors, test failures, type errors, analyze errors → FIXABLE
- EXTERNAL: None (toolchain pinned hermetically)

**Exit Code**: 0 if GO_QUALITY achieved, 2 if INTERNAL quality issues

---

## Blocker Classification

### INTERNAL (Fixable by self-heal)
- Missing npm dependencies → npm install
- Build errors → fix syntax, add missing files
- Callable parity mismatch → add missing callable wrappers
- Lint errors → auto-fix with eslint --fix
- Type errors → add missing types or `any` annotations
- Test failures → fix logic or skip flaky tests
- Config duplicates → merge or remove

### EXTERNAL (Cannot fix without human input)
- Missing credentials (Firebase login, service account, API keys)
- Missing signing certificates (iOS/Android)
- Missing Flutter SDK (can SKIP gates but note in evidence)
- Missing Node.js version (report version mismatch, user must install)
- Missing secrets (.env files, Stripe keys)
- Missing permissions (Firebase project access)

---

## Evidence Structure

Every pipeline run MUST create:

```
local-ci/evidence/PIPELINE/<UTC_TIMESTAMP>/
  FINAL_SUMMARY.json          # verdict, level, blockers, durations
  gates.json                  # per-gate results
  logs/
    <gate>.log                # stdout/stderr for each gate
  git/
    HEAD.txt                  # current commit SHA
    status.txt                # git status --porcelain
    log-1.txt                 # git log -1
    diff.patch                # git diff (staged + unstaged)
  inventory/
    repo_tree_depth4.txt      # tree view of repo
    file_inventory.txt        # all files with sizes
  callable_parity.json        # client callables vs server exports
  firestore_rules_check.json  # rules syntax validation
  toolchain_report.json       # node, npm, flutter versions
  external_blockers.json      # (only if exit 3) missing credentials/secrets
```

---

## Timeouts (Python subprocess, cross-platform)

All commands MUST have timeouts to prevent hanging:

| Gate | Timeout |
|------|---------|
| npm ci/install | 12 min |
| npm run build (functions) | 12 min |
| npm run build (web-admin) | 12 min |
| npm run lint | 10 min |
| flutter pub get | 10 min |
| flutter build apk --debug | 15 min |
| flutter analyze | 10 min |
| flutter test | 10 min |
| firebase emulators:start | 15s smoke + SIGTERM |
| firebase deploy | 15 min |

---

## Hermetic Toolchain

To ensure deterministic builds across machines and CI:

1. **Node.js**: Pin version in `.nvmrc` (e.g., `20.18.1`)
2. **Package manager**: Use `npm` with `package-lock.json` (prefer `npm ci` over `npm install`)
3. **ESLint**: Pin to 8.x in web-admin (avoid ESLint 9 flat config surprises)
4. **Next.js/TypeScript**: Pin versions in web-admin package.json
5. **Firebase CLI**: Use npx with version or install as dev dependency
6. **Flutter**: Record channel/version but allow system Flutter (SKIP if missing)

Bootstrap script (`tools/bootstrap_hermetic.py`) verifies versions and reports mismatches as EXTERNAL blockers.

---

## CI Integration

`.github/workflows/go.yml` runs the same pipeline on every push:
- Checkout code
- Setup Node.js using `.nvmrc`
- Cache npm and flutter pub
- Run `python3 tools/go_pipeline.py`
- Upload evidence artifacts (even on failure)
- No secrets required for GO_RUN gates

---

## Contract Safety (Starter Mechanism)

To prevent callable mismatch between client and server:

1. **spec/api_contract/callables.json**: Auto-generated list of client-used callables
2. **tools/codegen_callables.py**: Can generate skeleton wrappers from contract (future use)
3. **callable_parity.json**: Evidence artifact showing client vs server match

Self-heal loop can add missing callable wrappers automatically if mismatch detected.

---

## Success Criteria

- **GO_RUN**: Exit 0, all A gates pass, evidence complete, no INTERNAL/EXTERNAL blockers
- **GO_PROD**: Exit 0, all A+B gates pass, evidence complete, Firebase deploy succeeds
- **GO_QUALITY**: Exit 0, all A+C gates pass, lint/analyze/test pass, evidence complete

---

## Failure Modes

- **Exit 2**: INTERNAL blockers → Self-heal can fix → Retry up to 6 iterations
- **Exit 3**: EXTERNAL blockers → Cannot fix → Report exact missing inputs → Stop

---

## Final Output Format

```
PIPELINE_DONE
VERDICT=<GO|NO-GO>
LEVEL=<GO_RUN|GO_PROD|GO_QUALITY|NO-GO>
EVIDENCE_DIR=<absolute path>
COMMIT=<sha or NONE>
BLOCKERS=<NONE or see external_blockers.json>
```
