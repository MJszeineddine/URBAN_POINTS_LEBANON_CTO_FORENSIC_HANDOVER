#!/bin/bash
set -e

OUTPUT="ARTIFACTS/INVENTORY.md"
echo "# INVENTORY.md - Monorepo Structure Analysis" > $OUTPUT
echo "" >> $OUTPUT
echo "**Generated:** $(date)" >> $OUTPUT
echo "**Method:** Automated file system analysis" >> $OUTPUT
echo "" >> $OUTPUT

echo "## 📊 OVERALL STATISTICS" >> $OUTPUT
echo "" >> $OUTPUT
echo '```' >> $OUTPUT
echo "Total Files: $(find . -type f | wc -l)" >> $OUTPUT
echo "Total Directories: $(find . -type d | wc -l)" >> $OUTPUT
echo "Total Lines of Code (non-binary): $(find . -type f -name "*.dart" -o -name "*.ts" -o -name "*.js" -o -name "*.tsx" -o -name "*.jsx" | xargs wc -l 2>/dev/null | tail -1)" >> $OUTPUT
echo '```' >> $OUTPUT
echo "" >> $OUTPUT

echo "## 📱 MOBILE APPS INVENTORY" >> $OUTPUT
echo "" >> $OUTPUT

for app in apps/mobile-customer apps/mobile-merchant apps/mobile-admin; do
  if [ -d "$app" ]; then
    echo "### $app" >> $OUTPUT
    echo "" >> $OUTPUT
    echo "**Dart Files:** $(find $app/lib -name "*.dart" 2>/dev/null | wc -l)" >> $OUTPUT
    echo "**Total LOC:** $(find $app/lib -name "*.dart" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')" >> $OUTPUT
    echo "" >> $OUTPUT
    
    if [ -f "$app/pubspec.yaml" ]; then
      echo "**Dependencies:**" >> $OUTPUT
      echo '```yaml' >> $OUTPUT
      grep -A 50 "^dependencies:" "$app/pubspec.yaml" | grep -v "^dev_dependencies:" | head -20 >> $OUTPUT
      echo '```' >> $OUTPUT
      echo "" >> $OUTPUT
    fi
    
    if [ -f "$app/lib/main.dart" ]; then
      echo "**Entry Point:** \`$app/lib/main.dart\` ($(wc -l < $app/lib/main.dart) lines)" >> $OUTPUT
      echo "" >> $OUTPUT
    fi
  else
    echo "### $app - ❌ NOT FOUND" >> $OUTPUT
    echo "" >> $OUTPUT
  fi
done

echo "## 🌐 WEB ADMIN INVENTORY" >> $OUTPUT
echo "" >> $OUTPUT

if [ -d "apps/web-admin" ]; then
  echo "**Type:** $(if [ -f "apps/web-admin/package.json" ]; then echo "Node.js/JavaScript"; elif [ -f "apps/web-admin/next.config.js" ]; then echo "Next.js"; else echo "Static HTML"; fi)" >> $OUTPUT
  echo "**Files:** $(find apps/web-admin -type f -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.html" | wc -l)" >> $OUTPUT
  echo "**Total LOC:** $(find apps/web-admin -type f -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')" >> $OUTPUT
  echo "" >> $OUTPUT
  
  if [ -f "apps/web-admin/package.json" ]; then
    echo "**package.json exists:** ✅" >> $OUTPUT
    echo '```json' >> $OUTPUT
    cat apps/web-admin/package.json | jq '.dependencies' 2>/dev/null || echo "No dependencies found" >> $OUTPUT
    echo '```' >> $OUTPUT
    echo "" >> $OUTPUT
  fi
else
  echo "❌ apps/web-admin NOT FOUND" >> $OUTPUT
  echo "" >> $OUTPUT
fi

echo "## 🔥 BACKEND INVENTORY" >> $OUTPUT
echo "" >> $OUTPUT

echo "### Firebase Functions" >> $OUTPUT
if [ -d "backend/firebase-functions" ]; then
  echo "**Status:** ✅ EXISTS" >> $OUTPUT
  echo "**TypeScript Files:** $(find backend/firebase-functions/src -name "*.ts" 2>/dev/null | wc -l)" >> $OUTPUT
  echo "**Total LOC:** $(find backend/firebase-functions/src -name "*.ts" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')" >> $OUTPUT
  echo "" >> $OUTPUT
  
  echo "**Source Files:**" >> $OUTPUT
  echo '```' >> $OUTPUT
  find backend/firebase-functions/src -name "*.ts" -type f 2>/dev/null | sort >> $OUTPUT
  echo '```' >> $OUTPUT
  echo "" >> $OUTPUT
  
  if [ -f "backend/firebase-functions/package.json" ]; then
    echo "**Node Version:** $(grep '"node"' backend/firebase-functions/package.json)" >> $OUTPUT
    echo "" >> $OUTPUT
  fi
else
  echo "**Status:** ❌ NOT FOUND" >> $OUTPUT
  echo "" >> $OUTPUT
fi

echo "### REST API" >> $OUTPUT
if [ -d "backend/rest-api" ]; then
  echo "**Status:** ✅ EXISTS" >> $OUTPUT
  echo "**TypeScript Files:** $(find backend/rest-api/src -name "*.ts" 2>/dev/null | wc -l)" >> $OUTPUT
  echo "**Total LOC:** $(find backend/rest-api/src -name "*.ts" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')" >> $OUTPUT
  echo "" >> $OUTPUT
  
  echo "**Source Files:**" >> $OUTPUT
  echo '```' >> $OUTPUT
  find backend/rest-api/src -name "*.ts" -type f 2>/dev/null | sort >> $OUTPUT
  echo '```' >> $OUTPUT
  echo "" >> $OUTPUT
else
  echo "**Status:** ❌ NOT FOUND" >> $OUTPUT
  echo "" >> $OUTPUT
fi

echo "## 🏗️ INFRASTRUCTURE" >> $OUTPUT
echo "" >> $OUTPUT

echo "**Firebase Configuration:**" >> $OUTPUT
[ -f "infra/firebase.json" ] && echo "- ✅ infra/firebase.json" >> $OUTPUT || echo "- ❌ infra/firebase.json MISSING" >> $OUTPUT
[ -f "infra/.firebaserc" ] && echo "- ✅ infra/.firebaserc" >> $OUTPUT || echo "- ❌ infra/.firebaserc MISSING" >> $OUTPUT
[ -f "infra/firestore.rules" ] && echo "- ✅ infra/firestore.rules ($(wc -l < infra/firestore.rules) lines)" >> $OUTPUT || echo "- ❌ infra/firestore.rules MISSING" >> $OUTPUT
[ -f "infra/firestore.indexes.json" ] && echo "- ✅ infra/firestore.indexes.json" >> $OUTPUT || echo "- ❌ infra/firestore.indexes.json MISSING" >> $OUTPUT
echo "" >> $OUTPUT

echo "## 📜 DEPLOYMENT SCRIPTS" >> $OUTPUT
echo "" >> $OUTPUT
echo "**Found Scripts:**" >> $OUTPUT
echo '```' >> $OUTPUT
find scripts -type f -name "*.sh" 2>/dev/null | sort >> $OUTPUT
echo '```' >> $OUTPUT
echo "" >> $OUTPUT

echo "✅ INVENTORY.md generated successfully"
