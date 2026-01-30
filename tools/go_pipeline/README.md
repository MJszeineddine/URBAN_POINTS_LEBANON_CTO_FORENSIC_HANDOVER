# GO_RUN Pipeline

Self-healing build validation pipeline. Deterministic builds only (no lint/analyze).

## Components

- `go.py` - Producer: runs gates A-F (functions, web-admin, config, flutter), captures evidence
- `verify.py` - Verifier: reads evidence artifacts, decides GO_RUN/NO-GO (immutable)

## Gates

| Gate | Purpose | Tool | Timeout |
|------|---------|------|---------|
| A | Functions install | `npm ci` or `npm install` | 3 min |
| B | Functions build | `npm run build` | 15 min |
| C | Web Admin install | `npm ci` or `npm install` | 3 min |
| D | Web Admin build | `npm run build` | 15 min |
| E | Web Admin smoke | `npm run dev` (8s) | 0.2 min |
| F | Firebase config | Check files exist | 0 sec |
| G | Flutter Customer (opt) | `flutter pub get` + `flutter build apk --debug` | 3 + 15 min |
| H | Flutter Merchant (opt) | `flutter pub get` + `flutter build apk --debug` | 3 + 15 min |

## Evidence Structure

```
local-ci/evidence/GO_PIPELINE/<TIMESTAMP>/
  gates.json                    # All gate results {gate_id: {rc, passed, cmd, ...}}
  FINAL_SUMMARY.json           # Summary {verdict, gates_passed/failed, blockers, ...}
  FAIL_REASON.json             # (if NO-GO) Failure details + suggested fixes
  FINAL_REPORT.md              # Human-readable report
  logs/
    <gate_id>_stdout.log
    <gate_id>_stderr.log
    <gate_id>_meta.json        # {rc, elapsed_seconds, timeout_seconds, started_utc, finished_utc}
```

## Self-Healing Loop

```
for attempt in 1..8:
  evidence_dir = run(go.py)
  verdict = run(verify.py, evidence_dir)
  
  if verdict == GO_RUN:
    print("SUCCESS")
    exit(0)
  
  if verdict == NO-GO:
    blockers = read(evidence_dir/FAIL_REASON.json)
    
    if blockers.internal_blockers:
      # INTERNAL: attempt auto-fix and retry
      for target in blockers.suggested_fix_targets:
        apply_fix(target)
    else:
      # EXTERNAL: cannot fix, give up
      print("BLOCKED (EXTERNAL)")
      exit(1)

print("FAILED (max attempts)")
exit(1)
```

## Usage

```bash
# Single run
python3 tools/go_pipeline/go.py

# Single run + verify
python3 tools/go_pipeline/go.py && \
  python3 tools/go_pipeline/verify.py local-ci/evidence/GO_PIPELINE/<TIMESTAMP>

# Full self-healing loop (use make target)
make go
```

## Make Targets

- `make go` - Run full self-healing loop (up to 8 attempts)
- `make go-quality` - (future) Lint/analyze gates

## Exit Codes

- 0 = GO_RUN (success)
- 1 = NO-GO with internal blockers + max attempts exceeded
- 2 = NO-GO with external blockers (cannot fix)
