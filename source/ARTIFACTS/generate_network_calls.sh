#!/bin/bash
set -e

OUTPUT="ARTIFACTS/NETWORK_CALLS_MAP.md"
echo "# NETWORK_CALLS_MAP.md - API Integration Analysis" > $OUTPUT
echo "" >> $OUTPUT
echo "**Generated:** $(date)" >> $OUTPUT
echo "**Method:** Grep-based callsite detection" >> $OUTPUT
echo "" >> $OUTPUT

echo "## 🔥 FIREBASE CLOUD FUNCTIONS USAGE" >> $OUTPUT
echo "" >> $OUTPUT
echo "### httpsCallable Invocations" >> $OUTPUT
echo "" >> $OUTPUT
echo '```' >> $OUTPUT
grep -rn "httpsCallable" apps/ --include="*.dart" --include="*.ts" --include="*.js" 2>/dev/null || echo "No httpsCallable found" >> $OUTPUT
echo '```' >> $OUTPUT
echo "" >> $OUTPUT

echo "### firebase.functions() Usage" >> $OUTPUT
echo "" >> $OUTPUT
echo '```' >> $OUTPUT
grep -rn "functions()" apps/ --include="*.dart" --include="*.ts" --include="*.js" 2>/dev/null | head -20 || echo "No firebase.functions() found" >> $OUTPUT
echo '```' >> $OUTPUT
echo "" >> $OUTPUT

echo "## 🌐 REST API USAGE" >> $OUTPUT
echo "" >> $OUTPUT
echo "### HTTP Client Initialization (baseURL detection)" >> $OUTPUT
echo "" >> $OUTPUT
echo '```' >> $OUTPUT
grep -rn "baseURL\|baseUrl\|base_url" apps/ --include="*.dart" --include="*.ts" --include="*.js" 2>/dev/null || echo "No baseURL found" >> $OUTPUT
echo '```' >> $OUTPUT
echo "" >> $OUTPUT

echo "### Axios/HTTP Calls" >> $OUTPUT
echo "" >> $OUTPUT
echo '```' >> $OUTPUT
grep -rn "axios\|http.get\|http.post" apps/ --include="*.dart" --include="*.ts" --include="*.js" 2>/dev/null | head -30 || echo "No HTTP calls found" >> $OUTPUT
echo '```' >> $OUTPUT
echo "" >> $OUTPUT

echo "## 🔐 FIRESTORE DIRECT ACCESS" >> $OUTPUT
echo "" >> $OUTPUT
echo "### Collection References" >> $OUTPUT
echo "" >> $OUTPUT
echo '```' >> $OUTPUT
grep -rn "collection(" apps/ --include="*.dart" --include="*.ts" --include="*.js" 2>/dev/null | head -30 || echo "No Firestore collection() found" >> $OUTPUT
echo '```' >> $OUTPUT
echo "" >> $OUTPUT

echo "## 📊 SUMMARY TABLE" >> $OUTPUT
echo "" >> $OUTPUT
echo "| Caller App | Target Type | Function/Endpoint | File Location |" >> $OUTPUT
echo "|------------|-------------|-------------------|---------------|" >> $OUTPUT

# Flutter Customer App
if [ -d "apps/mobile-customer" ]; then
  grep -l "httpsCallable\|collection(" apps/mobile-customer/lib/*.dart 2>/dev/null | while read file; do
    echo "| Customer App | Firebase | (see file) | \`$file\` |" >> $OUTPUT
  done
fi

# Flutter Merchant App  
if [ -d "apps/mobile-merchant" ]; then
  grep -l "httpsCallable\|collection(" apps/mobile-merchant/lib/*.dart 2>/dev/null | while read file; do
    echo "| Merchant App | Firebase | (see file) | \`$file\` |" >> $OUTPUT
  done
fi

# Web Admin
if [ -d "apps/web-admin" ]; then
  grep -l "fetch\|axios" apps/web-admin/*.js apps/web-admin/*.ts 2>/dev/null | while read file; do
    echo "| Web Admin | HTTP/Firebase | (see file) | \`$file\` |" >> $OUTPUT
  done
fi

echo "" >> $OUTPUT
echo "✅ NETWORK_CALLS_MAP.md generated"
