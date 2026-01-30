# MVP Smoke Gate - PowerShell Version
# End-to-end callable tests on Firebase emulators

$ErrorActionPreference = "Stop"

$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$EVIDENCE_DIR = "local-ci/evidence/MVP_SMOKE_$TIMESTAMP"

Write-Host "======================================================================"
Write-Host "MVP SMOKE GATE - Firebase Emulator E2E Tests"
Write-Host "======================================================================"
Write-Host "Timestamp: $TIMESTAMP"
Write-Host "Evidence: $EVIDENCE_DIR"
Write-Host ""

# Create evidence directory
New-Item -ItemType Directory -Force -Path "$EVIDENCE_DIR/logs" | Out-Null

# Step 1: Capture git state
Write-Host "[1/5] Capturing git state..."
git rev-parse HEAD | Out-File -FilePath "$EVIDENCE_DIR/commit_hash.txt" -Encoding UTF8
git status --porcelain | Out-File -FilePath "$EVIDENCE_DIR/git_status.txt" -Encoding UTF8

# Step 2: Build functions
Write-Host "[2/5] Building functions..."
Push-Location source/backend/firebase-functions
npm ci 2>&1 | Tee-Object -FilePath "../../../$EVIDENCE_DIR/logs/npm_install_functions.log"
npm run build 2>&1 | Tee-Object -FilePath "../../../$EVIDENCE_DIR/logs/build.log"
Pop-Location

# Step 3: Install smoke dependencies
Write-Host "[3/5] Installing smoke dependencies..."
Push-Location tools/smoke
npm install 2>&1 | Tee-Object -FilePath "../../$EVIDENCE_DIR/logs/npm_install_smoke.log"
Pop-Location

# Step 4: Run emulators with smoke script
Write-Host "[4/5] Running emulators with MVP smoke tests..."
Write-Host "  This will start emulators, run tests, and shut down automatically..."

Push-Location tools/smoke
$SMOKE_EXIT = 0
try {
  npx firebase emulators:exec `
    --project demo-mvp `
    --only auth,firestore,functions `
    "node mvp_smoke.mjs --evidence ../../$EVIDENCE_DIR" `
    2>&1 | Tee-Object -FilePath "../../$EVIDENCE_DIR/logs/EMULATORS_EXEC.log"
} catch {
  $SMOKE_EXIT = $LASTEXITCODE
}
Pop-Location

# Step 5: Determine verdict
Write-Host "[5/5] Determining gate verdict..."

if (Test-Path "$EVIDENCE_DIR/SUMMARY.json") {
  $summaryContent = Get-Content "$EVIDENCE_DIR/SUMMARY.json" -Raw | ConvertFrom-Json
  $STATUS = $summaryContent.status
  
  if (($STATUS -eq "PASS") -and ($SMOKE_EXIT -eq 0)) {
    Write-Host ""
    Write-Host "======================================================================"
    Write-Host "MVP SMOKE GATE: GO ✅"
    Write-Host "======================================================================"
    Write-Host "Evidence: $EVIDENCE_DIR"
    Write-Host ""
    Write-Host "Summary:"
    Get-Content "$EVIDENCE_DIR/SUMMARY.json"
    Write-Host ""
    exit 0
  }
}

Write-Host ""
Write-Host "======================================================================"
Write-Host "MVP SMOKE GATE: NO-GO ❌"
Write-Host "======================================================================"
Write-Host "Evidence: $EVIDENCE_DIR"
Write-Host "Smoke exit code: $SMOKE_EXIT"
Write-Host ""
if (Test-Path "$EVIDENCE_DIR/SUMMARY.json") {
  Write-Host "Summary:"
  Get-Content "$EVIDENCE_DIR/SUMMARY.json"
} else {
  Write-Host "SUMMARY.json not found - smoke script failed to complete"
}
Write-Host ""
Write-Host "Check logs:"
Write-Host "  - $EVIDENCE_DIR/logs/EMULATORS_EXEC.log"
Write-Host "  - $EVIDENCE_DIR/SMOKE_LOG.txt"
Write-Host ""
exit 1
