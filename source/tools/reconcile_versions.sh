#!/bin/bash
# Urban Points Lebanon - Version Reconciliation Script
# Discovers all variant roots and generates inventory

set -euo pipefail

CANONICAL_ROOT="/home/user/urbanpoints-lebanon-complete-ecosystem"
OUTPUT_JSON="${CANONICAL_ROOT}/ARTIFACTS/RECONCILIATION/variants_inventory.json"
OUTPUT_REPORT="${CANONICAL_ROOT}/ARTIFACTS/RECONCILIATION/RECONCILIATION_REPORT.md"

echo "=== Urban Points Version Reconciliation ==="
echo "Canonical root: ${CANONICAL_ROOT}"
echo "Scanning /home/user for variants..."

# Find all potential Urban Points variant directories
VARIANTS=$(find /home/user -maxdepth 1 -type d \( \
  -name "urban_points*" -o \
  -name "urban-points*" -o \
  -name "urbanpoints*" -o \
  -name "*lebanon*customer*" -o \
  -name "*lebanon*merchant*" -o \
  -name "*points*admin*" \
\) ! -path "${CANONICAL_ROOT}" 2>/dev/null | sort)

echo "Found variants:"
echo "$VARIANTS"

# Initialize JSON array
echo "{" > "${OUTPUT_JSON}"
echo '  "scan_timestamp": "'$(date -Iseconds)'",' >> "${OUTPUT_JSON}"
echo '  "canonical_root": "'${CANONICAL_ROOT}'",' >> "${OUTPUT_JSON}"
echo '  "variants": [' >> "${OUTPUT_JSON}"

FIRST=true
for VARIANT in $VARIANTS; do
  # Skip if not a directory or doesn't exist
  [ ! -d "$VARIANT" ] && continue
  
  # Skip hidden directories and node_modules
  basename "$VARIANT" | grep -q "^\." && continue
  
  echo "Analyzing: $VARIANT"
  
  # Add comma separator for JSON array
  if [ "$FIRST" = false ]; then
    echo "    ," >> "${OUTPUT_JSON}"
  fi
  FIRST=false
  
  # Gather metadata
  LAST_MODIFIED=$(stat -c %y "$VARIANT" 2>/dev/null || echo "unknown")
  DART_COUNT=$(find "$VARIANT" -name "*.dart" -type f 2>/dev/null | wc -l)
  HAS_SHARED=$(grep -r "urban_points_shared" "$VARIANT" 2>/dev/null | wc -l)
  PROVIDER_COUNT=$(grep -r "class.*Provider" "$VARIANT" 2>/dev/null | grep -v node_modules | wc -l)
  
  # Auth heuristics
  PHONE_AUTH=$(find "$VARIANT" -name "*.dart" -type f -exec grep -l "phone.*auth\|otp.*verification" {} \; 2>/dev/null | wc -l)
  EMAIL_AUTH=$(find "$VARIANT" -name "*.dart" -type f -exec grep -l "email.*auth\|email.*password" {} \; 2>/dev/null | wc -l)
  
  # List screens (top 30)
  SCREENS=$(find "$VARIANT" -path "*/lib/screens/*.dart" -type f 2>/dev/null | head -30 | xargs -I {} basename {} | sort | paste -sd "," -)
  
  # List widgets (top 30)
  WIDGETS=$(find "$VARIANT" -path "*/lib/widgets/*.dart" -type f 2>/dev/null | head -30 | xargs -I {} basename {} | sort | paste -sd "," -)
  
  # Write JSON entry
  cat >> "${OUTPUT_JSON}" << EOF
    {
      "path": "$VARIANT",
      "last_modified": "$LAST_MODIFIED",
      "dart_file_count": $DART_COUNT,
      "has_urban_points_shared": $([ $HAS_SHARED -gt 0 ] && echo "true" || echo "false"),
      "shared_references": $HAS_SHARED,
      "provider_usage": $PROVIDER_COUNT,
      "auth_heuristic": {
        "phone_otp_files": $PHONE_AUTH,
        "email_password_files": $EMAIL_AUTH
      },
      "screens": [$(echo "$SCREENS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')],
      "widgets": [$(echo "$WIDGETS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')],
      "has_pubspec": $([ -f "$VARIANT/pubspec.yaml" ] && echo "true" || echo "false")
    }
EOF
done

# Close JSON
echo "" >> "${OUTPUT_JSON}"
echo "  ]" >> "${OUTPUT_JSON}"
echo "}" >> "${OUTPUT_JSON}"

echo ""
echo "✅ Inventory written to: ${OUTPUT_JSON}"
echo "✅ Variant count: $(echo "$VARIANTS" | wc -l)"
echo ""
echo "Next: Generate markdown report..."
