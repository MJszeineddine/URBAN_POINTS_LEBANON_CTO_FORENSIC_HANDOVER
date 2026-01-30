#!/usr/bin/env python3
"""
MVP 5 Scenarios Validator - Evidence-only verification (stdlib only)
Validates that all 5 scenarios ran and none were skipped.
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime

def main():
    if '--evidence' not in sys.argv:
        print("Usage: mvp_5scenarios_validator.py --evidence <path>")
        sys.exit(2)
    
    evidence_idx = sys.argv.index('--evidence')
    evidence_path = Path(sys.argv[evidence_idx + 1])
    
    if not evidence_path.exists():
        print(f"Evidence path not found: {evidence_path}")
        sys.exit(2)
    
    print(f"[MVP 5 Scenarios Validator] Validating: {evidence_path}")
    
    validation = {
        "validator": "mvp_5scenarios_validator",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "verdict": "FAIL",
        "errors": [],
        "warnings": [],
        "criteria_checks": []
    }
    
    # Check required files
    required_files = ["SUMMARY.json", "RESULTS.json", "SMOKE_LOG.txt", "git_commit.txt", "git_status.txt"]
    missing_files = []
    
    for filename in required_files:
        file_path = evidence_path / filename
        if not file_path.exists():
            missing_files.append(filename)
            validation["errors"].append({
                "code": "MISSING_FILE",
                "message": f"Required file not found: {filename}",
                "file": filename
            })
    
    if missing_files:
        validation["criteria_checks"].append({
            "criterion": "required_files",
            "status": "FAIL",
            "details": f"Missing files: {', '.join(missing_files)}"
        })
        write_validation(evidence_path, validation)
        sys.exit(1)
    
    validation["criteria_checks"].append({
        "criterion": "required_files",
        "status": "PASS",
        "details": "All required files present"
    })
    
    # Validate SUMMARY.json
    summary_path = evidence_path / "SUMMARY.json"
    try:
        with open(summary_path, 'r') as f:
            summary = json.load(f)
        
        # Check status
        if summary.get("status") != "PASS":
            validation["errors"].append({
                "code": "SUMMARY_STATUS_FAIL",
                "message": f"SUMMARY.json status is {summary.get('status')}, expected PASS",
                "file": "SUMMARY.json"
            })
        
        # Check test counts
        tests = summary.get("tests", {})
        total = tests.get("total", 0)
        passed = tests.get("passed", 0)
        failed = tests.get("failed", 0)
        skipped = tests.get("skipped", 0)
        
        if total != 5:
            validation["errors"].append({
                "code": "INVALID_TEST_COUNT",
                "message": f"Expected 5 tests, got {total}",
                "file": "SUMMARY.json"
            })
        
        if failed > 0:
            validation["errors"].append({
                "code": "TESTS_FAILED",
                "message": f"{failed} scenario(s) failed",
                "file": "SUMMARY.json"
            })
        
        if skipped > 0:
            validation["errors"].append({
                "code": "TESTS_SKIPPED",
                "message": f"{skipped} scenario(s) skipped - ZERO TOLERANCE",
                "file": "SUMMARY.json"
            })
        
        if passed != 5:
            validation["errors"].append({
                "code": "NOT_ALL_PASSED",
                "message": f"Only {passed}/5 scenarios passed",
                "file": "SUMMARY.json"
            })
        
        if not validation["errors"]:
            validation["criteria_checks"].append({
                "criterion": "scenarios",
                "status": "PASS",
                "details": f"All 5 scenarios passed: {total} total, {passed} passed, {failed} failed, {skipped} skipped"
            })
        else:
            validation["criteria_checks"].append({
                "criterion": "scenarios",
                "status": "FAIL",
                "details": f"{total} total, {passed} passed, {failed} failed, {skipped} skipped"
            })
        
    except json.JSONDecodeError as e:
        validation["errors"].append({
            "code": "INVALID_SUMMARY_JSON",
            "message": f"Failed to parse SUMMARY.json: {e}",
            "file": "SUMMARY.json"
        })
        validation["criteria_checks"].append({
            "criterion": "scenarios",
            "status": "FAIL",
            "details": "Invalid SUMMARY.json"
        })
    except Exception as e:
        validation["errors"].append({
            "code": "SUMMARY_READ_ERROR",
            "message": f"Error reading SUMMARY.json: {e}",
            "file": "SUMMARY.json"
        })
        validation["criteria_checks"].append({
            "criterion": "scenarios",
            "status": "FAIL",
            "details": f"Error reading SUMMARY.json: {e}"
        })
    
    # Validate RESULTS.json has scenarios array
    results_path = evidence_path / "RESULTS.json"
    try:
        with open(results_path, 'r') as f:
            results = json.load(f)
        
        scenarios = results.get("scenarios", [])
        if len(scenarios) != 5:
            validation["warnings"].append({
                "code": "MISSING_SCENARIOS",
                "message": f"RESULTS.json has {len(scenarios)} scenarios, expected 5",
                "file": "RESULTS.json"
            })
        
        # Check for SKIP status
        skipped_scenarios = [s for s in scenarios if s.get("status") == "SKIP"]
        if skipped_scenarios:
            validation["errors"].append({
                "code": "SKIPPED_SCENARIOS",
                "message": f"Skipped scenarios: {[s.get('name') for s in skipped_scenarios]}",
                "file": "RESULTS.json"
            })
        
    except Exception as e:
        validation["warnings"].append({
            "code": "RESULTS_READ_ERROR",
            "message": f"Could not validate RESULTS.json: {e}",
            "file": "RESULTS.json"
        })
    
    # Check logs folder exists
    logs_path = evidence_path / "logs"
    if not logs_path.exists() or not logs_path.is_dir():
        validation["warnings"].append({
            "code": "MISSING_LOGS_FOLDER",
            "message": "logs/ folder not found",
            "file": None
        })
    
    # Final verdict
    if not validation["errors"]:
        validation["verdict"] = "PASS"
        print("[MVP 5 Scenarios Validator] Verdict: PASS ✅")
    else:
        validation["verdict"] = "FAIL"
        print("[MVP 5 Scenarios Validator] Verdict: FAIL ❌")
        print(f"  Errors: {len(validation['errors'])}")
        for err in validation["errors"]:
            print(f"    - {err['code']}: {err['message']}")
    
    write_validation(evidence_path, validation)
    
    sys.exit(0 if validation["verdict"] == "PASS" else 1)

def write_validation(evidence_path, validation):
    validation_path = evidence_path / "VALIDATION.json"
    with open(validation_path, 'w') as f:
        json.dump(validation, f, indent=2)
    print(f"[MVP 5 Scenarios Validator] Validation written: {validation_path}")

if __name__ == '__main__':
    main()
