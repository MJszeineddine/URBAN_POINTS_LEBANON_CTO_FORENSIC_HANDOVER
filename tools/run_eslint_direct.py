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

print(f"Running eslint directly in: {WEB_ADMIN_DIR}")
print(f"Evidence dir: {EVIDENCE_DIR}")

# Save command - using direct eslint since 'next lint' is broken
(EVIDENCE_DIR / 'web_admin_lint_cmd.txt').write_text('npx --yes eslint . --ext .ts,.tsx,.js,.jsx --max-warnings 0\n')

# Run eslint directly instead of 'next lint'
try:
    result = subprocess.run(
        'npx --yes eslint . --ext .ts,.tsx,.js,.jsx --max-warnings 0',
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
print("ESLINT RESULTS (Direct, not via 'next lint')")
print("="*70)
print(f"RC: {rc}")
print(f"Evidence dir: {EVIDENCE_DIR}")
print("\nSTDOUT (last 50 lines):")
lines = stdout.split('\n')[-50:]
for line in lines:
    print(line)
print("\nSTDERR (last 30 lines):")
lines = stderr.split('\n')[-30:]
for line in lines:
    print(line)
print("="*70)

if rc == 0:
    print("\n✅ LINT PASSED")
else:
    print(f"\n❌ LINT FAILED (RC {rc})")

sys.exit(0)
