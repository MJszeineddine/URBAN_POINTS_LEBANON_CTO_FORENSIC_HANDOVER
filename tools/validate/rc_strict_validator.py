#!/usr/bin/env python3
"""
RC_STRICT Gate Validator
Enforces zero-tolerance acceptance criteria from RC_STRICT.yaml
Machine-verifiable GO/NO-GO verdict with detailed evidence analysis
"""

import json
import sys
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Tuple
import re

class RCStrictValidator:
    def __init__(self, evidence_path: str):
        self.evidence_path = Path(evidence_path)
        self.validation_result = {
            "gate_name": "RC_STRICT",
            "verdict": "FAIL",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "criteria_checks": [],
            "errors": [],
            "warnings": [],
            "evidence_path": str(evidence_path)
        }
        
    def validate(self) -> Tuple[bool, Dict[str, Any]]:
        """Run all validation checks and return verdict"""
        print(f"[RC_STRICT] Validating evidence: {self.evidence_path}")
        
        # D) Evidence Bundle Completeness (must check first)
        self._check_evidence_bundle()
        
        # A) Zero Skips
        self._check_zero_skips()
        
        # B) Merchant Validation
        self._check_merchant_validation()
        
        # C) getBalance Contract
        self._check_get_balance_contract()
        
        # E) Forbidden Patterns
        self._check_forbidden_patterns()
        
        # Determine verdict
        has_errors = len(self.validation_result["errors"]) > 0
        self.validation_result["verdict"] = "FAIL" if has_errors else "PASS"
        
        return not has_errors, self.validation_result
    
    def _check_evidence_bundle(self):
        """D) Evidence bundle completeness"""
        criterion = "evidence_bundle_completeness"
        required_files = [
            "SUMMARY.json",
            "RESULTS.json", 
            "SMOKE_LOG.txt",
            "commit_hash.txt",
            "git_status.txt",
            "branch.txt",
            "logs/emulators/EMULATORS_EXEC.log"
        ]
        
        missing_files = []
        for file_name in required_files:
            file_path = self.evidence_path / file_name
            if not file_path.exists():
                missing_files.append(file_name)
        
        if missing_files:
            self.validation_result["errors"].append({
                "criterion": criterion,
                "message": f"Missing required evidence files: {', '.join(missing_files)}"
            })
            self.validation_result["criteria_checks"].append({
                "criterion": criterion,
                "status": "FAIL",
                "details": f"Missing: {missing_files}"
            })
        else:
            self.validation_result["criteria_checks"].append({
                "criterion": criterion,
                "status": "PASS",
                "details": "All required files present"
            })
    
    def _check_zero_skips(self):
        """A) Zero skips requirement"""
        criterion = "zero_skips"
        summary_path = self.evidence_path / "SUMMARY.json"
        
        if not summary_path.exists():
            self.validation_result["errors"].append({
                "criterion": criterion,
                "message": "SUMMARY.json not found"
            })
            return
        
        try:
            with open(summary_path) as f:
                summary = json.load(f)
            
            # Check test counts
            tests = summary.get("tests", {})
            total = tests.get("total", 0)
            passed = tests.get("passed", 0)
            failed = tests.get("failed", 0)
            
            if total < 6:
                self.validation_result["errors"].append({
                    "criterion": criterion,
                    "message": f"Insufficient tests: {total} (minimum 6 required)"
                })
            
            if failed > 0:
                self.validation_result["errors"].append({
                    "criterion": criterion,
                    "message": f"{failed} test(s) failed"
                })
            
            if passed != total:
                self.validation_result["errors"].append({
                    "criterion": criterion,
                    "message": f"Not all tests passed: {passed}/{total}"
                })
            
            # Check SMOKE_LOG for SKIP patterns
            smoke_log_path = self.evidence_path / "SMOKE_LOG.txt"
            if smoke_log_path.exists():
                with open(smoke_log_path) as f:
                    smoke_log = f.read()
                if re.search(r'\bSKIP\b', smoke_log, re.IGNORECASE):
                    self.validation_result["errors"].append({
                        "criterion": criterion,
                        "message": "SKIP pattern found in SMOKE_LOG.txt"
                    })
            
            if not any(e["criterion"] == criterion for e in self.validation_result["errors"]):
                self.validation_result["criteria_checks"].append({
                    "criterion": criterion,
                    "status": "PASS",
                    "details": f"All {total} tests passed, no skips"
                })
            else:
                self.validation_result["criteria_checks"].append({
                    "criterion": criterion,
                    "status": "FAIL",
                    "details": "Zero skips requirement violated"
                })
                
        except Exception as e:
            self.validation_result["errors"].append({
                "criterion": criterion,
                "message": f"Error reading SUMMARY.json: {str(e)}"
            })
    
    def _check_merchant_validation(self):
        """B) Merchant validation must be REAL"""
        criterion = "merchant_validation_real"
        smoke_log_path = self.evidence_path / "SMOKE_LOG.txt"
        results_path = self.evidence_path / "RESULTS.json"
        
        if not smoke_log_path.exists():
            self.validation_result["errors"].append({
                "criterion": criterion,
                "message": "SMOKE_LOG.txt not found"
            })
            return
        
        with open(smoke_log_path) as f:
            smoke_log = f.read()
        
        # Check if PIN flow was completed (if PIN was required)
        pin_flow_completed = re.search(r'Redemption completed after PIN|PIN verified.*Redemption completed', smoke_log, re.IGNORECASE | re.DOTALL)
        
        # Forbidden: "PIN verification required" WITHOUT completion
        if re.search(r'PIN verification required', smoke_log, re.IGNORECASE):
            if not pin_flow_completed:
                self.validation_result["errors"].append({
                    "criterion": criterion,
                    "message": "PIN verification required but PIN flow was not completed"
                })
        
        # Forbidden: "accepted as valid", "callable reachable (PIN"
        forbidden_merchant_patterns = [
            r'accepted as valid',
            r'callable reachable \(PIN'
        ]
        
        found_forbidden = []
        for pattern in forbidden_merchant_patterns:
            if re.search(pattern, smoke_log, re.IGNORECASE):
                found_forbidden.append(pattern)
        
        if found_forbidden:
            self.validation_result["errors"].append({
                "criterion": criterion,
                "message": f"Forbidden patterns found: {', '.join(found_forbidden)}"
            })
        
        # Required: Check for redemption evidence
        has_redemption_evidence = (
            re.search(r'redemption.*created|redemptionId|Redemption completed', smoke_log, re.IGNORECASE) or
            re.search(r'used.*true|redemption.*success', smoke_log, re.IGNORECASE)
        )
        
        # Check validateQRToken or validateRedemption returned success
        has_validation_success = re.search(r'validateQRToken.*PASS|validateRedemption.*PASS', smoke_log, re.IGNORECASE)
        
        if not has_validation_success:
            self.validation_result["errors"].append({
                "criterion": criterion,
                "message": "validateQRToken/validateRedemption did not PASS"
            })
        
        if not has_redemption_evidence:
            self.validation_result["warnings"].append({
                "criterion": criterion,
                "message": "No explicit redemption record evidence found in logs"
            })
        
        if not any(e["criterion"] == criterion for e in self.validation_result["errors"]):
            self.validation_result["criteria_checks"].append({
                "criterion": criterion,
                "status": "PASS",
                "details": "Merchant validation completed with real redemption"
            })
        else:
            self.validation_result["criteria_checks"].append({
                "criterion": criterion,
                "status": "FAIL",
                "details": "Merchant validation did not complete full flow"
            })
    
    def _check_get_balance_contract(self):
        """C) getBalance contract safety"""
        criterion = "get_balance_contract"
        smoke_log_path = self.evidence_path / "SMOKE_LOG.txt"
        
        if not smoke_log_path.exists():
            return
        
        with open(smoke_log_path) as f:
            smoke_log = f.read()
        
        # Check getBalance called with empty payload
        has_empty_payload = re.search(r'getBalance.*\{\}|getBalance.*empty payload', smoke_log, re.IGNORECASE)
        
        # Check getBalance passed
        has_pass = re.search(r'getBalance.*PASS', smoke_log, re.IGNORECASE)
        
        # Check for errors
        has_error = re.search(r'getBalance.*customerId required|getBalance.*FAIL', smoke_log, re.IGNORECASE)
        
        if has_error:
            self.validation_result["errors"].append({
                "criterion": criterion,
                "message": "getBalance failed or required customerId"
            })
        elif not has_pass:
            self.validation_result["errors"].append({
                "criterion": criterion,
                "message": "getBalance did not PASS"
            })
        else:
            self.validation_result["criteria_checks"].append({
                "criterion": criterion,
                "status": "PASS",
                "details": "getBalance works with empty payload"
            })
    
    def _check_forbidden_patterns(self):
        """E) Forbidden patterns in evidence"""
        criterion = "forbidden_patterns"
        forbidden = [
            r'\bTODO\b',
            r'\bunimplemented\b',
            r'\bnot implemented\b'
        ]
        
        # Scan all text files
        text_files = [
            "SMOKE_LOG.txt",
            "RESULTS.json",
            "logs/emulators/EMULATORS_EXEC.log"
        ]
        
        found_patterns = []
        for file_name in text_files:
            file_path = self.evidence_path / file_name
            if not file_path.exists():
                continue
            
            with open(file_path) as f:
                content = f.read()
            
            for pattern in forbidden:
                if re.search(pattern, content, re.IGNORECASE):
                    found_patterns.append(f"{pattern} in {file_name}")
        
        if found_patterns:
            self.validation_result["errors"].append({
                "criterion": criterion,
                "message": f"Forbidden patterns: {', '.join(found_patterns)}"
            })
        else:
            self.validation_result["criteria_checks"].append({
                "criterion": criterion,
                "status": "PASS",
                "details": "No forbidden patterns detected"
            })
    
    def write_validation_json(self):
        """Write VALIDATION.json to evidence folder"""
        output_path = self.evidence_path / "VALIDATION.json"
        with open(output_path, 'w') as f:
            json.dump(self.validation_result, f, indent=2)
        print(f"[RC_STRICT] Validation report: {output_path}")


def main():
    if len(sys.argv) < 3 or sys.argv[1] != "--evidence":
        print("Usage: rc_strict_validator.py --evidence <path>")
        sys.exit(3)
    
    evidence_path = sys.argv[2]
    
    if not os.path.exists(evidence_path):
        print(f"ERROR: Evidence path not found: {evidence_path}")
        sys.exit(2)
    
    validator = RCStrictValidator(evidence_path)
    passed, result = validator.validate()
    validator.write_validation_json()
    
    # Print summary
    print("\n" + "="*70)
    print(f"RC_STRICT VALIDATION: {result['verdict']}")
    print("="*70)
    
    for check in result["criteria_checks"]:
        status_icon = "✓" if check["status"] == "PASS" else "✗"
        print(f"{status_icon} {check['criterion']}: {check['status']}")
        if check.get("details"):
            print(f"  {check['details']}")
    
    if result["errors"]:
        print("\nERRORS:")
        for error in result["errors"]:
            print(f"  ✗ [{error['criterion']}] {error['message']}")
    
    if result["warnings"]:
        print("\nWARNINGS:")
        for warning in result["warnings"]:
            print(f"  ⚠ [{warning['criterion']}] {warning['message']}")
    
    print("="*70)
    
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
