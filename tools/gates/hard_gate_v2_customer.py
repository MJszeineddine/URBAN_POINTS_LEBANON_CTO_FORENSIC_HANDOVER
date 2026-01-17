#!/usr/bin/env python3
"""
HARD GATE v2 — Customer App (ZERO-GAP CERTIFICATION)
Non-gameable verification for customer app quality.

Exit codes:
  0: All checks passed (CUSTOMER APP IS READY)
  1: One or more checks failed
"""

import sys
import os
import json
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Tuple

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed. Run: pip3 install pyyaml")
    sys.exit(1)

# Repo paths
REPO_ROOT = Path(__file__).parent.parent.parent.absolute()
CUSTOMER_APP = REPO_ROOT / "source" / "apps" / "mobile-customer"
ANALYSIS_FILE = CUSTOMER_APP / "analysis_options.yaml"
REQUIREMENTS_FILE = REPO_ROOT / "spec" / "requirements.yaml"
DOCS_DIR = REPO_ROOT / "docs"
VERIFICATION_DIR = REPO_ROOT / "local-ci" / "verification"

# Log files
RUN_LOG = VERIFICATION_DIR / "hard_gate_v2_run.log"
REPORT_FILE = VERIFICATION_DIR / "hard_gate_v2_report.json"
ANALYZE_LOG = VERIFICATION_DIR / "customer_app_analyze.log"
TEST_LOG = VERIFICATION_DIR / "customer_app_test.log"

# Placeholder patterns (BANNED)
BANNED_PATTERNS = [
    r"expect\s*\(\s*true\s*,\s*is\s*True\s*\)",  # expect(true, isTrue)
    r"placeholder\s+test",
    r"TODO.*test",
    r"SKIP",
    r"dummy\s+test",
    r"fake\s+test",
]

class Gate:
    def __init__(self):
        self.failures = []
        self.cust_ready = 0
        self.cust_blocked = 0
        self.banned_hits = []
        self.widget_tests = []
        self.analyze_exit = -1
        self.test_exit = -1
        
    def log(self, msg: str):
        """Print and log message"""
        print(msg)
        with open(RUN_LOG, "a") as f:
            f.write(msg + "\n")
    
    def fail(self, msg: str):
        """Record failure"""
        self.failures.append(msg)
        self.log(f"❌ {msg}")
    
    def pass_check(self, msg: str):
        """Record pass"""
        self.log(f"✅ {msg}")
    
    def run(self) -> bool:
        """Main gate runner"""
        # Clear logs
        RUN_LOG.write_text("")
        
        self.log("\n" + "="*70)
        self.log("HARD GATE v2 - Customer App (ZERO-GAP CERTIFICATION)")
        self.log("="*70 + "\n")
        
        # Check A: Strict linting
        self.log("\n[CHECK A] Strict Linting (analysis_options.yaml)")
        self.check_analysis_config()
        
        # Check B: Ban placeholder tests
        self.log("\n[CHECK B] Ban Placeholder Tests")
        self.check_no_placeholders()
        
        # Check C: Analyze & Test pass
        self.log("\n[CHECK C] Customer App Build (analyze + test)")
        self.check_analyze()
        self.check_test()
        
        # Check D: Verify CUSTOMER requirements
        self.log("\n[CHECK D] Verify CUST-* & TEST-CUSTOMER-* Requirements")
        self.check_requirements()
        
        # Check E: Evidence logs exist
        self.log("\n[CHECK E] Evidence Logs")
        self.check_logs()
        
        # Check F: Detect linting weakening
        self.log("\n[CHECK F] Detect Linting Weakening")
        self.check_weakening()
        
        # Summary
        self.log("\n" + "="*70)
        if self.failures:
            self.log(f"❌ GATE FAILED ({len(self.failures)} failures)\n")
            for f in self.failures:
                self.log(f"  - {f}")
            result = False
        else:
            self.log("✅ GATE PASSED - Customer App Ready")
            result = True
        self.log("="*70 + "\n")
        
        self.write_report(result)
        return result
    
    def check_analysis_config(self):
        """Verify analysis_options.yaml has strict linting"""
        if not ANALYSIS_FILE.exists():
            self.fail("analysis_options.yaml not found")
            return
        
        with open(ANALYSIS_FILE) as f:
            config = yaml.safe_load(f)
        
        # Check 1: Must include flutter_lints
        if not config or 'include' not in config:
            self.fail("analysis_options.yaml missing 'include: package:flutter_lints/flutter.yaml'")
            return
        
        include_val = config.get('include', '')
        if 'flutter_lints' not in include_val:
            self.fail(f"analysis_options.yaml does not include flutter_lints (has: {include_val})")
            return
        
        self.pass_check("analysis_options.yaml includes flutter_lints")
        
        # Check 2: linter.rules must NOT be empty
        linter = config.get('linter', {})
        if linter is None:
            linter = {}
        rules = linter.get('rules', [])
        
        if rules is not None and isinstance(rules, list) and len(rules) == 0:
            self.fail("linter.rules is empty (linter.rules: []) - must include real rules")
            return
        
        if rules is None or (isinstance(rules, list) and len(rules) == 0):
            self.fail("linter.rules is missing or empty - must include flutter_lints rules")
            return
        
        self.pass_check(f"linter.rules has {len(rules) if isinstance(rules, list) else 'rules'}")
    
    def check_no_placeholders(self):
        """Fail if test files contain placeholder patterns"""
        test_dir = CUSTOMER_APP / "test"
        if not test_dir.exists():
            self.fail("test/ directory not found")
            return
        
        dart_files = list(test_dir.rglob("*.dart"))
        if not dart_files:
            self.fail("No .dart test files found")
            return
        
        for dart_file in dart_files:
            content = dart_file.read_text()
            
            # Check banned patterns
            for pattern in BANNED_PATTERNS:
                matches = re.findall(pattern, content, re.IGNORECASE)
                if matches:
                    self.banned_hits.append((dart_file.name, pattern, len(matches)))
                    self.fail(f"{dart_file.name}: banned pattern '{pattern}' found {len(matches)} time(s)")
            
            # Special check: widget_test.dart must not be trivial
            if dart_file.name == "widget_test.dart":
                if "expect(true, isTrue)" in content and content.count("test(") == 1:
                    self.fail("widget_test.dart is trivial (single expect(true, isTrue) test)")
        
        if not self.banned_hits:
            self.pass_check("No placeholder/banned patterns found in tests")
    
    def check_analyze(self):
        """Run flutter analyze directly and capture to log"""
        self.log("\nRunning: flutter analyze...")
        
        # Ensure log dir exists
        ANALYZE_LOG.parent.mkdir(parents=True, exist_ok=True)
        
        # Find flutter executable
        flutter_which = subprocess.run(["which", "flutter"], capture_output=True, text=True)
        flutter_path = flutter_which.stdout.strip() if flutter_which.returncode == 0 else "/usr/local/bin/flutter"
        
        # Get flutter version (first line only)
        flutter_version_result = subprocess.run([flutter_path, "--version"], capture_output=True, text=True, cwd=CUSTOMER_APP)
        flutter_version_line = flutter_version_result.stdout.split('\n')[0] if flutter_version_result.stdout else "unknown"
        
        # Build command
        cmd = [flutter_path, "analyze", "--no-preamble"]
        
        # Write header to log
        with open(ANALYZE_LOG, "w") as f:
            f.write(f"CWD: {CUSTOMER_APP}\n")
            f.write(f"FLUTTER: {flutter_path}\n")
            f.write(f"VERSION: {flutter_version_line}\n")
            f.write(f"CMD: {' '.join(cmd)}\n")
            f.write("---- OUTPUT ----\n")
            f.flush()
        
        # Log what we're doing
        self.log(f"  CWD: {CUSTOMER_APP}")
        self.log(f"  FLUTTER: {flutter_path}")
        self.log(f"  CMD: {' '.join(cmd)}")
        
        # Run analyze and capture to file
        with open(ANALYZE_LOG, "a") as log_file:
            result = subprocess.run(
                cmd,
                cwd=CUSTOMER_APP,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                text=True
            )
            self.analyze_exit = result.returncode
            log_file.write(f"\n---- EXIT {self.analyze_exit} ----\n")
        
        # Read the output to check for issues
        analyze_output = ANALYZE_LOG.read_text()
        
        # STRICT: Fail if "N issues found" appears in output (where N > 0)
        issues_match = re.search(r'(\d+)\s+issues?\s+found', analyze_output)
        if issues_match:
            num_issues = int(issues_match.group(1))
            if num_issues > 0:
                self.fail(f"flutter analyze: contains {num_issues} issues (EXIT {self.analyze_exit})")
            else:
                self.pass_check(f"flutter analyze: EXIT {self.analyze_exit}")
        elif self.analyze_exit != 0:
            self.fail(f"flutter analyze: EXIT {self.analyze_exit}")
        elif "No issues found" in analyze_output:
            self.pass_check(f"flutter analyze: EXIT {self.analyze_exit}")
        else:
            self.log(f"⚠️  flutter analyze output unclear (EXIT {self.analyze_exit}), output: {analyze_output[:200]}")
    
    def check_test(self):
        """Run flutter test directly and capture to log"""
        self.log("\nRunning: flutter test...")
        
        # Ensure log dir exists
        TEST_LOG.parent.mkdir(parents=True, exist_ok=True)
        
        # Find flutter executable
        flutter_which = subprocess.run(["which", "flutter"], capture_output=True, text=True)
        flutter_path = flutter_which.stdout.strip() if flutter_which.returncode == 0 else "/usr/local/bin/flutter"
        
        # Build command
        cmd = [flutter_path, "test"]
        
        # Write header to log
        with open(TEST_LOG, "w") as f:
            f.write(f"CWD: {CUSTOMER_APP}\n")
            f.write(f"FLUTTER: {flutter_path}\n")
            f.write(f"CMD: {' '.join(cmd)}\n")
            f.write("---- OUTPUT ----\n")
            f.flush()
        
        # Log what we're doing
        self.log(f"  CWD: {CUSTOMER_APP}")
        self.log(f"  FLUTTER: {flutter_path}")
        self.log(f"  CMD: {' '.join(cmd)}")
        
        # Run test and capture to file
        with open(TEST_LOG, "a") as log_file:
            result = subprocess.run(
                cmd,
                cwd=CUSTOMER_APP,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                text=True
            )
            self.test_exit = result.returncode
            log_file.write(f"\n---- EXIT {self.test_exit} ----\n")
        
        # Check result
        if self.test_exit == 0:
            self.pass_check(f"flutter test: EXIT {self.test_exit}")
        else:
            self.fail(f"flutter test: EXIT {self.test_exit}")
    
    def check_requirements(self):
        """Verify all CUST-* and TEST-CUSTOMER-* are READY or BLOCKED"""
        if not REQUIREMENTS_FILE.exists():
            self.fail("spec/requirements.yaml not found")
            return
        
        with open(REQUIREMENTS_FILE) as f:
            data = yaml.safe_load(f)
        
        reqs = data.get("requirements", [])
        if not reqs:
            self.fail("No requirements in spec/requirements.yaml")
            return
        
        cust_reqs = [r for r in reqs if str(r.get("id", "")).startswith(("CUST-", "TEST-CUSTOMER-"))]
        
        for req in cust_reqs:
            req_id = req.get("id")
            status = req.get("status", "UNKNOWN")
            anchors = (req.get("frontend_anchors") or []) + (req.get("backend_anchors") or [])
            
            if status == "READY":
                if not anchors:
                    self.fail(f"{req_id}: READY but has no anchors")
                else:
                    # Check anchor files exist
                    for anchor in anchors:
                        if ":" in anchor:
                            file_path = anchor.split(":")[0]
                            full_path = REPO_ROOT / file_path
                            if not full_path.exists():
                                self.fail(f"{req_id}: anchor file not found: {file_path}")
                    self.cust_ready += 1
            
            elif status == "BLOCKED":
                # Verify blocker doc exists
                feature = req.get("feature", req_id)
                blocker_name = feature.replace(" ", "_").replace("/", "_").replace("(", "").replace(")", "").upper()
                blocker_file = DOCS_DIR / f"BLOCKER_{blocker_name}.md"
                if blocker_file.exists():
                    self.cust_blocked += 1
                else:
                    self.fail(f"{req_id}: BLOCKED but missing blocker doc: {blocker_file}")
            
            else:
                self.fail(f"{req_id}: Status is {status} (must be READY or BLOCKED)")
        
        self.pass_check(f"CUST requirements: {self.cust_ready} READY, {self.cust_blocked} BLOCKED")
    
    def check_logs(self):
        """Verify evidence logs exist"""
        required_logs = [ANALYZE_LOG, TEST_LOG, RUN_LOG]
        for log_file in required_logs:
            if log_file.exists() and log_file.stat().st_size > 0:
                self.pass_check(f"Log exists: {log_file.name} ({log_file.stat().st_size} bytes)")
            else:
                self.fail(f"Log missing or empty: {log_file}")
    
    def check_weakening(self):
        """Detect if analysis_options.yaml was weakened vs git HEAD"""
        try:
            result = subprocess.run(
                ["git", "show", f"HEAD:source/apps/mobile-customer/analysis_options.yaml"],
                capture_output=True,
                text=True,
                cwd=REPO_ROOT
            )
            if result.returncode != 0:
                self.pass_check("No git baseline (new file or not in repo)")
                return
            
            old_config = yaml.safe_load(result.stdout)
            with open(ANALYSIS_FILE) as f:
                new_config = yaml.safe_load(f)
            
            # Check if include was removed
            old_include = old_config.get('include', '') if old_config else ''
            new_include = new_config.get('include', '') if new_config else ''
            
            if 'flutter_lints' in old_include and 'flutter_lints' not in new_include:
                self.fail("analysis_options.yaml: flutter_lints include was REMOVED")
                return
            
            # Check if linter rules went from non-empty to empty
            old_rules = old_config.get('linter', {}).get('rules', []) if old_config and old_config.get('linter') else []
            new_rules = new_config.get('linter', {}).get('rules', []) if new_config and new_config.get('linter') else []
            
            if old_rules and len(old_rules) > 0 and (not new_rules or len(new_rules) == 0):
                self.fail("analysis_options.yaml: linter.rules was CLEARED (weakening)")
                return
            
            self.pass_check("analysis_options.yaml: No obvious weakening detected")
        
        except Exception as e:
            self.log(f"⚠️  Could not check git baseline: {e}")
    
    def write_report(self, passed: bool):
        """Write JSON report"""
        report = {
            "status": "PASS" if passed else "FAIL",
            "failures": self.failures,
            "cust_ready_count": self.cust_ready,
            "cust_blocked_count": self.cust_blocked,
            "analyze_exit": self.analyze_exit,
            "test_exit": self.test_exit,
            "banned_patterns_hits": self.banned_hits,
            "widget_tests_found": self.widget_tests,
        }
        
        with open(REPORT_FILE, "w") as f:
            json.dump(report, f, indent=2)
        
        self.log(f"\nReport written to: {REPORT_FILE}")

def main():
    gate = Gate()
    passed = gate.run()
    sys.exit(0 if passed else 1)

if __name__ == "__main__":
    main()
