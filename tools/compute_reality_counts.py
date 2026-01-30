#!/usr/bin/env python3
"""
STEP 5: Compute reality counts from actual evidence
STRICT: No guessing. Only use files that exist.
"""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).parent.parent
EVID = ROOT / 'local-ci/verification/admin_report_evidence'
OUT_FILE = EVID / 'reality_counts.json'
BLOCKER_FILE = EVID / 'BLOCKER_ADMIN_REPORT.md'

def write_blocker(reason):
    """Write blocker report and exit"""
    BLOCKER_FILE.write_text(f"""# BLOCKER: Cannot Generate Admin Report

**Reason:** {reason}

This is a FATAL blocker. Admin report cannot be generated without this data.
""")
    print(f"BLOCKER: {reason}")
    sys.exit(1)

# Check required files exist
reality_gate_exit_file = EVID / 'reality_gate_exit.txt'
exits_json_file = EVID / 'reality_gate/exits.json'
stub_summary_file = EVID / 'reality_gate/stub_scan_summary.json'

if not reality_gate_exit_file.exists():
    write_blocker(f"reality_gate_exit.txt not found at {reality_gate_exit_file}")
if not exits_json_file.exists():
    write_blocker(f"exits.json not found at {exits_json_file}")

# Read reality gate exit code
try:
    reality_gate_exit = int(reality_gate_exit_file.read_text().strip())
except Exception as e:
    write_blocker(f"Failed to read reality_gate_exit.txt: {e}")

# Read exits.json
try:
    exits_data = json.loads(exits_json_file.read_text())
except Exception as e:
    write_blocker(f"Failed to parse exits.json: {e}")

# Check if all exits are 0
all_exits_zero = all(v == 0 for k, v in exits_data.items())
reality_build_test_pass = (reality_gate_exit == 0) and all_exits_zero

# Check for E2E proof artifacts (STRICT: must exist on disk)
e2e_proof_patterns = [
    'local-ci/verification/**/e2e*.log',
    'local-ci/verification/**/playwright*.log',
    'local-ci/verification/**/cypress*.log',
    'local-ci/verification/**/firebase_emulator*.log',
    'local-ci/verification/**/flow_proof*.md',
    'local-ci/verification/**/journey_proof*.md'
]

e2e_proof_present = False
for pattern in e2e_proof_patterns:
    matches = list(ROOT.glob(pattern))
    if matches:
        e2e_proof_present = True
        break

# Read critical stub hits
critical_stub_hits_count = "UNKNOWN"
if stub_summary_file.exists():
    try:
        stub_data = json.loads(stub_summary_file.read_text())
        critical_hits = stub_data.get('critical_hits', [])
        critical_stub_hits_count = len(critical_hits)
    except:
        pass

# Compute reality_completion_percent (STRICT RULES)
if not reality_build_test_pass:
    reality_completion_percent = 0.0
elif reality_build_test_pass and not e2e_proof_present:
    reality_completion_percent = 70.0
else:  # reality_build_test_pass and e2e_proof_present
    reality_completion_percent = 100.0

# Build output
output = {
    'reality_gate_exit': reality_gate_exit,
    'all_exits_zero': all_exits_zero,
    'reality_build_test_pass': reality_build_test_pass,
    'e2e_proof_present': e2e_proof_present,
    'critical_stub_hits_count': critical_stub_hits_count,
    'reality_completion_percent': reality_completion_percent,
    'explanation': 'Reality % = 0 if builds fail, 70 if builds pass without E2E proof, 100 if builds pass WITH E2E proof'
}

# Write JSON
OUT_FILE.write_text(json.dumps(output, indent=2))
print(json.dumps(output, indent=2))
