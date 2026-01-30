# GO/NO-GO Wrapper Gate - Evidence-only verification (PowerShell)
# Creates evidence bundle, runs best available inner gate, validates

$ErrorActionPreference = "Stop"

$REPO_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $REPO_ROOT

$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$RUN_ID = "GO_NO_GO_$TIMESTAMP"
$EVIDENCE_DIR = "local-ci/evidence/$RUN_ID"

Write-Host "======================================================================"
Write-Host "GO/NO-GO WRAPPER GATE"
Write-Host "======================================================================"
Write-Host "Run ID: $RUN_ID"
Write-Host "Evidence: $EVIDENCE_DIR"
Write-Host ""

# Create evidence structure
New-Item -ItemType Directory -Force -Path "$EVIDENCE_DIR/logs" | Out-Null

# Save environment snapshot
Write-Host "[1/6] Capturing environment..."
try {
    git rev-parse HEAD | Out-File -FilePath "$EVIDENCE_DIR/commit_hash.txt" -Encoding UTF8
} catch {
    "not-a-git-repo" | Out-File -FilePath "$EVIDENCE_DIR/commit_hash.txt" -Encoding UTF8
}

try {
    git status --porcelain | Out-File -FilePath "$EVIDENCE_DIR/git_status.txt" -Encoding UTF8
} catch {
    "not-a-git-repo" | Out-File -FilePath "$EVIDENCE_DIR/git_status.txt" -Encoding UTF8
}

@"
=== Node ===
$(try { node -v } catch { "node: not found" })

=== NPM ===
$(try { npm -v } catch { "npm: not found" })

=== Python ===
$(try { python3 --version } catch { python --version })

=== Java ===
$(try { java -version 2>&1 } catch { "java: not found" })
"@ | Out-File -FilePath "$EVIDENCE_DIR/ENV.txt" -Encoding UTF8

# Discover best inner gate
$INNER_GATE = ""
if (Test-Path "tools/gates/run_rc_strict_gate.sh") {
    $INNER_GATE = "tools/gates/run_rc_strict_gate.sh"
    Write-Host "[2/6] Using inner gate: run_rc_strict_gate.sh"
} elseif (Test-Path "tools/gates/run_rc_gate.sh") {
    $INNER_GATE = "tools/gates/run_rc_gate.sh"
    Write-Host "[2/6] Using inner gate: run_rc_gate.sh"
} elseif (Test-Path "tools/gates/run_mvp_smoke_gate.sh") {
    $INNER_GATE = "tools/gates/run_mvp_smoke_gate.sh"
    Write-Host "[2/6] Using inner gate: run_mvp_smoke_gate.sh"
} else {
    Write-Host "[2/6] No inner gate found - minimal smoke"
    $INNER_GATE = ""
}

# Run inner gate or fallback
Write-Host "[3/6] Running tests..."

if ($INNER_GATE -ne "") {
    try {
        bash $INNER_GATE *>&1 | Out-File -FilePath "$EVIDENCE_DIR/logs/INNER_GATE.log" -Encoding UTF8
    } catch {
        Write-Host "  Inner gate exited with error: $_"
    }
    
    # Find latest evidence folder
    $INNER_EVIDENCE = Get-ChildItem -Path "local-ci/evidence" -Directory | 
        Where-Object { $_.Name -match "^(RC_STRICT_|RC_)" } | 
        Sort-Object Name | 
        Select-Object -Last 1
    
    if ($INNER_EVIDENCE -and (Test-Path $INNER_EVIDENCE.FullName)) {
        Write-Host "[4/6] Copying evidence from: $($INNER_EVIDENCE.Name)"
        Copy-Item -Path "$($INNER_EVIDENCE.FullName)/*" -Destination "$EVIDENCE_DIR/" -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "[4/6] Warning: No inner evidence folder found"
    }
} else {
    # Minimal fallback
    @"
{
  "status": "FAIL",
  "timestamp": "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')",
  "tests": {"total": 0, "passed": 0, "failed": 0, "skipped": 0},
  "blocker": "No inner gate found"
}
"@ | Out-File -FilePath "$EVIDENCE_DIR/SUMMARY.json" -Encoding UTF8
    
    "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')] NO-GO: No inner gate" | Out-File -FilePath "$EVIDENCE_DIR/SMOKE_LOG.txt" -Encoding UTF8
}

# Ensure required files
Write-Host "[5/6] Validating evidence..."

if (-not (Test-Path "$EVIDENCE_DIR/SUMMARY.json")) {
    @"
{
  "status": "FAIL",
  "timestamp": "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')",
  "tests": {"total": 0, "passed": 0, "failed": 0, "skipped": 0},
  "error": "SUMMARY.json not created"
}
"@ | Out-File -FilePath "$EVIDENCE_DIR/SUMMARY.json" -Encoding UTF8
}

if (-not (Test-Path "$EVIDENCE_DIR/SMOKE_LOG.txt")) {
    New-Item -ItemType File -Path "$EVIDENCE_DIR/SMOKE_LOG.txt" -Force | Out-Null
}

# Run validator
Write-Host "[6/6] Running validator..."
$VALIDATOR_EXIT = 0
try {
    python3 tools/validate/go_no_go_validator.py --evidence $EVIDENCE_DIR
} catch {
    $VALIDATOR_EXIT = 1
}

Write-Host ""
Write-Host "======================================================================"
if ($VALIDATOR_EXIT -eq 0) {
    Write-Host "GO/NO-GO VERDICT: GO ✅"
} else {
    Write-Host "GO/NO-GO VERDICT: NO-GO ❌"
}
Write-Host "======================================================================"
Write-Host "Evidence: $EVIDENCE_DIR"
Write-Host ""

if (Test-Path "$EVIDENCE_DIR/VALIDATION.json") {
    Get-Content "$EVIDENCE_DIR/VALIDATION.json"
}

exit $VALIDATOR_EXIT
