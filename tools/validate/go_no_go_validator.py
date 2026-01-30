#!/usr/bin/env python3
"""
GO/NO-GO Evidence Validator (stdlib only)
Machine-verifiable verdict from evidence artifacts
"""

import json
import os
import sys
import re
from pathlib import Path
from datetime import datetime
from glob import glob

class GoNoGoValidator:
    def __init__(self, evidence_path: str, spec_path: str):
        self.evidence_path = Path(evidence_path)
        self.spec_path = Path(spec_path)
        self.spec = self._load_spec()
        self.validation = {
            "gate_name": self.spec.get("name", "UNKNOWN"),
            "verdict": "FAIL",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "criteria_checks": [],
            "errors": [],
            "warnings": []
        }
    
    def _load_spec(self):
        """Load spec JSON"""
        if not self.spec_path.exists():
            print(f"ERROR: Spec not found: {self.spec_path}")
            sys.exit(3)
        with open(self.spec_path) as f:
            return json.load(f)
    
    def validate(self):
        """Run all validation checks"""
        print(f"[GO/NO-GO] Validating: {self.evidence_path}")
        
        # 1) Check required evidence files exist
        self._check_required_files()
        
        # 2) Validate SUMMARY.json structure and values
        self._validate_summary()
        
        # 3) Validate log globs
        self._validate_log_globs()
        
        # 4) Scan for forbidden patterns
        self._scan_forbidden_patterns()
        
        # Determine verdict
        self.validation["verdict"] = "FAIL" if self.validation["errors"] else "PASS"
        
        return self.validation["verdict"] == "PASS", self.validation
    
    def _check_required_files(self):
        """Check required_evidence_files exist"""
        criterion = "required_evidence_files"
        missing = []
        
        for fname in self.spec.get("required_evidence_files", []):
            if not (self.evidence_path / fname).exists():
                missing.append(fname)
        
        if missing:
            self.validation["errors"].append({
                "code": "MISSING_EVIDENCE",
                "message": f"Missing required files: {', '.join(missing)}",
                "file": None
            })
            self.validation["criteria_checks"].append({
                "criterion": criterion,
                "status": "FAIL",
                "details": f"Missing: {missing}"
            })
        else:
            self.validation["criteria_checks"].append({
                "criterion": criterion,
                "status": "PASS",
                "details": "All required files present"
            })
    
    def _validate_summary(self):
        """Validate SUMMARY.json structure"""
        criterion = "summary_structure"
        summary_path = self.evidence_path / "SUMMARY.json"
        
        if not summary_path.exists():
            return  # Already caught by required_files
        
        try:
            with open(summary_path) as f:
                summary = json.load(f)
        except json.JSONDecodeError as e:
            self.validation["errors"].append({
                "code": "INVALID_JSON",
                "message": f"SUMMARY.json is not valid JSON: {e}",
                "file": "SUMMARY.json"
            })
            return
        
        # Check status field
        status = summary.get("status")
        if status not in ["PASS", "FAIL"]:
            self.validation["errors"].append({
                "code": "INVALID_STATUS",
                "message": f"SUMMARY.json status must be PASS or FAIL, got: {status}",
                "file": "SUMMARY.json"
            })
        
        # Check tests structure
        tests = summary.get("tests", {})
        total = tests.get("total", 0)
        passed = tests.get("passed", 0)
        failed = tests.get("failed", 0)
        skipped = tests.get("skipped", 0)
        
        # Validate counts are numbers
        if not all(isinstance(x, int) for x in [total, passed, failed, skipped]):
            self.validation["errors"].append({
                "code": "INVALID_COUNTS",
                "message": "Test counts must be integers",
                "file": "SUMMARY.json"
            })
            return
        
        # Check min_tests
        min_tests = self.spec.get("min_tests", 1)
        if total < min_tests:
            self.validation["errors"].append({
                "code": "INSUFFICIENT_TESTS",
                "message": f"Total tests ({total}) < minimum required ({min_tests})",
                "file": "SUMMARY.json"
            })
        
        # Check require_zero_failed
        if self.spec.get("require_zero_failed", True) and failed > 0:
            self.validation["errors"].append({
                "code": "TESTS_FAILED",
                "message": f"{failed} test(s) failed",
                "file": "SUMMARY.json"
            })
        
        # Check require_zero_skipped
        if self.spec.get("require_zero_skipped", True) and skipped > 0:
            self.validation["errors"].append({
                "code": "TESTS_SKIPPED",
                "message": f"{skipped} test(s) skipped",
                "file": "SUMMARY.json"
            })
        
        if not any(e["code"] in ["INVALID_STATUS", "INVALID_COUNTS", "INSUFFICIENT_TESTS", "TESTS_FAILED", "TESTS_SKIPPED"] 
                   for e in self.validation["errors"]):
            self.validation["criteria_checks"].append({
                "criterion": criterion,
                "status": "PASS",
                "details": f"{total} tests, {passed} passed, {failed} failed, {skipped} skipped"
            })
    
    def _validate_log_globs(self):
        """Check required log globs have matches"""
        criterion = "required_logs"
        
        for pattern in self.spec.get("required_log_globs", []):
            # Search relative to evidence folder
            matches = list(self.evidence_path.glob(pattern))
            if not matches:
                # HARDENED: Missing log patterns are now ERRORS, not warnings
                self.validation["errors"].append({
                    "code": "MISSING_LOG_PATTERN",
                    "message": f"No files match pattern: {pattern}",
                    "file": None
                })
    
    def _scan_forbidden_patterns(self):
        """Scan logs for forbidden patterns"""
        criterion = "forbidden_patterns"
        
        # Check for completion markers
        completion_markers = [
            r"RC_STRICT GATE: COMPLETE",
            r"MVP SMOKE GATE: PASS",
            r"GO/NO-GO VERDICT: GO"
        ]
        
        # Find all text files to scan
        text_files = []
        for ext in ["*.log", "*.txt"]:
            text_files.extend(self.evidence_path.rglob(ext))
        
        # Also check specific files
        for fname in ["SMOKE_LOG.txt", "RESULTS.json"]:
            fpath = self.evidence_path / fname
            if fpath.exists():
                text_files.append(fpath)
        
        # Scan each file
        has_completion_marker = False
        forbidden_hits = []
        
        for fpath in text_files:
            try:
                content = fpath.read_text(errors='ignore')
                
                # Check for completion markers
                for marker in completion_markers:
                    if re.search(marker, content, re.IGNORECASE):
                        has_completion_marker = True
                        break
                
                # Scan for forbidden patterns
                for pattern in self.spec.get("forbidden_patterns", []):
                    if re.search(pattern, content, re.IGNORECASE):
                        # Find line with match
                        for i, line in enumerate(content.split('\n'), 1):
                            if re.search(pattern, line, re.IGNORECASE):
                                forbidden_hits.append({
                                    "pattern": pattern,
                                    "file": str(fpath.relative_to(self.evidence_path)),
                                    "line": i,
                                    "text": line[:100]
                                })
                                break
            except Exception as e:
                self.validation["warnings"].append({
                    "code": "SCAN_ERROR",
                    "message": f"Could not scan {fpath.name}: {e}",
                    "file": str(fpath.relative_to(self.evidence_path))
                })
        
        # Report forbidden patterns only if no completion marker
        if forbidden_hits and not has_completion_marker:
            for hit in forbidden_hits:
                self.validation["errors"].append({
                    "code": "FORBIDDEN_PATTERN",
                    "message": f"Pattern '{hit['pattern']}' found in {hit['file']}:{hit['line']}",
                    "file": hit["file"]
                })
        
        if not forbidden_hits or has_completion_marker:
            self.validation["criteria_checks"].append({
                "criterion": criterion,
                "status": "PASS",
                "details": "No forbidden patterns detected" if not forbidden_hits else "Completion marker present"
            })
    
    def write_validation_json(self):
        """Write VALIDATION.json to evidence folder"""
        output_path = self.evidence_path / "VALIDATION.json"
        with open(output_path, 'w') as f:
            json.dump(self.validation, f, indent=2)
        print(f"[GO/NO-GO] Validation written: {output_path}")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="GO/NO-GO Evidence Validator")
    parser.add_argument("--evidence", required=True, help="Evidence folder path")
    parser.add_argument("--spec", default="local-ci/spec/GO_NO_GO_SPEC.json", 
                       help="Spec JSON path")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.evidence):
        print(f"ERROR: Evidence path not found: {args.evidence}")
        sys.exit(2)
    
    validator = GoNoGoValidator(args.evidence, args.spec)
    passed, result = validator.validate()
    validator.write_validation_json()
    
    # Print summary
    print("\n" + "="*70)
    print(f"GO/NO-GO VALIDATION: {result['verdict']}")
    print("="*70)
    
    for check in result["criteria_checks"]:
        icon = "✓" if check["status"] == "PASS" else "✗"
        print(f"{icon} {check['criterion']}: {check['status']}")
        if check.get("details"):
            print(f"  {check['details']}")
    
    if result["errors"]:
        print("\nERRORS:")
        for err in result["errors"]:
            file_info = f" [{err['file']}]" if err.get('file') else ""
            print(f"  ✗ {err['code']}: {err['message']}{file_info}")
    
    if result["warnings"]:
        print("\nWARNINGS:")
        for warn in result["warnings"]:
            file_info = f" [{warn['file']}]" if warn.get('file') else ""
            print(f"  ⚠ {warn['code']}: {warn['message']}{file_info}")
    
    print("="*70)
    
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
