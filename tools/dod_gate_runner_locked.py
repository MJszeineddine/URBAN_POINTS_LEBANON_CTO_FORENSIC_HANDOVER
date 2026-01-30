#!/usr/bin/env python3
"""
LOCKED Definition of Done Gate Runner
Strict gate execution with mandatory TypeScript AST callable scanning.
All gates required to pass (no optional, no fallback).
Final verdict determined by independent verifier only.
"""

import os
import sys
import json
import subprocess
import re
import tempfile
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Any

# ============================================================================
# INITIALIZATION
# ============================================================================

REPO_ROOT = Path.cwd()
if not (REPO_ROOT / '.git').exists():
    print("ERROR: Not in git repository")
    sys.exit(1)

TIMESTAMP = datetime.now().strftime('%Y%m%dT%H%M%SZ')
EVIDENCE_DIR = REPO_ROOT / 'local-ci' / 'evidence' / 'DOD_LOCKED' / TIMESTAMP
LOGS_DIR = EVIDENCE_DIR / 'logs'
LOGS_DIR.mkdir(parents=True, exist_ok=True)

results = {
    'timestamp': TIMESTAMP,
    'repo_root': str(REPO_ROOT),
    'evidence_dir': str(EVIDENCE_DIR),
    'gates': {},
    'callable_parity': None,
    'rules_check': None,
    'config_check': None,
    'summary': None
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def run_cmd(cmd: str, cwd: Path = None, timeout: int = 180) -> Tuple[int, str, str]:
    """Run shell command"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd or REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return 124, "", f"Timeout after {timeout}s"
    except Exception as e:
        return 127, "", str(e)

def log_gate(gate_name: str, cmd: str, rc: int, stdout: str, stderr: str) -> bool:
    """Log gate execution"""
    log_file = LOGS_DIR / f"{gate_name.lower().replace(' ', '_').replace('(', '').replace(')', '')}.log"
    
    output = f"""GATE: {gate_name}
COMMAND: {cmd}
EXIT_CODE: {rc}

STDOUT:
{stdout}

STDERR:
{stderr}
"""
    log_file.write_text(output)
    
    results['gates'][gate_name] = {
        'cmd': cmd,
        'exit_code': rc,
        'log_file': str(log_file.relative_to(REPO_ROOT)),
        'passed': rc == 0
    }
    
    return rc == 0

def check_tool(name: str) -> bool:
    """Check if tool is available"""
    rc, _, _ = run_cmd(f"which {name}")
    return rc == 0

# ============================================================================
# GIT SNAPSHOT
# ============================================================================

def capture_git_snapshot():
    """Capture git state"""
    rc, out, _ = run_cmd("git rev-parse HEAD")
    (EVIDENCE_DIR / 'git-HEAD.txt').write_text(out.strip() if rc == 0 else "")
    
    rc, out, _ = run_cmd("git log -1 --oneline")
    (EVIDENCE_DIR / 'git-log-1.txt').write_text(out if rc == 0 else "")
    
    rc, out, _ = run_cmd("git status --porcelain")
    (EVIDENCE_DIR / 'git-status.txt').write_text(out if rc == 0 else "")
    
    rc, out, _ = run_cmd("git diff HEAD")
    (EVIDENCE_DIR / 'git-diff.patch').write_text(out if rc == 0 else "")

# ============================================================================
# CALLABLE DETECTION - TYPESCRIPT AST ONLY
# ============================================================================

def find_functions_dir() -> Path:
    """Find Firebase Functions directory"""
    known_path = REPO_ROOT / 'source' / 'backend' / 'firebase-functions'
    if known_path.exists():
        return known_path
    return known_path

def ensure_typescript_available(functions_dir: Path) -> bool:
    """Ensure TypeScript is available in functions workspace"""
    
    pjson = functions_dir / 'package.json'
    if not pjson.exists():
        print("[ERROR] Functions package.json not found")
        return False
    
    # Check if typescript is already installed
    rc, _, _ = run_cmd("npm ls typescript", cwd=functions_dir)
    if rc == 0:
        print(f"[OK] TypeScript already available in {functions_dir.name}")
        return True
    
    # Try to add typescript if missing
    print("[ACTION] Adding TypeScript to functions workspace...")
    content = pjson.read_text()
    
    try:
        pkg = json.loads(content)
    except:
        print("[ERROR] Functions package.json is invalid JSON")
        return False
    
    # Add TypeScript to devDependencies
    if 'devDependencies' not in pkg:
        pkg['devDependencies'] = {}
    
    pkg['devDependencies']['typescript'] = '^5.0.0'
    
    pjson.write_text(json.dumps(pkg, indent=2))
    
    # Run npm ci to install
    rc, out, err = run_cmd('npm ci --legacy-peer-deps', cwd=functions_dir)
    if rc != 0:
        print(f"[ERROR] npm ci failed after adding TypeScript")
        print(out)
        print(err)
        return False
    
    print("[OK] TypeScript installed successfully")
    return True

def scan_backend_callables_ast(functions_dir: Path) -> Tuple[List[str], bool]:
    """Scan backend callables using TypeScript AST (MANDATORY)"""
    
    # Ensure TypeScript is available
    if not ensure_typescript_available(functions_dir):
        return [], False
    
    # Copy scanner to functions directory so it can access node_modules
    scanner_source = REPO_ROOT / 'tools' / '_callable_ast_scan.js'
    scanner_dest = functions_dir / '_scanner_temp.js'
    
    try:
        scanner_dest.write_text(scanner_source.read_text())
        
        src_dir = functions_dir / 'src'
        rc, out, err = run_cmd(f"node _scanner_temp.js {src_dir}", cwd=functions_dir)
        
        if rc != 0:
            print(f"[ERROR] AST scan failed: {err}")
            return [], False
        
        try:
            result = json.loads(out)
            return result.get('callables', []), True
        except:
            print(f"[ERROR] AST scan returned invalid JSON: {out}")
            return [], False
    finally:
        scanner_dest.unlink(missing_ok=True)

def scan_callables() -> Dict[str, Any]:
    """Scan client and backend callables (AST required)"""
    client_used = set()
    
    # Client patterns
    patterns = [
        r'httpsCallable\s*\(\s*functions\s*,\s*[\'"]([^\'"]+)[\'"]',
        r'httpsCallable\s*\(\s*[\'"]([^\'"]+)[\'"]',
        r'functions\s*\.\s*httpsCallable\s*\(\s*[\'"]([^\'"]+)[\'"]',
        r'FirebaseFunctions\s*\.\s*instance\s*\.\s*httpsCallable\s*\(\s*[\'"]([^\'"]+)[\'"]',
    ]
    
    # Scan client code
    for ext in ['.dart', '.ts', '.tsx', '.js', '.jsx']:
        for client_file in REPO_ROOT.rglob(f'*{ext}'):
            if any(skip in client_file.parts for skip in ['node_modules', '.next', 'dist', '.git', 'build', 'lib']):
                continue
            try:
                content = client_file.read_text(errors='ignore')
                for pattern in patterns:
                    for m in re.finditer(pattern, content):
                        client_used.add(m.group(1))
            except:
                pass
    
    # Scan backend via AST (MANDATORY - no fallback)
    functions_dir = find_functions_dir()
    backend_callables, ast_success = scan_backend_callables_ast(functions_dir)
    
    if not ast_success:
        # AST scan failed - this is external blocker
        parity = {
            'client_used': sorted(list(client_used)),
            'backend_callables': [],
            'missing': sorted(list(client_used)),
            'count_client': len(client_used),
            'count_backend': 0,
            'count_missing': len(client_used),
            'scan_coverage': {
                'backend_mode': 'FAILED',
                'error': 'TypeScript AST scan failed - TypeScript not available or AST error'
            }
        }
        results['callable_parity'] = parity
        (EVIDENCE_DIR / 'callable_parity.json').write_text(json.dumps(parity, indent=2))
        return parity
    
    missing = sorted(list(client_used - set(backend_callables)))
    
    parity = {
        'client_used': sorted(list(client_used)),
        'backend_callables': sorted(backend_callables),
        'missing': missing,
        'count_client': len(client_used),
        'count_backend': len(backend_callables),
        'count_missing': len(missing),
        'scan_coverage': {
            'backend_mode': 'ts-ast',
            'success': True
        }
    }
    
    results['callable_parity'] = parity
    (EVIDENCE_DIR / 'callable_parity.json').write_text(json.dumps(parity, indent=2))
    
    return parity

# ============================================================================
# FIRESTORE RULES CHECK
# ============================================================================

def check_firestore_rules() -> Dict[str, Any]:
    """Check firestore.rules"""
    rules_file = REPO_ROOT / 'firestore.rules'
    
    check = {
        'file_path': str(rules_file),
        'exists': rules_file.exists(),
        'valid': False,
        'has_deny_catch_all': False,
        'errors': []
    }
    
    if not rules_file.exists():
        check['errors'].append('firestore.rules not found at repo root')
        results['rules_check'] = check
        (EVIDENCE_DIR / 'firestore_rules_check.json').write_text(json.dumps(check, indent=2))
        return check
    
    try:
        content = rules_file.read_text()
    except Exception as e:
        check['errors'].append(f'Failed to read: {e}')
        results['rules_check'] = check
        (EVIDENCE_DIR / 'firestore_rules_check.json').write_text(json.dumps(check, indent=2))
        return check
    
    # Check braces
    if content.count('{') != content.count('}'):
        check['errors'].append(f'Brace mismatch')
    
    # Check deny-by-default catch-all
    if 'match /{document=**}' in content and 'allow read, write: if false' in content:
        check['has_deny_catch_all'] = True
    else:
        check['errors'].append('Missing deny-by-default: match /{document=**} { allow read, write: if false; }')
    
    check['valid'] = len(check['errors']) == 0 and check['has_deny_catch_all']
    
    results['rules_check'] = check
    (EVIDENCE_DIR / 'firestore_rules_check.json').write_text(json.dumps(check, indent=2))
    
    return check

# ============================================================================
# CONFIG CANONICALIZATION CHECK
# ============================================================================

def check_config_duplicates() -> Dict[str, Any]:
    """Check config file duplicates"""
    config_files = {
        'firebase.json': [],
        'firestore.rules': [],
        'storage.rules': [],
        'firestore.indexes.json': []
    }
    
    for filename in config_files.keys():
        for found_file in REPO_ROOT.rglob(filename):
            if any(skip in found_file.parts for skip in ['.git', 'node_modules', '.next', 'dist', 'build', '.dist']):
                continue
            config_files[filename].append(str(found_file.relative_to(REPO_ROOT)))
    
    check = {
        'canonical_root': str(REPO_ROOT),
        'files': config_files,
        'duplicates': {k: v[1:] for k, v in config_files.items() if len(v) > 1},
        'warnings': []
    }
    
    results['config_check'] = check
    (EVIDENCE_DIR / 'config_duplicates.json').write_text(json.dumps(check, indent=2))
    
    return check

# ============================================================================
# BUILD GATES - ALL REQUIRED
# ============================================================================

def find_workspaces() -> Dict[str, Path]:
    """Auto-discover workspaces"""
    workspaces = {}
    
    functions_dir = find_functions_dir()
    if (functions_dir / 'package.json').exists():
        workspaces['firebase-functions'] = functions_dir
    
    for pjson in REPO_ROOT.rglob('package.json'):
        if 'node_modules' in pjson.parts or '.git' in pjson.parts:
            continue
        content = pjson.read_text(errors='ignore')
        if '"next"' in content and 'web-admin' in str(pjson):
            workspaces['web-admin'] = pjson.parent
            break
    
    for pubspec in REPO_ROOT.rglob('pubspec.yaml'):
        if '.git' in pubspec.parts:
            continue
        content = pubspec.read_text(errors='ignore')
        if 'sdk: flutter' in content:
            if 'mobile-customer' in str(pubspec):
                workspaces['flutter-customer'] = pubspec.parent
            elif 'mobile-merchant' in str(pubspec):
                workspaces['flutter-merchant'] = pubspec.parent
    
    return workspaces

def gate_firebase_functions(ws_dir: Path) -> bool:
    """Firebase Functions - ALL steps required"""
    print("[GATE] Firebase Functions...")
    
    if not check_tool('node'):
        log_gate('Firebase Functions (npm ci)', '', 127, "", "EXTERNAL: node/npm not available")
        return False
    
    # npm ci
    rc, out, err = run_cmd('npm ci --legacy-peer-deps', cwd=ws_dir)
    if not log_gate('Firebase Functions (npm ci)', 'npm ci --legacy-peer-deps', rc, out, err):
        return False
    
    # npm run build
    rc, out, err = run_cmd('npm run build', cwd=ws_dir, timeout=120)
    if not log_gate('Firebase Functions (npm run build)', 'npm run build', rc, out, err):
        return False
    
    # npm run lint (REQUIRED)
    rc, out, err = run_cmd('npm run lint', cwd=ws_dir, timeout=60)
    if not log_gate('Firebase Functions (npm run lint)', 'npm run lint', rc, out, err):
        return False
    
    print("  ✅ Firebase Functions passed")
    return True

def gate_web_admin(ws_dir: Path) -> bool:
    """Web Admin - ALL steps required"""
    print("[GATE] Web Admin...")
    
    if not check_tool('node'):
        log_gate('Web Admin (npm ci)', '', 127, "", "EXTERNAL: node/npm not available")
        return False
    
    rc, out, err = run_cmd('npm ci --legacy-peer-deps', cwd=ws_dir)
    if not log_gate('Web Admin (npm ci)', 'npm ci --legacy-peer-deps', rc, out, err):
        return False
    
    rc, out, err = run_cmd('npm run build', cwd=ws_dir, timeout=180)
    if not log_gate('Web Admin (npm run build)', 'npm run build', rc, out, err):
        return False
    
    # npm run lint (REQUIRED)
    rc, out, err = run_cmd('npm run lint', cwd=ws_dir, timeout=60)
    if not log_gate('Web Admin (npm run lint)', 'npm run lint', rc, out, err):
        return False
    
    print("  ✅ Web Admin passed")
    return True

def gate_flutter_app(ws_dir: Path, app_name: str) -> bool:
    """Flutter app - ALL steps required"""
    print(f"[GATE] {app_name}...")
    
    if not check_tool('flutter'):
        log_gate(f'{app_name} (pub get)', '', 127, "", "EXTERNAL: flutter not available")
        return False
    
    rc, out, err = run_cmd('flutter pub get', cwd=ws_dir, timeout=120)
    if not log_gate(f'{app_name} (pub get)', 'flutter pub get', rc, out, err):
        return False
    
    # analyze (REQUIRED - must pass, no "info warnings only")
    rc, out, err = run_cmd('flutter analyze', cwd=ws_dir, timeout=120)
    if not log_gate(f'{app_name} (analyze)', 'flutter analyze', rc, out, err):
        return False
    
    print(f"  ✅ {app_name} passed")
    return True

# ============================================================================
# MAIN
# ============================================================================

def main():
    print("\n" + "="*80)
    print("LOCKED DEFINITION OF DONE GATE RUNNER")
    print(f"Timestamp: {TIMESTAMP}")
    print(f"Evidence: {EVIDENCE_DIR}")
    print("="*80 + "\n")
    
    # Capture git snapshot
    print("[SETUP] Capturing git snapshot...")
    capture_git_snapshot()
    
    # Callable parity (AST required)
    print("[GATE A] Callable parity (TypeScript AST REQUIRED)...")
    parity = scan_callables()
    print(f"  Client used: {parity['count_client']}")
    print(f"  Backend callables: {parity['count_backend']}")
    print(f"  Missing: {parity['count_missing']}")
    print(f"  Backend mode: {parity['scan_coverage'].get('backend_mode')}")
    
    # Rules check
    print("[GATE F] Firestore rules sanity...")
    rules = check_firestore_rules()
    print(f"  Valid: {rules['valid']}")
    print(f"  Deny catch-all: {rules['has_deny_catch_all']}")
    
    # Config check
    print("[GATE G] Config canonicalization...")
    config = check_config_duplicates()
    print(f"  firebase.json at root: {bool(config['files']['firebase.json'])}")
    print(f"  firestore.rules at root: {bool(config['files']['firestore.rules'])}")
    
    # Build gates
    print("\n[GATES B-E] Build gates (ALL REQUIRED)...")
    workspaces = find_workspaces()
    all_passed = True
    
    for ws_name, ws_dir in workspaces.items():
        if ws_name == 'firebase-functions':
            if not gate_firebase_functions(ws_dir):
                all_passed = False
        elif ws_name == 'web-admin':
            if not gate_web_admin(ws_dir):
                all_passed = False
        elif ws_name == 'flutter-customer':
            if not gate_flutter_app(ws_dir, 'Flutter Customer'):
                all_passed = False
        elif ws_name == 'flutter-merchant':
            if not gate_flutter_app(ws_dir, 'Flutter Merchant'):
                all_passed = False
    
    # Prepare summary (tentative - verifier will determine final verdict)
    internal_blockers = []
    external_blockers = []
    
    if parity.get('scan_coverage', {}).get('backend_mode') == 'FAILED':
        external_blockers.append("TypeScript AST callable scan failed - TypeScript unavailable or AST error")
    
    if parity.get('missing'):
        internal_blockers.append(f"Missing callables: {parity['missing']}")
    
    if not rules['valid']:
        internal_blockers.append(f"Firestore rules invalid: {rules['errors']}")
    
    if not all_passed:
        internal_blockers.append("One or more build gates failed")
    
    # Write intermediate summary
    results['summary'] = {
        'repo_verdict': 'PENDING_VERIFICATION',
        'internal_blockers': internal_blockers,
        'external_blockers': external_blockers,
        'gates_passed': sum(1 for g in results['gates'].values() if g.get('passed', False)),
        'gates_total': len(results['gates'])
    }
    
    (EVIDENCE_DIR / 'gates.json').write_text(json.dumps(results['gates'], indent=2))
    (EVIDENCE_DIR / 'FINAL_SUMMARY.json').write_text(json.dumps(results['summary'], indent=2))
    
    # Write human report
    report = f"""# LOCKED Definition of Done - Final Report

**Status:** Awaiting verifier

Timestamp: {TIMESTAMP}
Evidence: {EVIDENCE_DIR}

## Gate Results

### Gate A: Callable Parity
- Client: {parity['count_client']} | Backend: {parity['count_backend']} | Missing: {parity['count_missing']}
- Mode: {parity['scan_coverage'].get('backend_mode')}

### Gate F: Firestore Rules
- Valid: {rules['valid']} | Deny catch-all: {rules['has_deny_catch_all']}

### Gate G: Config
- firebase.json root: {bool(config['files']['firebase.json'])}
- firestore.rules root: {bool(config['files']['firestore.rules'])}

### Gates B-E: Build
- Passed: {results['summary']['gates_passed']}/{results['summary']['gates_total']}

## Blockers (Tentative)
- Internal: {len(internal_blockers)}
- External: {len(external_blockers)}

---
**VERIFIER DETERMINES FINAL VERDICT**
"""
    
    (EVIDENCE_DIR / 'FINAL_REPORT.md').write_text(report)
    
    # CALL VERIFIER (THE BOSS)
    print("\n[VERIFY] Calling independent verifier...")
    rc, out, err = run_cmd(f"python3 tools/verify_evidence_locked.py {EVIDENCE_DIR}")
    
    final_verdict = 'GO' if rc == 0 else 'NO-GO'
    
    print(f"\nVERIFIER OUTPUT: {out.strip()}")
    
    # Update FINAL_SUMMARY with verifier result
    results['summary']['repo_verdict'] = final_verdict
    (EVIDENCE_DIR / 'FINAL_SUMMARY.json').write_text(json.dumps(results['summary'], indent=2))
    
    print("\n" + "="*80)
    print(f"FINAL VERDICT: {final_verdict} (by verifier)")
    print(f"Evidence: {EVIDENCE_DIR}")
    print("="*80)
    
    sys.exit(rc)

if __name__ == '__main__':
    main()
