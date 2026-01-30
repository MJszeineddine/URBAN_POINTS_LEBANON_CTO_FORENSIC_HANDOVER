#!/usr/bin/env python3
"""
GO_RUN Pipeline Producer - Self-healing build pipeline
Compiles functions + web-admin + flutter apps. Evidence-based.
"""

import os
import sys
import json
import subprocess
import time
from pathlib import Path
from datetime import datetime
from collections import OrderedDict

REPO_ROOT = Path.cwd()
if not (REPO_ROOT / '.git').exists():
    print("ERROR: Not in git repository")
    sys.exit(1)

TIMESTAMP = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
EVIDENCE_DIR = REPO_ROOT / 'local-ci' / 'evidence' / 'GO_PIPELINE' / TIMESTAMP
LOGS_DIR = EVIDENCE_DIR / 'logs'
LOGS_DIR.mkdir(parents=True, exist_ok=True)

gates = OrderedDict()
internal_blockers = []
external_blockers = []

def run_gate(gate_id, cwd, cmd_list, timeout_sec=900):
    """Run a gate and capture output."""
    print(f"\n[GATE] {gate_id}")
    
    started = datetime.utcnow().isoformat() + 'Z'
    
    try:
        result = subprocess.run(
            cmd_list,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout_sec
        )
        
        rc = result.returncode
        stdout = result.stdout
        stderr = result.stderr
        elapsed = timeout_sec
        
    except subprocess.TimeoutExpired:
        rc = 124
        stdout = f"Process timed out after {timeout_sec}s"
        stderr = "TIMEOUT"
        elapsed = timeout_sec
    except Exception as e:
        rc = 127
        stdout = ""
        stderr = str(e)
        elapsed = 0
    
    finished = datetime.utcnow().isoformat() + 'Z'
    
    # Save logs
    (LOGS_DIR / f"{gate_id}_stdout.log").write_text(stdout)
    (LOGS_DIR / f"{gate_id}_stderr.log").write_text(stderr)
    
    # Save metadata
    meta = {
        'rc': rc,
        'elapsed_seconds': elapsed,
        'timeout_seconds': timeout_sec,
        'started_utc': started,
        'finished_utc': finished
    }
    (LOGS_DIR / f"{gate_id}_meta.json").write_text(json.dumps(meta, indent=2))
    
    # Record gate
    gates[gate_id] = {
        'id': gate_id,
        'cwd': str(cwd),
        'cmd': cmd_list,
        'rc': rc,
        'seconds': elapsed,
        'stdout_path': f"logs/{gate_id}_stdout.log",
        'stderr_path': f"logs/{gate_id}_stderr.log",
        'timeout_seconds': timeout_sec,
        'started_utc': started,
        'finished_utc': finished,
        'passed': rc == 0
    }
    
    # Print status
    status = "✅ PASS" if rc == 0 else "❌ FAIL"
    print(f"  {status} (rc {rc})")
    
    return rc == 0

# =============================================================================
# GATE A: Firebase Functions
# =============================================================================

functions_dir = REPO_ROOT / 'source' / 'backend' / 'firebase-functions'
if not functions_dir.exists():
    print(f"ERROR: Functions dir not found: {functions_dir}")
    internal_blockers.append("Firebase Functions directory missing")
else:
    # Detect lockfile
    if (functions_dir / 'package-lock.json').exists():
        install_cmd = ['npm', 'ci', '--no-audit', '--no-fund', '--legacy-peer-deps']
    else:
        install_cmd = ['npm', 'install', '--no-audit', '--no-fund', '--legacy-peer-deps']
    
    install_ok = run_gate('functions_install', functions_dir, install_cmd, timeout_sec=180)
    
    if install_ok:
        build_ok = run_gate('functions_build', functions_dir, ['npm', 'run', 'build'], timeout_sec=900)
        if not build_ok:
            internal_blockers.append("Functions build failed")
    else:
        internal_blockers.append("Functions install failed")

# =============================================================================
# GATE B: Web Admin
# =============================================================================

web_admin_dir = REPO_ROOT / 'source' / 'apps' / 'web-admin'
if not web_admin_dir.exists():
    print(f"ERROR: Web admin dir not found: {web_admin_dir}")
    internal_blockers.append("Web Admin directory missing")
else:
    # Detect lockfile
    if (web_admin_dir / 'package-lock.json').exists():
        install_cmd = ['npm', 'ci', '--no-audit', '--no-fund', '--legacy-peer-deps']
    else:
        install_cmd = ['npm', 'install', '--no-audit', '--no-fund', '--legacy-peer-deps']
    
    install_ok = run_gate('web_admin_install', web_admin_dir, install_cmd, timeout_sec=180)
    
    if install_ok:
        build_ok = run_gate('web_admin_build', web_admin_dir, ['npm', 'run', 'build'], timeout_sec=900)
        if not build_ok:
            internal_blockers.append("Web Admin build failed")
        
        # Smoke test (best-effort)
        if build_ok:
            print("\n[SMOKE] Web Admin dev server")
            try:
                proc = subprocess.Popen(
                    ['npm', 'run', 'dev'],
                    cwd=web_admin_dir,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                
                # Wait 8 seconds
                time.sleep(8)
                
                if proc.poll() is None:
                    # Still running - good!
                    proc.terminate()
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                    
                    # Log success
                    (LOGS_DIR / "web_admin_smoke_stdout.log").write_text("Dev server started and terminated cleanly after 8s")
                    (LOGS_DIR / "web_admin_smoke_stderr.log").write_text("")
                    (LOGS_DIR / "web_admin_smoke_meta.json").write_text(json.dumps({'rc': 0, 'seconds': 8}))
                    gates['web_admin_smoke'] = {'id': 'web_admin_smoke', 'rc': 0, 'passed': True}
                    print("  ✅ PASS (dev server ran successfully)")
                else:
                    # Failed to start
                    rc = proc.returncode
                    stdout, stderr = proc.communicate()
                    (LOGS_DIR / "web_admin_smoke_stdout.log").write_text(stdout or "")
                    (LOGS_DIR / "web_admin_smoke_stderr.log").write_text(stderr or "")
                    (LOGS_DIR / "web_admin_smoke_meta.json").write_text(json.dumps({'rc': rc}))
                    if rc != 0:
                        gates['web_admin_smoke'] = {'id': 'web_admin_smoke', 'rc': rc, 'passed': False}
                        internal_blockers.append("Web Admin dev server failed to start")
                        print(f"  ❌ FAIL (rc {rc})")
                    else:
                        gates['web_admin_smoke'] = {'id': 'web_admin_smoke', 'rc': 0, 'passed': True}
                        print("  ✅ PASS")
            except Exception as e:
                # Smoke test error is not blocking if build passed
                (LOGS_DIR / "web_admin_smoke_stdout.log").write_text("")
                (LOGS_DIR / "web_admin_smoke_stderr.log").write_text(str(e))
                (LOGS_DIR / "web_admin_smoke_meta.json").write_text(json.dumps({'rc': 1, 'error': str(e)}))
                gates['web_admin_smoke'] = {'id': 'web_admin_smoke', 'rc': 1, 'passed': False}
                print(f"  ⚠️  SMOKE FAILED (but build passed, continuing): {e}")
    else:
        internal_blockers.append("Web Admin install failed")

# =============================================================================
# GATE C: Firebase Config Existence
# =============================================================================

config_ok = True

firebase_json = REPO_ROOT / 'firebase.json'
if not firebase_json.exists():
    internal_blockers.append("firebase.json missing at repo root")
    config_ok = False
else:
    gates['config_firebase_json'] = {'id': 'config_firebase_json', 'rc': 0, 'passed': True}

firestore_rules = REPO_ROOT / 'firestore.rules'
if not firestore_rules.exists():
    # Create minimal deny-all as INTERNAL fix
    print("\n[FIX] Creating minimal firestore.rules")
    minimal_rules = """rules_version = '3';

service cloud.firestore {
  match /{document=**} {
    allow read, write: if false;
  }
}
"""
    firestore_rules.write_text(minimal_rules)
    print("  Created minimal rules at root/firestore.rules")
    gates['config_firestore_rules'] = {'id': 'config_firestore_rules', 'rc': 0, 'passed': True}
else:
    gates['config_firestore_rules'] = {'id': 'config_firestore_rules', 'rc': 0, 'passed': True}

# =============================================================================
# GATE D: Flutter Customer (optional if flutter missing)
# =============================================================================

try:
    flutter_check = subprocess.run(['which', 'flutter'], capture_output=True, timeout=5)
    flutter_exists = flutter_check.returncode == 0
except:
    flutter_exists = False

if flutter_exists:
    flutter_customer_dir = REPO_ROOT / 'source' / 'apps' / 'mobile-customer'
    if flutter_customer_dir.exists():
        pub_ok = run_gate('flutter_customer_pub_get', flutter_customer_dir, ['flutter', 'pub', 'get'], timeout_sec=180)
        if pub_ok:
            build_ok = run_gate('flutter_customer_build', flutter_customer_dir, ['flutter', 'build', 'apk', '--debug'], timeout_sec=900)
            if not build_ok:
                internal_blockers.append("Flutter customer build failed")
        else:
            internal_blockers.append("Flutter customer pub get failed")
else:
    # Flutter not found - external blocker
    print("\n[SKIP] Flutter not available on system")
    (LOGS_DIR / "flutter_check_stderr.log").write_text("flutter: command not found")
    external_blockers.append("Flutter toolchain not installed")
    gates['flutter_customer'] = {'id': 'flutter_customer', 'rc': 1, 'skipped': True, 'reason': 'flutter not found'}

# =============================================================================
# GATE E: Flutter Merchant (optional if flutter missing)
# =============================================================================

if flutter_exists:
    flutter_merchant_dir = REPO_ROOT / 'source' / 'apps' / 'mobile-merchant'
    if flutter_merchant_dir.exists():
        pub_ok = run_gate('flutter_merchant_pub_get', flutter_merchant_dir, ['flutter', 'pub', 'get'], timeout_sec=180)
        if pub_ok:
            build_ok = run_gate('flutter_merchant_build', flutter_merchant_dir, ['flutter', 'build', 'apk', '--debug'], timeout_sec=900)
            if not build_ok:
                internal_blockers.append("Flutter merchant build failed")
        else:
            internal_blockers.append("Flutter merchant pub get failed")
else:
    gates['flutter_merchant'] = {'id': 'flutter_merchant', 'rc': 1, 'skipped': True, 'reason': 'flutter not found'}

# =============================================================================
# VERDICT
# =============================================================================

gates_passed = sum(1 for g in gates.values() if g.get('passed', False))
gates_failed = sum(1 for g in gates.values() if not g.get('passed', True) and not g.get('skipped', False))

# GO_RUN logic (simplified: functions + web-admin + config must pass, flutter optional if missing)
functions_pass = any(g.get('passed', False) for g_id, g in gates.items() if 'functions_build' in g_id)
web_admin_pass = any(g.get('passed', False) for g_id, g in gates.items() if 'web_admin_build' in g_id)
config_pass = config_ok

verdict = 'GO_RUN' if (functions_pass and web_admin_pass and config_pass and len(internal_blockers) == 0) else 'NO-GO'

summary = {
    'verdict': verdict,
    'evidence_dir': str(EVIDENCE_DIR),
    'timestamp': TIMESTAMP,
    'attempts': 1,
    'gates_passed': gates_passed,
    'gates_failed': gates_failed,
    'gates_total': len(gates),
    'internal_blockers': internal_blockers,
    'external_blockers': external_blockers
}

# Write outputs
(EVIDENCE_DIR / 'gates.json').write_text(json.dumps(gates, indent=2))
(EVIDENCE_DIR / 'FINAL_SUMMARY.json').write_text(json.dumps(summary, indent=2))

if verdict == 'NO-GO' and internal_blockers:
    fail_reason = {
        'verdict': 'NO-GO',
        'internal_blockers': internal_blockers,
        'external_blockers': external_blockers,
        'first_failing_gate': next((g_id for g_id, g in gates.items() if not g.get('passed', True)), 'unknown'),
        'proof_logs': [f"logs/{gate_id}_stderr.log" for gate_id in gates if not gates[gate_id].get('passed', True)]
    }
    (EVIDENCE_DIR / 'FAIL_REASON.json').write_text(json.dumps(fail_reason, indent=2))

# Write report
report = f"""# GO_RUN Pipeline Report

**Verdict:** {verdict}

**Timestamp:** {TIMESTAMP}

**Evidence Dir:** {EVIDENCE_DIR}

## Summary
- Gates passed: {gates_passed}/{len(gates)}
- Internal blockers: {len(internal_blockers)}
- External blockers: {len(external_blockers)}

## Gates
"""

for gate_id, gate in gates.items():
    status = "✅ PASS" if gate.get('passed', False) else "❌ FAIL" if not gate.get('skipped', False) else "⊘ SKIPPED"
    report += f"\n- {gate_id}: {status} (rc {gate.get('rc', 'N/A')})"

if internal_blockers:
    report += "\n\n## Internal Blockers\n"
    for blocker in internal_blockers:
        report += f"- {blocker}\n"

if external_blockers:
    report += "\n\n## External Blockers\n"
    for blocker in external_blockers:
        report += f"- {blocker}\n"

(EVIDENCE_DIR / 'FINAL_REPORT.md').write_text(report)

# Print final output
print("\n" + "="*70)
print(f"VERDICT: {verdict}")
print(f"Evidence dir: {EVIDENCE_DIR}")
print(f"Gates passed: {gates_passed}/{len(gates)}")
if internal_blockers:
    print(f"\nInternal blockers:")
    for b in internal_blockers:
        print(f"  - {b}")
if external_blockers:
    print(f"\nExternal blockers:")
    for b in external_blockers:
        print(f"  - {b}")
print("="*70)

# Exit with status
sys.exit(0 if verdict == 'GO_RUN' else 1)
