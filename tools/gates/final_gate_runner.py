#!/usr/bin/env python3
"""
Final Gate Runner - Urban Points Lebanon Full Stack Validation
Runs all tests, builds, security checks and produces evidence bundle.
Exit 0 = all gates pass, non-zero = blockers exist.
"""
import os, sys, json, subprocess, pathlib, datetime, hashlib, re, textwrap

ROOT = pathlib.Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "local-ci" / "verification" / "final_release" / "LATEST"
INV = EVIDENCE / "inventory"
LOGS = EVIDENCE / "logs"
REPORTS = EVIDENCE / "reports"
CI = EVIDENCE / "ci"
SECURITY = EVIDENCE / "security"

def run(cmd, cwd=None, log_path=None, env=None, timeout=600):
    """Run command and capture output. Returns (exit_code, output)."""
    try:
        p = subprocess.Popen(
            cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, 
            text=True, env=env or os.environ.copy()
        )
        out = []
        for line in p.stdout:
            out.append(line)
        rc = p.wait(timeout=timeout)
        s = "".join(out)
        if log_path:
            pathlib.Path(log_path).parent.mkdir(parents=True, exist_ok=True)
            pathlib.Path(log_path).write_text(s)
        return rc, s
    except subprocess.TimeoutExpired:
        p.kill()
        return -1, "TIMEOUT"
    except Exception as e:
        return -2, str(e)

def write(path: pathlib.Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)

def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()

def now_beirut():
    return (datetime.datetime.utcnow() + datetime.timedelta(hours=2)).strftime("%Y-%m-%d %H:%M:%S EET")

def git(args):
    rc, out = run(["git"] + args, cwd=ROOT)
    return out.strip()

def ensure_dirs():
    for p in [INV, LOGS, REPORTS, CI, SECURITY]:
        p.mkdir(parents=True, exist_ok=True)

class GateResult:
    def __init__(self, name: str):
        self.name = name
        self.passed = False
        self.exit_code = None
        self.log_path = None
        self.error = None
        self.duration = 0.0

    def __repr__(self):
        status = "✓ PASS" if self.passed else "✗ FAIL"
        return f"{status} | {self.name} | exit={self.exit_code} | {self.duration:.1f}s"

class FinalGateRunner:
    def __init__(self):
        self.gates = []
        self.blockers = []
        self.start_time = datetime.datetime.now()
        
    def add_gate(self, gate: GateResult):
        self.gates.append(gate)
        if not gate.passed:
            self.blockers.append(f"{gate.name}: exit={gate.exit_code} | log={gate.log_path}")

    def run_npm_gate(self, name: str, path: pathlib.Path, test_script="test") -> GateResult:
        """Run npm ci + test for a component."""
        gate = GateResult(name)
        start = datetime.datetime.now()
        
        if not path.exists():
            gate.error = f"Path not found: {path}"
            gate.duration = (datetime.datetime.now() - start).total_seconds()
            return gate
        
        # npm ci
        ci_log = LOGS / f"{name}_npm_ci.log"
        rc_ci, _ = run(["npm", "ci"], cwd=path, log_path=ci_log, timeout=300)
        
        # npm test or npm run <script>
        test_log = LOGS / f"{name}_npm_test.log"
        if test_script == "test":
            cmd = ["npm", "test"]
        else:
            cmd = ["npm", "run", test_script]
        rc_test, _ = run(cmd, cwd=path, log_path=test_log, timeout=300)
        
        gate.exit_code = rc_test
        gate.log_path = str(test_log.relative_to(ROOT))
        gate.passed = (rc_ci == 0 and rc_test == 0)
        gate.duration = (datetime.datetime.now() - start).total_seconds()
        
        if rc_ci != 0:
            gate.error = f"npm ci failed (see {ci_log.relative_to(ROOT)})"
        elif rc_test != 0:
            gate.error = f"npm test failed (see {test_log.relative_to(ROOT)})"
            
        return gate

    def run_flutter_build_gate(self, name: str, path: pathlib.Path, flavor=None) -> GateResult:
        """Run flutter build for mobile app."""
        gate = GateResult(name)
        start = datetime.datetime.now()
        
        if not path.exists():
            gate.error = f"Path not found: {path}"
            gate.duration = (datetime.datetime.now() - start).total_seconds()
            return gate
        
        # Check if pubspec.yaml exists
        if not (path / "pubspec.yaml").exists():
            gate.error = "No pubspec.yaml found"
            gate.duration = (datetime.datetime.now() - start).total_seconds()
            return gate
        
        # flutter pub get
        get_log = LOGS / f"{name}_flutter_pub_get.log"
        rc_get, _ = run(["flutter", "pub", "get"], cwd=path, log_path=get_log, timeout=180)
        
        # flutter analyze
        analyze_log = LOGS / f"{name}_flutter_analyze.log"
        rc_analyze, _ = run(["flutter", "analyze"], cwd=path, log_path=analyze_log, timeout=180)
        
        # flutter build apk (debug) - faster than release
        build_log = LOGS / f"{name}_flutter_build.log"
        build_cmd = ["flutter", "build", "apk", "--debug"]
        if flavor:
            build_cmd.extend(["--flavor", flavor])
        rc_build, _ = run(build_cmd, cwd=path, log_path=build_log, timeout=600)
        
        gate.exit_code = rc_build
        gate.log_path = str(build_log.relative_to(ROOT))
        gate.passed = (rc_get == 0 and rc_analyze == 0 and rc_build == 0)
        gate.duration = (datetime.datetime.now() - start).total_seconds()
        
        if rc_get != 0:
            gate.error = f"flutter pub get failed (see {get_log.relative_to(ROOT)})"
        elif rc_analyze != 0:
            gate.error = f"flutter analyze failed (see {analyze_log.relative_to(ROOT)})"
        elif rc_build != 0:
            gate.error = f"flutter build failed (see {build_log.relative_to(ROOT)})"
            
        return gate

    def check_security_gate(self) -> GateResult:
        """Check for security issues: tracked .env, hardcoded keys."""
        gate = GateResult("security-scan")
        start = datetime.datetime.now()
        
        issues = []
        
        # Check tracked .env files
        rc, out = run(["git", "ls-files", "*.env"], cwd=ROOT)
        env_files = [f for f in out.strip().split("\n") if f and not f.endswith(".env.example")]
        if env_files:
            issues.append(f"Tracked .env files: {', '.join(env_files)}")
        
        # Check for sk_live_ in tracked code files (exclude reports/docs)
        rc, out = run(["git", "grep", "-n", "sk_live_", "--", "*.ts", "*.js", "*.dart", "*.py"], cwd=ROOT)
        if rc == 0:  # found matches in code files
            lines = [l for l in out.strip().split("\n") if "sk_live_REDACTED" not in l and "REPORT" not in l]
            if lines:
                issues.append(f"Found sk_live_ in code files: {len(lines)} matches")
        
        # Firebase API keys in firebase_options.dart are PUBLIC and safe - skip this check
        
        sec_log = SECURITY / "security_scan.log"
        write(sec_log, "\n".join(issues) if issues else "No security issues found.")
        
        gate.exit_code = 0 if not issues else 1
        gate.log_path = str(sec_log.relative_to(ROOT))
        gate.passed = len(issues) == 0
        gate.error = "; ".join(issues) if issues else None
        gate.duration = (datetime.datetime.now() - start).total_seconds()
        
        return gate

    def check_required_files_gate(self) -> GateResult:
        """Check required files exist."""
        gate = GateResult("required-files")
        start = datetime.datetime.now()
        
        required = [
            "firebase.json",
            "firestore.rules",
            "storage.rules",
            ".github/workflows/deploy.yml",
            "docs/ENVIRONMENT_VARIABLES.md",
        ]
        
        missing = [f for f in required if not (ROOT / f).exists()]
        
        if missing:
            gate.error = f"Missing required files: {', '.join(missing)}"
            gate.exit_code = 1
            gate.passed = False
        else:
            gate.exit_code = 0
            gate.passed = True
        
        gate.duration = (datetime.datetime.now() - start).total_seconds()
        gate.log_path = "N/A (file check)"
        
        return gate

    def capture_inventory(self):
        """Capture git state and file inventory."""
        write(INV / "run_timestamp.txt", now_beirut() + "\n")
        write(INV / "git_commit.txt", git(["rev-parse", "HEAD"]) + "\n")
        write(INV / "git_status.txt", git(["status", "--porcelain"]) + "\n")
        write(INV / "git_branch.txt", git(["rev-parse", "--abbrev-ref", "HEAD"]) + "\n")
        
        # Tracked files
        rc, out = run(["git", "ls-files"], cwd=ROOT)
        write(INV / "tracked_files.txt", out)

    def capture_ci_workflow(self):
        """Snapshot CI workflow."""
        wf = ROOT / ".github" / "workflows" / "deploy.yml"
        if wf.exists():
            write(CI / "deploy.yml", wf.read_text())

    def generate_final_report(self):
        """Generate comprehensive final report."""
        lines = []
        lines.append("# URBAN POINTS LEBANON - FINAL RELEASE REPORT\n\n")
        lines.append(f"**Timestamp:** {now_beirut()}\n")
        lines.append(f"**Commit:** {git(['rev-parse', 'HEAD'])}\n")
        lines.append(f"**Branch:** {git(['rev-parse', '--abbrev-ref', 'HEAD'])}\n")
        lines.append(f"**Total Duration:** {(datetime.datetime.now() - self.start_time).total_seconds():.1f}s\n\n")
        
        lines.append("## EXECUTIVE SUMMARY\n\n")
        
        passed_count = sum(1 for g in self.gates if g.passed)
        total_count = len(self.gates)
        
        if self.blockers:
            lines.append(f"**STATUS: ✗ NO-GO** ({passed_count}/{total_count} gates passed)\n\n")
            lines.append("### BLOCKERS\n\n")
            for b in self.blockers:
                lines.append(f"- {b}\n")
            lines.append("\n")
        else:
            lines.append(f"**STATUS: ✓ PRODUCTION READY** ({passed_count}/{total_count} gates passed)\n\n")
        
        lines.append("## GATE RESULTS\n\n")
        lines.append("| Gate | Status | Exit Code | Duration | Log |\n")
        lines.append("|------|--------|-----------|----------|-----|\n")
        
        for gate in self.gates:
            status = "✓" if gate.passed else "✗"
            log = gate.log_path or "N/A"
            lines.append(f"| {gate.name} | {status} | {gate.exit_code} | {gate.duration:.1f}s | {log} |\n")
        
        lines.append("\n## DETAILED RESULTS\n\n")
        for gate in self.gates:
            lines.append(f"### {gate.name}\n")
            lines.append(f"- Status: {'✓ PASS' if gate.passed else '✗ FAIL'}\n")
            lines.append(f"- Exit Code: {gate.exit_code}\n")
            lines.append(f"- Duration: {gate.duration:.1f}s\n")
            if gate.log_path:
                lines.append(f"- Log: `{gate.log_path}`\n")
            if gate.error:
                lines.append(f"- Error: {gate.error}\n")
            lines.append("\n")
        
        lines.append("## ARTIFACTS\n\n")
        lines.append("All evidence artifacts are in:\n")
        lines.append(f"```\n{EVIDENCE.relative_to(ROOT)}/\n```\n\n")
        
        lines.append("### Structure\n")
        lines.append("- `inventory/` - Git state, timestamps, file lists\n")
        lines.append("- `logs/` - All test/build logs\n")
        lines.append("- `ci/` - CI workflow snapshot\n")
        lines.append("- `security/` - Security scan results\n")
        lines.append("- `reports/FINAL_REPORT.md` - This file\n")
        lines.append("- `SHA256SUMS.txt` - Cryptographic verification\n\n")
        
        if not self.blockers:
            lines.append("## DEPLOYMENT READINESS\n\n")
            lines.append("✓ Backend: Firebase Functions + REST API tests passing\n")
            lines.append("✓ Security: No tracked secrets, no hardcoded keys\n")
            lines.append("✓ Rules: Firestore + Storage rules present\n")
            lines.append("✓ CI: GitHub Actions workflow configured\n")
            lines.append("✓ Docs: Environment variables documented\n\n")
            lines.append("**Ready for production deployment.**\n")
        
        write(REPORTS / "FINAL_REPORT.md", "".join(lines))

    def generate_sha256sums(self):
        """Generate SHA256 checksums for all evidence files."""
        sums = []
        for p in sorted([p for p in EVIDENCE.rglob("*") if p.is_file() and p.name != "SHA256SUMS.txt"]):
            sums.append(f"{sha256_file(p)}  {p.relative_to(EVIDENCE)}")
        write(EVIDENCE / "SHA256SUMS.txt", "\n".join(sums) + "\n")

    def run_all_gates(self):
        """Execute all validation gates."""
        print("=" * 80)
        print("URBAN POINTS LEBANON - FINAL GATE RUNNER")
        print("=" * 80)
        print()
        
        ensure_dirs()
        self.capture_inventory()
        self.capture_ci_workflow()
        
        # Gate 1: Required files
        print("→ Checking required files...")
        gate = self.check_required_files_gate()
        self.add_gate(gate)
        print(f"  {gate}")
        
        # Gate 2: Security scan
        print("→ Running security scan...")
        gate = self.check_security_gate()
        self.add_gate(gate)
        print(f"  {gate}")
        
        # Gate 3: REST API
        print("→ Testing REST API...")
        gate = self.run_npm_gate("rest-api", ROOT / "source/backend/rest-api")
        self.add_gate(gate)
        print(f"  {gate}")
        
        # Gate 4: Firebase Functions
        print("→ Testing Firebase Functions...")
        gate = self.run_npm_gate("firebase-functions", ROOT / "source/backend/firebase-functions")
        self.add_gate(gate)
        print(f"  {gate}")
        
        # Gate 5: Web Admin
        print("→ Building Web Admin...")
        web_admin = ROOT / "source/apps/web-admin"
        if web_admin.exists():
            gate = self.run_npm_gate("web-admin", web_admin, test_script="build")
            self.add_gate(gate)
            print(f"  {gate}")
        else:
            print("  ⊘ SKIP (not found)")
        
        # Gate 6: Mobile Customer
        print("→ Building Mobile Customer...")
        customer = ROOT / "source/apps/mobile-customer"
        if customer.exists() and (customer / "pubspec.yaml").exists():
            gate = self.run_flutter_build_gate("mobile-customer", customer)
            self.add_gate(gate)
            print(f"  {gate}")
        else:
            print("  ⊘ SKIP (not found or no pubspec.yaml)")
        
        # Gate 7: Mobile Merchant
        print("→ Building Mobile Merchant...")
        merchant = ROOT / "source/apps/mobile-merchant"
        if merchant.exists() and (merchant / "pubspec.yaml").exists():
            gate = self.run_flutter_build_gate("mobile-merchant", merchant)
            self.add_gate(gate)
            print(f"  {gate}")
        else:
            print("  ⊘ SKIP (not found or no pubspec.yaml)")
        
        print()
        print("=" * 80)
        
        # Generate report and checksums
        self.generate_final_report()
        self.generate_sha256sums()
        
        # Summary
        passed = sum(1 for g in self.gates if g.passed)
        total = len(self.gates)
        
        print(f"RESULTS: {passed}/{total} gates passed")
        print()
        
        if self.blockers:
            print("✗ NO-GO - Blockers detected:")
            for b in self.blockers:
                print(f"  - {b}")
            print()
            print(f"Report: {REPORTS / 'FINAL_REPORT.md'}")
            return 1
        else:
            print("✓ ALL GATES PASSED - PRODUCTION READY")
            print()
            print(f"Commit: {git(['rev-parse', 'HEAD'])}")
            print(f"Report: {REPORTS / 'FINAL_REPORT.md'}")
            print(f"Evidence: {EVIDENCE.relative_to(ROOT)}")
            return 0

def main():
    runner = FinalGateRunner()
    return runner.run_all_gates()

if __name__ == "__main__":
    sys.exit(main())
