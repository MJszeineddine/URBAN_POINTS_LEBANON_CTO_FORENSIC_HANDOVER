#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
RUN_DIR="$ROOT_DIR/local-ci/verification/reality_gate"
LOG="$RUN_DIR/reality_gate_run.log"

mkdir -p "$RUN_DIR"
: > "$LOG"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG"
}

run_and_capture() {
  local name="$1"; shift
  local cmd=("$@")
  local out_log="$RUN_DIR/${name}.log"
  local exit_file="$RUN_DIR/${name}_exit.txt"
  log "RUN $name: ${cmd[*]}"
  local ec=0
  set +e
  (set -o pipefail; "${cmd[@]}" 2>&1 | tee "$out_log")
  ec=$?
  set -e
  echo "$ec" > "$exit_file"
  log "DONE $name exit=$ec"
}

# 1) CTO gate (normal mode)
log "=== CTO gate (normal mode) ==="
run_and_capture cto_gate_normal bash -lc "cd '$ROOT_DIR' && python3 tools/gates/cto_verify.py"
# copy report
if [[ -f "$ROOT_DIR/local-ci/verification/cto_verify_report.json" ]]; then
  cp "$ROOT_DIR/local-ci/verification/cto_verify_report.json" "$RUN_DIR/cto_verify_report.json"
fi

# 2) Backend firebase-functions build/test
log "=== Backend build/test ==="
run_and_capture backend_build bash -lc "cd '$ROOT_DIR/source/backend/firebase-functions' && npm run build"
run_and_capture backend_test bash -lc "cd '$ROOT_DIR/source/backend/firebase-functions' && npm test"

# 3) Web-admin build/test
log "=== Web-admin build/test ==="
run_and_capture web_build bash -lc "cd '$ROOT_DIR/source/apps/web-admin' && npm run build"
run_and_capture web_test bash -lc "cd '$ROOT_DIR/source/apps/web-admin' && npm test"

# 4) Mobile-merchant analyze/test
log "=== Mobile-merchant analyze/test ==="
run_and_capture merchant_analyze bash -lc "cd '$ROOT_DIR/source/apps/mobile-merchant' && flutter analyze"
run_and_capture merchant_test bash -lc "cd '$ROOT_DIR/source/apps/mobile-merchant' && flutter test"

# 5) Mobile-customer analyze/test
log "=== Mobile-customer analyze/test ==="
run_and_capture customer_analyze bash -lc "cd '$ROOT_DIR/source/apps/mobile-customer' && flutter analyze"
run_and_capture customer_test bash -lc "cd '$ROOT_DIR/source/apps/mobile-customer' && flutter test"

# 6) Stub scan
log "=== Stub scan ==="
STUB_LOG="$RUN_DIR/stub_scan.log"
run_and_capture stub_scan bash -lc "cd '$ROOT_DIR' && grep -R -n -E 'TODO|FIXME|NOT_IMPLEMENTED|throw new Error|placeholder|mock' source tools --exclude-dir=node_modules --exclude-dir=.dart_tool --exclude-dir=build --exclude-dir=dist --exclude-dir=.next || true"
# The above wrote to stub_scan.log; if empty, touch
if [[ ! -s "$STUB_LOG" ]]; then
  : > "$STUB_LOG"
fi

# Build stub_scan_summary.json with Python
log "=== Analyzing stub scan results ==="
export RUN_DIR ROOT_DIR
python3 - <<'PYCODE' || { log "ERROR: Stub scan summary generation failed"; exit 1; }
import json, os, re
run_dir = os.environ['RUN_DIR']
root_dir = os.environ['ROOT_DIR']
log_path = os.path.join(run_dir, 'stub_scan.log')
out_path = os.path.join(run_dir, 'stub_scan_summary.json')
by_file = {}
pat = re.compile(r"^(.*?):(\d+):")
with open(log_path, 'r', errors='ignore') as f:
    for line in f:
        m = pat.match(line)
        if not m:
            continue
        path = m.group(1)
        by_file[path] = by_file.get(path, 0) + 1

critical_globs = [
    'source/backend/firebase-functions/src/core/',
    'source/apps/mobile-customer/lib/services/',
    'source/apps/mobile-merchant/lib/services/',
    'source/apps/web-admin/src/core/'
]

def is_critical(p):
    p = p.replace('\\\\', '/')
    return any(p.startswith(g) for g in critical_globs)

items = [{'file': k, 'count': v, 'critical': is_critical(k)} for k, v in by_file.items()]
items.sort(key=lambda x: x['count'], reverse=True)
critical = [{'file': it['file'], 'count': it['count']} for it in items if it['critical']]
obj = {
    'total_hits': sum(by_file.values()),
    'files_scanned': len(by_file),
    'top_50': items[:50],
    'critical_hits': critical,
}
with open(out_path, 'w') as out:
    json.dump(obj, out, indent=2)
print(f"Total stub hits: {obj['total_hits']}")
print(f"Critical hits count: {len(critical)}")
if critical:
    print("Top 10 critical files:")
    for i, c in enumerate(critical[:10], 1):
        print(f"  {i}. {c['file']} ({c['count']} hits)")
PYCODE

CRIT_COUNT=$(python3 -c "import json,os;ex=os.path.join(os.environ['RUN_DIR'],'stub_scan_summary.json');d=json.load(open(ex));print(len(d.get('critical_hits',[])))")
log "Stub scan critical files: $CRIT_COUNT"

# Save git diffs
log "=== Git diffs ==="
( cd "$ROOT_DIR" && git --no-pager diff --stat ) > "$RUN_DIR/git_diff_stat.txt" 2>&1 || true
( cd "$ROOT_DIR" && git --no-pager diff ) > "$RUN_DIR/git_diff_patch.diff" 2>&1 || true

# Build exits.json
log "=== Build exits.json ==="
read_ec() { local f="$RUN_DIR/$1_exit.txt"; [[ -f "$f" ]] && tr -d '\n' < "$f" || echo 1; }
cat > "$RUN_DIR/exits.json" <<JSON
{
  "cto_gate": $(read_ec cto_gate_normal),
  "backend_build": $(read_ec backend_build),
  "backend_test": $(read_ec backend_test),
  "web_build": $(read_ec web_build),
  "web_test": $(read_ec web_test),
  "merchant_analyze": $(read_ec merchant_analyze),
  "merchant_test": $(read_ec merchant_test),
  "customer_analyze": $(read_ec customer_analyze),
  "customer_test": $(read_ec customer_test),
  "stub_scan": $(read_ec stub_scan),
  "critical_stub_hits": ${CRIT_COUNT}
}
JSON

# Determine final exit using exits.json
log "=== Determining final verdict ==="
final_ec=$(python3 -c "import json,os;ex=os.path.join(os.environ['RUN_DIR'],'exits.json');d=json.load(open(ex));crit=int(d.get('critical_stub_hits',0));keys=['cto_gate','backend_build','backend_test','web_build','web_test','merchant_analyze','merchant_test','customer_analyze','customer_test','stub_scan'];nonzero=any(int(d.get(k,1))!=0 for k in keys);print(1 if (crit>0 or nonzero) else 0)")

log "FINAL_EXIT=$final_ec"
echo "FINAL_EXIT=$final_ec"
exit $final_ec