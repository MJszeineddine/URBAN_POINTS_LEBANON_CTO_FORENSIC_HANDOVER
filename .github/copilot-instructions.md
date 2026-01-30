# GitHub Copilot Instructions - Urban Points Lebanon

## Core Principle
**Evidence-only verification. No claims without machine proof.**

## MANDATORY OUTPUT FORMAT
Every response MUST include:
1. **VERDICT**: GO or NO-GO
2. **EVIDENCE_PATH**: Absolute path to evidence folder
3. **WHAT_RAN**: Commands executed (with exit codes)
4. **DIFFSTAT**: `git diff --stat` output
5. **NEXT_ACTION**: What to do next OR "DONE" if PASS

## Workflow
1. Run strictest gate: `bash tools/gates/run_go_no_go.sh`
2. Check evidence: Latest folder in `local-ci/evidence/`
3. Validate: `VALIDATION.json` verdict must be `PASS`
4. Fix if needed: One root cause per cycle (max 5 cycles)
5. Commit only on PASS

## Truth Sources (Priority Order)
1. `VALIDATION.json` verdict field (on disk)
2. `SUMMARY.json` status and test counts (on disk)
3. Actual code in `source/` and `tools/`
4. Evidence logs in `local-ci/evidence/<RUN_ID>/logs/`

## Never Accept
- Missing evidence files
- Missing required logs
- Test skips (must be 0)
- Test failures (must be 0)
- "Warnings" about evidence (treat as FAIL)
- Forbidden patterns in logs
- Claims of PASS without showing SUMMARY.json + VALIDATION.json content

## Always Output
```bash
# Evidence path
EVIDENCE_PATH=local-ci/evidence/<RUN_ID>

# Artifacts (MUST cat these)
cat $EVIDENCE_PATH/SUMMARY.json
cat $EVIDENCE_PATH/VALIDATION.json

# Changes
git diff --stat
```

## Commit Format
```
chore(scope): brief description

- Evidence: <path>
- Verdict: PASS/FAIL
- Tests: X/X passed
```

## Available Tools
- Gate: `tools/gates/run_go_no_go.sh`
- Validator: `tools/validate/go_no_go_validator.py`
- Triage: `tools/triage/next_fix.py --evidence <path>`
- Spec: `local-ci/spec/GO_NO_GO_SPEC.json`

## Blockers
If external dependency fails (Java/Firebase/etc):
1. Output NO-GO
2. List exact blocker with evidence file pointer
3. DO NOT attempt workarounds
4. Stop execution
