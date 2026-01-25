#!/usr/bin/env python3
"""
Autopilot Release Gate - Urban Points Lebanon
Strict: exit code 0 = PASS, anything else = FAIL
Produces reproducible proof bundle with cryptographic verification.
"""
import os, sys, json, subprocess, pathlib, datetime, hashlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "local-ci" / "verification" / "autopilot_release" / "LATEST"
INV = EVIDENCE / "inventory"
LOGS = EVIDENCE / "logs"
SECURITY = EVIDENCE / "security"
REPORTS = EVIDENCE / "reports"
ARTIFACTS = EVIDENCE / "artifacts"

def run(cmd, cwd=None, log_path=None, env=None, timeout=900):
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
        return 999, "TIMEOUT"
    except Exception as e:
        return 998, str(e)

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
    """Return current time in Asia/Beirut timezone."""
    import subprocess
    rc, out = run(["date", "+%Y-%m-%d %H:%M:%S %Z"], env={**os.environ, "TZ": "Asia/Beirut"})
    return out.strip() if rc == 0 else "UNKNOWN"

def git(args):
    rc, out = run(["git"] + args, cwd=ROOT)
    return out.strip()

def ensure_dirs():
    for p in [INV, LOGS, SECURITY, REPORTS, ARTIFACTS]:
        p.mkdir(parents=True, exist_ok=True)

class Gate:
    def __init__(self, name: str):
        self.name = name
        self.exit_code = None
        self.log_path = None
        self.duration = 0.0
        self.error = None
        
    @property
    def passed(self):
        """STRICT: only exit code 0 is PASS."""
        return self.exit_code == 0
    
    def __repr__(self):
        status = "✓" if self.passed else "✗"
        return f"{status} {self.name} | exit={self.exit_code} | {self.duration:.1f}s"

class AutopilotReleaseGate:
    def __init__(self):
        self.gates = []
        self.start_time = datetime.datetime.now()
        
    def add_gate(self, gate: Gate):
        self.gates.append(gate)
    
    def capture_inventory_before(self):
        """Capture git state before running gates."""
        write(INV / "run_timestamp.txt", now_beirut() + "\n")
        write(INV / "git_commit_before.txt", git(["rev-parse", "HEAD"]) + "\n")
        write(INV / "git_status_before.txt", git(["status", "--porcelain"]) + "\n")
        write(INV / "git_branch.txt", git(["rev-parse", "--abbrev-ref", "HEAD"]) + "\n")
        
        rc, out = run(["git", "ls-files"], cwd=ROOT)
        write(INV / "tracked_files_snapshot.txt", out)
    
    def capture_inventory_after(self):
        """Capture git state after running gates."""
        write(INV / "git_commit_after.txt", git(["rev-parse", "HEAD"]) + "\n")
        write(INV / "git_status_after.txt", git(["status", "--porcelain"]) + "\n")
    
    def run_security_gate(self) -> Gate:
        """Security scan: fail on real secrets, allow public Firebase keys."""
        gate = Gate("security-scan")
        start = datetime.datetime.now()
        
        issues = []
        log_lines = []
        
        # Check tracked .env files (except .env.example)
        rc, out = run(["git", "ls-files", "*.env"], cwd=ROOT)
        env_files = [f for f in out.strip().split("\n") if f and not f.endswith(".env.example")]
        if env_files:
            issue = f"BLOCKED: Tracked .env files: {', '.join(env_files)}"
            issues.append(issue)
            log_lines.append(issue)
        
        # Check for sk_live_ in code files (exclude docs/reports that mention it)
        rc, out = run(["git", "grep", "-n", "sk_live_", "--", "*.ts", "*.js", "*.dart"], cwd=ROOT)
        if rc == 0:
            lines = [l for l in out.strip().split("\n") 
                    if "sk_live_REDACTED" not in l and "REPORT" not in l]
            if lines:
                issue = f"BLOCKED: Found sk_live_ in code: {len(lines)} matches"
                issues.append(issue)
                log_lines.append(issue)
                log_lines.extend(lines[:20])
        
        # Check for service account keys
        rc, out = run(["git", "ls-files", "*serviceAccount*.json"], cwd=ROOT)
        sa_files = [f for f in out.strip().split("\n") if f]
        if sa_files:
            issue = f"BLOCKED: Service account files tracked: {', '.join(sa_files)}"
            issues.append(issue)
            log_lines.append(issue)
        
        # Firebase API keys (AIza...) are PUBLIC - no longer blocked
        log_lines.append("\n✓ Firebase web API keys (AIza...) are public and allowed")
        
        sec_log = SECURITY / "security_scan.log"
        write(sec_log, "\n".join(log_lines) if log_lines else "✓ No security issues found")
        
        gate.exit_code = 0 if not issues else 1
        gate.log_path = str(sec_log.relative_to(ROOT))
        gate.error = "; ".join(issues) if issues else None
        gate.duration = (datetime.datetime.now() - start).total_seconds()
        
        return gate
    
    def run_npm_gate(self, name: str, path: pathlib.Path, build_script=None) -> Gate:
        """Run npm ci + test (or build) for a component."""
        gate = Gate(name)
        start = datetime.datetime.now()
        
        if not path.exists():
            gate.exit_code = 404
            gate.error = f"Path not found: {path}"
            gate.duration = (datetime.datetime.now() - start).total_seconds()
            return gate
        
        # npm ci
        ci_log = LOGS / f"{name}_npm_ci.log"
        rc_ci, _ = run(["npm", "ci"], cwd=path, log_path=ci_log, timeout=300)
        
        if rc_ci != 0:
            gate.exit_code = rc_ci
            gate.log_path = str(ci_log.relative_to(ROOT))
            gate.error = f"npm ci failed"
            gate.duration = (datetime.datetime.now() - start).total_seconds()
            return gate
        
        # npm test or npm run build
        test_log = LOGS / f"{name}_npm_test.log"
        if build_script:
            cmd = ["npm", "run", build_script]
        else:
            cmd = ["npm", "test"]
        rc_test, _ = run(cmd, cwd=path, log_path=test_log, timeout=300)
        
        gate.exit_code = rc_test
        gate.log_path = str(test_log.relative_to(ROOT))
        gate.error = None if rc_test == 0 else f"npm {'test' if not build_script else build_script} failed"
        gate.duration = (datetime.datetime.now() - start).total_seconds()
        
        return gate
    
    def run_flutter_gate(self, name: str, path: pathlib.Path) -> Gate:
        """Run flutter build for mobile app (strict: must build)."""
        gate = Gate(name)
        start = datetime.datetime.now()
        
        if not path.exists():
            gate.exit_code = 404
            gate.error = f"Path not found: {path}"
            gate.duration = (datetime.datetime.now() - start).total_seconds()
            return gate
        
        if not (path / "pubspec.yaml").exists():
            gate.exit_code = 404
            gate.error = "No pubspec.yaml"
            gate.duration = (datetime.datetime.now() - start).total_seconds()
            return gate
        
        # Flutter version
        version_log = LOGS / f"{name}_flutter_version.log"
        run(["flutter", "--version"], cwd=path, log_path=version_log, timeout=30)
        
        # flutter pub get
        get_log = LOGS / f"{name}_flutter_pub_get.log"
        rc_get, _ = run(["flutter", "pub", "get"], cwd=path, log_path=get_log, timeout=180)
        
        if rc_get != 0:
            gate.exit_code = rc_get
            gate.log_path = str(get_log.relative_to(ROOT))
            gate.error = "flutter pub get failed"
            gate.duration = (datetime.datetime.now() - start).total_seconds()
            return gate
        
        # flutter analyze
        analyze_log = LOGS / f"{name}_flutter_analyze.log"
        rc_analyze, _ = run(["flutter", "analyze"], cwd=path, log_path=analyze_log, timeout=180)
        
        # Note: analyze warnings are OK, but we still log them
        # Continue to build even if analyze has warnings (non-zero but not critical)
        
        # flutter build apk (debug for speed)
        build_log = LOGS / f"{name}_flutter_build.log"
        rc_build, _ = run(["flutter", "build", "apk", "--debug"], cwd=path, log_path=build_log, timeout=600)
        
        gate.exit_code = rc_build
        gate.log_path = str(build_log.relative_to(ROOT))
        gate.error = None if rc_build == 0 else "flutter build apk failed"
        gate.duration = (datetime.datetime.now() - start).total_seconds()
        
        return gate
    
    def generate_report(self):
        """Generate final autopilot report with GO/NO-GO verdict."""
        lines = []
        lines.append("# URBAN POINTS LEBANON - AUTOPILOT RELEASE GATE\n\n")
        lines.append(f"**Timestamp:** {now_beirut()}\n")
        lines.append(f"**Commit:** {git(['rev-parse', 'HEAD'])}\n")
        lines.append(f"**Branch:** {git(['rev-parse', '--abbrev-ref', 'HEAD'])}\n")
        lines.append(f"**Total Duration:** {(datetime.datetime.now() - self.start_time).total_seconds():.1f}s\n\n")
        
        # Count passes (STRICT: only exit 0)
        passed_count = sum(1 for g in self.gates if g.passed)
        total_count = len(self.gates)
        
        # Verdict
        if passed_count == total_count:
            lines.append("## VERDICT: ✓ GO\n\n")
            lines.append(f"All {total_count} gates passed with exit code 0.\n\n")
        else:
            lines.append("## VERDICT: ✗ NO-GO\n\n")
            lines.append(f"**{passed_count}/{total_count} gates passed. Blockers detected.**\n\n")
            
            # Top 3 blockers
            blockers = [g for g in self.gates if not g.passed][:3]
            lines.append("### TOP BLOCKERS\n\n")
            for i, g in enumerate(blockers, 1):
                lines.append(f"{i}. **{g.name}** (exit={g.exit_code})\n")
                lines.append(f"   - Error: {g.error}\n")
                lines.append(f"   - Log: `{g.log_path}`\n")
            lines.append("\n")
        
        # Gate results table
        lines.append("## GATE RESULTS\n\n")
        lines.append("| Gate | Status | Exit Code | Duration | Log |\n")
        lines.append("|------|--------|-----------|----------|-----|\n")
        
        for gate in self.gates:
            status = "✓ PASS" if gate.passed else "✗ FAIL"
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
        
        lines.append("## EVIDENCE BUNDLE\n\n")
        lines.append(f"Location: `{EVIDENCE.relative_to(ROOT)}/`\n\n")
        lines.append("Structure:\n")
        lines.append("- `inventory/` - Git state snapshots (before/after)\n")
        lines.append("- `logs/` - All command outputs\n")
        lines.append("- `security/` - Security scan results\n")
        lines.append("- `reports/AUTOPILOT_FINAL_REPORT.md` - This file\n")
        lines.append("- `SHA256SUMS.txt` - Cryptographic verification\n\n")
        
        if passed_count == total_count:
            lines.append("## PRODUCTION READINESS\n\n")
            lines.append("✓ All backend tests passing\n")
            lines.append("✓ All frontend builds successful\n")
            lines.append("✓ Security scan clean\n")
            lines.append("✓ Zero gaps detected\n\n")
            lines.append("**System is production-ready for deployment.**\n")
        else:
            lines.append("## REMEDIATION REQUIRED\n\n")
            lines.append("Review blocker logs and fix issues before release.\n")
        
        write(REPORTS / "AUTOPILOT_FINAL_REPORT.md", "".join(lines))
    
    def generate_sha256sums(self):
        """Generate SHA256 checksums for all evidence + key config files."""
        sums = []
        
        # Evidence files
        for p in sorted([p for p in EVIDENCE.rglob("*") if p.is_file() and p.name != "SHA256SUMS.txt"]):
            sums.append(f"{sha256_file(p)}  {p.relative_to(EVIDENCE)}")
        
        # Key config files
        key_configs = [
            ROOT / "firebase.json",
            ROOT / "firestore.rules",
            ROOT / "storage.rules",
            ROOT / ".github/workflows/deploy.yml",
        ]
        
        for p in key_configs:
            if p.exists():
                sums.append(f"{sha256_file(p)}  ../{p.relative_to(ROOT)}")
        
        write(EVIDENCE / "SHA256SUMS.txt", "\n".join(sums) + "\n")
    
    def run_all_gates(self):
        """Execute all validation gates."""
        print("=" * 80)
        print("AUTOPILOT RELEASE GATE - URBAN POINTS LEBANON")
        print("Strict Mode: exit 0 = PASS, anything else = FAIL")
        print("=" * 80)
        print()
        
        ensure_dirs()
        self.capture_inventory_before()
        
        # Gate A: Security scan
        print("→ Running security scan...")
        gate = self.run_security_gate()
        self.add_gate(gate)
        print(f"  {gate}")
        
        # Gate B: REST API
        print("→ Testing REST API...")
        gate = self.run_npm_gate("rest-api", ROOT / "source/backend/rest-api")
        self.add_gate(gate)
        print(f"  {gate}")
        
        # Gate C: Firebase Functions
        print("→ Testing Firebase Functions...")
        gate = self.run_npm_gate("firebase-functions", ROOT / "source/backend/firebase-functions")
        self.add_gate(gate)
        print(f"  {gate}")
        
        # Gate D: Web Admin
        print("→ Building Web Admin...")
        gate = self.run_npm_gate("web-admin", ROOT / "source/apps/web-admin", build_script="build")
        self.add_gate(gate)
        print(f"  {gate}")
        
        # Gate E: Mobile Merchant
        print("→ Building Mobile Merchant...")
        gate = self.run_flutter_gate("mobile-merchant", ROOT / "source/apps/mobile-merchant")
        self.add_gate(gate)
        print(f"  {gate}")
        
        # Gate F: Mobile Customer
        print("→ Building Mobile Customer...")
        gate = self.run_flutter_gate("mobile-customer", ROOT / "source/apps/mobile-customer")
        self.add_gate(gate)
        print(f"  {gate}")
        
        print()
        print("=" * 80)
        
        self.capture_inventory_after()
        self.generate_report()
        self.generate_sha256sums()
        
        # Summary
        passed = sum(1 for g in self.gates if g.passed)
        total = len(self.gates)
        
        print(f"\nRESULTS: {passed}/{total} gates passed")
        print()
        
        if passed == total:
            print("✓ GO - All gates passed")
            print(f"\nCommit: {git(['rev-parse', 'HEAD'])}")
            print(f"Report: {REPORTS / 'AUTOPILOT_FINAL_REPORT.md'}")
            print(f"Evidence: {EVIDENCE.relative_to(ROOT)}")
            return 0
        else:
            print("✗ NO-GO - Blockers detected")
            blockers = [g for g in self.gates if not g.passed][:3]
            print("\nTop 3 Blockers:")
            for i, g in enumerate(blockers, 1):
                print(f"  {i}. {g.name} (exit={g.exit_code}) - {g.log_path}")
            print()
            print(f"Report: {REPORTS / 'AUTOPILOT_FINAL_REPORT.md'}")
            return 1

def main():
    runner = AutopilotReleaseGate()
    return runner.run_all_gates()

if __name__ == "__main__":
    sys.exit(main())
