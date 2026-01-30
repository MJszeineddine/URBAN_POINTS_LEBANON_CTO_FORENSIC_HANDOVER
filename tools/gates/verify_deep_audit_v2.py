#!/usr/bin/env python3
"""
Verification gate for deep audit v2.
Ensures 100% text file coverage and evidence-based claims.
"""
import json
from pathlib import Path
from datetime import datetime

BASE = Path("/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER")
V2 = BASE / "local-ci/verification/deep_audit_v2/LATEST"

def log(msg):
    print(f"[VERIFY-V2] {msg}", flush=True)

def main():
    log("="*70)
    log("DEEP AUDIT V2 VERIFICATION GATE")
    log("="*70)
    
    # Require FULL report with per-file data
    full_file = V2 / "derived/COMPREHENSIVE_AUDIT_REPORT_FULL.json"
    if not full_file.exists():
        log(f"ERROR: {full_file} does not exist!")
        blocker = V2 / "proof/BLOCKER_DEEP_AUDIT_V2_MISSING_FULL.md"
        with open(blocker, 'w') as f:
            f.write("# BLOCKER: Missing FULL report with per-file data\n\n")
            f.write(f"Required: {full_file}\n")
        log(f"Wrote blocker: {blocker}")
        return 2

    with open(full_file, 'r') as f:
        full = json.load(f)
    data = {
        'summary': full.get('summary', {})
    }
    
    summary = data['summary']
    
    log(f"Tracked total: {summary['tracked_total']}")
    log(f"Auditable text: {summary['auditable_text_total']}")
    log(f"Skipped binary: {summary['skipped_binary_total']}")
    log(f"Files audited: {summary['files_audited']}")
    log(f"Text coverage: {summary['audited_coverage_text_pct']:.2f}%")
    
    # Verify classification completeness
    total_classified = summary['auditable_text_total'] + summary['skipped_binary_total']
    if total_classified != summary['tracked_total']:
        log(f"ERROR: Classification mismatch!")
        log(f"  Auditable + Skipped = {total_classified}")
        log(f"  Tracked = {summary['tracked_total']}")
        log(f"  Missing: {summary['tracked_total'] - total_classified}")
        return 2
    
    log("✓ Classification complete (100% of tracked files)")
    
    # Verify FULL report files array integrity
    files = full.get('files', [])
    if not isinstance(files, list) or len(files) == 0:
        log("ERROR: FULL report has no per-file data")
        blocker = V2 / "proof/BLOCKER_DEEP_AUDIT_V2_EMPTY_FULL.md"
        with open(blocker, 'w') as f:
            f.write("# BLOCKER: FULL report missing per-file data\n")
        log(f"Wrote blocker: {blocker}")
        return 2

    unique_paths = {f.get('path') for f in files}
    if len(unique_paths) != len(files):
        log("ERROR: Duplicate file paths detected in FULL report")
        blocker = V2 / "proof/BLOCKER_DEEP_AUDIT_V2_DUPLICATE_PATHS.md"
        with open(blocker, 'w') as f:
            f.write("# BLOCKER: Duplicate file paths in FULL report\n")
            f.write(f"Total entries: {len(files)}\n")
            f.write(f"Unique paths: {len(unique_paths)}\n")
        log(f"Wrote blocker: {blocker}")
        return 2

    # Verify counts against auditable_text_total
    if len(files) != summary['auditable_text_total']:
        log("ERROR: FULL report file count != auditable_text_total")
        blocker = V2 / "proof/BLOCKER_DEEP_AUDIT_V2_COUNT_MISMATCH.md"
        with open(blocker, 'w') as f:
            f.write("# BLOCKER: FULL report count mismatch\n")
            f.write(f"FULL files: {len(files)}\n")
            f.write(f"Expected auditable_text_total: {summary['auditable_text_total']}\n")
        log(f"Wrote blocker: {blocker}")
        return 2

    # Verify text coverage using summary
    if summary['files_audited'] != summary['auditable_text_total']:
        missing = summary['auditable_text_total'] - summary['files_audited']
        log(f"ERROR: Text coverage incomplete!")
        log(f"  Audited: {summary['files_audited']}")
        log(f"  Expected: {summary['auditable_text_total']}")
        log(f"  Missing: {missing}")
        blocker = V2 / "proof/BLOCKER_DEEP_AUDIT_V2_COVERAGE.md"
        with open(blocker, 'w') as f:
            f.write("# BLOCKER: DEEP AUDIT V2 NOT 100% TEXT COVERAGE\n\n")
            f.write(f"**Missing Files:** {missing}\n")
            f.write(f"**Expected:** {summary['auditable_text_total']}\n")
            f.write(f"**Audited:** {summary['files_audited']}\n")
        log(f"Wrote blocker: {blocker}")
        return 2

    log(f"✓ FULL report integrity OK ({len(files)} files, unique paths)")
    log(f"✓ Text coverage 100% ({summary['files_audited']}/{summary['auditable_text_total']})")
    
    # Verify per-file output exists
    batch_files = list((V2 / "reports").glob("batch*.json"))
    total_files_in_batches = 0
    
    for batch_file in batch_files:
        with open(batch_file, 'r') as f:
            batch_data = json.load(f)
        total_files_in_batches += batch_data['summary']['files_audited']
    
    if total_files_in_batches != summary['files_audited']:
        log(f"ERROR: Batch file mismatch!")
        log(f"  Batches total: {total_files_in_batches}")
        log(f"  Summary total: {summary['files_audited']}")
        return 2
    
    log(f"✓ Batch reports consistent ({len(batch_files)} batches)")
    
    # Verify required outputs exist
    required_files = [
        V2 / "reports/EXEC_SUMMARY.md",
        V2 / "derived/COMPREHENSIVE_AUDIT_REPORT.json",
        V2 / "derived/COMPREHENSIVE_AUDIT_REPORT_FULL.json",
        V2 / "derived/auditable_text_files.txt",
        V2 / "derived/skipped_binary_files.txt"
    ]
    
    missing_outputs = []
    for required in required_files:
        if not required.exists():
            missing_outputs.append(str(required))
    
    if missing_outputs:
        log(f"ERROR: Missing required outputs:")
        for path in missing_outputs:
            log(f"  - {path}")
        return 2
    
    log(f"✓ All required outputs exist")
    
    # All checks passed
    log("="*70)
    log("✅ GATE PASS - 100% TEXT COVERAGE VERIFIED")
    log("="*70)
    log(f"Summary:")
    log(f"  - Tracked files: {summary['tracked_total']}")
    log(f"  - Text files: {summary['auditable_text_total']} (100% audited)")
    log(f"  - Binary files: {summary['skipped_binary_total']} (explicitly skipped)")
    log(f"  - Total issues: {summary['total_issues']:,}")
    log(f"  - Security: {summary['security_issues']:,}")
    log(f"  - Quality: {summary['quality_issues']:,}")
    
    # Write success proof
    ok_file = V2 / "proof/OK_DEEP_AUDIT_V2_100_PERCENT.md"
    with open(ok_file, 'w') as f:
        f.write("# GATE PASS: DEEP AUDIT V2 - 100% TEXT COVERAGE\n\n")
        # Use timezone-aware UTC
        from datetime import datetime, timezone
        f.write(f"**Timestamp:** {datetime.now(timezone.utc).isoformat()}\n\n")
        f.write("## Verification Results\n\n")
        f.write(f"- **Tracked files:** {summary['tracked_total']}\n")
        f.write(f"- **Text files:** {summary['auditable_text_total']}\n")
        f.write(f"- **Files audited:** {summary['files_audited']}\n")
        f.write(f"- **Text coverage:** {summary['audited_coverage_text_pct']:.2f}%\n")
        f.write(f"- **Binary files skipped:** {summary['skipped_binary_total']}\n\n")
        f.write("## Gate Checks\n\n")
        f.write("✅ Classification complete (100% of tracked files)\n")
        f.write("✅ FULL report integrity (files count + unique paths)\n")
        f.write("✅ Text coverage 100%\n")
        f.write("✅ Batch reports consistent\n")
        f.write("✅ All required outputs exist\n\n")
        f.write("## Audit Summary\n\n")
        f.write(f"- Total issues: {summary['total_issues']:,}\n")
        f.write(f"- Security issues: {summary['security_issues']:,}\n")
        f.write(f"- Quality issues: {summary['quality_issues']:,}\n")
    
    log(f"Wrote success proof: {ok_file}")
    
    return 0

if __name__ == "__main__":
    try:
        exit_code = main()
        print(f"[VERIFY-V2] Exit code: {exit_code}")
        exit(exit_code)
    except Exception as e:
        print(f"[VERIFY-V2] FATAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        exit(1)
