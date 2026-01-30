#!/bin/bash
set -e

OUTPUT="ARTIFACTS/ENTRYPOINTS.md"
echo "# ENTRYPOINTS.md - Application Entry Points" > $OUTPUT
echo "" >> $OUTPUT
echo "**Generated:** $(date)" >> $OUTPUT
echo "" >> $OUTPUT

echo "## 📱 FLUTTER MOBILE APPS" >> $OUTPUT
echo "" >> $OUTPUT

for app in apps/mobile-customer apps/mobile-merchant apps/mobile-admin; do
  appname=$(basename $app)
  echo "### $appname" >> $OUTPUT
  echo "" >> $OUTPUT
  
  if [ -f "$app/lib/main.dart" ]; then
    echo "**Entry Point:** \`$app/lib/main.dart\`" >> $OUTPUT
    echo "" >> $OUTPUT
    echo "**Main Function:**" >> $OUTPUT
    echo '```dart' >> $OUTPUT
    grep -A 20 "^void main(" "$app/lib/main.dart" 2>/dev/null || echo "main() not found" >> $OUTPUT
    echo '```' >> $OUTPUT
    echo "" >> $OUTPUT
    
    echo "**Routing Analysis:**" >> $OUTPUT
    echo '```dart' >> $OUTPUT
    grep -n "routes\|onGenerateRoute\|Navigator.push" "$app/lib/main.dart" 2>/dev/null | head -10 || echo "No routing configuration found" >> $OUTPUT
    echo '```' >> $OUTPUT
    echo "" >> $OUTPUT
  else
    echo "❌ main.dart NOT FOUND" >> $OUTPUT
    echo "" >> $OUTPUT
  fi
done

echo "## 🌐 WEB ADMIN (Next.js)" >> $OUTPUT
echo "" >> $OUTPUT

if [ -d "apps/web-admin" ]; then
  echo "**Framework Detection:**" >> $OUTPUT
  if [ -f "apps/web-admin/next.config.js" ]; then
    echo "- ✅ Next.js detected (\`next.config.js\` exists)" >> $OUTPUT
  elif [ -f "apps/web-admin/package.json" ] && grep -q "next" "apps/web-admin/package.json"; then
    echo "- ✅ Next.js detected (package.json has 'next')" >> $OUTPUT
  else
    echo "- ⚠️ Static HTML or unknown framework" >> $OUTPUT
  fi
  echo "" >> $OUTPUT
  
  echo "**Entry Points:**" >> $OUTPUT
  if [ -d "apps/web-admin/pages" ]; then
    echo "- Next.js Pages Directory: \`apps/web-admin/pages/\`" >> $OUTPUT
    echo '```' >> $OUTPUT
    find apps/web-admin/pages -name "*.js" -o -name "*.jsx" -o -name "*.tsx" 2>/dev/null | sort >> $OUTPUT
    echo '```' >> $OUTPUT
  elif [ -d "apps/web-admin/app" ]; then
    echo "- Next.js App Directory: \`apps/web-admin/app/\`" >> $OUTPUT
    echo '```' >> $OUTPUT
    find apps/web-admin/app -name "page.tsx" -o -name "page.jsx" 2>/dev/null | sort >> $OUTPUT
    echo '```' >> $OUTPUT
  elif [ -f "apps/web-admin/index.html" ]; then
    echo "- Static HTML Entry: \`apps/web-admin/index.html\`" >> $OUTPUT
  fi
  echo "" >> $OUTPUT
else
  echo "❌ apps/web-admin NOT FOUND" >> $OUTPUT
  echo "" >> $OUTPUT
fi

echo "## 🔥 BACKEND ENTRYPOINTS" >> $OUTPUT
echo "" >> $OUTPUT

echo "### Firebase Cloud Functions" >> $OUTPUT
if [ -f "backend/firebase-functions/src/index.ts" ]; then
  echo "**Entry:** \`backend/firebase-functions/src/index.ts\`" >> $OUTPUT
  echo "" >> $OUTPUT
  echo "**Exported Functions:**" >> $OUTPUT
  echo '```typescript' >> $OUTPUT
  grep "^export " backend/firebase-functions/src/index.ts 2>/dev/null || echo "No exports found" >> $OUTPUT
  echo '```' >> $OUTPUT
  echo "" >> $OUTPUT
else
  echo "❌ index.ts NOT FOUND" >> $OUTPUT
  echo "" >> $OUTPUT
fi

echo "### REST API" >> $OUTPUT
if [ -f "backend/rest-api/src/server.ts" ]; then
  echo "**Entry:** \`backend/rest-api/src/server.ts\`" >> $OUTPUT
  echo "" >> $OUTPUT
  echo "**Server Setup:**" >> $OUTPUT
  echo '```typescript' >> $OUTPUT
  head -30 backend/rest-api/src/server.ts 2>/dev/null || echo "Cannot read server.ts" >> $OUTPUT
  echo '```' >> $OUTPUT
  echo "" >> $OUTPUT
else
  echo "❌ server.ts NOT FOUND" >> $OUTPUT
  echo "" >> $OUTPUT
fi

echo "✅ ENTRYPOINTS.md generated"
