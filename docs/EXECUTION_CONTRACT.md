# EXECUTION CONTRACT - URBAN POINTS PHASE 3

**Version:** 1.0  
**Date:** 2026-01-06  
**Status:** CANONICAL - All execution must follow this contract

---

## MISSION

Provide a **COPILOT-PROOF** execution workflow that:
1. NEVER enters infinite loops
2. ALWAYS produces GO/NO-GO status
3. ALWAYS produces on-disk evidence artifacts
4. NEVER silently hangs

---

## FOUNDATION LOCK: ENV_GATE

**Script:** `tools/env_gate.sh`

### Required Checks

| Check | Command | Expected Output | Pass Marker |
|-------|---------|-----------------|-------------|
| Node Version | `node -v` | v20.x.x or v18.x.x | `v20` or `v18` |
| NPM Version | `npm -v` | 10.x.x or 9.x.x | Exit code 0 |
| Java Version | `java -version` | openjdk 17 or 21 | `openjdk` |
| Port 8080 | `lsof -ti tcp:8080` | Empty or PID | Not occupied or known emulator |
| Port 9099 | `lsof -ti tcp:9099` | Empty | Not occupied |
| Port 9150 | `lsof -ti tcp:9150` | Empty | Not occupied |
| IPv4 Normalized | Check FIRESTORE_EMULATOR_HOST | Must be `127.0.0.1:8080` | No `localhost` or `::1` |
| Emulator Probe | `nc -z 127.0.0.1 8080` (2s timeout) | Exit 0 if running, 1 if not | Known state |

### Blocker Detection

If ANY check fails, `tools/env_gate.sh` MUST:
1. Exit with non-zero code
2. Print exactly ONE line starting with: `BLOCKER_ENV_GATE: <reason>`
3. Write blocker to `/tmp/phase3/<ts>/env.log`

**Examples:**
```
BLOCKER_ENV_GATE: Node version v16.x.x unsupported (require v18+)
BLOCKER_ENV_GATE: Port 8080 occupied by PID 12345 (not emulator)
BLOCKER_ENV_GATE: Java not found in PATH
BLOCKER_ENV_GATE: FIRESTORE_EMULATOR_HOST=localhost:8080 (must use 127.0.0.1)
```

### NO-GO Handling

If ENV_GATE fails:
- **DO NOT** run phase gate
- **DO NOT** run tests
- **DO NOT** attempt deploy
- Output: `NO-GO (ENV_BLOCKER)` to terminal and `status.txt`
- Evidence: `env.log` with blocker details

---

## GATE-ONLY WORKFLOW

### Execution Sequence

```
1. ENV_GATE        → env.log + blocker detection
   ↓ (if PASS)
2. PHASE3_GATE     → gate.log + 9 checks
   ↓ (if PASS)
3. TESTS           → tests.log + emulator lifecycle
   ↓ (if PASS)
4. DEPLOY_DRY_RUN  → deploy.log + validation
   ↓
5. GO/NO-GO        → status.txt + OUTPUT.md
```

### Local/CI Mode: Deploy is Optional

**Deploy Gate Behavior:**
- If cloud credentials are present (GOOGLE_APPLICATION_CREDENTIALS file, gcloud ADC, or `firebase projects:list` succeeds):
  - Deploy runs (dry-run in CI, can be real with credentials)
  - If auth/perm errors found → deploy_status=97 → NO-GO (DEPLOY_AUTH_BLOCKER)
  - If deploy succeeds → GO
- If cloud credentials are absent:
   - Deploy is SKIPPED (neutral outcome)
   - deploy.log contains the following lines:
      - "[deploy] START <timestamp>"
      - "DEPLOY_MODE=SKIPPED"
      - "DEPLOY_SKIPPED_NO_CREDENTIALS: Local/CI mode"
      - "[deploy] END   <timestamp> (status=0)"
   - deploy_status=0 and deploy_mode="SKIPPED" in meta.json
   - Readiness verdict: READY_FOR_CLOUD_CUTOVER (all local gates pass)

### Stop Conditions

Execution MUST stop at the **first failure** in the sequence:
- ENV_GATE fails → NO-GO (ENV_BLOCKER)
- PHASE3_GATE fails → NO-GO (GATE_BLOCKER)
- TESTS fail → NO-GO (TEST_BLOCKER)
- DEPLOY fails (auth/perm error) → NO-GO (DEPLOY_AUTH_BLOCKER)
- DEPLOY skipped or passes → continue to GO verdict

### Timeouts (Enforced)

| Step | Timeout | Enforcement |
|------|---------|-------------|
| ENV_GATE | 30s | Script internal |
| PHASE3_GATE (build) | 5min | `timeout` or `gtimeout` |
| PHASE3_GATE (tests) | 10min | `timeout` or `gtimeout` |
| TESTS (full) | 10min | CI runner timeout |
| DEPLOY_DRY_RUN | 5min | Firebase CLI timeout |

If ANY step exceeds timeout:
- Kill process
- Write `TIMEOUT: <step>` to log
- Exit with `NO-GO (TIMEOUT)`

---

## CLOUD CUTOVER CHECKLIST (One-Time Setup)

To enable real cloud deploy after Local/CI gates pass:

### Option A: Google Cloud ADC (Easiest)
```bash
gcloud auth application-default login
# Re-run: bash tools/release_gate.sh
# Deploy will now execute against your GCP project
```

### Option B: Service Account JSON
```bash
# 1. Create service account in GCP Console with Firebase Admin role
# 2. Download JSON key file
# 3. export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
# 4. Re-run: bash tools/release_gate.sh
```

### Verification
Before re-running gates, verify credentials:
```bash
gcloud auth application-default print-access-token 2>/dev/null && echo "ADC OK" || echo "ADC missing"
firebase projects:list 2>/dev/null && echo "Firebase CLI OK" || echo "Firebase CLI not authenticated"
```

### Expected Result
- deploy.log will show: "Deploying to 'urbangenspark'..." (not "DEPLOY_SKIPPED")
- status.txt will include deploy_exit=0 on success
- Final status: GO (all gates pass including deploy)

---

## EVIDENCE REQUIREMENTS

### Mandatory Artifacts (Every Run)

Must be written to:
1. `/tmp/phase3/<timestamp>/` (ephemeral)
2. `docs/parity/evidence/phase3/<timestamp>/` (permanent)

#### Required Files

| File | Contents | Min Size | Max Age |
|------|----------|----------|---------|
| `env.log` | ENV_GATE output + checks | 500 bytes | Current run |
| `gate.log` | PHASE3_GATE full output | 2KB | Current run |
| `tests.log` | Test execution + results | 10KB | Current run |
| `deploy.log` | Deploy dry-run output | 1KB | Current run |
| `status.txt` | Final GO/NO-GO status (+ exit codes) | 50 bytes | Current run |
| `OUTPUT.md` | Summary + excerpts | 5KB | Current run |
| `meta.json` | Timestamp, git sha, node/npm/java, exit codes | 300 bytes | Current run |

#### Evidence Validation

Before declaring GO/NO-GO, verify:
```bash
[ -f env.log ] && [ $(wc -c < env.log) -gt 500 ]
[ -f gate.log ] && [ $(wc -c < gate.log) -gt 2000 ]
[ -f tests.log ] && [ $(wc -c < tests.log) -gt 10000 ]
[ -f status.txt ] && grep -qE '^(GO|NO-GO)' status.txt
[ -f meta.json ] && grep -q 'timestamp' meta.json
```

If validation fails:
- Output: `NO-GO (EVIDENCE_INCOMPLETE)`
- Reason: List missing files

---

## RETRY BUDGET

### Per-Blocker Limits

| Blocker Type | Max Retries | Action After Budget |
|--------------|-------------|---------------------|
| ENV_GATE | 0 | Fix environment, do not retry |
| GATE_BLOCKER (lint/build) | 1 | Fix code, manual intervention required |
| TEST_BLOCKER | 1 | Fix tests, manual intervention required |
| TIMEOUT | 0 | Investigate hang, do not retry |
| DEPLOY_BLOCKER | 2 | Check credentials/network |

### Exhaustion Protocol

When retry budget exhausted:
1. Write `BLOCKER_EXHAUSTED: <type>` to `status.txt`
2. Output full stack trace to evidence logs
3. Exit with `NO-GO (INTERVENTION_REQUIRED)`
4. Do NOT continue

---

## EVIDENCE > CLAIMS POLICY (STRICT)

### Rules

1. **NEVER** say "PASS" without citing log line
2. **NEVER** say "tests passed" without showing `Tests: X passed`
3. **NEVER** say "deployed successfully" without showing deployment ID
4. **ALWAYS** show exact file paths + excerpts

### Example (CORRECT)

```
✅ Tests PASS
Evidence: /tmp/phase3/20260106_185748/tests.log:87
  "Tests: 22 passed, 22 total"
```

### Example (FORBIDDEN)

```
Tests passed successfully.
```
*(No file path, no line number, no excerpt = INVALID)*

---

## EXECUTION SCRIPTS

### Primary Entry Point

**Script:** `tools/phase3_evidence_capture.sh`

**Responsibilities:**
1. Call `tools/env_gate.sh` first
2. Store all logs to timestamped directories
3. Stream output to terminal (unbuffered)
4. Always finish with GO/NO-GO
5. Never hang (all steps have timeouts)

**Usage:**
```bash
cd /path/to/repo
bash tools/phase3_evidence_capture.sh
```

**Expected Output:**
```
[ENV_GATE] Starting environment validation...
[ENV_GATE] ✓ Node v20.11.0
[ENV_GATE] ✓ Java 17.0.9
[ENV_GATE] ✓ Ports clear
[ENV_GATE] PASS

[GATE] Running phase3_gate.sh...
[GATE] CHECK 1-9: PASS
[GATE] Build: PASS
[GATE] Tests: 22/22 passed

[DEPLOY] Dry-run validation...
[DEPLOY] Config valid

FINAL STATUS: GO
Evidence: docs/parity/evidence/phase3/20260106_185748/
```

### Evidence Capture Contract

`tools/phase3_evidence_capture.sh` MUST:
- Use `script -q` or `tee` for dual-stream output
- Print progress markers every 10s for long operations
- Kill child processes on EXIT trap
- Write `status.txt` as last action

---

## OUTPUT.md TEMPLATE

Every run MUST produce `OUTPUT.md` with:

```markdown
# PHASE 3 EXECUTION REPORT

**Timestamp:** <YYYY-MM-DD HH:MM:SS>
**Evidence Dir:** docs/parity/evidence/phase3/<timestamp>/

---

## ENVIRONMENT (ENV_GATE)

Node: <version>
NPM: <version>
Java: <version>
Ports: <status>

Status: <PASS|FAIL>
Blocker: <if any>

---

## GATE (phase3_gate.sh)

CHECK 1-9: <results>
Build: <PASS|FAIL>

---

## TESTS (npm run test:ci)

Test Suites: <X passed, Y total>
Tests: <X passed, Y total>
Time: <duration>

Status: <PASS|FAIL>
Failures: <if any>

---

## DEPLOY (dry-run)

Config Validation: <PASS|FAIL>
Functions: <list>

---

## FINAL STATUS

Result: <GO|NO-GO>
Reason: <if NO-GO>
Evidence Files: <list>

---

## LOG EXCERPTS

### GATE (first 80 + last 40 lines)
```
<excerpt>
```

### TESTS (last 60 lines)
```
<excerpt>
```

### DEPLOY (last 60 lines)
```
<excerpt>
```
```

---

## FORBIDDEN PATTERNS

These patterns are **STRICTLY FORBIDDEN** in execution scripts:

### 1. Unchecked Pipes
```bash
# FORBIDDEN
grep foo bar.log | wc -l
```
```bash
# CORRECT
{ grep foo bar.log || true; } | wc -l
```

### 2. Unbound Variables
```bash
# FORBIDDEN
echo $SOME_VAR
```
```bash
# CORRECT
set -u
echo "${SOME_VAR:-default}"
```

### 3. Silent Failures
```bash
# FORBIDDEN
npm run build
npm run test
```
```bash
# CORRECT
npm run build || { echo "Build failed"; exit 1; }
npm run test || { echo "Tests failed"; exit 1; }
```

### 4. Infinite Waits
```bash
# FORBIDDEN
while ! nc -z 127.0.0.1 8080; do sleep 1; done
```
```bash
# CORRECT
timeout 60 bash -c 'while ! nc -z 127.0.0.1 8080; do sleep 1; done'
```

### 5. Hidden Output
```bash
# FORBIDDEN (for user-facing runs)
npm run build > /dev/null 2>&1
```
```bash
# CORRECT
npm run build 2>&1 | tee build.log
```

---

## SUCCESS CRITERIA

A run is **GO** if and only if:

1. ✅ ENV_GATE: All checks PASS
2. ✅ PHASE3_GATE: All 9 checks PASS
3. ✅ PHASE3_GATE: Build completes (0 errors)
4. ✅ TESTS: 22/22 tests pass
5. ✅ DEPLOY: Dry-run validates config
6. ✅ EVIDENCE: All 6 required files present
7. ✅ EVIDENCE: All logs > minimum size
8. ✅ NO TIMEOUTS

If ANY criterion fails: **NO-GO**

---

## MAINTENANCE

### When to Update This Contract

1. Adding new phases (Phase 4, 5, etc.)
2. Changing timeout values
3. Adding new evidence requirements
4. Changing tool versions (Node, Java, etc.)

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-06 | Initial contract for Phase 3 |

---

**END OF EXECUTION CONTRACT**

This is the SINGLE SOURCE OF TRUTH for Phase 3 execution.
All scripts, documentation, and AI prompts must align with this contract.
