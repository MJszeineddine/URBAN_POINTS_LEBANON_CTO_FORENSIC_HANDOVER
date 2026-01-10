#!/bin/bash

OUTPUT="ARTIFACTS/DATA_MAP.md"

echo "# DATA MAP — Firestore Collections + Rules + SQL (if any)" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "**Generated**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$OUTPUT"
echo "" >> "$OUTPUT"

cat >> "$OUTPUT" << 'EOF'

## Firestore Collections (from rules file)

| Collection | Read Rules | Write Rules | Delete Rules | Evidence |
|------------|-----------|-------------|--------------|----------|
EOF

# Extract all collection names from firestore.rules
if [ -f "infra/firestore.rules" ]; then
    grep "match /" infra/firestore.rules | grep -v "//" | sed 's/.*match \///;s/{.*//' | sort -u | while read -r collection; do
        read_rule=$(grep -A 5 "match /$collection/" infra/firestore.rules | grep "allow read" | head -1 || echo "NONE")
        write_rule=$(grep -A 5 "match /$collection/" infra/firestore.rules | grep "allow write\|allow create\|allow update" | head -1 || echo "NONE")
        delete_rule=$(grep -A 5 "match /$collection/" infra/firestore.rules | grep "allow delete" | head -1 || echo "NONE")
        
        echo "| $collection | $read_rule | $write_rule | $delete_rule | infra/firestore.rules |" >> "$OUTPUT"
    done
else
    echo "| UNKNOWN | NO RULES FILE | NO RULES FILE | NO RULES FILE | infra/firestore.rules NOT FOUND |" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'

## Firestore Indexes

EOF

if [ -f "infra/firestore.indexes.json" ]; then
    echo '```json' >> "$OUTPUT"
    cat infra/firestore.indexes.json >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
else
    echo "**NO INDEXES FILE FOUND** at infra/firestore.indexes.json" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'

## SQL / PostgreSQL / MySQL Usage

EOF

# Check for SQL usage in REST API
if rg -i "select |insert |update |delete |create table" backend/rest-api/ 2>/dev/null | grep -q .; then
    echo "**SQL DETECTED** in backend/rest-api/" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    rg -i "select |insert |update |delete " backend/rest-api/ -A 2 2>/dev/null | head -50 >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
else
    echo "**NO SQL USAGE DETECTED** (Firestore-only project)" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'

## Data Access Patterns

| Caller | Collection | Operation | Evidence |
|--------|------------|-----------|----------|
EOF

# Detect Firestore reads/writes in Flutter apps
for app in apps/mobile-customer apps/mobile-merchant apps/mobile-admin; do
    if [ -d "$app" ]; then
        app_name=$(basename "$app")
        rg "collection\(['\"](\w+)['\"]" "$app" -o -r '$1' 2>/dev/null | sort -u | while read -r coll; do
            echo "| $app_name | $coll | read/write | $app/lib/ (grep collection) |" >> "$OUTPUT"
        done || true
    fi
done

# Detect Firestore access in Web Admin
if [ -d "apps/web-admin" ]; then
    rg "collection\(['\"](\w+)['\"]" apps/web-admin -o -r '$1' 2>/dev/null | sort -u | while read -r coll; do
        echo "| web-admin | $coll | read/write | apps/web-admin/ (grep collection) |" >> "$OUTPUT"
    done || true
fi

echo "" >> "$OUTPUT"
echo "✅ DATA_MAP.md generated"
