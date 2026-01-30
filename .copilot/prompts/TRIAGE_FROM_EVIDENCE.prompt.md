# TRIAGE FROM EVIDENCE PROMPT

## Context
Parse evidence bundle to identify the single root cause of failure.

## Execute
```bash
# Find latest evidence
LATEST=$(ls -td local-ci/evidence/*_* | head -1)

# Run triage
python3 tools/triage/next_fix.py --evidence "$LATEST"

# Manual review if needed
cat "$LATEST/VALIDATION.json"
cat "$LATEST/SUMMARY.json"
tail -50 "$LATEST/SMOKE_LOG.txt"
```

## Triage Priority
1. **Missing Evidence Files**
   - Fix: Gate runner must create all required files
   - Files: SUMMARY.json, VALIDATION.json, RESULTS.json, SMOKE_LOG.txt

2. **Missing Required Logs**
   - Fix: Gate must write logs to exact paths in spec
   - Check: `local-ci/spec/GO_NO_GO_SPEC.json` → required_log_globs

3. **Test Failures**
   - Fix: Find first failing test in SMOKE_LOG.txt
   - Apply minimal fix to that one test
   - Do not fix multiple tests at once

4. **Forbidden Patterns**
   - Fix: Remove or handle the pattern correctly
   - Common: TODO, FIXME, unimplemented, SKIP, TypeError

5. **External Blockers**
   - Action: Output NO-GO with exact error
   - Do NOT attempt workarounds
   - Examples: Java version, Firebase emulator unavailable

## Fix Guidelines
- **One root cause per cycle**
- **Minimal code change** (no refactors)
- **Target specific file** mentioned in error
- **Verify fix** by rerunning gate

## Output Format
```json
{
  "priority": "HIGH|MEDIUM|LOW",
  "reason": "exact error message",
  "file_hint": "path/to/file.ext",
  "action": "specific fix action"
}
```

## Decision Logic
```python
if missing_evidence_files:
    return "Fix gate runner to create required files"
elif tests.failed > 0:
    return "Fix first failing test: <test_name>"
elif forbidden_patterns_found:
    return "Remove/handle forbidden pattern: <pattern>"
elif external_dependency_missing:
    return "NO-GO: External blocker - <exact_error>"
else:
    return "Review VALIDATION.json for details"
```

## Never Do
- Fix multiple issues at once
- Make large refactors
- Ignore validator verdict
- Claim PASS with warnings present
