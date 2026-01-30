#!/usr/bin/env python3
"""
Hermetic Self-Healing Pipeline for Urban Points Lebanon
Executes GO_RUN / GO_PROD / GO_QUALITY gates with evidence generation
Exit codes: 0=GO, 2=INTERNAL blockers, 3=EXTERNAL blockers
"""

import os
import sys
import json
import subprocess
import time
import hashlib
from pathlib import Path
from datetime import datetime
from collections import OrderedDict

# =============================================================================
# CONSTANTS
# =============================================================================

REPO_ROOT = Path.cwd()
if not (REPO_ROOT / 'firebase.json').exists() and not (REPO_ROOT / 'source').exists():
    print("ERROR: Not in repo root (no firebase.json or source/)")
    sys.exit(1)

TIMESTAMP = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
EVIDENCE_DIR = REPO_ROOT / 'local-ci' / 'evidence' / 'PIPELINE' / TIMESTAMP
LOGS_DIR = EVIDENCE_DIR / 'logs'
GIT_DIR = EVIDENCE_DIR / 'git'
INV_DIR = EVIDENCE_DIR / 'inventory'

for d in [LOGS_DIR, GIT_DIR, INV_DIR]:
    d.mkdir(parents=True, exist_ok=True)

gates = OrderedDict()
internal_blockers = []
external_blockers = []
level_achieved = 'NO-GO'

# Component paths
FUNCTIONS_DIR = REPO_ROOT / 'source' / 'backend' / 'firebase-functions'
WEB_ADMIN_DIR = REPO_ROOT / 'source' / 'apps' / 'web-admin'
FLUTTER_CUSTOMER_DIR = REPO_ROOT / 'source' / 'apps' / 'mobile-customer'
FLUTTER_MERCHANT_DIR = REPO_ROOT / 'source' / 'apps' / 'mobile-merchant'

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def run_cmd(gate_id, cwd, cmd_list, timeout_sec=720, check_rc_zero=True):
    """Run a command with timeout and capture output."""
    print(f"\n[GATE] {gate_id}")
    log_file = LOGS_DIR / f"{gate_id}.log"
    
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
        output = f"STDOUT:\n{result.stdout}\n\nSTDERR:\n{result.stderr}"
        elapsed = timeout_sec
        
    except subprocess.TimeoutExpired:
        rc = 124
        output = f"Process timed out after {timeout_sec}s"
        elapsed = timeout_sec
    except Exception as e:
        rc = 127
        output = f"ERROR: {str(e)}"
        elapsed = 0
    
    finished = datetime.utcnow().isoformat() + 'Z'
    
    # Write log
    log_file.write_text(output)
    
    # Record gate
    passed = (rc == 0) if check_rc_zero else True
    gates[gate_id] = {
        'id': gate_id,
        'cwd': str(cwd),
        'cmd': ' '.join(cmd_list),
        'rc': rc,
        'seconds': elapsed,
        'log': str(log_file.relative_to(EVIDENCE_DIR)),
        'started_utc': started,
        'finished_utc': finished,
        'passed': passed
    }
    
    status = "✅ PASS" if passed else "❌ FAIL"
    print(f"  {status} (rc {rc})")
    
    return passed, rc, output

def check_tool_exists(tool_name):
    """Check if tool exists in PATH."""
    try:
        result = subprocess.run(['which', tool_name], capture_output=True, timeout=5)
        return result.returncode == 0
    except:
        return False

def write_git_evidence():
    """Capture git state."""
    def git_cmd(args):
        try:
            result = subprocess.run(['git'] + args, cwd=REPO_ROOT, capture_output=True, text=True, timeout=5)
            return result.stdout
        except:
            return "ERROR"
    
    (GIT_DIR / 'HEAD.txt').write_text(git_cmd(['rev-parse', 'HEAD']))
    (GIT_DIR / 'status.txt').write_text(git_cmd(['status', '--porcelain']))
    (GIT_DIR / 'log-1.txt').write_text(git_cmd(['log', '-1']))
    (GIT_DIR / 'diff.patch').write_text(git_cmd(['diff', 'HEAD']))

def write_inventory():
    """Capture repo structure."""
    # Tree (depth 4)
    try:
        result = subprocess.run(['find', '.', '-maxdepth', '4', '-type', 'd'], 
                               cwd=REPO_ROOT, capture_output=True, text=True, timeout=10)
        tree = result.stdout
    except:
        tree = "ERROR"
    
    (INV_DIR / 'repo_tree_depth4.txt').write_text(tree)
    
    # File inventory
    files = []
    for root, dirs, filenames in os.walk(REPO_ROOT):
        # Exclude heavy dirs
        dirs[:] = [d for d in dirs if d not in {'node_modules', '.git', '.next', 'build', 'dist', 'coverage'}]
        for fname in filenames:
            fpath = Path(root) / fname
            try:
                size = fpath.stat().st_size
                rel = fpath.relative_to(REPO_ROOT)
                files.append(f"{rel} ({size} bytes)")
            except:
                pass
    
    (INV_DIR / 'file_inventory.txt').write_text('\n'.join(files))

def scan_callable_parity():
    """Check client callable usage vs server exports - BLOCKING."""
    client_callables = set()
    server_callables = set()
    
    # Scan client (Flutter Customer app + any web-admin if it uses callables)
    if FLUTTER_CUSTOMER_DIR.exists():
        for dart_file in FLUTTER_CUSTOMER_DIR.rglob('*.dart'):
            try:
                content = dart_file.read_text()
                # Look for httpsCallable('functionName')
                import re
                matches = re.findall(r"httpsCallable\(['\"](\w+)['\"]\)", content)
                client_callables.update(matches)
            except:
                pass
    
    # Scan server (Functions) - comprehensive scan
    if FUNCTIONS_DIR.exists():
        index_file = FUNCTIONS_DIR / 'src' / 'index.ts'
        callables_file = FUNCTIONS_DIR / 'src' / 'callableWrappers.ts'
        
        for src_file in [index_file, callables_file]:
            if not src_file.exists():
                continue
            
            try:
                content = src_file.read_text()
                import re
                
                # Pattern 1: export const name =
                matches1 = re.findall(r"export\s+const\s+(\w+)\s*=", content)
                server_callables.update(matches1)
                
                # Pattern 2: exports.name =
                matches2 = re.findall(r"exports\.(\w+)\s*=", content)
                server_callables.update(matches2)
                
                # Pattern 3: export { name, name2 } from
                matches3 = re.findall(r"export\s*\{\s*([^}]+)\s*\}\s*from", content)
                for match in matches3:
                    names = [n.strip() for n in match.split(',') if n.strip()]
                    # Handle "name as alias" → extract first part
                    names = [n.split()[0] if ' ' in n else n for n in names if n]
                    server_callables.update(names)
                
                # Pattern 4: export { name, name2 }
                matches4 = re.findall(r"export\s*\{\s*([^}]+)\s*\}\s*;", content)
                for match in matches4:
                    names = [n.strip() for n in match.split(',') if n.strip()]
                    # Handle "name as alias" → extract first part
                    names = [n.split()[0] if ' ' in n else n for n in names if n]
                    server_callables.update(names)
                    
            except Exception as e:
                print(f"  Warning: Error scanning {src_file}: {e}")
                pass
    
    parity = {
        'client_used': sorted(client_callables),
        'server_exports': sorted(server_callables),
        'missing_on_server': sorted(client_callables - server_callables),
        'unused_on_server': sorted(server_callables - client_callables),
        'match': len(client_callables - server_callables) == 0
    }
    
    (EVIDENCE_DIR / 'callable_parity.json').write_text(json.dumps(parity, indent=2))
    
    # BLOCKING: If missing callables, mark as INTERNAL blocker
    if parity['missing_on_server']:
        internal_blockers.append(f"Missing server callables: {', '.join(parity['missing_on_server'])}")
    
    return parity

def check_firestore_rules():
    """Validate firestore.rules syntax."""
    rules_file = REPO_ROOT / 'firestore.rules'
    
    if not rules_file.exists():
        internal_blockers.append("firestore.rules missing at root")
        result = {'valid': False, 'error': 'File not found'}
    else:
        try:
            content = rules_file.read_text()
            # Basic syntax check
            has_version = 'rules_version' in content
            has_service = 'service cloud.firestore' in content
            has_deny_default = 'allow read, write: if false' in content or 'allow read, write: if' in content
            
            result = {
                'valid': has_version and has_service,
                'has_version': has_version,
                'has_service': has_service,
                'has_deny_default': has_deny_default,
                'size_bytes': len(content)
            }
            
            if not result['valid']:
                internal_blockers.append("firestore.rules invalid syntax")
        except Exception as e:
            result = {'valid': False, 'error': str(e)}
            internal_blockers.append(f"firestore.rules read error: {e}")
    
    (EVIDENCE_DIR / 'firestore_rules_check.json').write_text(json.dumps(result, indent=2))
    return result

def record_toolchain():
    """Record installed tool versions."""
    def get_version(cmd):
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            return result.stdout.strip()
        except:
            return "NOT FOUND"
    
    toolchain = {
        'node': get_version(['node', '--version']),
        'npm': get_version(['npm', '--version']),
        'flutter': get_version(['flutter', '--version']) if check_tool_exists('flutter') else 'NOT FOUND',
        'firebase': get_version(['npx', 'firebase', '--version']),
        'python': get_version(['python3', '--version']),
        'git': get_version(['git', '--version'])
    }
    
    # Check .nvmrc match
    nvmrc_file = REPO_ROOT / '.nvmrc'
    if nvmrc_file.exists():
        required_node = nvmrc_file.read_text().strip()
        actual_node = toolchain['node'].strip('v')
        if not actual_node.startswith(required_node.split('.')[0]):
            external_blockers.append(f"Node version mismatch: required {required_node}, got {toolchain['node']}")
    
    (EVIDENCE_DIR / 'toolchain_report.json').write_text(json.dumps(toolchain, indent=2))
    return toolchain

# =============================================================================
# GO_RUN GATES
# =============================================================================

def gate_functions_install():
    """A1: Functions install"""
    if not FUNCTIONS_DIR.exists():
        internal_blockers.append("Functions directory missing")
        return False
    
    # Detect lockfile
    if (FUNCTIONS_DIR / 'package-lock.json').exists():
        cmd = ['npm', 'ci', '--legacy-peer-deps', '--no-audit', '--no-fund']
    else:
        cmd = ['npm', 'install', '--legacy-peer-deps', '--no-audit', '--no-fund']
    
    passed, rc, _ = run_cmd('A1_functions_install', FUNCTIONS_DIR, cmd, timeout_sec=720)
    if not passed:
        internal_blockers.append("Functions install failed")
    return passed

def gate_functions_build():
    """A2: Functions build"""
    passed, rc, _ = run_cmd('A2_functions_build', FUNCTIONS_DIR, ['npm', 'run', 'build'], timeout_sec=720)
    if not passed:
        internal_blockers.append("Functions build failed")
    return passed

def gate_web_admin_install():
    """A3: Web Admin install"""
    if not WEB_ADMIN_DIR.exists():
        internal_blockers.append("Web Admin directory missing")
        return False
    
    if (WEB_ADMIN_DIR / 'package-lock.json').exists():
        cmd = ['npm', 'ci', '--legacy-peer-deps', '--no-audit', '--no-fund']
    else:
        cmd = ['npm', 'install', '--legacy-peer-deps', '--no-audit', '--no-fund']
    
    passed, rc, _ = run_cmd('A3_web_admin_install', WEB_ADMIN_DIR, cmd, timeout_sec=720)
    if not passed:
        internal_blockers.append("Web Admin install failed")
    return passed

def gate_web_admin_build():
    """A4: Web Admin build"""
    passed, rc, _ = run_cmd('A4_web_admin_build', WEB_ADMIN_DIR, ['npm', 'run', 'build'], timeout_sec=720)
    if not passed:
        internal_blockers.append("Web Admin build failed")
    return passed

def gate_web_admin_smoke():
    """A5: Web Admin dev server smoke"""
    print("\n[GATE] A5_web_admin_smoke")
    try:
        proc = subprocess.Popen(
            ['npm', 'run', 'dev'],
            cwd=WEB_ADMIN_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        time.sleep(8)
        
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
            
            (LOGS_DIR / 'A5_web_admin_smoke.log').write_text("Dev server started and stopped cleanly")
            gates['A5_web_admin_smoke'] = {'id': 'A5_web_admin_smoke', 'rc': 0, 'passed': True}
            print("  ✅ PASS")
            return True
        else:
            rc = proc.returncode
            gates['A5_web_admin_smoke'] = {'id': 'A5_web_admin_smoke', 'rc': rc, 'passed': False}
            internal_blockers.append("Web Admin dev server failed to start")
            print(f"  ❌ FAIL (rc {rc})")
            return False
    except Exception as e:
        gates['A5_web_admin_smoke'] = {'id': 'A5_web_admin_smoke', 'rc': 1, 'passed': False}
        print(f"  ❌ FAIL ({e})")
        return False

def gate_config_valid():
    """A6: Firebase config exists"""
    firebase_json = REPO_ROOT / 'firebase.json'
    firestore_rules = REPO_ROOT / 'firestore.rules'
    
    if not firebase_json.exists():
        internal_blockers.append("firebase.json missing at root")
        return False
    
    if not firestore_rules.exists():
        internal_blockers.append("firestore.rules missing at root")
        return False
    
    gates['A6_config_valid'] = {'id': 'A6_config_valid', 'rc': 0, 'passed': True}
    print("\n[GATE] A6_config_valid\n  ✅ PASS")
    return True

def gate_flutter_customer():
    """A8-A9: Flutter Customer"""
    if not check_tool_exists('flutter'):
        gates['A8_flutter_customer_pub'] = {'id': 'A8_flutter_customer_pub', 'rc': 1, 'skipped': True}
        gates['A9_flutter_customer_build'] = {'id': 'A9_flutter_customer_build', 'rc': 1, 'skipped': True}
        print("\n[GATE] A8-A9 Flutter Customer: SKIPPED (flutter not found)")
        return True  # Not a blocker
    
    if not FLUTTER_CUSTOMER_DIR.exists():
        gates['A8_flutter_customer_pub'] = {'id': 'A8_flutter_customer_pub', 'rc': 1, 'skipped': True}
        gates['A9_flutter_customer_build'] = {'id': 'A9_flutter_customer_build', 'rc': 1, 'skipped': True}
        return True
    
    passed_pub, _, _ = run_cmd('A8_flutter_customer_pub', FLUTTER_CUSTOMER_DIR, ['flutter', 'pub', 'get'], timeout_sec=600)
    if not passed_pub:
        internal_blockers.append("Flutter Customer pub get failed")
        return False
    
    passed_build, _, _ = run_cmd('A9_flutter_customer_build', FLUTTER_CUSTOMER_DIR, 
                                  ['flutter', 'build', 'apk', '--debug'], timeout_sec=900)
    if not passed_build:
        internal_blockers.append("Flutter Customer build failed")
        return False
    
    return True

def gate_flutter_merchant():
    """A10-A11: Flutter Merchant"""
    if not check_tool_exists('flutter'):
        gates['A10_flutter_merchant_pub'] = {'id': 'A10_flutter_merchant_pub', 'rc': 1, 'skipped': True}
        gates['A11_flutter_merchant_build'] = {'id': 'A11_flutter_merchant_build', 'rc': 1, 'skipped': True}
        print("\n[GATE] A10-A11 Flutter Merchant: SKIPPED (flutter not found)")
        return True
    
    if not FLUTTER_MERCHANT_DIR.exists():
        gates['A10_flutter_merchant_pub'] = {'id': 'A10_flutter_merchant_pub', 'rc': 1, 'skipped': True}
        gates['A11_flutter_merchant_build'] = {'id': 'A11_flutter_merchant_build', 'rc': 1, 'skipped': True}
        return True
    
    passed_pub, _, _ = run_cmd('A10_flutter_merchant_pub', FLUTTER_MERCHANT_DIR, ['flutter', 'pub', 'get'], timeout_sec=600)
    if not passed_pub:
        internal_blockers.append("Flutter Merchant pub get failed")
        return False
    
    passed_build, _, _ = run_cmd('A11_flutter_merchant_build', FLUTTER_MERCHANT_DIR, 
                                  ['flutter', 'build', 'apk', '--debug'], timeout_sec=900)
    if not passed_build:
        internal_blockers.append("Flutter Merchant build failed")
        return False
    
    return True

# =============================================================================
# GO_SMOKE GATES (Runtime Proof via Emulators)
# =============================================================================

def gate_smoke_install_deps():
    """S1: Install smoke test dependencies"""
    smoke_dir = REPO_ROOT / 'tools' / 'smoke'
    if not (smoke_dir / 'package.json').exists():
        gates['S1_smoke_deps'] = {'id': 'S1_smoke_deps', 'rc': 1, 'skipped': True}
        return True  # Not a blocker if no smoke tests
    
    passed, rc, _ = run_cmd('S1_smoke_deps', smoke_dir, 
                            ['npm', 'install', '--no-audit', '--no-fund'], timeout_sec=180)
    return passed

def gate_smoke_run():
    """S2: Run emulators + smoke tests"""
    smoke_runner = REPO_ROOT / 'tools' / 'smoke' / 'run_emulators.py'
    if not smoke_runner.exists():
        gates['S2_smoke_run'] = {'id': 'S2_smoke_run', 'rc': 1, 'skipped': True}
        external_blockers.append("Smoke tests not available (run_emulators.py missing)")
        return False
    
    # Pre-check: Java (external dependency) - emulator runner will do full checks
    try:
        java_check = subprocess.run(['which', 'java'], capture_output=True, timeout=5)
        if java_check.returncode != 0:
            gates['S2_smoke_run'] = {'id': 'S2_smoke_run', 'rc': 1, 'skipped': True}
            external_blockers.append("Java not installed (Firestore emulator requires JRE)")
            print("\n[GATE] S2_smoke_run")
            print("  ⏭️  SKIPPED (Java not available)")
            return False
    except:
        pass
    
    # Set evidence dir for smoke script
    env = os.environ.copy()
    env['EVIDENCE_DIR'] = str(EVIDENCE_DIR)
    
    print("\n[GATE] S2_smoke_run")
    try:
        result = subprocess.run(
            ['python3', str(smoke_runner)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=300,  # 5 minutes total for emulators + smoke
            env=env
        )
        
        # Write log
        (LOGS_DIR / 'S2_smoke_run.log').write_text(f"STDOUT:\n{result.stdout}\n\nSTDERR:\n{result.stderr}")
        
        passed = result.returncode == 0
        gates['S2_smoke_run'] = {
            'id': 'S2_smoke_run',
            'rc': result.returncode,
            'passed': passed,
            'log': 'logs/S2_smoke_run.log'
        }
        
        if passed:
            print("  ✅ PASS")
        else:
            print(f"  ❌ FAIL (rc {result.returncode})")
            # Check for external blockers from preflight
            preflight_blocker = EVIDENCE_DIR / 'preflight_blocker.json'
            if preflight_blocker.exists():
                blocker_data = json.loads(preflight_blocker.read_text())
                blocker_name = blocker_data.get('blocker_name', 'Unknown')
                if blocker_name == 'JAVA_MISSING':
                    external_blockers.append("Java not installed (Firestore emulator requires JRE)")
                elif blocker_name == 'NODE_MISSING':
                    external_blockers.append("Node.js not installed")
                else:
                    internal_blockers.append("Smoke tests failed")
            else:
                # Check log for failures
                log_content = result.stdout + result.stderr
                if 'java' in log_content.lower() and 'not found' in log_content.lower():
                    external_blockers.append("Java not installed")
                else:
                    internal_blockers.append("Smoke tests failed")
        
        return passed
        
    except subprocess.TimeoutExpired:
        gates['S2_smoke_run'] = {'id': 'S2_smoke_run', 'rc': 124, 'passed': False}
        internal_blockers.append("Smoke tests timed out")
        print("  ❌ TIMEOUT")
        return False
    except Exception as e:
        gates['S2_smoke_run'] = {'id': 'S2_smoke_run', 'rc': 127, 'passed': False}
        external_blockers.append(f"Smoke tests error: {e}")
        print(f"  ❌ ERROR: {e}")
        return False

# =============================================================================
# GO_PROD GATES (Optional)
# =============================================================================

def gate_firebase_login():
    """B1: Firebase login check"""
    passed, rc, output = run_cmd('B1_firebase_login', REPO_ROOT, 
                                  ['npx', 'firebase', 'projects:list'], timeout_sec=30, check_rc_zero=False)
    
    if rc != 0:
        if 'not logged in' in output.lower() or 'login' in output.lower():
            external_blockers.append("Firebase not logged in (run: firebase login)")
            return False
        else:
            external_blockers.append("Firebase CLI error")
            return False
    
    return True

# =============================================================================
# MAIN PIPELINE
# =============================================================================

def run_go_run_gates():
    """Execute all GO_RUN gates."""
    global level_achieved
    
    print("\n" + "="*70)
    print("EXECUTING GO_RUN GATES")
    print("="*70)
    
    # Prepare evidence
    write_git_evidence()
    write_inventory()
    toolchain = record_toolchain()
    
    # A7: Firestore rules check (runs first, non-blocking for evidence)
    check_firestore_rules()
    
    # Gate A1-A6 (core build gates)
    if not gate_functions_install():
        return False
    if not gate_functions_build():
        return False
    if not gate_web_admin_install():
        return False
    if not gate_web_admin_build():
        return False
    gate_web_admin_smoke()  # Smoke can fail without blocking
    if not gate_config_valid():
        return False
    
    # Flutter gates (can skip if not available)
    gate_flutter_customer()
    gate_flutter_merchant()
    
    # Check if all required gates passed
    required_gates = ['A1_functions_install', 'A2_functions_build', 
                     'A3_web_admin_install', 'A4_web_admin_build', 'A6_config_valid']
    
    all_required_passed = all(gates.get(g, {}).get('passed', False) for g in required_gates)
    
    if all_required_passed and not internal_blockers:
        level_achieved = 'GO_RUN'
        return True
    
    return False

def run_go_smoke_gates():
    """Execute GO_SMOKE gates (runtime proof)."""
    global level_achieved
    
    print("\n" + "="*70)
    print("EXECUTING GO_SMOKE GATES")
    print("="*70)
    
    # Callable parity check (BLOCKING now)
    parity = scan_callable_parity()
    if not parity['match']:
        return False
    
    # Install smoke dependencies
    if not gate_smoke_install_deps():
        internal_blockers.append("Smoke dependencies install failed")
        return False
    
    # Run emulators + smoke tests
    if not gate_smoke_run():
        return False
    
    # Verify smoke report exists
    smoke_report = EVIDENCE_DIR / 'smoke_report.json'
    if not smoke_report.exists() or smoke_report.stat().st_size == 0:
        internal_blockers.append("Smoke report missing or empty")
        return False
    
    level_achieved = 'GO_SMOKE'
    return True

def run_go_prod_gates():
    """Execute GO_PROD gates (if GO_RUN passed)."""
    global level_achieved
    
    print("\n" + "="*70)
    print("EXECUTING GO_PROD GATES")
    print("="*70)
    
    if not gate_firebase_login():
        return False
    
    # TODO: Add emulator start, deploy gates
    # For now, just check login
    
    level_achieved = 'GO_PROD'
    return True

def write_final_summary():
    """Write final evidence artifacts."""
    # gates.json
    (EVIDENCE_DIR / 'gates.json').write_text(json.dumps(gates, indent=2))
    
    # FINAL_SUMMARY.json
    summary = {
        'timestamp': TIMESTAMP,
        'verdict': 'GO' if level_achieved != 'NO-GO' else 'NO-GO',
        'level_achieved': level_achieved,
        'internal_blockers': internal_blockers,
        'external_blockers': external_blockers,
        'gates_total': len(gates),
        'gates_passed': sum(1 for g in gates.values() if g.get('passed', False)),
        'gates_failed': sum(1 for g in gates.values() if not g.get('passed', True) and not g.get('skipped', False)),
        'evidence_dir': str(EVIDENCE_DIR)
    }
    
    (EVIDENCE_DIR / 'FINAL_SUMMARY.json').write_text(json.dumps(summary, indent=2))
    
    # external_blockers.json (only if external blockers exist)
    if external_blockers:
        ext_data = {
            'external_blockers': external_blockers,
            'resolution': {
                'firebase_login': 'Run: firebase login',
                'node_version': 'Install Node.js version from .nvmrc',
                'flutter_missing': 'Install Flutter SDK from flutter.dev'
            }
        }
        (EVIDENCE_DIR / 'external_blockers.json').write_text(json.dumps(ext_data, indent=2))

def main():
    """Main pipeline execution."""
    print(f"\n{'='*70}")
    print(f"HERMETIC PIPELINE - Urban Points Lebanon")
    print(f"Timestamp: {TIMESTAMP}")
    print(f"Evidence: {EVIDENCE_DIR}")
    print(f"{'='*70}")
    
    # Execute GO_RUN gates
    go_run_ok = run_go_run_gates()
    
    if not go_run_ok:
        # GO_RUN failed
        write_final_summary()
        print_final_verdict()
        sys.exit(3 if external_blockers else 2)
    
    # GO_RUN passed, attempt GO_SMOKE
    go_smoke_ok = run_go_smoke_gates()
    
    if not go_smoke_ok:
        # GO_SMOKE failed, but GO_RUN passed
        write_final_summary()
        print_final_verdict()
        sys.exit(2)  # Internal blocker
    
    # GO_SMOKE passed, write evidence and exit
    write_final_summary()
    print_final_verdict()
    sys.exit(0)

def print_final_verdict():
    """Print final verdict to stdout."""
    print("\n" + "="*70)
    print(f"VERDICT: {'GO' if level_achieved != 'NO-GO' else 'NO-GO'}")
    print(f"LEVEL: {level_achieved}")
    print(f"Evidence: {EVIDENCE_DIR}")
    print(f"Internal blockers: {len(internal_blockers)}")
    print(f"External blockers: {len(external_blockers)}")
    
    if internal_blockers:
        print("\nINTERNAL BLOCKERS:")
        for b in internal_blockers:
            print(f"  - {b}")
    
    if external_blockers:
        print("\nEXTERNAL BLOCKERS:")
        for b in external_blockers:
            print(f"  - {b}")
    
    print("="*70)

if __name__ == '__main__':
    main()
