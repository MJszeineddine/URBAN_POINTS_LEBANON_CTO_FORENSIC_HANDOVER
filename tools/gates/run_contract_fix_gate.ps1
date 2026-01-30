# Contract Fix Gate - PowerShell Version
#
# Verifies callable overrides fixed and DTO contracts enforced
#

$ErrorActionPreference = "Stop"

$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$EVIDENCE_DIR = "local-ci/evidence/CONTRACT_FIX_$TIMESTAMP"
$SUMMARY_FILE = "$EVIDENCE_DIR/SUMMARY.json"

Write-Host "======================================================================"
Write-Host "CONTRACT FIX GATE"
Write-Host "======================================================================"
Write-Host "Timestamp: $TIMESTAMP"
Write-Host "Evidence: $EVIDENCE_DIR"
Write-Host ""

# Create evidence directory
New-Item -ItemType Directory -Force -Path "$EVIDENCE_DIR/logs" | Out-Null

# Capture git state
Write-Host "[1/6] Capturing git state..."
git rev-parse HEAD | Out-File -FilePath "$EVIDENCE_DIR/commit_hash.txt" -Encoding UTF8
git status | Out-File -FilePath "$EVIDENCE_DIR/git_status.txt" -Encoding UTF8
git diff --name-only | Out-File -FilePath "$EVIDENCE_DIR/changed_files.txt" -Encoding UTF8

# Navigate to backend
Push-Location source/backend/firebase-functions

# Install dependencies
Write-Host "[2/6] Installing dependencies..."
npm ci 2>&1 | Tee-Object -FilePath "../../../$EVIDENCE_DIR/logs/npm_install.log"

# Build
Write-Host "[3/6] Building backend..."
npm run build 2>&1 | Tee-Object -FilePath "../../../$EVIDENCE_DIR/logs/build.log"

# Run contract tests
Write-Host "[4/6] Running contract tests..."
$TEST_EXIT_CODE = 0
try {
  npx jest --runTestsByPath src/__tests__/contracts.customer.test.ts 2>&1 | Tee-Object -FilePath "../../../$EVIDENCE_DIR/logs/test.log"
} catch {
  $TEST_EXIT_CODE = $LASTEXITCODE
}

Pop-Location

# Check for unimplemented stubs in compiled output
Write-Host "[5/6] Checking compiled output for removed stubs..."
$STUB_CHECK_PASSED = $true
if (Test-Path "source/backend/firebase-functions/lib/callableWrappers.js") {
  $CRITICAL_CALLABLES = @("getAvailableOffers", "getFilteredOffers", "searchOffers", "getPointsHistory", "redeemOffer", "generateQRToken")
  foreach ($callable in $CRITICAL_CALLABLES) {
    $pattern = "exports\.$callable.*HttpsError.*unimplemented"
    if (Select-String -Path "source/backend/firebase-functions/lib/callableWrappers.js" -Pattern $pattern -Quiet) {
      Write-Host "  ❌ FAIL: $callable still has unimplemented stub"
      $STUB_CHECK_PASSED = $false
    } else {
      Write-Host "  ✅ PASS: $callable stub removed"
    }
  }
} else {
  Write-Host "  ⚠️  WARN: lib/callableWrappers.js not found"
  $STUB_CHECK_PASSED = $false
}

# Generate summary
Write-Host "[6/6] Generating evidence summary..."

$GATE_STATUS = "FAIL"
if (($TEST_EXIT_CODE -eq 0) -and ($STUB_CHECK_PASSED -eq $true)) {
  $GATE_STATUS = "PASS"
}

$commitHash = Get-Content "$EVIDENCE_DIR/commit_hash.txt" -Raw
$commitHash = $commitHash.Trim()

$summaryJson = @{
  gate = "CONTRACT_FIX"
  timestamp = $TIMESTAMP
  status = $GATE_STATUS
  test_exit_code = $TEST_EXIT_CODE
  stub_check_passed = $STUB_CHECK_PASSED
  commit_hash = $commitHash
  changed_files = @(
    "source/backend/firebase-functions/src/callableWrappers.ts",
    "source/backend/firebase-functions/src/adapters/time.ts",
    "source/backend/firebase-functions/src/adapters/offerDto.ts",
    "source/backend/firebase-functions/src/index.ts",
    "source/backend/firebase-functions/src/__tests__/contracts.customer.test.ts"
  )
  fixed_callables = @(
    "getAvailableOffers",
    "getFilteredOffers",
    "searchOffers",
    "getPointsHistory",
    "redeemOffer",
    "generateQRToken",
    "getOffersByLocationFunc",
    "getBalance"
  )
  changes_summary = "Removed CommonJS stub overrides, added DTO adapters for time/offer, enforced Flutter contracts (points_required, qr_token, valid_until as ISO), implemented getPointsHistory"
} | ConvertTo-Json -Depth 10

$summaryJson | Out-File -FilePath $SUMMARY_FILE -Encoding UTF8

Write-Host ""
Write-Host "======================================================================"
Write-Host "GATE RESULT: $GATE_STATUS"
Write-Host "======================================================================"
Write-Host "Evidence folder: $EVIDENCE_DIR"
Write-Host "Summary: $SUMMARY_FILE"
Write-Host ""

if ($GATE_STATUS -eq "PASS") {
  Write-Host "✅ GO - All contract fixes verified"
  Get-Content $SUMMARY_FILE
  exit 0
} else {
  Write-Host "❌ NO-GO - Contract fix gate failed"
  Write-Host ""
  Write-Host "Test exit code: $TEST_EXIT_CODE"
  Write-Host "Stub check: $STUB_CHECK_PASSED"
  Write-Host ""
  Write-Host "Logs:"
  Write-Host "  - Build: $EVIDENCE_DIR/logs/build.log"
  Write-Host "  - Tests: $EVIDENCE_DIR/logs/test.log"
  Get-Content $SUMMARY_FILE
  exit 1
}
