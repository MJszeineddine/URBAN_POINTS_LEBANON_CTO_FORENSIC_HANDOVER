# RC Gate - Release Candidate pipeline with zero skips (PowerShell)

$ErrorActionPreference = "Stop"

$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$EVIDENCE_DIR = "local-ci/evidence/RC_$TIMESTAMP"

Write-Host "======================================================================"
Write-Host "RC GATE - Release Candidate Pipeline"
Write-Host "======================================================================"
Write-Host "Timestamp: $TIMESTAMP"
Write-Host "Evidence: $EVIDENCE_DIR"
Write-Host ""

# A) Create evidence directory structure
Write-Host "[1/7] Creating evidence directory..."
New-Item -ItemType Directory -Force -Path "$EVIDENCE_DIR/logs/backend" | Out-Null
New-Item -ItemType Directory -Force -Path "$EVIDENCE_DIR/logs/emulators" | Out-Null
New-Item -ItemType Directory -Force -Path "$EVIDENCE_DIR/logs/smoke" | Out-Null

# B) Git snapshot
Write-Host "[2/7] Capturing git snapshot..."
git rev-parse HEAD | Out-File -FilePath "$EVIDENCE_DIR/commit_hash.txt" -Encoding UTF8
git status --porcelain | Out-File -FilePath "$EVIDENCE_DIR/git_status.txt" -Encoding UTF8
git branch --show-current | Out-File -FilePath "$EVIDENCE_DIR/branch.txt" -Encoding UTF8

# C) Backend build
Write-Host "[3/7] Building backend..."
Push-Location source/backend/firebase-functions
npm ci 2>&1 | Tee-Object -FilePath "../../../$EVIDENCE_DIR/logs/backend/npm_install.log"
$BACKEND_EXIT = $LASTEXITCODE
if ($BACKEND_EXIT -eq 0) {
  npm run build 2>&1 | Tee-Object -FilePath "../../../$EVIDENCE_DIR/logs/backend/build.log"
  $BACKEND_EXIT = $LASTEXITCODE
}
Pop-Location

if ($BACKEND_EXIT -ne 0) {
  Write-Host ""
  Write-Host "======================================================================"
  Write-Host "RC GATE: NO-GO ❌"
  Write-Host "======================================================================"
  Write-Host "Backend build failed (exit code: $BACKEND_EXIT)"
  Write-Host "Evidence: $EVIDENCE_DIR"
  Write-Host ""
  exit 1
}

# D) Smoke dependencies
Write-Host "[4/7] Installing smoke dependencies..."
Push-Location tools/smoke
npm ci 2>&1 | Tee-Object -FilePath "../../$EVIDENCE_DIR/logs/smoke/npm_install.log"
Pop-Location

# E) Run emulators with smoke tests
Write-Host "[5/7] Running Firebase emulators with RC smoke tests..."
Write-Host "  This will start emulators, run tests (NO SKIPS), and shut down automatically..."

$SMOKE_EXIT = 0
try {
  npx -y firebase-tools@latest emulators:exec `
    --project demo-mvp `
    --only auth,firestore,functions `
    "node tools/smoke/mvp_smoke.mjs --evidence $EVIDENCE_DIR" `
    2>&1 | Tee-Object -FilePath "$EVIDENCE_DIR/logs/emulators/EMULATORS_EXEC.log"
  $SMOKE_EXIT = $LASTEXITCODE
} catch {
  $SMOKE_EXIT = 1
}

# F) Final verdict
Write-Host "[6/7] Determining gate verdict..."

if (Test-Path "$EVIDENCE_DIR/SUMMARY.json") {
  $summaryContent = Get-Content "$EVIDENCE_DIR/SUMMARY.json" -Raw | ConvertFrom-Json
  $STATUS = $summaryContent.status
  $TOTAL = $summaryContent.tests.total
  $PASSED = $summaryContent.tests.passed
  $FAILED = $summaryContent.tests.failed
  
  if (($STATUS -eq "PASS") -and ($SMOKE_EXIT -eq 0) -and ($PASSED -eq $TOTAL)) {
    Write-Host ""
    Write-Host "======================================================================"
    Write-Host "RC GATE: GO ✅"
    Write-Host "======================================================================"
    Write-Host "Evidence: $EVIDENCE_DIR"
    Write-Host "Tests: $PASSED/$TOTAL PASS, $FAILED FAIL"
    Write-Host ""
    Write-Host "Summary:"
    Get-Content "$EVIDENCE_DIR/SUMMARY.json"
    Write-Host ""
    exit 0
  }
}

Write-Host ""
Write-Host "======================================================================"
Write-Host "RC GATE: NO-GO ❌"
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
Write-Host "  - $EVIDENCE_DIR/logs/emulators/EMULATORS_EXEC.log"
Write-Host "  - $EVIDENCE_DIR/SMOKE_LOG.txt"
Write-Host ""
exit 1
