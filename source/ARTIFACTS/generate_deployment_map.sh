#!/bin/bash

OUTPUT="ARTIFACTS/DEPLOYMENT_MAP.md"

echo "# DEPLOYMENT MAP — How Each Component Deploys" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "**Generated**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$OUTPUT"
echo "" >> "$OUTPUT"

cat >> "$OUTPUT" << 'EOF'

## Component Deployment Status

| Component | Deployment Method | Config File | Deploy Command | Status |
|-----------|-------------------|-------------|----------------|--------|
EOF

# Firebase Functions
if [ -f "backend/firebase-functions/package.json" ]; then
    echo "| Firebase Cloud Functions | Firebase CLI | firebase.json + backend/firebase-functions/ | \`firebase deploy --only functions\` | ✅ READY |" >> "$OUTPUT"
else
    echo "| Firebase Cloud Functions | UNKNOWN | NO package.json | UNKNOWN | ❌ MISSING |" >> "$OUTPUT"
fi

# Firestore Rules + Indexes
if [ -f "infra/firestore.rules" ] && [ -f "infra/firestore.indexes.json" ]; then
    echo "| Firestore Rules + Indexes | Firebase CLI | infra/firestore.rules + infra/firestore.indexes.json | \`firebase deploy --only firestore:rules,firestore:indexes\` | ✅ READY |" >> "$OUTPUT"
else
    echo "| Firestore Rules + Indexes | UNKNOWN | MISSING FILES | UNKNOWN | ❌ MISSING |" >> "$OUTPUT"
fi

# Web Admin (Hosting)
if [ -f "apps/web-admin/package.json" ]; then
    echo "| Web Admin Dashboard | Firebase Hosting OR Vercel/Netlify | apps/web-admin/ | \`firebase deploy --only hosting\` OR platform-specific | ⚠️ PARTIAL (needs build config) |" >> "$OUTPUT"
else
    echo "| Web Admin Dashboard | UNKNOWN | NO package.json | UNKNOWN | ❌ MISSING |" >> "$OUTPUT"
fi

# Mobile Apps
if [ -f "apps/mobile-customer/pubspec.yaml" ]; then
    echo "| Mobile Customer App (APK) | Flutter Build | apps/mobile-customer/pubspec.yaml | \`cd apps/mobile-customer && flutter build apk --release\` | ✅ READY |" >> "$OUTPUT"
else
    echo "| Mobile Customer App (APK) | UNKNOWN | NO pubspec.yaml | UNKNOWN | ❌ MISSING |" >> "$OUTPUT"
fi

if [ -f "apps/mobile-merchant/pubspec.yaml" ]; then
    echo "| Mobile Merchant App (APK) | Flutter Build | apps/mobile-merchant/pubspec.yaml | \`cd apps/mobile-merchant && flutter build apk --release\` | ✅ READY |" >> "$OUTPUT"
else
    echo "| Mobile Merchant App (APK) | UNKNOWN | NO pubspec.yaml | UNKNOWN | ❌ MISSING |" >> "$OUTPUT"
fi

# REST API
if [ -f "backend/rest-api/package.json" ]; then
    echo "| REST API (Express) | PM2 OR Cloud Run OR App Engine | backend/rest-api/package.json | \`pm2 start npm --name rest-api -- start\` | ⚠️ UNCLEAR (no deploy script) |" >> "$OUTPUT"
else
    echo "| REST API (Express) | UNKNOWN | NO package.json | UNKNOWN | ❌ MISSING |" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'

## Firebase Deployment Configuration

EOF

if [ -f "firebase.json" ]; then
    echo '```json' >> "$OUTPUT"
    cat firebase.json >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
else
    echo "**NO firebase.json FOUND** at project root" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'

## Deployment Scripts

EOF

# Check for deployment scripts
if [ -d "scripts" ]; then
    echo "**Scripts found**:" >> "$OUTPUT"
    ls -1 scripts/*.sh 2>/dev/null | while read -r script; do
        echo "- \`$script\`" >> "$OUTPUT"
    done
else
    echo "**NO SCRIPTS DIRECTORY FOUND**" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'

## Missing Deployment Components

| Component | Missing Item | Impact | Recommended Action |
|-----------|--------------|--------|-------------------|
EOF

# Check for common missing deployment items
[ ! -f "backend/firebase-functions/.env" ] && echo "| Firebase Functions | .env file | 🔴 CRITICAL | Create .env with secrets (STRIPE_SECRET, HMAC_SECRET, etc.) |" >> "$OUTPUT"
[ ! -f ".firebaserc" ] && echo "| Firebase Project | .firebaserc | 🔴 CRITICAL | Run \`firebase init\` or create .firebaserc with project ID |" >> "$OUTPUT"
[ ! -f "apps/web-admin/next.config.js" ] && [ ! -f "apps/web-admin/next.config.mjs" ] && echo "| Web Admin | next.config.js | 🟡 MEDIUM | Create Next.js config for production build |" >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "## Recommended One-Command Deployment" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo '```bash' >> "$OUTPUT"
echo '#!/bin/bash' >> "$OUTPUT"
echo '# Complete deployment script' >> "$OUTPUT"
echo '' >> "$OUTPUT"
echo '# 1. Deploy Firebase Functions + Firestore' >> "$OUTPUT"
echo 'firebase deploy --only functions,firestore:rules,firestore:indexes' >> "$OUTPUT"
echo '' >> "$OUTPUT"
echo '# 2. Build and deploy Web Admin' >> "$OUTPUT"
echo 'cd apps/web-admin && npm run build && firebase deploy --only hosting' >> "$OUTPUT"
echo '' >> "$OUTPUT"
echo '# 3. Build Mobile APKs' >> "$OUTPUT"
echo 'cd ../../apps/mobile-customer && flutter build apk --release' >> "$OUTPUT"
echo 'cd ../mobile-merchant && flutter build apk --release' >> "$OUTPUT"
echo '```' >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "✅ DEPLOYMENT_MAP.md generated"
