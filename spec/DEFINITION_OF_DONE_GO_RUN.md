# Definition of Done - GO_RUN Pipeline

**Purpose:** Deterministic, self-healing build pipeline to verify deployment readiness today.

**GO_RUN Verdict:** TRUE only if ALL criteria pass.

---

## Gate A: Firebase Functions Build

**Objective:** Functions compile and are deployment-ready.

**Steps:**
1. Detect lockfile: if `source/backend/firebase-functions/package-lock.json` exists → use `npm ci`, else `npm install`
2. Run install with non-interactive flags: `npm ci --no-audit --no-fund --legacy-peer-deps` (or install)
3. Run build: `npm run build` (must exit code 0)

**Pass Criteria:** Both install and build return exit code 0. Build output artifact exists (`lib/index.js` or equivalent).

**Timeout:** 15 minutes per step.

---

## Gate B: Web Admin Build

**Objective:** Next.js web admin compiles and can start dev server.

**Steps:**
1. Detect lockfile: if `source/apps/web-admin/package-lock.json` exists → use `npm ci`, else `npm install`
2. Run install: `npm ci --no-audit --no-fund --legacy-peer-deps` (or install)
3. Run build: `npm run build` (must exit code 0)
4. **Smoke test (best-effort):** Start dev server (`npm run dev`), keep running for 8 seconds, terminate cleanly.
   - If dev server fails immediately (rc != 0 at startup): INTERNAL blocker.
   - If dev server runs for 8 seconds, then terminate: PASS (build already passed).
   - If dev server hangs or exceeds timeout after 8s: Still PASS (build passed, dev is best-effort).

**Pass Criteria:** Install rc 0, build rc 0. Smoke is best-effort (does not block if build passed).

**Timeout:** 15 min install, 15 min build, 20 sec smoke server.

---

## Gate C: Firebase Config Existence

**Objective:** Root-level config files present (will be used for deployment).

**Steps:**
1. Check file exists: `root/firebase.json` (existence only, no edit)
2. Check file exists: `root/firestore.rules` (if missing, create minimal deny-all)

**Pass Criteria:** Both files exist after gate runs.

**Note:** If rules missing, pipeline creates minimal rules as INTERNAL fix and retries.

---

## Gate D: Flutter Customer App

**Objective:** Flutter customer app compiles for debugging.

**Trigger:** Only run if `flutter` command is available on machine (check `which flutter`).

**Steps (if flutter exists):**
1. Run: `cd source/apps/mobile-customer && flutter pub get` (timeout 3 min)
2. Run: `flutter build apk --debug` (timeout 15 min)

**Pass Criteria:** Both commands exit code 0.

**If flutter NOT found:** Classify as EXTERNAL blocker (will not prevent GO_RUN).

**Timeout:** 3 min pub, 15 min build.

---

## Gate E: Flutter Merchant App

**Objective:** Flutter merchant app compiles for debugging.

**Trigger:** Only run if `flutter` command is available.

**Steps (if flutter exists):**
1. Run: `cd source/apps/mobile-merchant && flutter pub get` (timeout 3 min)
2. Run: `flutter build apk --debug` (timeout 15 min)

**Pass Criteria:** Both commands exit code 0.

**If flutter NOT found:** Classify as EXTERNAL blocker (will not prevent GO_RUN).

**Timeout:** 3 min pub, 15 min build.

---

## Gate F: Evidence Bundle Complete

**Objective:** All required artifacts exist and are non-empty.

**Required files in evidence dir:**
- `gates.json` (all gates recorded)
- `FINAL_SUMMARY.json` (verdict, blocker counts)
- `FINAL_REPORT.md` (human-readable)
- `logs/<gate_id>_stdout.log` (all gates)
- `logs/<gate_id>_stderr.log` (all gates)
- `logs/<gate_id>_meta.json` (all gates: rc, duration, timeout)

**Pass Criteria:** All files exist, no zero-byte files.

---

## GO_RUN Verdict Logic

```
GO_RUN = (Gate A rc 0) 
      AND (Gate B rc 0) 
      AND (Gate C exists) 
      AND (Gate F complete)
      AND (no INTERNAL blockers remain)
      AND ((Gate D rc 0 OR Gate D skipped EXTERNAL) 
           OR (Gate E rc 0 OR Gate E skipped EXTERNAL))
```

**In plain English:**
- Functions build MUST pass (non-negotiable).
- Web admin build MUST pass (non-negotiable).
- Config files MUST exist (non-negotiable).
- Evidence MUST be complete.
- Flutter is optional if toolchain missing (EXTERNAL blocker allowed); if toolchain exists, Flutter builds MUST pass.

---

## Blocker Classification

**INTERNAL:** Fixable by code changes or repo modifications (missing imports, compile errors, missing config files in repo, etc.).

**EXTERNAL:** Requires user action or environment setup (missing toolchain, secrets not set, auth required, iOS/Android signing, etc.).

---

## Evidence Location

All evidence for each run:
```
local-ci/evidence/GO_PIPELINE/<UTC_TIMESTAMP>/
├── gates.json
├── FINAL_SUMMARY.json
├── FINAL_REPORT.md
├── [FAIL_REASON.json] (if NO-GO)
└── logs/
    ├── <gate_id>_stdout.log
    ├── <gate_id>_stderr.log
    └── <gate_id>_meta.json
```

---

## Self-Healing Loop

Pipeline auto-runs up to 8 attempts. On INTERNAL failure:
1. Parse FAIL_REASON.json for failing_gate_id and suggested_targets.
2. Apply minimal fix to codebase.
3. Rerun: new evidence dir, same attempt counter.
4. Exit loop when GO_RUN or only EXTERNAL blockers remain.

**Examples of INTERNAL fixes:**
- Add missing npm dependencies
- Fix TypeScript compilation errors
- Create missing root config files
- Fix broken symlinks or path assumptions
- Update package versions if lockfile conflict

**No fix allowed:**
- Downgrading gates to "optional"
- Skipping lint/analyze as required (they are not GO_RUN; those are GO_QUALITY)
- Relaxing timeout criteria

---
