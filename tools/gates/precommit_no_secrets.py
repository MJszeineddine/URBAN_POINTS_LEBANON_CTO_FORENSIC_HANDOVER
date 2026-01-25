#!/usr/bin/env python3
"""
Pre-commit hook to prevent reintroduction of secrets.
Scans staged files for common secret patterns.
"""

import re
import subprocess
import sys

# Secret patterns to detect
SECRET_PATTERNS = {
    'stripe_secret': r'sk_(?:live)_[A-Za-z0-9]{20,}',
    'stripe_test_secret': r'sk_(?:test)_[A-Za-z0-9]{20,}',
    'aws_secret': r'aws_secret_access_key[=:]\s*[\'"][A-Za-z0-9/+=]{40}[\'"]',
    'github_token': r'ghp_[A-Za-z0-9]{36,}',
    'github_oauth': r'gho_[A-Za-z0-9]{36,}',
    'private_key': r'-----BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE KEY',
    'service_account': r'\"type\"\s*:\s*\"service_account\"',
    'generic_secret': r'(api[_-]?key|password|secret)[=:]\s*[\'"][^\'\"]{8,}[\'"]',
}

def get_staged_files():
    """Get list of staged files from git."""
    try:
        result = subprocess.run(
            ['git', 'diff', '--cached', '--name-only'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip().split('\n') if result.stdout.strip() else []
    except subprocess.CalledProcessError:
        return []

def get_staged_diff():
    """Get staged changes as unified diff."""
    try:
        result = subprocess.run(
            ['git', 'diff', '--cached'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout
    except subprocess.CalledProcessError:
        return ''

def check_for_secrets():
    """Scan staged changes for secret patterns."""
    
    staged_diff = get_staged_diff()
    if not staged_diff:
        print("✅ No staged changes to scan")
        return True
    
    violations = []
    
    # Check each secret pattern
    for pattern_name, pattern in SECRET_PATTERNS.items():
        matches = re.finditer(pattern, staged_diff, re.IGNORECASE | re.MULTILINE)
        for match in matches:
            # Skip if it's a comment or example
            line = match.group(0)
            if any(marker in line for marker in ['example', 'test', 'dummy', 'EXAMPLE', 'TEST']):
                continue
            
            violations.append({
                'pattern': pattern_name,
                'found': line[:50] + '...' if len(line) > 50 else line
            })
    
    if violations:
        print("❌ SECURITY ALERT: Potential secrets detected in staged changes!")
        print()
        for violation in violations:
            print(f"  Pattern: {violation['pattern']}")
            print(f"  Found:   {violation['found']} (redacted)")
        print()
        print("Do NOT commit secrets. Options:")
        print("  1. Unstage and fix: git reset HEAD <file>")
        print("  2. Remove secret and add to .env.example (without value)")
        print("  3. Use environment variables instead")
        return False
    
    return True

def main():
    """Main hook function."""
    print("[Pre-commit] Scanning for secrets...")
    
    if not check_for_secrets():
        print()
        print("❌ Commit blocked: secrets detected")
        print("Use --no-verify to bypass (NOT RECOMMENDED)")
        sys.exit(1)
    
    print("✅ No secrets detected - safe to commit")
    sys.exit(0)

if __name__ == '__main__':
    main()
