#!/usr/bin/env python3
"""
XSS regression self-test:
- Flags real dangerous sinks
- Skips safe clears
- Skips artifacts/build/test paths via is_false_positive_xss
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

def assert_true(cond, msg):
    if not cond:
        failures.append(msg)

def assert_false(cond, msg):
    if cond:
        failures.append(msg)

# 1) Real dangerous sinks
assert_true(mod.check_xss_vulnerable('element.innerHTML = userInput'), 'Should flag innerHTML variable assignment')
assert_true(mod.check_xss_vulnerable('element.innerHTML += moreHtml'), 'Should flag innerHTML concatenation')
assert_true(mod.check_xss_vulnerable('document.write("<div>" + x)') , 'Should flag document.write')
assert_true(mod.check_xss_vulnerable('<Component dangerouslySetInnerHTML={{__html: html}} />'), 'Should flag dangerouslySetInnerHTML')

# 2) Safe clears should be ignored
assert_false(mod.check_xss_vulnerable('element.innerHTML = ""'), 'Safe clear with empty string should NOT flag')
assert_false(mod.check_xss_vulnerable("element.innerHTML = ''"), 'Safe clear with empty string should NOT flag')
assert_false(mod.check_xss_vulnerable('element.innerHTML = ``'), 'Safe clear with empty template should NOT flag')
assert_false(mod.check_xss_vulnerable('element.innerHTML = null'), 'Safe clear with null should NOT flag')

# 3) False positive path skips
assert_true(mod.is_false_positive_xss('source/ARTIFACTS/ZERO_GAPS/diff.patch', ''), 'Artifacts path should be skipped')
assert_true(mod.is_false_positive_xss('source/apps/web-admin/.next/static/chunks/foo.js', ''), '.next static path should be skipped')
assert_true(mod.is_false_positive_xss('source/backend/rest-api/coverage/lcov-report/prettify.js', ''), 'coverage report should be skipped')
assert_true(mod.is_false_positive_xss('source/apps/web-admin/__tests__/view.test.tsx', ''), 'test files should be skipped')

if failures:
    print('[XSS-SELFTEST] FAIL')
    for i, msg in enumerate(failures, 1):
        print(f'  {i}. {msg}')
    sys.exit(1)
else:
    print('[XSS-SELFTEST] PASS: all checks OK')
    sys.exit(0)
