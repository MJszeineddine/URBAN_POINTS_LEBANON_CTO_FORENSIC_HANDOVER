#!/usr/bin/env bash
set +e  # Don't exit on errors, we want to capture all exit codes

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
EVID="$ROOT/local-ci/verification/admin_report_evidence"

echo "Collecting build/test evidence..."

# Backend
echo "Backend build..."
(cd source/backend/firebase-functions && npm run build > "$EVID/backend_build.log" 2>&1)
echo $? > "$EVID/backend_build_exit.txt"

echo "Backend test..."
(cd source/backend/firebase-functions && npm test > "$EVID/backend_test.log" 2>&1)
echo $? > "$EVID/backend_test_exit.txt"

# Web Admin
echo "Web build..."
(cd source/apps/web-admin && npm run build > "$EVID/web_build.log" 2>&1)
echo $? > "$EVID/web_build_exit.txt"

echo "Web test..."
(cd source/apps/web-admin && npm test > "$EVID/web_test.log" 2>&1)
echo $? > "$EVID/web_test_exit.txt"

# Merchant
echo "Merchant analyze..."
(cd source/apps/mobile-merchant && flutter analyze > "$EVID/merchant_analyze.log" 2>&1)
echo $? > "$EVID/merchant_analyze_exit.txt"

echo "Merchant test..."
(cd source/apps/mobile-merchant && flutter test > "$EVID/merchant_test.log" 2>&1)
echo $? > "$EVID/merchant_test_exit.txt"

# Customer
echo "Customer analyze..."
(cd source/apps/mobile-customer && flutter analyze > "$EVID/customer_analyze.log" 2>&1)
echo $? > "$EVID/customer_analyze_exit.txt"

echo "Customer test..."
(cd source/apps/mobile-customer && flutter test > "$EVID/customer_test.log" 2>&1)
echo $? > "$EVID/customer_test_exit.txt"

echo "Evidence collection complete!"
ls -lh "$EVID"/*.txt "$EVID"/*.log 2>/dev/null | tail -20
