#!/usr/bin/env python3
"""
Hermetic Toolchain Bootstrap
Verifies Node.js version, npm, and other required tools
"""

import sys
import subprocess
from pathlib import Path

REPO_ROOT = Path.cwd()
NVMRC_FILE = REPO_ROOT / '.nvmrc'

def check_version(cmd, name):
    """Check if tool exists and get version."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            version = result.stdout.strip()
            print(f"✅ {name}: {version}")
            return True, version
        else:
            print(f"❌ {name}: NOT FOUND")
            return False, None
    except Exception as e:
        print(f"❌ {name}: ERROR ({e})")
        return False, None

def check_node_version():
    """Verify Node.js version matches .nvmrc."""
    if not NVMRC_FILE.exists():
        print("⚠️  .nvmrc not found, skipping Node version check")
        return True
    
    required = NVMRC_FILE.read_text().strip()
    ok, actual = check_version(['node', '--version'], 'Node.js')
    
    if not ok:
        print(f"\n❌ EXTERNAL BLOCKER: Node.js not installed")
        print(f"   Required: v{required}")
        print(f"   Install: https://nodejs.org/")
        return False
    
    actual_clean = actual.strip('v')
    required_major = required.split('.')[0]
    actual_major = actual_clean.split('.')[0]
    
    if actual_major != required_major:
        print(f"\n❌ EXTERNAL BLOCKER: Node.js version mismatch")
        print(f"   Required: v{required} (major {required_major})")
        print(f"   Actual: {actual} (major {actual_major})")
        print(f"   Fix: nvm install {required} && nvm use {required}")
        return False
    
    print(f"✅ Node.js version OK (matches .nvmrc)")
    return True

def check_flutter():
    """Check Flutter (optional)."""
    ok, version = check_version(['flutter', '--version'], 'Flutter')
    if not ok:
        print("⚠️  Flutter not found (optional for GO_RUN, gates will be skipped)")
    return True  # Not a blocker

def main():
    """Main bootstrap check."""
    print("="*70)
    print("HERMETIC TOOLCHAIN BOOTSTRAP")
    print("="*70 + "\n")
    
    checks = [
        check_node_version(),
        check_version(['npm', '--version'], 'npm')[0],
        check_version(['git', '--version'], 'git')[0],
        check_version(['python3', '--version'], 'Python')[0],
        check_flutter()
    ]
    
    print("\n" + "="*70)
    
    if all(checks[:4]):  # Node, npm, git, python are required
        print("✅ BOOTSTRAP OK - All required tools available")
        sys.exit(0)
    else:
        print("❌ BOOTSTRAP FAILED - Missing required tools")
        sys.exit(1)

if __name__ == '__main__':
    main()
