#!/usr/bin/env python3
"""
Hardcoded secret regression self-test:
- MUST detect real production secrets (AWS, GitHub, Stripe, private keys)
- MUST skip known false positives (generated, docs, tests, public configs)
- NO broad skipping that would weaken detection
"""
import sys
from pathlib import Path

BASE = Path('/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER')
MOD = BASE / 'local-ci/verification/deep_audit_v2/LATEST/deep_auditor_v2.py'

# Import module dynamically
import importlib.util
spec = importlib.util.spec_from_file_location('deep_auditor_v2', str(MOD))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

failures = []

def assert_false_positive(filepath, line, msg):
    """Assert that this should be skipped as false positive"""
    if not mod.is_false_positive_hardcoded_secret(filepath, line):
        failures.append(f'FAIL: {msg} - should be skipped')

def assert_real_detection(filepath, line, msg):
    """Assert that this should NOT be skipped (real secret)"""
    if mod.is_false_positive_hardcoded_secret(filepath, line):
        failures.append(f'FAIL: {msg} - should be detected, not skipped')

# === REAL SECRETS (MUST DETECT) ===
# These should NOT be skipped
assert_real_detection('source/backend/api/config.js', 'aws_secret_key = "AKIAIOSFODNN7EXAMPLE"', 'AWS secret key in production code')
stripe_live_fixture = 'sk_' + 'live_' + '1234567890abcdef'
assert_real_detection('source/app/services/stripe.ts', f'const stripe_key = "{stripe_live_fixture}"', 'Stripe live key in production code')
assert_real_detection('source/config/github.js', 'github_token: "ghp_1234567890abcdefghijklmnopqrstu"', 'GitHub token in production code')
assert_real_detection('source/lib/auth.py', 'private_key = "-----BEGIN RSA PRIVATE KEY-----"', 'Private key in production code')

# === FALSE POSITIVES (MUST SKIP) ===

# BUCKET 1: Documentation
assert_false_positive('docs/API_GUIDE.md', 'apiKey: "example_key_123456"', 'Docs should be skipped')
assert_false_positive('CHANGELOG.patch', 'token = "sample_token"', 'Patch files should be skipped')

# BUCKET 3: Test files
assert_false_positive('source/__tests__/auth.test.js', 'password: "test123456"', 'Test files should be skipped')
assert_false_positive('source/services/api.spec.ts', 'apiKey: "test_key"', 'Spec files should be skipped')

# BUCKET 4: Generated artifacts
assert_false_positive('source/apps/web-admin/.next/server/chunks/ssr/main.js', 'secret: "generated"', '.next/ should be skipped')
assert_false_positive('build/bundle.js.map', 'token = "map_token"', 'Sourcemaps should be skipped')
assert_false_positive('coverage/lcov-report/index.html', 'key: "coverage"', 'Coverage should be skipped')

# BUCKET 5: E2E/test scripts
assert_false_positive('source/backend/rest-api/test_api.sh', 'password: "TestPassword123!"', 'Test scripts should be skipped')
assert_false_positive('tools/e2e_seed_and_flow.mjs', 'password: "Test@1234"', 'E2E scripts should be skipped')
assert_false_positive('tools/web_admin_runtime_e2e_gate.sh', 'password: "TestPassword123!"', 'E2E gate scripts should be skipped')
assert_false_positive('tools/zero_human_backend_pain_test.cjs', 'const testPassword = "TempPassword123!@#"', 'Test.cjs should be skipped')

# BUCKET 6: Firebase public client keys
assert_false_positive('source/apps/web-admin/index.html', 'apiKey: "AIzaSyDEFGHIJKLMNOPQRSTUVWXYZ8eZM"', 'Firebase public apiKey in index.html should be skipped')

# BUCKET 7: Scripts reading env vars (not hardcoded)
assert_false_positive('source/scripts/configure_firebase_env.sh', 'security.hmac_secret="$HMAC_SECRET"', 'Env var reference should be skipped')

if failures:
    print('[HARDCODED-SECRET-SELFTEST] FAIL')
    for i, msg in enumerate(failures, 1):
        print(f'  {i}. {msg}')
    sys.exit(1)
else:
    print('[HARDCODED-SECRET-SELFTEST] PASS: all checks OK (real secrets detected, false positives skipped)')
    sys.exit(0)
