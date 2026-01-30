#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path
from datetime import datetime

REPO_ROOT = Path('/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER')
WEB_ADMIN_DIR = REPO_ROOT / 'source' / 'apps' / 'web-admin'

TIMESTAMP = datetime.now().strftime('%Y%m%dT%H%M%SZ')
EVIDENCE_DIR = REPO_ROOT / 'local-ci' / 'evidence' / 'LINT_FIX' / TIMESTAMP
EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)

print(f"Running lint in: {WEB_ADMIN_DIR}")
print(f"Evidence dir: {EVIDENCE_DIR}")

# Save command
(EVIDENCE_DIR / 'web_admin_lint_cmd.txt').write_text('npm run lint\n')

# Run with timeout via subprocess
try:
    result = subprocess.run(
        'npm run lint',
        shell=True,
        cwd=WEB_ADMIN_DIR,
        capture_output=True,
        text=True,
        timeout=120
    )
    
    rc = result.returncode
    stdout = result.stdout
    stderr = result.stderr
    
except subprocess.TimeoutExpired:
    rc = 124
    stdout = "Timeout after 120s"
    stderr = "Process killed"

# Save outputs
(EVIDENCE_DIR / 'web_admin_lint_stdout.log').write_text(stdout)
(EVIDENCE_DIR / 'web_admin_lint_stderr.log').write_text(stderr)
(EVIDENCE_DIR / 'web_admin_lint_rc.txt').write_text(str(rc) + '\n')

# Copy .eslintignore
import shutil
shutil.copy(WEB_ADMIN_DIR / '.eslintignore', EVIDENCE_DIR / 'web_admin_eslintignore.txt')

# Print results
print("\n" + "="*70)
print("LINT RESULTS")
print("="*70)
print(f"RC: {rc}")
print(f"Evidence dir: {EVIDENCE_DIR}")
print("\nSTDOUT (last 50 lines):")
print('\n'.join(stdout.split('\n')[-50:]))
print("\nSTDERR (last 50 lines):")
print('\n'.join(stderr.split('\n')[-50:]))
print("="*70)

sys.exit(0)
