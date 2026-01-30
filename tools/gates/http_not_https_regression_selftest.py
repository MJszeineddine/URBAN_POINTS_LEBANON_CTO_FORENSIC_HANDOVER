#!/usr/bin/env python3
"""
HTTP_NOT_HTTPS regression self-test:
- MUST detect real code endpoints (http://example.com in code)
- MUST skip XML namespace/DTD URIs
- MUST skip docs/patches/build paths
- Exit 0 only if all pass
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

def assert_false_positive(filepath, url, line, msg):
    """Assert that this should be skipped as false positive"""
    if not mod.is_false_positive_http_not_https(filepath, url, line):
        failures.append(f'FAIL: {msg} - should be skipped')

def assert_real_detection(filepath, url, line, msg):
    """Assert that this should NOT be skipped (real endpoint)"""
    if mod.is_false_positive_http_not_https(filepath, url, line):
        failures.append(f'FAIL: {msg} - should be detected, not skipped')

# === REAL ENDPOINTS (MUST DETECT) ===
# Code endpoints with http:// that are NOT in exceptions
assert_real_detection('source/services/api.ts', 'http://api.example.com/data', 'const url = "http://api.example.com/data"', 'Real code endpoint should be detected')
assert_real_detection('source/config/endpoints.js', 'http://localhost:8080', 'http://localhost:8080/api', 'Real code endpoint (localhost) should be detected')

# === FALSE POSITIVES (MUST SKIP) ===

# XML namespaces in XML files
assert_false_positive('source/app/AndroidManifest.xml', 'http://schemas.android.com/apk/res/android', '<manifest xmlns:android="http://...', 'XML namespace in AndroidManifest should be skipped')
assert_false_positive('source/app/Info.plist', 'http://www.apple.com/DTDs/PropertyList-1.0.dtd', '<!DOCTYPE plist...', 'DTD in plist should be skipped')

# XML/DTD in .xcsettings
assert_false_positive('source/ios/Runner.xcworkspace/IDEWorkspaceChecks.xcsettings', 'http://www.apple.com/DTDs/PropertyList-1.0.dtd', 'DOCTYPE ...', 'DTD in xcsettings should be skipped')

# XML namespace in entitlements
assert_false_positive('source/macos/Runner/Release.entitlements', 'http://schemas.microsoft.com/smi', 'xmlns=...', 'Microsoft schema in entitlements should be skipped')

# Documentation
assert_false_positive('docs/API_GUIDE.md', 'http://api.example.com', '> Example: http://api.example.com', 'Docs should be skipped')
assert_false_positive('CHANGELOG.patch', 'http://old.api.com', '-http://old.api.com', 'Patch files should be skipped')

# Build artifacts
assert_false_positive('source/apps/web-admin/.next/server/chunks/ssr/main.js', 'http://example.com', 'const x = "http://example.com"', '.next/ build artifacts should be skipped')
assert_false_positive('coverage/lcov-report/index.html', 'http://localhost:3000', '<a href="http://localhost:3000"', 'Coverage report should be skipped')

# Test fixtures
assert_false_positive('source/__tests__/api.test.js', 'http://test.local', 'const mockUrl = "http://test.local"', 'Test files should be skipped')

if failures:
    print('[HTTP-NOT-HTTPS-SELFTEST] FAIL')
    for i, msg in enumerate(failures, 1):
        print(f'  {i}. {msg}')
    sys.exit(1)
else:
    print('[HTTP-NOT-HTTPS-SELFTEST] PASS: all checks OK (real endpoints detected, false positives skipped)')
    sys.exit(0)
