#!/usr/bin/env python3
import json
import subprocess

# Get git info
try:
    commit = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD'], text=True).strip()
except:
    commit = "unknown"

try:
    branch = subprocess.check_output(['git', 'branch', '--show-current'], text=True).strip()
except:
    branch = "unknown"

# Read exit codes
try:
    with open('local-ci/verification/exit_normal.txt') as f:
        content = f.read().strip()
        exit_normal = content.split(':')[1] if ':' in content else content
except:
    exit_normal = "unknown"

try:
    with open('local-ci/verification/exit_allow_blocked.txt') as f:
        content = f.read().strip()
        exit_allow_blocked = content.split(':')[1] if ':' in content else content
except:
    exit_allow_blocked = "unknown"

# Read report
try:
    with open('local-ci/verification/cto_verify_report_after_last_run.json') as f:
        report = json.load(f)
    report_status = report.get('status', 'unknown')
    counts = report.get('requirement_counts', {})
except:
    report_status = "unknown"
    counts = {}

summary = {
    "git_commit": commit,
    "branch": branch,
    "exit_normal": exit_normal,
    "exit_allow_blocked": exit_allow_blocked,
    "report_status": report_status,
    "requirement_counts": counts
}

with open('local-ci/verification/summary.json', 'w') as f:
    json.dump(summary, f, indent=2)

print(json.dumps(summary, indent=2))
