#!/usr/bin/env python3
"""
LOCKED Definition of Done Verifier
Independent gate keeper - NO EXCEPTIONS, NO RELAXED LOGIC
This script reads evidence and returns GO/NO-GO based on HARD rules only.
"""

import sys
import json
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        print("NO-GO: Evidence directory path required")
        sys.exit(2)
    
    evidence_dir = Path(sys.argv[1])
    
    # Check all required files exist
    required_files = [
        'FINAL_SUMMARY.json',
        'gates.json',
        'callable_parity.json',
        'firestore_rules_check.json',
        'config_duplicates.json',
        'FINAL_REPORT.md',
        'git-HEAD.txt',
        'git-log-1.txt'
    ]
    
    for fname in required_files:
        fpath = evidence_dir / fname
        if not fpath.exists():
            print(f"NO-GO: Missing required artifact: {fname}")
            sys.exit(2)
        if fpath.stat().st_size == 0:
            print(f"NO-GO: Empty artifact: {fname}")
            sys.exit(2)
    
    # Verify gates.json - ALL must pass (no optional, no fallback)
    try:
        gates = json.loads((evidence_dir / 'gates.json').read_text())
    except:
        print("NO-GO: gates.json invalid JSON")
        sys.exit(2)
    
    # Required gates (non-negotiable)
    required_gates = [
        'Firebase Functions (npm ci)',
        'Firebase Functions (npm run build)',
        'Firebase Functions (npm run lint)',
        'Web Admin (npm ci)',
        'Web Admin (npm run build)',
        'Web Admin (npm run lint)',
        'Flutter Customer (pub get)',
        'Flutter Customer (analyze)',
        'Flutter Merchant (pub get)',
        'Flutter Merchant (analyze)'
    ]
    
    for gate_name in required_gates:
        if gate_name not in gates:
            print(f"NO-GO: Missing required gate: {gate_name}")
            sys.exit(2)
        
        gate = gates[gate_name]
        if gate.get('exit_code', -1) != 0:
            print(f"NO-GO: Gate failed (exit code {gate['exit_code']}): {gate_name}")
            print(f"       Log: {gate.get('log_file', 'unknown')}")
            sys.exit(2)
        
        if not gate.get('passed', False):
            print(f"NO-GO: Gate marked as failed: {gate_name}")
            sys.exit(2)
    
    # Verify callable_parity.json - missing must be empty, mode must be ts-ast
    try:
        parity = json.loads((evidence_dir / 'callable_parity.json').read_text())
    except:
        print("NO-GO: callable_parity.json invalid JSON")
        sys.exit(2)
    
    if parity.get('missing', None) != []:
        print(f"NO-GO: Callable parity has missing callables: {parity.get('missing')}")
        sys.exit(2)
    
    backend_mode = parity.get('scan_coverage', {}).get('backend_mode', 'unknown')
    if backend_mode != 'ts-ast':
        print(f"NO-GO: Backend callable scan mode is '{backend_mode}', not 'ts-ast'")
        print("       TypeScript AST detection is REQUIRED for GO (no regex fallback)")
        sys.exit(2)
    
    # Verify firestore_rules_check.json
    try:
        rules = json.loads((evidence_dir / 'firestore_rules_check.json').read_text())
    except:
        print("NO-GO: firestore_rules_check.json invalid JSON")
        sys.exit(2)
    
    if not rules.get('valid', False):
        print(f"NO-GO: Firestore rules invalid: {rules.get('errors', [])}")
        sys.exit(2)
    
    if not rules.get('has_deny_catch_all', False):
        print("NO-GO: Firestore rules missing deny-by-default catch-all")
        sys.exit(2)
    
    # Verify config_duplicates.json
    try:
        config = json.loads((evidence_dir / 'config_duplicates.json').read_text())
    except:
        print("NO-GO: config_duplicates.json invalid JSON")
        sys.exit(2)
    
    # Canonical files must exist at root
    firebase_files = config.get('files', {}).get('firebase.json', [])
    if not firebase_files or firebase_files[0] != 'firebase.json':
        print("NO-GO: firebase.json not canonical at repo root")
        sys.exit(2)
    
    firestore_files = config.get('files', {}).get('firestore.rules', [])
    if not firestore_files or firestore_files[0] != 'firestore.rules':
        print("NO-GO: firestore.rules not canonical at repo root")
        sys.exit(2)
    
    # Verify FINAL_SUMMARY.json structure
    try:
        summary = json.loads((evidence_dir / 'FINAL_SUMMARY.json').read_text())
    except:
        print("NO-GO: FINAL_SUMMARY.json invalid JSON")
        sys.exit(2)
    
    # Check that internal_blockers is empty
    if summary.get('internal_blockers', None) != []:
        print(f"NO-GO: Internal blockers remain: {summary.get('internal_blockers')}")
        sys.exit(2)
    
    # All checks passed
    print("GO")
    sys.exit(0)

if __name__ == '__main__':
    main()
