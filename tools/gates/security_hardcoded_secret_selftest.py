#!/usr/bin/env python3
"""
BATCH_4: Self-test for hardcoded_secret false positive hardening.
Verifies:
1. Real secrets are still detected (AWS, GitHub, Stripe, RSA)
2. Documentation files (.md/.patch) are NOT flagged
3. Firebase public keys (AIzaSy) are NOT flagged
4. Test-only fixtures (__tests__, .test., .spec.) are NOT flagged
"""

import sys
import os
import re
from pathlib import Path

# Add deep_audit_v2 to path
sys.path.insert(0, '/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/local-ci/verification/deep_audit_v2/LATEST')
from deep_auditor_v2 import is_false_positive_hardcoded_secret

def test_real_secrets_detected():
    """Verify real secrets are still flagged (NOT false positives)"""
    
    stripe_live_fixture = "sk_" + "live_" + "TEST_REDACTED"
    test_cases = [
        # AWS secret access key (test fixture - redacted)
        ('source/config.ts', 'const AWS_SECRET = "AKIA_TEST_REDACTED"'),
        # GitHub personal token (test fixture - redacted)
        ('src/auth.js', 'github_token: "ghp_TEST_REDACTED"'),
        # Stripe secret key (test fixture - redacted)
        ('backend/payment.py', f'stripe_secret_key = "{stripe_live_fixture}"'),
        # RSA private key (test fixture - redacted)
        ('certs/key.pem', 'PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----"'),
    ]
    
    passed = 0
    for filepath, line in test_cases:
        is_fp = is_false_positive_hardcoded_secret(filepath, line)
        if not is_fp:  # Should NOT be a false positive (should be detected)
            passed += 1
            print(f"  ✓ {filepath}: Real secret CORRECTLY detected")
        else:
            print(f"  ✗ {filepath}: Real secret INCORRECTLY marked as false positive!")
            return False
    
    print(f"\n[+] Real secrets test: {passed}/{len(test_cases)} passed")
    return passed == len(test_cases)

def test_documentation_not_flagged():
    """Verify .md, .patch, .log, .txt, .diff files are skipped"""
    
    test_cases = [
        ('BLOCKER_UP-FS-008.md', 'api_key: "some_value_from_error_message"'),
        ('audit_report.md', 'password = "debug_output_from_test"'),
        ('FINAL_COMPLETION_REPORT.md', 'secret: "value_from_log"'),
        ('changes.patch', 'token = "old_token_value"'),
        ('build.log', 'AUTH_TOKEN="temporary_test_value"'),
        ('notes.txt', 'api_key: "example_key"'),
    ]
    
    passed = 0
    for filepath, line in test_cases:
        is_fp = is_false_positive_hardcoded_secret(filepath, line)
        if is_fp:  # Should be skipped (false positive)
            passed += 1
            print(f"  ✓ {filepath}: Documentation correctly SKIPPED")
        else:
            print(f"  ✗ {filepath}: Documentation incorrectly FLAGGED!")
            return False
    
    print(f"\n[+] Documentation test: {passed}/{len(test_cases)} passed")
    return passed == len(test_cases)

def test_firebase_public_keys_not_flagged():
    """Verify firebaseClient.ts and firebase_options.dart are skipped"""
    
    test_cases = [
        ('source/apps/web-admin/lib/firebaseClient.ts', 'apiKey: "AIzaSyDummyKeyForTesting123456"'),
        ('source/apps/web-admin/lib/firebaseClient.ts', 'appId: "1:123456789:web:abcdef123456"'),
        ('source/firebase_options.dart', 'const apiKey = "AIzaSyDummyFlutterKey123"'),
        ('firebase-messaging-sw.js', 'const firebase_config = { apiKey: "AIzaSy..." }'),
    ]
    
    passed = 0
    for filepath, line in test_cases:
        is_fp = is_false_positive_hardcoded_secret(filepath, line)
        if is_fp:  # Should be skipped
            passed += 1
            print(f"  ✓ {filepath}: Firebase public key correctly SKIPPED")
        else:
            print(f"  ✗ {filepath}: Firebase public key incorrectly FLAGGED!")
            return False
    
    print(f"\n[+] Firebase public keys test: {passed}/{len(test_cases)} passed")
    return passed == len(test_cases)

def test_test_files_not_flagged():
    """Verify test files (__tests__, .test., .spec., jest.setup, widget_test) are skipped"""
    
    test_cases = [
        ('source/backend/firebase-functions/src/__tests__/core-qr.test.ts', 'const test_secret = "dummy_test_key"'),
        ('src/__tests__/auth.test.js', 'mock_api_key = "fake_key_for_testing"'),
        ('spec/payment.spec.ts', 'stub_token = "test_token_value"'),
        ('jest.setup.js', 'process.env.API_KEY = "jest_setup_dummy"'),
        ('source/apps/mobile-merchant/test/widget_test.dart', 'const testPassword = "test_password_123"'),
    ]
    
    passed = 0
    for filepath, line in test_cases:
        is_fp = is_false_positive_hardcoded_secret(filepath, line)
        if is_fp:  # Should be skipped
            passed += 1
            print(f"  ✓ {filepath}: Test fixture correctly SKIPPED")
        else:
            print(f"  ✗ {filepath}: Test fixture incorrectly FLAGGED!")
            return False
    
    print(f"\n[+] Test files test: {passed}/{len(test_cases)} passed")
    return passed == len(test_cases)

def main():
    print("=" * 70)
    print("BATCH_4 Self-Test: Hardcoded Secret False Positive Hardening")
    print("=" * 70)
    print()
    
    all_passed = True
    
    print("[TEST 1] Real secrets should still be DETECTED")
    print("-" * 70)
    all_passed &= test_real_secrets_detected()
    print()
    
    print("[TEST 2] Documentation files should be SKIPPED")
    print("-" * 70)
    all_passed &= test_documentation_not_flagged()
    print()
    
    print("[TEST 3] Firebase public keys should be SKIPPED")
    print("-" * 70)
    all_passed &= test_firebase_public_keys_not_flagged()
    print()
    
    print("[TEST 4] Test-only fixtures should be SKIPPED")
    print("-" * 70)
    all_passed &= test_test_files_not_flagged()
    print()
    
    print("=" * 70)
    if all_passed:
        print("[✓] ALL TESTS PASSED - No regression in hardening")
        print("=" * 70)
        return 0
    else:
        print("[✗] SOME TESTS FAILED - Review hardening logic")
        print("=" * 70)
        return 1

if __name__ == '__main__':
    exit_code = main()
    sys.exit(exit_code)
