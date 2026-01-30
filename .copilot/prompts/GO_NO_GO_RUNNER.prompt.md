# GO/NO-GO RUNNER PROMPT

## Context
You are running the evidence-only GO/NO-GO gate for Urban Points Lebanon.

## Execute
```bash
bash tools/gates/run_go_no_go.sh
```

## Parse Evidence
```bash
# Find latest evidence folder
LATEST=$(ls -td local-ci/evidence/GO_NO_GO_* | head -1)

# Check verdict
cat "$LATEST/VALIDATION.json" | grep verdict

# Check summary
cat "$LATEST/SUMMARY.json"
```

## Decision Tree
- If verdict == "PASS" and no errors:
  - Print: GO ✅
  - Print evidence path
  - Print SUMMARY.json
  - Print VALIDATION.json
  - Commit changes
  - STOP

- If verdict == "FAIL":
  - Run triage: `python3 tools/triage/next_fix.py --evidence "$LATEST"`
  - Apply minimal fix for ONE root cause
  - Rerun gate
  - Max 5 cycles

- If external blocker (Java/Firebase/etc):
  - Print: NO-GO ❌
  - List blocker with evidence file path
  - STOP (do not attempt workarounds)

## Output Format
```
Evidence: local-ci/evidence/<RUN_ID>

SUMMARY.json:
{...}

VALIDATION.json:
{...}

git diff --stat:
<changes>
```

## Rules
- Never claim PASS without printing evidence
- Treat warnings as failures
- Missing evidence files = FAIL
- Zero skips required
- Zero failures required
