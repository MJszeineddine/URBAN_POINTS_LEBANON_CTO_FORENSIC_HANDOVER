#!/usr/bin/env bash
# FEATURE_COMPLETENESS_GATE - Verify real implementation completeness
# Checks for missing features, stubs, TODOs, and broken implementations
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/feature_completeness/${TS}"
mkdir -p "${EVIDENCE_DIR}"

LOG="${EVIDENCE_DIR}/scan.log"
FINDINGS_JSON="${EVIDENCE_DIR}/findings.json"

exec > >(tee -a "${LOG}") 2>&1

echo "FEATURE_COMPLETENESS_GATE - Started"
echo "Timestamp: ${TS}"
echo "Repository: ${REPO_ROOT}"
echo ""

# Initialize findings
BLOCKERS=()
WARNINGS=()

# ============================================================================
# CHECK A: Backend Build & Compilation
# ============================================================================
echo "▶ CHECK A: Backend Build & Compilation"
BACKEND_DIR="${REPO_ROOT}/source/backend/firebase-functions"

if [ -d "${BACKEND_DIR}" ]; then
  cd "${BACKEND_DIR}"
  
  # Check if package.json exists
  if [ -f "package.json" ]; then
    echo "  Found package.json, checking for build script..."
    
    # Try to compile TypeScript
    if grep -q '"build"' package.json; then
      echo "  Running npm run build..."
      if npm run build > "${EVIDENCE_DIR}/backend_build.log" 2>&1; then
        echo "  ✅ Backend build successful"
      else
        echo "  ❌ Backend build failed"
        BLOCKERS+=("BACKEND_BUILD_FAILED:${BACKEND_DIR}:See backend_build.log")
      fi
    else
      # Try tsc directly
      if command -v npx >/dev/null 2>&1; then
        echo "  Running tsc..."
        if npx tsc --noEmit > "${EVIDENCE_DIR}/backend_tsc.log" 2>&1; then
          echo "  ✅ TypeScript compilation successful"
        else
          echo "  ❌ TypeScript compilation failed"
          BLOCKERS+=("BACKEND_TSC_FAILED:${BACKEND_DIR}:See backend_tsc.log")
        fi
      fi
    fi
  fi
fi

# ============================================================================
# CHECK B: API Surface - Placeholder/Stub Detection
# ============================================================================
echo ""
echo "▶ CHECK B: API Surface - Stub/Placeholder Detection"

STUB_PATTERNS=(
  "TODO"
  "FIXME"
  "throw.*not implemented"
  "throw.*Not implemented"
  "return.*dummy"
  "return.*placeholder"
  "PLACEHOLDER.*return"
)

STUB_FILES=()
for pattern in "${STUB_PATTERNS[@]}"; do
  while IFS= read -r match; do
    if [[ -n "$match" ]]; then
      STUB_FILES+=("$match")
    fi
  done < <(grep -rn -E "${pattern}" "${REPO_ROOT}/source/backend" \
    --include="*.ts" --include="*.js" \
    --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
    2>/dev/null | head -50 || true)
done

if [ ${#STUB_FILES[@]} -gt 0 ]; then
  echo "  ❌ Found stub/placeholder implementations:"
  printf '  %s\n' "${STUB_FILES[@]}" | head -20
  BLOCKERS+=("API_STUBS_FOUND:${#STUB_FILES[@]}_occurrences:See scan.log")
else
  echo "  ✅ No obvious stubs/placeholders found in backend"
fi

# ============================================================================
# CHECK C: Frontend Web-Admin Build
# ============================================================================
echo ""
echo "▶ CHECK C: Frontend Web-Admin Build"
WEB_ADMIN_DIR="${REPO_ROOT}/source/apps/web-admin"

if [ -d "${WEB_ADMIN_DIR}" ]; then
  cd "${WEB_ADMIN_DIR}"
  
  if [ -f "package.json" ]; then
    echo "  Found web-admin package.json"
    
    # Detect package manager
    if [ -f "pnpm-lock.yaml" ]; then
      PKG_MGR="pnpm"
    elif [ -f "yarn.lock" ]; then
      PKG_MGR="yarn"
    else
      PKG_MGR="npm"
    fi
    
    echo "  Using package manager: ${PKG_MGR}"
    
    # Check for build script
    if grep -q '"build"' package.json; then
      echo "  Running ${PKG_MGR} run build..."
      if ${PKG_MGR} run build > "${EVIDENCE_DIR}/web_admin_build.log" 2>&1; then
        echo "  ✅ Web-admin build successful"
      else
        echo "  ❌ Web-admin build failed"
        BLOCKERS+=("WEB_ADMIN_BUILD_FAILED:${WEB_ADMIN_DIR}:See web_admin_build.log")
      fi
    else
      WARNINGS+=("WEB_ADMIN_NO_BUILD_SCRIPT:${WEB_ADMIN_DIR}")
      echo "  ⚠️  No build script found"
    fi
  fi
fi

# ============================================================================
# CHECK D: Flutter Apps - Analyze & Test
# ============================================================================
echo ""
echo "▶ CHECK D: Flutter Apps - Analyze & Test"

for APP_NAME in "mobile-customer" "mobile-merchant" "mobile-admin"; do
  APP_DIR="${REPO_ROOT}/source/apps/${APP_NAME}"
  
  if [ -d "${APP_DIR}" ] && [ -f "${APP_DIR}/pubspec.yaml" ]; then
    echo "  Checking ${APP_NAME}..."
    cd "${APP_DIR}"
    
    # Flutter analyze
    echo "    Running flutter analyze..."
    if flutter analyze > "${EVIDENCE_DIR}/${APP_NAME}_analyze.log" 2>&1; then
      echo "    ✅ Flutter analyze passed"
    else
      # Check if it's just warnings or actual errors
      if grep -q "error •" "${EVIDENCE_DIR}/${APP_NAME}_analyze.log"; then
        echo "    ❌ Flutter analyze found errors"
        BLOCKERS+=("FLUTTER_ANALYZE_ERRORS:${APP_NAME}:See ${APP_NAME}_analyze.log")
      else
        echo "    ⚠️  Flutter analyze has warnings"
        WARNINGS+=("FLUTTER_ANALYZE_WARNINGS:${APP_NAME}")
      fi
    fi
    
    # Flutter test
    echo "    Running flutter test..."
    if flutter test --machine > "${EVIDENCE_DIR}/${APP_NAME}_test.log" 2>&1; then
      echo "    ✅ Flutter tests passed"
    else
      echo "    ❌ Flutter tests failed"
      BLOCKERS+=("FLUTTER_TESTS_FAILED:${APP_NAME}:See ${APP_NAME}_test.log")
    fi
  fi
done

# ============================================================================
# CHECK E: Broken Imports / Missing Files
# ============================================================================
echo ""
echo "▶ CHECK E: Broken Imports / Missing Files"

# Check TypeScript/JavaScript imports
echo "  Scanning TypeScript/JavaScript imports..."
BROKEN_IMPORTS=()

while IFS= read -r file; do
  while IFS= read -r line; do
    # Extract import path
    import_path=$(echo "$line" | sed -E "s/.*from ['\"]([^'\"]+)['\"].*/\1/")
    
    # Skip node_modules and absolute paths
    if [[ "$import_path" =~ ^(@|[a-z]) ]] || [[ "$import_path" == "node_modules"* ]]; then
      continue
    fi
    
    # Resolve relative path
    file_dir=$(dirname "$file")
    if [[ "$import_path" == ./* ]] || [[ "$import_path" == ../* ]]; then
      resolved="${file_dir}/${import_path}"
      
      # Check if file exists (with common extensions)
      if [ ! -f "${resolved}.ts" ] && [ ! -f "${resolved}.js" ] && \
         [ ! -f "${resolved}/index.ts" ] && [ ! -f "${resolved}/index.js" ]; then
        BROKEN_IMPORTS+=("${file}:import_not_found:${import_path}")
      fi
    fi
  done < <(grep -E "^import .* from ['\"]" "$file" 2>/dev/null || true)
done < <(find "${REPO_ROOT}/source" -name "*.ts" -o -name "*.js" \
  | grep -v node_modules | grep -v dist | grep -v build | head -100)

if [ ${#BROKEN_IMPORTS[@]} -gt 0 ]; then
  echo "  ❌ Found broken imports:"
  printf '  %s\n' "${BROKEN_IMPORTS[@]}" | head -10
  BLOCKERS+=("BROKEN_IMPORTS_FOUND:${#BROKEN_IMPORTS[@]}_occurrences")
else
  echo "  ✅ No obvious broken imports detected"
fi

# ============================================================================
# CHECK F: Config Sanity - No PLACEHOLDER in Live Code
# ============================================================================
echo ""
echo "▶ CHECK F: Config Sanity - PLACEHOLDER Usage"

# Find PLACEHOLDER usage outside of .env files
PLACEHOLDER_IN_CODE=()
while IFS= read -r match; do
  if [[ -n "$match" ]]; then
    PLACEHOLDER_IN_CODE+=("$match")
  fi
done < <(grep -rn "PLACEHOLDER" "${REPO_ROOT}/source" \
  --include="*.ts" --include="*.js" --include="*.dart" \
  --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
  2>/dev/null | grep -v "\.env" | head -20 || true)

if [ ${#PLACEHOLDER_IN_CODE[@]} -gt 0 ]; then
  echo "  ❌ Found PLACEHOLDER in source code:"
  printf '  %s\n' "${PLACEHOLDER_IN_CODE[@]}"
  WARNINGS+=("PLACEHOLDER_IN_CODE:${#PLACEHOLDER_IN_CODE[@]}_occurrences")
else
  echo "  ✅ No PLACEHOLDER found in source code"
fi

# ============================================================================
# Generate Findings JSON
# ============================================================================
{
  echo "{"
  echo "  \"scan_timestamp\": \"${TS}\","
  echo "  \"blockers\": ["
  for i in "${!BLOCKERS[@]}"; do
    [ $i -gt 0 ] && echo ","
    echo -n "    \"${BLOCKERS[$i]}\""
  done
  echo ""
  echo "  ],"
  echo "  \"warnings\": ["
  for i in "${!WARNINGS[@]}"; do
    [ $i -gt 0 ] && echo ","
    echo -n "    \"${WARNINGS[$i]}\""
  done
  echo ""
  echo "  ],"
  echo "  \"blocker_count\": ${#BLOCKERS[@]},"
  echo "  \"warning_count\": ${#WARNINGS[@]}"
  echo "}"
} > "${FINDINGS_JSON}"

# ============================================================================
# Generate Verdict
# ============================================================================
echo ""
echo "▶ FINAL VERDICT"
echo "  Blockers: ${#BLOCKERS[@]}"
echo "  Warnings: ${#WARNINGS[@]}"

if [ ${#BLOCKERS[@]} -eq 0 ]; then
  {
    echo "# FEATURE_COMPLETENESS_GATE Verdict"
    echo ""
    echo "**VERDICT: GO ✅**"
    echo ""
    echo "## Feature Completeness Verified"
    echo ""
    echo "All implementation checks passed:"
    echo ""
    echo "- ✅ Backend compiles successfully"
    echo "- ✅ No stub/placeholder implementations detected"
    echo "- ✅ Frontend builds successfully"
    echo "- ✅ Flutter apps analyze and test successfully"
    echo "- ✅ No broken imports detected"
    echo "- ✅ Config sanity verified"
    echo ""
    if [ ${#WARNINGS[@]} -gt 0 ]; then
      echo "## Warnings (Non-Blocking)"
      echo ""
      for warning in "${WARNINGS[@]}"; do
        echo "- ⚠️  ${warning}"
      done
      echo ""
    fi
    echo "**Status:** Feature implementation complete and verified."
  } > "${EVIDENCE_DIR}/VERDICT.md"
  
  echo "✅ FEATURE COMPLETENESS VERIFIED"
  EXIT_CODE=0
else
  {
    echo "# FEATURE_COMPLETENESS_GATE Verdict"
    echo ""
    echo "**VERDICT: NO_GO ❌**"
    echo ""
    echo "## Feature Completeness Issues Detected"
    echo ""
    echo "The following blockers prevent release:"
    echo ""
    for blocker in "${BLOCKERS[@]}"; do
      echo "- ❌ ${blocker}"
    done
    echo ""
    if [ ${#WARNINGS[@]} -gt 0 ]; then
      echo "## Additional Warnings"
      echo ""
      for warning in "${WARNINGS[@]}"; do
        echo "- ⚠️  ${warning}"
      done
      echo ""
    fi
    echo "## Remediation Required"
    echo ""
    echo "See scan.log and findings.json for detailed information."
    echo "Fix all blockers before proceeding with release."
  } > "${EVIDENCE_DIR}/NO_GO_FEATURE_COMPLETENESS.md"
  
  echo "❌ FEATURE COMPLETENESS ISSUES FOUND"
  EXIT_CODE=1
fi

# Generate SHA256SUMS
cd "${EVIDENCE_DIR}"
find . -type f ! -name SHA256SUMS.txt -exec shasum -a 256 {} \; | sort > SHA256SUMS.txt

echo ""
echo "Evidence: ${EVIDENCE_DIR}"
echo "Files: $(ls -1 ${EVIDENCE_DIR} | tr '\n' ' ')"

exit ${EXIT_CODE}
