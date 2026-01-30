#!/usr/bin/env python3
"""
Triage Helper - Identifies next fix action from evidence
Outputs single-line JSON for programmatic consumption
"""

import json
import sys
import os
from pathlib import Path

def analyze_evidence(evidence_path):
    """Analyze evidence and return next fix action"""
    evidence_path = Path(evidence_path)
    
    # Check required files exist
    summary_path = evidence_path / "SUMMARY.json"
    results_path = evidence_path / "RESULTS.json"
    smoke_log_path = evidence_path / "SMOKE_LOG.txt"
    validation_path = evidence_path / "VALIDATION.json"
    
    if not summary_path.exists():
        return {
            "priority": "HIGH",
            "reason": "SUMMARY.json missing",
            "file_hint": "gate runner script",
            "action": "Fix gate runner to always create SUMMARY.json in evidence folder"
        }
    
    if not validation_path.exists():
        return {
            "priority": "HIGH",
            "reason": "VALIDATION.json missing",
            "file_hint": "validator not run",
            "action": "Ensure validator runs and creates VALIDATION.json"
        }
    
    # Load validation
    with open(validation_path) as f:
        validation = json.load(f)
    
    # Check if already PASS
    if validation.get("verdict") == "PASS":
        return {
            "priority": "NONE",
            "reason": "Already PASS",
            "file_hint": None,
            "action": "No fix needed"
        }
    
    # Check for errors in validation
    errors = validation.get("errors", [])
    if errors:
        first_error = errors[0]
        return {
            "priority": "HIGH",
            "reason": first_error.get("message", "Unknown error"),
            "file_hint": first_error.get("file", "unknown"),
            "action": f"Fix: {first_error.get('code', 'ERROR')}"
        }
    
    # Load summary
    try:
        with open(summary_path) as f:
            summary = json.load(f)
    except:
        return {
            "priority": "HIGH",
            "reason": "SUMMARY.json invalid JSON",
            "file_hint": "SUMMARY.json",
            "action": "Fix gate runner to output valid JSON"
        }
    
    # Check test failures
    tests = summary.get("tests", {})
    failed = tests.get("failed", 0)
    
    if failed > 0:
        # Try to find failing test details
        if results_path.exists():
            try:
                with open(results_path) as f:
                    results = json.load(f)
                calls = results.get("calls", [])
                for call in calls:
                    if call.get("status") == "FAIL" or call.get("error"):
                        return {
                            "priority": "HIGH",
                            "reason": f"Test {call.get('name')} failed: {call.get('error', 'unknown')}",
                            "file_hint": "smoke test or backend",
                            "action": f"Fix test: {call.get('name')}"
                        }
            except:
                pass
        
        # Check smoke log
        if smoke_log_path.exists():
            content = smoke_log_path.read_text()
            lines = content.split('\n')
            for line in lines:
                if 'FAIL' in line or 'Error:' in line:
                    return {
                        "priority": "HIGH",
                        "reason": line.strip()[:100],
                        "file_hint": "SMOKE_LOG.txt",
                        "action": "Check SMOKE_LOG.txt for failure details"
                    }
        
        return {
            "priority": "HIGH",
            "reason": f"{failed} test(s) failed",
            "file_hint": "SMOKE_LOG.txt",
            "action": "Review test logs for failure cause"
        }
    
    # No clear next action
    return {
        "priority": "MEDIUM",
        "reason": "Validation failed but no clear error",
        "file_hint": "VALIDATION.json",
        "action": "Review VALIDATION.json for details"
    }


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Triage next fix from evidence")
    parser.add_argument("--evidence", required=True, help="Evidence folder path")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.evidence):
        print(json.dumps({
            "priority": "HIGH",
            "reason": "Evidence path not found",
            "file_hint": None,
            "action": "Check evidence path"
        }))
        sys.exit(1)
    
    next_fix = analyze_evidence(args.evidence)
    print(json.dumps(next_fix))


if __name__ == "__main__":
    main()
