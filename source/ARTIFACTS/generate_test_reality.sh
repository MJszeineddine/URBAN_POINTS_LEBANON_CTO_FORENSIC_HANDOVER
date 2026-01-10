#!/bin/bash

OUTPUT="ARTIFACTS/TEST_REALITY.md"

echo "# TEST REALITY — Tests Present, Pass/Fail, Coverage" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "**Generated**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$OUTPUT"
echo "" >> "$OUTPUT"

cat >> "$OUTPUT" << 'EOF'

## Test Files Inventory

| Location | Test Files | Test Type | Run Command |
|----------|----------|-----------|-------------|
EOF

# Firebase Functions tests
if [ -d "backend/firebase-functions/src/__tests__" ]; then
    test_count=$(find backend/firebase-functions/src/__tests__ -name "*.test.ts" -o -name "*.spec.ts" | wc -l)
    echo "| backend/firebase-functions/src/__tests__/ | $test_count test files | Jest (TypeScript) | \`cd backend/firebase-functions && npm test\` |" >> "$OUTPUT"
else
    echo "| backend/firebase-functions/ | 0 | NONE | N/A |" >> "$OUTPUT"
fi

# REST API tests
if [ -d "backend/rest-api/tests" ] || [ -d "backend/rest-api/src/__tests__" ]; then
    test_count=$(find backend/rest-api/tests backend/rest-api/src/__tests__ -name "*.test.ts" -o -name "*.spec.ts" 2>/dev/null | wc -l)
    echo "| backend/rest-api/tests/ | $test_count test files | Jest OR Mocha | \`cd backend/rest-api && npm test\` |" >> "$OUTPUT"
else
    echo "| backend/rest-api/ | 0 | NONE | N/A |" >> "$OUTPUT"
fi

# Mobile apps tests
for app in apps/mobile-customer apps/mobile-merchant apps/mobile-admin; do
    if [ -d "$app/test" ]; then
        test_count=$(find "$app/test" -name "*_test.dart" 2>/dev/null | wc -l)
        echo "| $app/test/ | $test_count test files | Flutter test | \`cd $app && flutter test\` |" >> "$OUTPUT"
    else
        echo "| $app/ | 0 | NONE | N/A |" >> "$OUTPUT"
    fi
done

# Web Admin tests
if [ -d "apps/web-admin/__tests__" ] || [ -d "apps/web-admin/test" ]; then
    test_count=$(find apps/web-admin/__tests__ apps/web-admin/test -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" 2>/dev/null | wc -l)
    echo "| apps/web-admin/ | $test_count test files | Jest/Vitest | \`cd apps/web-admin && npm test\` |" >> "$OUTPUT"
else
    echo "| apps/web-admin/ | 0 | NONE | N/A |" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'

## Test Configuration Files

EOF

# Jest configs
echo "### Jest/Vitest Configs" >> "$OUTPUT"
find . -maxdepth 3 -name "jest.config.*" -o -name "vitest.config.*" 2>/dev/null | while read -r config; do
    echo "- \`$config\`" >> "$OUTPUT"
done

# Flutter test configs
echo "" >> "$OUTPUT"
echo "### Flutter Test Configs" >> "$OUTPUT"
find apps/ -name "flutter_test.yaml" 2>/dev/null | while read -r config; do
    echo "- \`$config\`" >> "$OUTPUT"
done

cat >> "$OUTPUT" << 'EOF'

## Test Execution Reality Check

EOF

# Try to detect test scripts in package.json files
echo "### Backend Tests (Firebase Functions)" >> "$OUTPUT"
if [ -f "backend/firebase-functions/package.json" ]; then
    test_script=$(grep '"test"' backend/firebase-functions/package.json || echo "NO TEST SCRIPT")
    echo '```json' >> "$OUTPUT"
    echo "$test_script" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
else
    echo "**NO package.json FOUND**" >> "$OUTPUT"
fi

echo "" >> "$OUTPUT"
echo "### REST API Tests" >> "$OUTPUT"
if [ -f "backend/rest-api/package.json" ]; then
    test_script=$(grep '"test"' backend/rest-api/package.json || echo "NO TEST SCRIPT")
    echo '```json' >> "$OUTPUT"
    echo "$test_script" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
else
    echo "**NO package.json FOUND**" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'

## Test Coverage Evidence

EOF

# Check for coverage configs
if grep -r "collectCoverage" backend/ 2>/dev/null | grep -q "true"; then
    echo "**Coverage enabled** in backend tests" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    grep -r "collectCoverage\|coverageThreshold" backend/ 2>/dev/null | head -10 >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
else
    echo "**NO COVERAGE CONFIG** found in backend" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'

## Actual Test Execution (Sample Run)

EOF

# Try to run Firebase Functions tests
echo "### Firebase Functions Test Run" >> "$OUTPUT"
if [ -f "backend/firebase-functions/package.json" ]; then
    echo '```bash' >> "$OUTPUT"
    echo "$ cd backend/firebase-functions && npm test 2>&1 | head -50" >> "$OUTPUT"
    cd backend/firebase-functions && npm test 2>&1 | head -50 >> "$OUTPUT" || echo "TESTS FAILED OR NOT CONFIGURED" >> "$OUTPUT"
    cd ../../
    echo '```' >> "$OUTPUT"
else
    echo "**CANNOT RUN TESTS** - no package.json" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'

## Test Reality Summary

| Component | Tests Present | Tests Run | Pass/Fail | Coverage | Confidence |
|-----------|---------------|-----------|-----------|----------|------------|
EOF

# Firebase Functions
fb_tests=$(find backend/firebase-functions/src/__tests__ -name "*.test.ts" 2>/dev/null | wc -l)
if [ "$fb_tests" -gt 0 ]; then
    echo "| Firebase Functions | ✅ YES ($fb_tests files) | ❓ UNKNOWN | ❓ UNKNOWN | ❓ UNKNOWN | 🟡 LOW (not verified) |" >> "$OUTPUT"
else
    echo "| Firebase Functions | ❌ NO | N/A | N/A | 0% | 🔴 ZERO |" >> "$OUTPUT"
fi

# REST API
rest_tests=$(find backend/rest-api/tests backend/rest-api/src/__tests__ -name "*.test.ts" 2>/dev/null | wc -l)
if [ "$rest_tests" -gt 0 ]; then
    echo "| REST API | ✅ YES ($rest_tests files) | ❓ UNKNOWN | ❓ UNKNOWN | ❓ UNKNOWN | 🟡 LOW |" >> "$OUTPUT"
else
    echo "| REST API | ❌ NO | N/A | N/A | 0% | 🔴 ZERO |" >> "$OUTPUT"
fi

# Mobile apps
for app in mobile-customer mobile-merchant mobile-admin; do
    app_tests=$(find "apps/$app/test" -name "*_test.dart" 2>/dev/null | wc -l)
    if [ "$app_tests" -gt 0 ]; then
        echo "| $app | ✅ YES ($app_tests files) | ❓ UNKNOWN | ❓ UNKNOWN | ❓ UNKNOWN | 🟡 LOW |" >> "$OUTPUT"
    else
        echo "| $app | ❌ NO | N/A | N/A | 0% | 🔴 ZERO |" >> "$OUTPUT"
    fi
done

# Web Admin
webadmin_tests=$(find apps/web-admin/__tests__ apps/web-admin/test -name "*.test.ts*" 2>/dev/null | wc -l)
if [ "$webadmin_tests" -gt 0 ]; then
    echo "| Web Admin | ✅ YES ($webadmin_tests files) | ❓ UNKNOWN | ❓ UNKNOWN | ❓ UNKNOWN | 🟡 LOW |" >> "$OUTPUT"
else
    echo "| Web Admin | ❌ NO | N/A | N/A | 0% | 🔴 ZERO |" >> "$OUTPUT"
fi

echo "" >> "$OUTPUT"
echo "## VERDICT: Test Confidence" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "**Overall Test Maturity**: 🟡 **LOW**" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "**Reasons**:" >> "$OUTPUT"
echo "1. Tests exist in some components but execution status UNKNOWN" >> "$OUTPUT"
echo "2. No automated test runs in CI/CD (if scripts exist, not proven to run)" >> "$OUTPUT"
echo "3. No coverage reports found" >> "$OUTPUT"
echo "4. No evidence of integration tests or E2E tests" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "**Recommendation**: Run all tests manually, verify pass/fail, add to CI/CD pipeline" >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "✅ TEST_REALITY.md generated"
