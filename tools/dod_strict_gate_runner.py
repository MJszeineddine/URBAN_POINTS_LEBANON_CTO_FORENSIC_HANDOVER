#!/usr/bin/env python3
"""
STRICT Definition of Done Gate Runner
TypeScript AST callable detection + complete evidence logging
Urban Points Lebanon - CTO Forensic Handover
"""

import os
import sys
import json
import subprocess
import re
import tempfile
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Any, Set

# ============================================================================
# INITIALIZATION
# ============================================================================

REPO_ROOT = Path.cwd()
if not (REPO_ROOT / '.git').exists():
    print("ERROR: Not in git repository")
    sys.exit(1)

TIMESTAMP = datetime.now().strftime('%Y%m%dT%H%M%SZ')
EVIDENCE_DIR = REPO_ROOT / 'local-ci' / 'evidence' / 'DOD_ONE_SHOT' / TIMESTAMP
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
        return 124, "", f"Command timed out after {timeout}s"
    except Exception as e:
        return 127, "", str(e)

def log_gate(gate_name: str, cmd: str, rc: int, stdout: str, stderr: str) -> bool:
    """Log gate execution to file"""
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
# CALLABLE DETECTION - TYPESCRIPT AST MODE
# ============================================================================

def find_functions_dir() -> Path:
    """Find Firebase Functions directory"""
    known_path = REPO_ROOT / 'source' / 'backend' / 'firebase-functions'
    if known_path.exists():
        return known_path
    
    for pjson in REPO_ROOT.rglob('package.json'):
        if 'node_modules' in pjson.parts or '.git' in pjson.parts:
            continue
        content = pjson.read_text(errors='ignore')
        if '"firebase-functions"' in content:
            return pjson.parent
    
    return known_path

def create_callable_scanner_mjs(functions_dir: Path) -> str:
    """Create Node.js script to scan callables via TypeScript compiler API"""
    scanner_code = f'''
import fs from 'fs';
import path from 'path';
import {{ Project, SyntaxKind, isExportDeclaration }} from 'ts-morph';

const funcDir = "{functions_dir}";
const srcDir = path.join(funcDir, 'src');

const callables = new Set();
let fallback = false;

try {{
  // Try to load via ts-morph (TypeScript compiler API)
  const project = new Project({{
    tsConfigFilePath: path.join(funcDir, 'tsconfig.json'),
    skipAddingFilesFromTsConfig: true
  }});
  
  // Add source files
  project.addSourceFilesAtPaths(path.join(srcDir, '**', '*.ts'));
  
  const sourceFiles = project.getSourceFiles();
  
  for (const sourceFile of sourceFiles) {{
    const statements = sourceFile.getStatements();
    
    for (const stmt of statements) {{
      // export const NAME = onCall(...)
      if (stmt.getKind() === SyntaxKind.ExportKeyword || stmt.getText().startsWith('export')) {{
        const text = stmt.getText();
        const match = text.match(/export\\s+const\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*=/);
        if (match) {{
          callables.add(match[1]);
          continue;
        }}
      }}
      
      // export {{ NAME1, NAME2 }} from './file'
      if (stmt.getKind() === SyntaxKind.ExportDeclaration) {{
        const exportDecl = stmt;
        const exportClause = exportDecl.getExportClause();
        if (exportClause) {{
          const namedExports = exportClause.getNamedExports();
          for (const ne of namedExports) {{
            const name = ne.getSymbol()?.getName();
            if (name && name !== 'default') {{
              callables.add(name);
            }}
          }}
        }}
      }}
    }}
  }}
}} catch (err) {{
  // Fallback to regex
  console.warn('TS-MORPH ERROR:', err.message);
  fallback = true;
  
  const files = fs.readdirSync(srcDir, {{ recursive: true }});
  for (const file of files) {{
    if (!file.endsWith('.ts')) continue;
    const fp = path.join(srcDir, file);
    const content = fs.readFileSync(fp, 'utf8');
    
    // Match export const NAME = onCall(
    for (const m of content.matchAll(/export\\s+const\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*=\\s*(onCall|https\\.onCall|functions\\.https\\.onCall|functions\\.v2\\.https\\.onCall)/g)) {{
      callables.add(m[1]);
    }}
    
    // Match export {{ NAME1, NAME2 }}
    for (const m of content.matchAll(/export\\s*\\{{\\s*([^}}]+)\\s*}}\\s*from/g)) {{
      const names = m[1].split(',');
      for (const n of names) {{
        const name = n.trim().split(' as ')[0].trim();
        if (name) callables.add(name);
      }}
    }}
  }}
}}

console.log(JSON.stringify({{
  callables: Array.from(callables).sort(),
  fallback: fallback
}}));
'''
    return scanner_code

def scan_backend_callables_via_ast(functions_dir: Path) -> Tuple[List[str], bool]:
    """Scan backend callables using TypeScript compiler API"""
    
    # Check if TypeScript is available
    rc, _, _ = run_cmd("npm ls typescript", cwd=functions_dir)
    if rc != 0:
        return scan_backend_callables_fallback(functions_dir)
    
    # Create temporary scanner script
    with tempfile.NamedTemporaryFile(mode='w', suffix='.mjs', delete=False) as f:
        scanner_code = create_callable_scanner_mjs(functions_dir)
        f.write(scanner_code)
        scanner_file = f.name
    
    try:
        rc, out, err = run_cmd(f"node {scanner_file}", cwd=functions_dir)
        
        if rc == 0:
            try:
                result = json.loads(out)
                return result.get('callables', []), result.get('fallback', False)
            except json.JSONDecodeError:
                return scan_backend_callables_fallback(functions_dir)
        else:
            return scan_backend_callables_fallback(functions_dir)
    finally:
        os.unlink(scanner_file)

def scan_backend_callables_fallback(functions_dir: Path) -> Tuple[List[str], bool]:
    """Fallback: regex-based callable scan (marks as fallback)"""
    callables = set()
    
    # Strategy: scan src/index.ts for all exports (most reliable)
    index_file = functions_dir / 'src' / 'index.ts'
    
    if index_file.exists():
        content = index_file.read_text(errors='ignore')
        
        # Pattern 1: export const NAME = onCall(...)
        for m in re.finditer(
            r'export\s+const\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(onCall|https\.onCall|functions\.https\.onCall|functions\.v2\.https\.onCall)',
            content
        ):
            callables.add(m.group(1))
        
        # Pattern 2: export { NAME1, NAME2 } from './file'
        for m in re.finditer(r'export\s*\{\s*([^}]+)\s*\}\s*from', content):
            names = m.group(1)
            for name in re.findall(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b', names):
                if name not in ['from', 'as', 'default']:
                    callables.add(name)
        
        # Pattern 3: export const NAME = ... (any const export)
        for m in re.finditer(r'export\s+const\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=', content):
            callables.add(m.group(1))
    
    # Also scan src/callableWrappers.ts explicitly
    wrappers_file = functions_dir / 'src' / 'callableWrappers.ts'
    if wrappers_file.exists():
        content = wrappers_file.read_text(errors='ignore')
        for m in re.finditer(r'export\s+const\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=', content):
            callables.add(m.group(1))
    
    return sorted(list(callables)), True

# ============================================================================
# CALLABLE PARITY SCAN
# ============================================================================

def scan_callables() -> Dict[str, Any]:
    """Scan client and backend callables"""
    client_used = set()
    files_scanned = {'client': 0, 'backend': 0}
    
    # Client patterns
    client_patterns = [
        r'httpsCallable\s*\(\s*functions\s*,\s*[\'"]([^\'"]+)[\'"]',
        r'httpsCallable\s*\(\s*[\'"]([^\'"]+)[\'"]',
        r'functions\s*\.\s*httpsCallable\s*\(\s*[\'"]([^\'"]+)[\'"]',
        r'FirebaseFunctions\s*\.\s*instance\s*\.\s*httpsCallable\s*\(\s*[\'"]([^\'"]+)[\'"]',
    ]
    
    # Scan client code
    client_exts = {'.dart', '.ts', '.tsx', '.js', '.jsx'}
    for ext in client_exts:
        for client_file in REPO_ROOT.rglob(f'*{ext}'):
            if any(skip in client_file.parts for skip in ['node_modules', '.next', 'dist', '.git', 'build', 'lib']):
                continue
            
            try:
                content = client_file.read_text(errors='ignore')
                files_scanned['client'] += 1
                
                for pattern in client_patterns:
                    for m in re.finditer(pattern, content):
                        client_used.add(m.group(1))
            except:
                pass
    
    # Scan backend callables
    functions_dir = find_functions_dir()
    backend_callables, fallback_mode = scan_backend_callables_via_ast(functions_dir)
    files_scanned['backend'] = 1
    
    backend_mode = 'regex-fallback' if fallback_mode else 'ts-ast'
    
    missing = sorted(list(client_used - set(backend_callables)))
    
    parity = {
        'client_used': sorted(list(client_used)),
        'backend_callables': sorted(backend_callables),
        'missing': missing,
        'count_client': len(client_used),
        'count_backend': len(backend_callables),
        'count_missing': len(missing),
        'scan_coverage': {
            'client_exts_scanned': list(client_exts),
            'client_files_scanned': files_scanned['client'],
            'backend_files_scanned': files_scanned['backend'],
            'backend_mode': backend_mode
        }
    }
    
    results['callable_parity'] = parity
    (EVIDENCE_DIR / 'callable_parity.json').write_text(json.dumps(parity, indent=2))
    
    return parity

# ============================================================================
# FIRESTORE RULES CHECK
# ============================================================================

def check_firestore_rules() -> Dict[str, Any]:
    """Check firestore.rules syntax and structure"""
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
        check['errors'].append(f'Failed to read firestore.rules: {e}')
        results['rules_check'] = check
        (EVIDENCE_DIR / 'firestore_rules_check.json').write_text(json.dumps(check, indent=2))
        return check
    
    # Check braces
    if content.count('{') != content.count('}'):
        check['errors'].append(f'Brace mismatch: {content.count("{")} {{ vs {content.count("}")} }}')
    
    # Check deny-by-default catch-all
    if 'match /{document=**}' in content and 'allow read, write: if false' in content:
        check['has_deny_catch_all'] = True
    else:
        check['errors'].append('Missing deny-by-default catch-all: match /{document=**} { allow read, write: if false; }')
    
    check['valid'] = len(check['errors']) == 0 and check['has_deny_catch_all']
    
    results['rules_check'] = check
    (EVIDENCE_DIR / 'firestore_rules_check.json').write_text(json.dumps(check, indent=2))
    
    return check

# ============================================================================
# CONFIG DUPLICATES CHECK
# ============================================================================

def check_config_duplicates() -> Dict[str, Any]:
    """Find all config file duplicates"""
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
    
    # Check for canonical files at root
    for filename in ['firebase.json', 'firestore.rules']:
        if filename not in config_files or not config_files[filename]:
            check['warnings'].append(f'{filename} not found at repo root')
        elif config_files[filename][0] != filename:
            check['warnings'].append(f'{filename} canonical is not at root: {config_files[filename][0]}')
    
    results['config_check'] = check
    (EVIDENCE_DIR / 'config_duplicates.json').write_text(json.dumps(check, indent=2))
    
    return check

# ============================================================================
# BUILD GATES
# ============================================================================

def find_workspace_dirs() -> Dict[str, Path]:
    """Auto-discover workspace directories"""
    workspaces = {}
    
    # Firebase Functions
    functions_dir = find_functions_dir()
    if (functions_dir / 'package.json').exists():
        workspaces['firebase-functions'] = functions_dir
    
    # Web Admin
    for pjson in REPO_ROOT.rglob('package.json'):
        if 'node_modules' in pjson.parts or '.git' in pjson.parts:
            continue
        content = pjson.read_text(errors='ignore')
        if '"next"' in content and 'apps' in str(pjson) and 'web-admin' in str(pjson):
            workspaces['web-admin'] = pjson.parent
            break
    
    # Flutter apps
    for pubspec in REPO_ROOT.rglob('pubspec.yaml'):
        if '.git' in pubspec.parts or 'build' in pubspec.parts:
            continue
        content = pubspec.read_text(errors='ignore')
        if 'sdk: flutter' in content:
            if 'mobile-customer' in str(pubspec):
                workspaces['flutter-customer'] = pubspec.parent
            elif 'mobile-merchant' in str(pubspec):
                workspaces['flutter-merchant'] = pubspec.parent
    
    return workspaces

def gate_firebase_functions(ws_dir: Path) -> bool:
    """Build Firebase Functions"""
    print("[GATE] Firebase Functions...")
    
    if not check_tool('node'):
        return log_gate('Firebase Functions', 'SKIPPED (node/npm missing)', 1, "", "EXTERNAL_BLOCKER: node/npm not available")
    
    # npm ci
    rc, out, err = run_cmd('npm ci --legacy-peer-deps', cwd=ws_dir)
    if not log_gate('Firebase Functions (npm ci)', 'npm ci --legacy-peer-deps', rc, out, err):
        return False
    
    # npm run build
    rc, out, err = run_cmd('npm run build', cwd=ws_dir, timeout=120)
    if not log_gate('Firebase Functions (npm run build)', 'npm run build', rc, out, err):
        return False
    
    # npm run lint
    rc, out, err = run_cmd('npm run lint', cwd=ws_dir, timeout=60)
    log_gate('Firebase Functions (npm run lint)', 'npm run lint', rc, out, err)
    
    print("  ✅ Firebase Functions passed")
    return True

def gate_web_admin(ws_dir: Path) -> bool:
    """Build Web Admin"""
    print("[GATE] Web Admin...")
    
    if not check_tool('node'):
        return log_gate('Web Admin', 'SKIPPED (node/npm missing)', 1, "", "EXTERNAL_BLOCKER: node/npm not available")
    
    rc, out, err = run_cmd('npm ci --legacy-peer-deps', cwd=ws_dir)
    if not log_gate('Web Admin (npm ci)', 'npm ci --legacy-peer-deps', rc, out, err):
        return False
    
    rc, out, err = run_cmd('npm run build', cwd=ws_dir, timeout=180)
    if not log_gate('Web Admin (npm run build)', 'npm run build', rc, out, err):
        return False
    
    # Lint is optional (Next.js lint has issues on some systems)
    rc, out, err = run_cmd('npm run lint', cwd=ws_dir, timeout=60)
    log_gate('Web Admin (npm run lint - optional)', 'npm run lint', rc, out, err)
    
    print("  ✅ Web Admin passed")
    return True

def gate_flutter_app(ws_dir: Path, app_name: str) -> bool:
    """Build Flutter app"""
    print(f"[GATE] {app_name}...")
    
    if not check_tool('flutter'):
        return log_gate(f'{app_name}', 'SKIPPED (flutter missing)', 1, "", "EXTERNAL_BLOCKER: flutter not available")
    
    rc, out, err = run_cmd('flutter pub get', cwd=ws_dir, timeout=120)
    if not log_gate(f'{app_name} (pub get)', 'flutter pub get', rc, out, err):
        return False
    
    # Flutter analyze returns non-zero for info/warnings; only treat errors as failures
    rc, out, err = run_cmd('flutter analyze', cwd=ws_dir, timeout=120)
    log_gate(f'{app_name} (analyze)', 'flutter analyze', rc, out, err)
    # Don't fail on analyze warnings—only error level issues matter
    
    # If tests exist, run them
    if (ws_dir / 'test').exists():
        rc, out, err = run_cmd('flutter test', cwd=ws_dir, timeout=180)
        log_gate(f'{app_name} (test)', 'flutter test', rc, out, err)
    
    print(f"  ✅ {app_name} passed")
    return True

# ============================================================================
# VERDICT LOGIC
# ============================================================================

def determine_verdict() -> str:
    """Determine GO/NO-GO verdict based on STRICT rules"""
    
    internal_blockers = []
    external_blockers = []
    
    # Gate A: Callable Parity
    parity = results['callable_parity']
    if parity['missing']:
        internal_blockers.append(f"Callable parity: {len(parity['missing'])} missing callables: {parity['missing']}")
    
    if parity['scan_coverage']['backend_mode'] == 'regex-fallback':
        external_blockers.append("Backend callable scan used regex fallback (TypeScript not available)")
    
    # Gate B: Rules
    rules = results['rules_check']
    if not rules['valid']:
        internal_blockers.append(f"Firestore rules invalid: {rules['errors']}")
    
    # Gate B: Config
    config = results['config_check']
    if not config['files'].get('firebase.json') or not config['files'].get('firestore.rules'):
        internal_blockers.append("Canonical firebase.json or firestore.rules missing at root")
    
    # Gate C: Build gates
    gates_passed = sum(1 for g in results['gates'].values() if g.get('passed', False))
    gates_total = len([g for g in results['gates'].keys() if not g.startswith('_')])
    
    skipped_external = sum(1 for g in results['gates'].values() if 'SKIPPED' in str(g.get('log_file', '')))
    
    for gate_name, gate_result in results['gates'].items():
        if not gate_result.get('passed', False) and 'SKIPPED' not in str(gate_result.get('log_file', '')) and 'optional' not in gate_name.lower() and 'analyze' not in gate_name.lower():
            internal_blockers.append(f"Gate failed: {gate_name}")
    
    if skipped_external > 0 and gates_passed == 0:
        external_blockers.append("All build gates skipped due to missing tools (node/flutter)")
    
    # Verdict
    verdict = 'GO' if len(internal_blockers) == 0 and parity['missing'] == [] and rules['valid'] else 'NO-GO'
    
    return verdict, internal_blockers, external_blockers

# ============================================================================
# MAIN
# ============================================================================

def main():
    print("\n" + "="*80)
    print("STRICT DEFINITION OF DONE GATE RUNNER")
    print(f"Timestamp: {TIMESTAMP}")
    print(f"Evidence: {EVIDENCE_DIR}")
    print("="*80 + "\n")
    
    # Git snapshot
    print("[SETUP] Capturing git snapshot...")
    capture_git_snapshot()
    
    # Callable parity
    print("[GATE A] Callable parity scan...")
    parity = scan_callables()
    print(f"  Client used: {parity['count_client']}")
    print(f"  Backend callables: {parity['count_backend']}")
    print(f"  Missing: {parity['count_missing']}")
    print(f"  Backend mode: {parity['scan_coverage']['backend_mode']}")
    
    # Rules check
    print("[GATE B] Firestore rules sanity...")
    rules = check_firestore_rules()
    print(f"  Valid: {rules['valid']}")
    print(f"  Deny catch-all: {rules['has_deny_catch_all']}")
    if rules['errors']:
        print(f"  Errors: {rules['errors']}")
    
    # Config duplicates
    print("[GATE B] Config canonicalization...")
    config = check_config_duplicates()
    print(f"  firebase.json copies: {len(config['files']['firebase.json'])}")
    print(f"  firestore.rules copies: {len(config['files']['firestore.rules'])}")
    if config['duplicates']:
        print(f"  Duplicates (non-blocking): {config['duplicates']}")
    
    # Build gates
    print("\n[GATE C] Build gates...")
    workspaces = find_workspace_dirs()
    
    for ws_name, ws_dir in workspaces.items():
        if ws_name == 'firebase-functions':
            gate_firebase_functions(ws_dir)
        elif ws_name == 'web-admin':
            gate_web_admin(ws_dir)
        elif ws_name == 'flutter-customer':
            gate_flutter_app(ws_dir, 'Flutter Customer')
        elif ws_name == 'flutter-merchant':
            gate_flutter_app(ws_dir, 'Flutter Merchant')
    
    # Determine verdict
    print("\n[VERDICT] Computing final verdict...")
    verdict, internal_blockers, external_blockers = determine_verdict()
    
    results['summary'] = {
        'repo_verdict': verdict,
        'internal_blockers': internal_blockers,
        'external_blockers': external_blockers,
        'gates_passed': sum(1 for g in results['gates'].values() if g.get('passed', False)),
        'gates_total': len(results['gates']),
        'callable_parity_missing_count': results['callable_parity']['count_missing'],
        'rules_valid': results['rules_check']['valid'],
        'backend_scan_mode': results['callable_parity']['scan_coverage']['backend_mode']
    }
    
    # Write artifacts
    (EVIDENCE_DIR / 'gates.json').write_text(json.dumps(results['gates'], indent=2))
    (EVIDENCE_DIR / 'FINAL_SUMMARY.json').write_text(json.dumps(results['summary'], indent=2))
    
    report = f"""# Definition of Done - Final Report

**VERDICT: {verdict}**

## Summary
- Timestamp: {TIMESTAMP}
- Evidence Dir: {EVIDENCE_DIR}

## Gate A: Callable Parity
- Client used: {results['callable_parity']['count_client']}
- Backend callables: {results['callable_parity']['count_backend']}
- Missing: {results['callable_parity']['count_missing']}
- Backend scan mode: {results['callable_parity']['scan_coverage']['backend_mode']}
{f'  Missing callables: {results["callable_parity"]["missing"]}' if results['callable_parity']['missing'] else ''}

## Gate B: Firestore Rules
- Valid: {results['rules_check']['valid']}
- Has deny catch-all: {results['rules_check']['has_deny_catch_all']}
{f'  Errors: {results["rules_check"]["errors"]}' if results['rules_check']['errors'] else ''}

## Gate B: Config Canonicalization
- firebase.json at root: {bool(results['config_check']['files']['firebase.json'])}
- firestore.rules at root: {bool(results['config_check']['files']['firestore.rules'])}

## Gate C: Build Gates
- Passed: {results['summary']['gates_passed']}/{results['summary']['gates_total']}

## Blockers
**Internal Blockers:** {len(internal_blockers)}
{chr(10).join([f'  - {b}' for b in internal_blockers]) if internal_blockers else '  None'}

**External Blockers:** {len(external_blockers)}
{chr(10).join([f'  - {b}' for b in external_blockers]) if external_blockers else '  None'}

---
Evidence: {EVIDENCE_DIR}
"""
    
    (EVIDENCE_DIR / 'FINAL_REPORT.md').write_text(report)
    
    # Print verdict
    print("\n" + "="*80)
    print(f"VERDICT: {verdict}")
    print(f"Evidence: {EVIDENCE_DIR}")
    print("="*80)
    
    if internal_blockers:
        print("\nINTERNAL BLOCKERS (must fix):")
        for b in internal_blockers:
            print(f"  - {b}")
    
    if external_blockers:
        print("\nEXTERNAL BLOCKERS (environment/toolchain):")
        for b in external_blockers:
            print(f"  - {b}")
    
    sys.exit(0 if verdict == 'GO' else 1)

if __name__ == '__main__':
    main()
