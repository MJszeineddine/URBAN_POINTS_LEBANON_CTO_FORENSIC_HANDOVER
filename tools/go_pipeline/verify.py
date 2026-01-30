#!/usr/bin/env python3
"""
GO_RUN Pipeline Verifier - Strict verdict only based on evidence
Reads gates.json + FINAL_SUMMARY.json, decides GO_RUN/NO-GO.
This script is IMMUTABLE after creation.
"""

import sys
import json
from pathlib import Path

if len(sys.argv) < 2:
    print("USAGE: verify.py <evidence_dir>")
    sys.exit(2)

evidence_dir = Path(sys.argv[1])

if not evidence_dir.exists():
    print(f"ERROR: Evidence dir not found: {evidence_dir}")
    sys.exit(2)

# Load artifacts
gates_file = evidence_dir / 'gates.json'
summary_file = evidence_dir / 'FINAL_SUMMARY.json'

if not gates_file.exists():
    print(f"ERROR: gates.json not found in {evidence_dir}")
    sys.exit(2)

if not summary_file.exists():
    print(f"ERROR: FINAL_SUMMARY.json not found in {evidence_dir}")
    sys.exit(2)

gates = json.loads(gates_file.read_text())
summary = json.loads(summary_file.read_text())

# Verification logic (IMMUTABLE)
verdict = 'NO-GO'

# Required gates for GO_RUN: functions + web_admin + config
required_gates = ['functions_build', 'web_admin_build']
config_gates = ['config_firebase_json', 'config_firestore_rules']

functions_ok = any(gates[g].get('passed', False) for g in gates if 'functions_build' in g)
web_admin_ok = any(gates[g].get('passed', False) for g in gates if 'web_admin_build' in g)
config_ok = all(gates[g].get('passed', False) for g in gates if any(c in g for c in config_gates))

# Flutter is optional if missing
flutter_skip_ok = all(gates[g].get('skipped', False) or gates[g].get('passed', False) for g in gates if 'flutter' in g)

if functions_ok and web_admin_ok and config_ok and flutter_skip_ok and len(summary.get('internal_blockers', [])) == 0:
    verdict = 'GO_RUN'
else:
    verdict = 'NO-GO'

# Output
print(f"VERDICT: {verdict}")

# Exit code: 0 = GO, 2 = NO-GO
sys.exit(0 if verdict == 'GO_RUN' else 2)
