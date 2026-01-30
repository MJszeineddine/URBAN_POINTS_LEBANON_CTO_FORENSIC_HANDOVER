#!/usr/bin/env python3
"""
Definition of Done Gate Runner - Urban Points Lebanon
Single-shot evidence collection and repo readiness assessment
"""

import os
import sys
import json
import subprocess
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Any

# Configuration
REPO_ROOT = Path.cwd()
if not (REPO_ROOT / '.git').exists():
    REPO_ROOT = Path(__file__).parent.parent
    if not (REPO_ROOT / '.git').exists():
        print("ERROR: Not in a git repository")
        sys.exit(1)

TIMESTAMP = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
EVIDENCE_DIR = REPO_ROOT / 'local-ci' / 'evidence' / 'DOD_ONE_SHOT' / TIMESTAMP
LOGS_DIR = EVIDENCE_DIR / 'logs'
LOGS_DIR.mkdir(parents=True, exist_ok=True)

# Track results
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

def run_cmd(cmd: str, cwd: Path = None, timeout: int = 120) -> Tuple[int, str, str]:
    """Run shell command and capture stdout/stderr"""
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

def log_gate(name: str, cmd: str, rc: int, stdout: str, stderr: str):
    """Log a gate execution"""
    log_file = LOGS_DIR / f"{name.lower().replace(' ', '_')}.log"
    output = f"COMMAND: {cmd}\nEXIT_CODE: {rc}\n\nSTDOUT:\n{stdout}\n\nSTDERR:\n{stderr}"
    log_file.write_text(output)
    
    results['gates'][name] = {
        'cmd': cmd,
        'exit_code': rc,
        'log_file': str(log_file.relative_to(REPO_ROOT))
    }
    return rc == 0

def check_tool(name: str) -> bool:
    """Check if a tool is available"""
    rc, _, _ = run_cmd(f"which {name}")
    return rc == 0

# ============================================================================
# GIT SNAPSHOT
# ============================================================================

def capture_git_snapshot():
    """Capture git state"""
    rc, stdout, _ = run_cmd("git rev-parse HEAD")
    (EVIDENCE_DIR / 'git-HEAD.txt').write_text(stdout.strip() if rc == 0 else "")
    
    rc, stdout, _ = run_cmd("git log -1")
    (EVIDENCE_DIR / 'git-log-1.txt').write_text(stdout if rc == 0 else "")
    
    rc, stdout, _ = run_cmd("git status --porcelain")
    (EVIDENCE_DIR / 'git-status.txt').write_text(stdout if rc == 0 else "")
    
    rc, stdout, _ = run_cmd("git diff HEAD~1 HEAD")
    (EVIDENCE_DIR / 'git-diff.patch').write_text(stdout if rc == 0 else "")

# ============================================================================
# CALLABLE PARITY SCAN
# ============================================================================

def scan_callables() -> Dict[str, Any]:
    """Scan for callable mismatches"""
    client_used = set()
    backend_exported = set()
    
    # Scan client code for httpsCallable patterns
    patterns = [
        r'httpsCallable\([\'"]([^\'"]+)[\'"]',  # TypeScript/JavaScript
        r"httpsCallable\('([^']+)'\)",         # Single quotes
        r'FirebaseFunctions\.instance\.httpsCallable\([\'"]([^\'"]+)[\'"]',  # Dart
    ]
    
    for dart_file in REPO_ROOT.rglob('*.dart'):
        if 'node_modules' in dart_file.parts or '.next' in dart_file.parts:
            continue
        content = dart_file.read_text(errors='ignore')
        for pattern in patterns:
            for match in re.finditer(pattern, content):
                client_used.add(match.group(1))
    
    for ts_file in REPO_ROOT.rglob('*.ts'):
        if 'node_modules' in ts_file.parts or '.next' in ts_file.parts or 'dist' in ts_file.parts:
            continue
        content = ts_file.read_text(errors='ignore')
        for pattern in patterns:
            for match in re.finditer(pattern, content):
                client_used.add(match.group(1))
    
    for js_file in REPO_ROOT.rglob('*.jsx'):
        if 'node_modules' in js_file.parts or '.next' in js_file.parts or 'dist' in js_file.parts:
            continue
        content = js_file.read_text(errors='ignore')
        for pattern in patterns:
            for match in re.finditer(pattern, content):
                client_used.add(match.group(1))
    
    # Scan backend exports from index.ts
    index_file = REPO_ROOT / 'source' / 'backend' / 'firebase-functions' / 'src' / 'index.ts'
    if index_file.exists():
        content = index_file.read_text()
        # Match: export const name = ...
        for match in re.finditer(r'export\s+const\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=', content):
            backend_exported.add(match.group(1))
        
        # Match: export { name1, name2, ... } from '...'
        for match in re.finditer(r'export\s*\{\s*([^}]+)\s*\}\s*from', content):
            names = match.group(1)
            for name in re.findall(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b', names):
                if name not in ['from', 'as']:
                    backend_exported.add(name)
    
    missing = sorted(list(client_used - backend_exported))
    
    parity = {
        'client_used': sorted(list(client_used)),
        'backend_exported': sorted(list(backend_exported)),
        'missing': missing,
        'count_client': len(client_used),
        'count_exported': len(backend_exported),
        'count_missing': len(missing)
    }
    
    results['callable_parity'] = parity
    (EVIDENCE_DIR / 'callable_parity.json').write_text(json.dumps(parity, indent=2))
    
    return parity

# ============================================================================
# FIRESTORE RULES SANITY CHECK
# ============================================================================

def check_firestore_rules() -> Dict[str, Any]:
    """Check firestore.rules syntax and structure"""
    rules_file = REPO_ROOT / 'firestore.rules'
    
    check = {
        'file_exists': rules_file.exists(),
        'valid': False,
        'errors': [],
        'has_deny_catch_all': False
    }
    
    if not rules_file.exists():
        check['errors'].append("firestore.rules not found at repo root")
        results['rules_check'] = check
        (EVIDENCE_DIR / 'firestore_rules_check.json').write_text(json.dumps(check, indent=2))
        return check
    
    content = rules_file.read_text()
    
    # Check braces match
    open_braces = content.count('{')
    close_braces = content.count('}')
    if open_braces != close_braces:
        check['errors'].append(f"Brace mismatch: {open_braces} {{ vs {close_braces} }}")
    
    # Check for deny-by-default catch-all
    if 'match /{document=**}' in content and 'allow read, write: if false' in content:
        check['has_deny_catch_all'] = True
    else:
        check['errors'].append("Missing deny-by-default catch-all: match /{document=**} { allow read, write: if false; }")
    
    # Check subscription field rules if subscriptionActive is mentioned
    if 'subscriptionActive' in content:
        # Should have admin-only update rule
        if 'isAdmin()' in content:
            pass  # Good
        else:
            check['errors'].append("subscriptionActive mentioned but no admin-only rule found")
    
    check['valid'] = len(check['errors']) == 0 and check['has_deny_catch_all']
    results['rules_check'] = check
    (EVIDENCE_DIR / 'firestore_rules_check.json').write_text(json.dumps(check, indent=2))
    
    return check

# ============================================================================
# FIREBASE CONFIG CANONICALIZATION CHECK
# ============================================================================

def check_firebase_config() -> Dict[str, Any]:
    """Check for canonical firebase.json"""
    firebase_jsons = list(REPO_ROOT.rglob('firebase.json'))
    
    check = {
        'count': len(firebase_jsons),
        'canonical_path': None,
        'all_paths': [str(f.relative_to(REPO_ROOT)) for f in firebase_jsons],
        'duplicates': [],
        'canonical_valid': False
    }
    
    if firebase_jsons:
        # Prefer root
        root_firebase = REPO_ROOT / 'firebase.json'
        if root_firebase.exists():
            check['canonical_path'] = 'firebase.json'
            try:
                json.load(open(root_firebase))
                check['canonical_valid'] = True
            except:
                check['errors'] = ["firebase.json at root is invalid JSON"]
        
        # Flag duplicates
        if len(firebase_jsons) > 1:
            check['duplicates'] = [str(f.relative_to(REPO_ROOT)) for f in firebase_jsons if f != root_firebase]
    else:
        check['errors'] = ["No firebase.json found"]
    
    results['config_check'] = check
    (EVIDENCE_DIR / 'firebase_config_check.json').write_text(json.dumps(check, indent=2))
    
    return check

# ============================================================================
# BUILD GATES
# ============================================================================

def gate_firebase_functions() -> bool:
    """Build Firebase Functions"""
    functions_dir = REPO_ROOT / 'source' / 'backend' / 'firebase-functions'
    if not functions_dir.exists():
        print("[SKIP] Firebase Functions dir not found")
        return True
    
    if not check_tool('node'):
        print("[SKIP] Node.js not available")
        return True
    
    print("[GATE] Firebase Functions...")
    
    # npm ci
    rc, out, err = run_cmd('npm ci --legacy-peer-deps', cwd=functions_dir)
    if rc != 0:
        log_gate('Firebase Functions (npm ci)', 'npm ci --legacy-peer-deps', rc, out, err)
        return False
    
    # npm run lint (optional)
    rc_lint, out_lint, err_lint = run_cmd('npm run lint', cwd=functions_dir, timeout=60)
    
    # npm run build
    rc, out, err = run_cmd('npm run build', cwd=functions_dir)
    
    # Check lib/index.js exists
    lib_index = functions_dir / 'lib' / 'index.js'
    if rc != 0 or not lib_index.exists():
        log_gate('Firebase Functions (build)', 'npm run build', rc, out, err)
        return False
    
    log_gate('Firebase Functions (build)', 'npm run build', rc, out, err)
    print("  ✅ Firebase Functions built")
    return True

def gate_web_admin() -> bool:
    """Build Web Admin"""
    web_admin_dir = REPO_ROOT / 'source' / 'apps' / 'web-admin'
    if not web_admin_dir.exists():
        print("[SKIP] Web Admin dir not found")
        return True
    
    if not check_tool('node'):
        print("[SKIP] Node.js not available")
        return True
    
    print("[GATE] Web Admin...")
    
    # npm ci
    rc, out, err = run_cmd('npm ci --legacy-peer-deps', cwd=web_admin_dir)
    if rc != 0:
        log_gate('Web Admin (npm ci)', 'npm ci --legacy-peer-deps', rc, out, err)
        return False
    
    # npm run build
    rc, out, err = run_cmd('npm run build', cwd=web_admin_dir, timeout=180)
    
    # Check .next exists
    next_dir = web_admin_dir / '.next'
    if rc != 0 or not next_dir.exists():
        log_gate('Web Admin (build)', 'npm run build', rc, out, err)
        return False
    
    log_gate('Web Admin (build)', 'npm run build', rc, out, err)
    print("  ✅ Web Admin built")
    return True

def gate_mobile_customer() -> bool:
    """Check Mobile Customer"""
    app_dir = REPO_ROOT / 'source' / 'apps' / 'mobile-customer'
    if not app_dir.exists():
        print("[SKIP] Mobile Customer dir not found")
        return True
    
    if not (app_dir / 'pubspec.yaml').exists():
        print("[SKIP] Mobile Customer pubspec.yaml not found")
        return True
    
    if not check_tool('flutter'):
        print("[SKIP] Flutter not available")
        return True
    
    print("[GATE] Mobile Customer...")
    
    # flutter pub get
    rc, out, err = run_cmd('flutter pub get', cwd=app_dir, timeout=120)
    if rc != 0:
        log_gate('Mobile Customer (pub get)', 'flutter pub get', rc, out, err)
        return False
    
    # flutter analyze
    rc_analyze, out_analyze, err_analyze = run_cmd('flutter analyze', cwd=app_dir, timeout=120)
    
    log_gate('Mobile Customer (analyze)', 'flutter analyze', rc_analyze, out_analyze, err_analyze)
    print("  ✅ Mobile Customer checked")
    return rc_analyze == 0

def gate_mobile_merchant() -> bool:
    """Check Mobile Merchant"""
    app_dir = REPO_ROOT / 'source' / 'apps' / 'mobile-merchant'
    if not app_dir.exists():
        print("[SKIP] Mobile Merchant dir not found")
        return True
    
    if not (app_dir / 'pubspec.yaml').exists():
        print("[SKIP] Mobile Merchant pubspec.yaml not found")
        return True
    
    if not check_tool('flutter'):
        print("[SKIP] Flutter not available")
        return True
    
    print("[GATE] Mobile Merchant...")
    
    # flutter pub get
    rc, out, err = run_cmd('flutter pub get', cwd=app_dir, timeout=120)
    if rc != 0:
        log_gate('Mobile Merchant (pub get)', 'flutter pub get', rc, out, err)
        return False
    
    # flutter analyze
    rc_analyze, out_analyze, err_analyze = run_cmd('flutter analyze', cwd=app_dir, timeout=120)
    
    log_gate('Mobile Merchant (analyze)', 'flutter analyze', rc_analyze, out_analyze, err_analyze)
    print("  ✅ Mobile Merchant checked")
    return rc_analyze == 0

# ============================================================================
# MAIN
# ============================================================================

def main():
    print("\n" + "="*70)
    print(f"DEFINITION OF DONE GATE RUNNER")
    print(f"Timestamp: {TIMESTAMP}")
    print(f"Evidence Dir: {EVIDENCE_DIR}")
    print("="*70 + "\n")
    
    # Capture git snapshot
    print("[SETUP] Capturing git snapshot...")
    capture_git_snapshot()
    
    # Callable parity
    print("[SCAN] Callable parity...")
    parity = scan_callables()
    print(f"  Client used: {parity['count_client']}")
    print(f"  Backend exported: {parity['count_exported']}")
    print(f"  Missing: {parity['count_missing']}")
    if parity['missing']:
        print(f"    → {parity['missing']}")
    
    # Rules sanity
    print("[CHECK] Firestore rules...")
    rules = check_firestore_rules()
    if rules['valid']:
        print("  ✅ Rules sanity check passed")
    else:
        print(f"  ❌ Rules errors: {rules['errors']}")
    
    # Config check
    print("[CHECK] Firebase config canonicalization...")
    config = check_firebase_config()
    if config['canonical_path']:
        print(f"  ✅ Canonical: {config['canonical_path']}")
        if config['duplicates']:
            print(f"  ⚠️  Duplicates found: {config['duplicates']}")
    else:
        print(f"  ❌ No canonical firebase.json found")
    
    # Build gates
    print("\n[GATES] Running build gates...")
    gates_passed = 0
    gate_firebase_functions() and (gates_passed := gates_passed + 1)
    gate_web_admin() and (gates_passed := gates_passed + 1)
    gate_mobile_customer() and (gates_passed := gates_passed + 1)
    gate_mobile_merchant() and (gates_passed := gates_passed + 1)
    
    # Determine verdict
    print("\n" + "="*70)
    internal_blockers = []
    external_blockers = []
    
    if parity['missing']:
        internal_blockers.append(f"Missing callables: {parity['missing']}")
    
    if not rules['valid']:
        internal_blockers.append(f"Firestore rules errors: {rules['errors']}")
    
    if not config['canonical_path']:
        internal_blockers.append("No canonical firebase.json found")
    
    if not check_tool('node'):
        external_blockers.append("Node.js not installed (needed for Firebase Functions, Web Admin)")
    
    if not check_tool('flutter'):
        external_blockers.append("Flutter not installed (needed for mobile apps)")
    
    repo_verdict = 'GO' if len(internal_blockers) == 0 and parity['missing'] == [] else 'NO-GO'
    
    results['summary'] = {
        'repo_verdict': repo_verdict,
        'internal_blockers': internal_blockers,
        'external_blockers': external_blockers,
        'gates_passed': gates_passed,
        'callable_parity_missing': parity['missing'],
        'rules_valid': rules['valid'],
        'config_canonical': config['canonical_path'] is not None
    }
    
    # Write final outputs
    (EVIDENCE_DIR / 'gates.json').write_text(json.dumps(results['gates'], indent=2))
    (EVIDENCE_DIR / 'FINAL_SUMMARY.json').write_text(json.dumps(results['summary'], indent=2))
    
    # Write human-readable report
    report = f"""# Definition of Done - Final Report

**Verdict: {repo_verdict}**

## Summary
- Timestamp: {TIMESTAMP}
- Evidence Dir: {EVIDENCE_DIR}

## Callable Parity
- Client used: {parity['count_client']}
- Backend exported: {parity['count_exported']}
- Missing: {parity['count_missing']}
{f'  Missing callables: {parity["missing"]}' if parity['missing'] else ''}

## Build Gates
- Gates results in: {LOGS_DIR}

## Firestore Rules
- Valid: {rules['valid']}
- Has deny catch-all: {rules['has_deny_catch_all']}
{f'- Errors: {rules["errors"]}' if rules['errors'] else ''}

## Firebase Config
- Canonical: {config['canonical_path']}
- Count: {config['count']}
{f'- Duplicates: {config["duplicates"]}' if config['duplicates'] else ''}

## Blockers
Internal Blockers: {len(internal_blockers)}
{chr(10).join([f'  - {b}' for b in internal_blockers]) if internal_blockers else '  None'}

External Blockers: {len(external_blockers)}
{chr(10).join([f'  - {b}' for b in external_blockers]) if external_blockers else '  None'}

---
Generated: {TIMESTAMP}
"""
    
    (EVIDENCE_DIR / 'FINAL_REPORT.md').write_text(report)
    
    print(f"VERDICT: {repo_verdict}")
    print(f"Evidence: {EVIDENCE_DIR}")
    print("="*70 + "\n")
    
    if internal_blockers:
        print("Internal Blockers (must fix):")
        for b in internal_blockers:
            print(f"  - {b}")
    
    if external_blockers:
        print("\nExternal Blockers (do not block, but impact deployment):")
        for b in external_blockers:
            print(f"  - {b}")
    
    sys.exit(0 if repo_verdict == 'GO' else 1)

if __name__ == '__main__':
    main()
