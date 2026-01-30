# COPILOT RULES - URBAN POINTS LEBANON

## HARD RULES (NON-NEGOTIABLE)

### 0. MANDATORY OUTPUT FORMAT
Every response MUST include:
- **VERDICT**: GO or NO-GO
- **EVIDENCE_PATH**: Full path to evidence folder
- **WHAT_RAN**: Commands with exit codes
- **DIFFSTAT**: git diff --stat
- **NEXT_ACTION**: Next step or "DONE"

### 1. TRUTH SOURCE
- Code + machine-generated evidence ONLY
- Ignore markdown docs as source of truth
- DONE = gate returns PASS/GO AND evidence bundle complete
- Never claim PASS without showing SUMMARY.json + VALIDATION.json content

### 2. GATE-FIRST WORKFLOW
```bash
# Always start here:
bash tools/gates/run_go_no_go.sh

# Parse evidence:
python3 tools/triage/next_fix.py --evidence <latest_evidence_path>

# Fix ONE root cause (minimal change)

# Rerun gate
```

### 3. EVIDENCE REQUIREMENTS
- SUMMARY.json must exist with status="PASS"
- VALIDATION.json must exist with verdict="PASS"
- All required log files present (no missing patterns)
- Zero test failures, zero skips
- No forbidden patterns in logs

### 4. NEVER CLAIM SUCCESS WITHOUT
- Evidence folder path printed
- `cat SUMMARY.json` output shown
- `cat VALIDATION.json` output shown
- `git diff --stat` shown
- All evidence files verified present

### 5. WARNINGS = FAILURES
- Missing log patterns → FAIL (not warning)
- Missing evidence files → FAIL
- Any SKIP in tests → FAIL
- Forbidden patterns → FAIL

### 6. COMMIT POLICY
- ONLY commit when gate returns GO/PASS
- Never commit "partial fixes"
- Commit message format: `chore(category): brief description`

## AVAILABLE GATES (STRICTNESS ORDER)
1. `tools/gates/run_rc_strict_gate.sh` - Strictest (zero tolerance)
2. `tools/gates/run_go_no_go.sh` - Wrapper (uses strictest inner gate)
3. `tools/gates/run_rc_gate.sh` - Release candidate
4. `tools/gates/run_mvp_smoke_gate.sh` - MVP baseline

## VALIDATOR LOCATIONS
- `tools/validate/go_no_go_validator.py` - Wrapper validator
- `tools/validate/rc_strict_validator.py` - RC strict validator

## EVIDENCE STRUCTURE
```
local-ci/evidence/<RUN_ID>/
├── SUMMARY.json (required)
├── VALIDATION.json (required)
├── RESULTS.json (required)
├── SMOKE_LOG.txt (required)
├── commit_hash.txt
├── git_status.txt
├── branch.txt
└── logs/
    ├── backend/
    ├── emulators/
    │   └── EMULATORS_EXEC.log (required)
    └── smoke/
```

## SELF-HEALING LOOP (MAX 5 CYCLES)
```
FOR cycle in 1..5:
  1. Run gate
  2. If PASS: commit & stop
  3. If FAIL: triage → minimal fix → repeat
  4. If external blocker: output NO-GO + blocker evidence
```

## FORBIDDEN ACTIONS
- ❌ Asking user questions
- ❌ Long explanations
- ❌ Claiming success without evidence
- ❌ Ignoring validator failures
- ❌ Treating warnings as acceptable
- ❌ Manual verification requests

## REQUIRED ACTIONS
- ✅ Run gate first
- ✅ Print all evidence artifacts
- ✅ Show git diff
- ✅ Minimal targeted fixes only
- ✅ Commit only on PASS
