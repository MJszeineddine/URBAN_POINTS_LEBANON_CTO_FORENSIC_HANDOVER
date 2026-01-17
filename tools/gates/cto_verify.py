#!/usr/bin/env python3
"""
Urban Points Lebanon - CTO Verification Gate
This script enforces completion criteria per master file requirements.

Exit codes:
  0: All checks passed (READY to declare 100% complete)
  1: One or more checks failed (NOT ready)
"""

import sys
import os
import json
from pathlib import Path
from typing import Dict, List, Tuple
from datetime import datetime

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed. Run: pip3 install pyyaml")
    sys.exit(1)

# Repository root (3 levels up from this script)
REPO_ROOT = Path(__file__).parent.parent.parent.absolute()
VERIFICATION_DIR = REPO_ROOT / "local-ci" / "verification"
REQUIREMENTS_FILE = REPO_ROOT / "spec" / "requirements.yaml"
DOCS_DIR = REPO_ROOT / "docs"

# Output files
REPORT_FILE = VERIFICATION_DIR / "cto_verify_report.json"
LOG_FILE = VERIFICATION_DIR / "gate_run.log"

# Critical modules that must NOT contain TODO/mock/placeholder
CRITICAL_MODULES = [
    "source/backend/firebase-functions/src/analytics.ts",
    "source/backend/firebase-functions/src/redemption.ts",
    "source/backend/firebase-functions/src/points.ts",
    "source/backend/firebase-functions/src/whatsapp.ts",
]

# Allowlist for acceptable TODOs (e.g., "// TODO: optimize performance" is OK)
TODO_ALLOWLIST = [
    "optimize",
    "refactor",
    "improve",
]


class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def log(message: str, color: str = ""):
    """Print and log message"""
    colored_msg = f"{color}{message}{Colors.RESET}" if color else message
    print(colored_msg)
    with open(LOG_FILE, "a") as f:
        f.write(f"{message}\n")


def load_requirements() -> Dict:
    """Load and parse requirements.yaml"""
    log(f"Loading requirements from {REQUIREMENTS_FILE}...", Colors.BLUE)
    if not REQUIREMENTS_FILE.exists():
        log(f"❌ FATAL: {REQUIREMENTS_FILE} not found", Colors.RED)
        sys.exit(1)
    
    with open(REQUIREMENTS_FILE, "r") as f:
        data = yaml.safe_load(f)
    
    if not data or "requirements" not in data:
        log("❌ FATAL: requirements.yaml has no 'requirements' key", Colors.RED)
        sys.exit(1)
    
    log(f"✅ Loaded {len(data['requirements'])} requirements", Colors.GREEN)
    return data


def check_requirement_status(requirements: List[Dict]) -> Tuple[bool, List[str], Dict]:
    """
    Check that all requirements are READY (or BLOCKED with blocker doc).
    Returns: (passed, failures, counts)
    """
    log("\n" + "="*60, Colors.BOLD)
    log("CHECK 1: Requirement Status", Colors.BOLD)
    log("="*60, Colors.BOLD)
    
    passed = True
    failures = []
    
    # Count requirements by status
    counts = {"ready": 0, "blocked": 0, "partial": 0, "missing": 0}
    blocked_ids = []
    
    for req in requirements:
        req_id = req.get("id", "UNKNOWN")
        status = req.get("status", "UNKNOWN")
        
        if status == "READY":
            counts["ready"] += 1
            log(f"  ✅ {req_id}: {status}", Colors.GREEN)
        elif status == "BLOCKED":
            counts["blocked"] += 1
            blocked_ids.append(req_id)
            # Check if blocker doc exists
            feature = req.get("feature", req_id)
            blocker_name = feature.replace(" ", "_").replace("/", "_").replace("(", "").replace(")", "").upper()
            blocker_file = DOCS_DIR / f"BLOCKER_{blocker_name}.md"
            
            if blocker_file.exists():
                log(f"  ⚠️  {req_id}: {status} (blocker doc exists: {blocker_file.name})", Colors.YELLOW)
            else:
                log(f"  ❌ {req_id}: {status} but no blocker doc found (expected: {blocker_file.name})", Colors.RED)
                failures.append(f"{req_id}: BLOCKED but missing blocker doc")
                passed = False
        elif status in ["PARTIAL", "MISSING"]:
            if status == "PARTIAL":
                counts["partial"] += 1
            else:
                counts["missing"] += 1
            log(f"  ❌ {req_id}: {status} (must be READY or BLOCKED)", Colors.RED)
            failures.append(f"{req_id}: Status is {status}, must be READY or BLOCKED")
            passed = False
        else:
            log(f"  ❌ {req_id}: Invalid status '{status}'", Colors.RED)
            failures.append(f"{req_id}: Invalid status")
            passed = False
    
    if passed:
        log("\n✅ CHECK 1 PASSED: All requirements are READY or BLOCKED with docs", Colors.GREEN)
    else:
        log(f"\n❌ CHECK 1 FAILED: {len(failures)} requirements not ready", Colors.RED)
    
    status_info = {
        "counts": counts,
        "blocked_ids": blocked_ids
    }
    return passed, failures, status_info


def check_requirement_anchors(requirements: List[Dict]) -> Tuple[bool, List[str]]:
    """
    Check that all requirements have non-empty anchors.
    Returns: (passed, failures)
    """
    log("\n" + "="*60, Colors.BOLD)
    log("CHECK 2: Requirement Anchors", Colors.BOLD)
    log("="*60, Colors.BOLD)
    
    passed = True
    failures = []
    
    for req in requirements:
        req_id = req.get("id", "UNKNOWN")
        status = req.get("status", "UNKNOWN")
        frontend_anchors = req.get("frontend_anchors", [])
        backend_anchors = req.get("backend_anchors", [])
        
        # Skip anchor check for BLOCKED/MISSING requirements
        if status in ["BLOCKED", "MISSING"]:
            log(f"  ⏭️  {req_id}: Skipped (status={status})", Colors.YELLOW)
            continue
        
        # READY/PARTIAL requirements must have anchors
        if not frontend_anchors and not backend_anchors:
            log(f"  ❌ {req_id}: No anchors (both frontend_anchors and backend_anchors are empty)", Colors.RED)
            failures.append(f"{req_id}: No anchors")
            passed = False
        else:
            anchor_count = len(frontend_anchors) + len(backend_anchors)
            log(f"  ✅ {req_id}: {anchor_count} anchors", Colors.GREEN)
    
    if passed:
        log("\n✅ CHECK 2 PASSED: All READY requirements have anchors", Colors.GREEN)
    else:
        log(f"\n❌ CHECK 2 FAILED: {len(failures)} requirements missing anchors", Colors.RED)
    
    return passed, failures


def check_anchor_files_exist(requirements: List[Dict]) -> Tuple[bool, List[str]]:
    """
    Check that files referenced in anchors actually exist.
    Returns: (passed, failures)
    """
    log("\n" + "="*60, Colors.BOLD)
    log("CHECK 3: Anchor Files Exist", Colors.BOLD)
    log("="*60, Colors.BOLD)
    
    passed = True
    failures = []
    missing_anchor_list = []  # Collect all missing for JSON report
    
    for req in requirements:
        req_id = req.get("id", "UNKNOWN")
        status = req.get("status", "UNKNOWN")
        
        if status in ["BLOCKED", "MISSING"]:
            continue
        
        frontend_anchors = req.get("frontend_anchors", [])
        backend_anchors = req.get("backend_anchors", [])
        
        for anchor in frontend_anchors:
            file_path = anchor.split(":")[0] if ":" in anchor else anchor
            full_path = REPO_ROOT / file_path
            
            if not full_path.exists():
                log(f"  ❌ {req_id}: File not found: {file_path}", Colors.RED)
                failures.append(f"{req_id}: Missing file {file_path}")
                missing_anchor_list.append({
                    "path": file_path,
                    "requirements": [req_id],
                    "field": "frontend_anchors"
                })
                passed = False
        
        for anchor in backend_anchors:
            file_path = anchor.split(":")[0] if ":" in anchor else anchor
            full_path = REPO_ROOT / file_path
            
            if not full_path.exists():
                log(f"  ❌ {req_id}: File not found: {file_path}", Colors.RED)
                failures.append(f"{req_id}: Missing file {file_path}")
                missing_anchor_list.append({
                    "path": file_path,
                    "requirements": [req_id],
                    "field": "backend_anchors"
                })
                passed = False
    
    # Write missing_anchors.json
    import json
    missing_report = {
        "missing": missing_anchor_list[:50],
        "count": len(missing_anchor_list)
    }
    verification_dir = REPO_ROOT / "local-ci/verification"
    verification_dir.mkdir(parents=True, exist_ok=True)
    with open(verification_dir / "missing_anchors.json", "w") as f:
        json.dump(missing_report, f, indent=2)
    
    if passed:
        log("\n✅ CHECK 3 PASSED: All anchor files exist", Colors.GREEN)
    else:
        log(f"\n❌ CHECK 3 FAILED: {len(failures)} anchor files not found", Colors.RED)
        log(f"   Details: local-ci/verification/missing_anchors.json", Colors.YELLOW)
    
    return passed, failures


def check_critical_modules_no_mocks(modules: List[str]) -> Tuple[bool, List[str]]:
    """
    Check that critical modules don't contain TODO/mock/placeholder.
    Returns: (passed, failures)
    """
    log("\n" + "="*60, Colors.BOLD)
    log("CHECK 4: Critical Modules (No TODO/Mock/Placeholder)", Colors.BOLD)
    log("="*60, Colors.BOLD)
    
    passed = True
    failures = []
    
    # Keywords to search for
    keywords = ["TODO", "FIXME", "XXX", "HACK", "mock", "placeholder", "PLACEHOLDER", "fake"]
    
    for module_path in modules:
        full_path = REPO_ROOT / module_path
        
        if not full_path.exists():
            log(f"  ⚠️  {module_path}: File not found (skipping)", Colors.YELLOW)
            continue
        
        log(f"  Scanning {module_path}...")
        
        with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
        
        found_issues = []
        for i, line in enumerate(lines, start=1):
            for keyword in keywords:
                if keyword in line:
                    # Check if it's in allowlist
                    is_allowed = any(allowed in line.lower() for allowed in TODO_ALLOWLIST)
                    if not is_allowed:
                        found_issues.append(f"Line {i}: {line.strip()}")
        
        if found_issues:
            log(f"  ❌ {module_path}: Found {len(found_issues)} issues", Colors.RED)
            for issue in found_issues[:5]:  # Show first 5
                log(f"      {issue}", Colors.RED)
            if len(found_issues) > 5:
                log(f"      ... and {len(found_issues) - 5} more", Colors.RED)
            failures.append(f"{module_path}: {len(found_issues)} TODO/mock/placeholder found")
            passed = False
        else:
            log(f"  ✅ {module_path}: Clean", Colors.GREEN)
    
    if passed:
        log("\n✅ CHECK 4 PASSED: No TODO/mock/placeholder in critical modules", Colors.GREEN)
    else:
        log(f"\n❌ CHECK 4 FAILED: {len(failures)} critical modules have issues", Colors.RED)
    
    return passed, failures


def check_test_logs_exist() -> Tuple[bool, List[str]]:
    """
    Check that required test/build logs exist in local-ci/verification/.
    Returns: (passed, failures)
    """
    log("\n" + "="*60, Colors.BOLD)
    log("CHECK 5: Test/Build Logs Exist", Colors.BOLD)
    log("="*60, Colors.BOLD)
    
    passed = True
    failures = []
    
    required_logs = [
        "customer_app_test.log",
        "merchant_app_test.log",
        "web_admin_test.log",
        "backend_functions_test.log",
        "customer_app_build.log",
        "merchant_app_build.log",
        "web_admin_build.log",
        "backend_functions_build.log",
    ]
    
    for log_file in required_logs:
        full_path = VERIFICATION_DIR / log_file
        if full_path.exists():
            # Check if file is not empty
            size = full_path.stat().st_size
            if size > 0:
                log(f"  ✅ {log_file}: Exists ({size} bytes)", Colors.GREEN)
            else:
                log(f"  ⚠️  {log_file}: Exists but empty", Colors.YELLOW)
                failures.append(f"{log_file}: File is empty")
                passed = False
        else:
            log(f"  ❌ {log_file}: Not found", Colors.RED)
            failures.append(f"{log_file}: Missing")
            passed = False
    
    if passed:
        log("\n✅ CHECK 5 PASSED: All required logs exist", Colors.GREEN)
    else:
        log(f"\n❌ CHECK 5 FAILED: {len(failures)} logs missing or empty", Colors.RED)
    
    return passed, failures


def generate_report(checks: Dict, passed: bool, status_info: Dict):
    """Generate JSON report"""
    blocked_count = status_info.get("counts", {}).get("blocked", 0)
    allow_blocked = os.getenv("CTO_ALLOW_BLOCKED", "0") == "1"
    
    # Determine final status
    if not passed:
        final_status = "FAIL"
    elif blocked_count > 0 and allow_blocked:
        final_status = "PASS_WITH_BLOCKERS"
    elif blocked_count > 0:
        final_status = "FAIL"
    else:
        final_status = "PASS"
    
    report = {
        "timestamp": datetime.now().isoformat(),
        "status": final_status,
        "requirement_counts": status_info.get("counts", {}),
        "blocked_ids": status_info.get("blocked_ids", []),
        "checks": checks,
        "summary": {
            "total_checks": len(checks),
            "passed_checks": sum(1 for c in checks.values() if c["passed"]),
            "failed_checks": sum(1 for c in checks.values() if not c["passed"]),
        }
    }
    
    with open(REPORT_FILE, "w") as f:
        json.dump(report, f, indent=2)
    
    log(f"\n📄 Report written to: {REPORT_FILE}", Colors.BLUE)


def main():
    """Main verification flow"""
    # Initialize log
    VERIFICATION_DIR.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, "w") as f:
        f.write(f"CTO Verification Gate Run\n")
        f.write(f"Timestamp: {datetime.now().isoformat()}\n")
        f.write(f"Repository: {REPO_ROOT}\n")
        f.write("="*60 + "\n\n")
    
    log(f"\n{Colors.BOLD}{'='*60}{Colors.RESET}")
    log(f"{Colors.BOLD}Urban Points Lebanon - CTO Verification Gate{Colors.RESET}")
    log(f"{Colors.BOLD}{'='*60}{Colors.RESET}\n")
    
    # Load requirements
    data = load_requirements()
    requirements = data["requirements"]
    
    # Run checks
    checks = {}
    all_passed = True
    
    # Check 1: Requirement status
    passed, failures, status_info = check_requirement_status(requirements)
    checks["requirement_status"] = {"passed": passed, "failures": failures}
    all_passed = all_passed and passed
    
    # Check 2: Requirement anchors
    passed, failures = check_requirement_anchors(requirements)
    checks["requirement_anchors"] = {"passed": passed, "failures": failures}
    all_passed = all_passed and passed
    
    # Check 3: Anchor files exist
    passed, failures = check_anchor_files_exist(requirements)
    checks["anchor_files_exist"] = {"passed": passed, "failures": failures}
    all_passed = all_passed and passed
    
    # Check 4: Critical modules clean
    passed, failures = check_critical_modules_no_mocks(CRITICAL_MODULES)
    checks["critical_modules_clean"] = {"passed": passed, "failures": failures}
    all_passed = all_passed and passed
    
    # Check 5: Test logs exist
    passed, failures = check_test_logs_exist()
    checks["test_logs_exist"] = {"passed": passed, "failures": failures}
    all_passed = all_passed and passed
    
    # Generate report
    generate_report(checks, all_passed, status_info)
    
    # Final summary
    log(f"\n{Colors.BOLD}{'='*60}{Colors.RESET}")
    log(f"{Colors.BOLD}FINAL RESULT{Colors.RESET}")
    log(f"{Colors.BOLD}{'='*60}{Colors.RESET}\n")
    
    # Check blocked count
    blocked_count = status_info.get("counts", {}).get("blocked", 0)
    allow_blocked = os.getenv("CTO_ALLOW_BLOCKED", "0") == "1"
    
    if not all_passed:
        log(f"{Colors.RED}{Colors.BOLD}❌ GATE FAILED{Colors.RESET}")
        log(f"{Colors.RED}Status: NOT READY (fix failures and re-run){Colors.RESET}\n")
        
        # Print summary of failures
        total_failures = sum(len(c["failures"]) for c in checks.values())
        log(f"Total failures: {total_failures}")
        log(f"See {REPORT_FILE} for details\n", Colors.YELLOW)
        
        sys.exit(1)
    elif blocked_count > 0 and not allow_blocked:
        log(f"{Colors.YELLOW}{Colors.BOLD}⚠️  NOT COMPLETE{Colors.RESET}")
        log(f"{Colors.YELLOW}All checks passed BUT {blocked_count} requirements are BLOCKED:{Colors.RESET}")
        for bid in status_info.get("blocked_ids", []):
            log(f"  - {bid}", Colors.YELLOW)
        log(f"\n{Colors.YELLOW}This is NOT 100% complete. Requirements remain blocked.{Colors.RESET}")
        log(f"{Colors.YELLOW}To override: CTO_ALLOW_BLOCKED=1 python3 {__file__}{Colors.RESET}\n")
        sys.exit(1)
    elif blocked_count > 0 and allow_blocked:
        log(f"{Colors.YELLOW}{Colors.BOLD}✅ PASS (WITH BLOCKERS){Colors.RESET}")
        log(f"{Colors.YELLOW}All checks passed WITH {blocked_count} BLOCKED requirements:{Colors.RESET}")
        for bid in status_info.get("blocked_ids", []):
            log(f"  - {bid}", Colors.YELLOW)
        log(f"\n{Colors.YELLOW}CTO_ALLOW_BLOCKED override is active. Passing with awareness.{Colors.RESET}\n")
        sys.exit(0)
    else:
        log(f"{Colors.GREEN}{Colors.BOLD}✅ ALL CHECKS PASSED{Colors.RESET}")
        log(f"{Colors.GREEN}Status: READY - 100% complete, zero blocked requirements{Colors.RESET}\n")
        sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"\n❌ FATAL ERROR: {str(e)}", Colors.RED)
        import traceback
        traceback.print_exc()
        sys.exit(1)
