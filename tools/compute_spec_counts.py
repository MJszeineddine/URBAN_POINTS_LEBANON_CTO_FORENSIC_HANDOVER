#!/usr/bin/env python3
"""
STEP 4: Compute spec counts from spec/requirements.yaml
STRICT: No guessing. If file missing or parse fails, write BLOCKER and exit.
"""
import json
import yaml
from pathlib import Path
import sys

ROOT = Path(__file__).parent.parent
SPEC_FILE = ROOT / 'spec/requirements.yaml'
OUT_FILE = ROOT / 'local-ci/verification/admin_report_evidence/spec_counts.json'
BLOCKER_FILE = ROOT / 'local-ci/verification/admin_report_evidence/BLOCKER_ADMIN_REPORT.md'

def write_blocker(reason):
    """Write blocker report and exit"""
    BLOCKER_FILE.write_text(f"""# BLOCKER: Cannot Generate Admin Report

**Reason:** {reason}

**Timestamp:** {Path('local-ci/verification/admin_report_evidence/git_commit.txt').read_text().strip() if Path('local-ci/verification/admin_report_evidence/git_commit.txt').exists() else 'UNKNOWN'}

This is a FATAL blocker. Admin report cannot be generated without this data.
""")
    print(f"BLOCKER: {reason}")
    sys.exit(1)

# Check if spec file exists
if not SPEC_FILE.exists():
    write_blocker(f"spec/requirements.yaml not found at {SPEC_FILE}")

# Parse YAML
try:
    spec_data = yaml.safe_load(SPEC_FILE.read_text())
except Exception as e:
    write_blocker(f"Failed to parse spec/requirements.yaml: {e}")

# Extract requirements
requirements = spec_data.get('requirements', [])
if not requirements:
    write_blocker("spec/requirements.yaml has no requirements list")

# Count by status
status_counts = {'READY': 0, 'BLOCKED': 0, 'PARTIAL': 0, 'MISSING': 0}
for req in requirements:
    status = req.get('status', 'MISSING')
    status_counts[status] = status_counts.get(status, 0) + 1

total = len(requirements)
ready = status_counts.get('READY', 0)
spec_completion_percent = round((ready / total * 100), 2) if total > 0 else 0.0

# Build output
output = {
    'total_requirements': total,
    'status_counts': status_counts,
    'ready_count': ready,
    'spec_completion_percent': spec_completion_percent
}

# Write JSON
OUT_FILE.write_text(json.dumps(output, indent=2))
print(json.dumps(output, indent=2))
