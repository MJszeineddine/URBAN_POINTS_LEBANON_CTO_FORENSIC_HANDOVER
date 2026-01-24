#!/usr/bin/env python3
import os
import re
import sys
import json
import shutil
import hashlib
import subprocess
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Paths
REPO_ROOT = Path(__file__).resolve().parents[2]
SCAN_BASE = REPO_ROOT / "local-ci" / "verification" / "reality_scan"
TIMESTAMP = time.strftime("%Y-%m-%d_%H%M%S")
BUNDLE_DIR = SCAN_BASE / f"SCAN_{TIMESTAMP}"

# Components paths
APPS_DIR = REPO_ROOT / "source" / "apps"
FB_FUNC_DIR = REPO_ROOT / "source" / "backend" / "firebase-functions"
REST_API_DIR = REPO_ROOT / "source" / "backend" / "rest-api"
WEB_ADMIN_DIR = APPS_DIR / "web-admin"

# Infra paths
FIREBASE_JSON_CANDIDATES = [REPO_ROOT / "firebase.json", REPO_ROOT / "source" / "firebase.json"]
FIRESTORE_RULES = REPO_ROOT / "source" / "infra" / "firestore.rules"
FIREBASE_RC = REPO_ROOT / "source" / "infra" / ".firebaserc"

SENSITIVE_KEYS = {"QR_TOKEN_SECRET", "STRIPE_SECRET_KEY", "JWT_SECRET", "TWILIO_AUTH_TOKEN", "DATABASE_URL", "SENTRY_DSN"}


def redact(s: str) -> str:
    if not s:
        return s
    r = s
    for k in SENSITIVE_KEYS:
        r = re.sub(rf"{k}=['\"]?[^'\"\s]+['\"]?", f"{k}=REDACTED", r, flags=re.IGNORECASE)
        if "token" in k.lower() or "secret" in k.lower():
            r = re.sub(r"(['\"])[-A-Za-z0-9_\.]{20,}(['\"])", r"\\1REDACTED\\2", r)
    return r


def run(cmd: List[str], cwd: Optional[Path] = None, timeout: int = 900) -> Tuple[int, str, str]:
    try:
        p = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, timeout=timeout)
        return p.returncode, redact(p.stdout), redact(p.stderr)
    except subprocess.TimeoutExpired:
        return 1, "", f"TIMEOUT after {timeout}s"


def ensure_dir(p: Path):
    p.mkdir(parents=True, exist_ok=True)


def write_text(p: Path, txt: str):
    ensure_dir(p.parent)
    with p.open("w", encoding="utf-8") as f:
        f.write(txt)


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def compute_hashes(root: Path, dst: Path):
    lines = []
    for p in sorted(root.rglob("*")):
        if p.is_file():
            lines.append(f"{sha256_file(p)}  {p.relative_to(root)}")
    write_text(dst, "\n".join(lines))


def now_utc() -> str:
    return time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())


def now_beirut() -> str:
    try:
        from zoneinfo import ZoneInfo  # Python 3.9+
        tz = ZoneInfo("Asia/Beirut")
        return time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime(time.time()))
    except Exception:
        # Fallback: approximate by printing localtime
        return time.strftime("%Y-%m-%d %H:%M:%S LOCAL", time.localtime())


def git_info() -> Tuple[bool, str, str]:
    code, status_out, _ = run(["git", "status", "--porcelain"], cwd=REPO_ROOT)
    clean = (code == 0 and status_out.strip() == "")
    code2, rev_out, _ = run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO_ROOT)
    rev = rev_out.strip() if code2 == 0 else "UNKNOWN"
    return clean, rev, status_out


def detect_flutter_apps() -> List[Dict]:
    apps = []
    if APPS_DIR.exists():
        for p in APPS_DIR.rglob("pubspec.yaml"):
            apps.append({"path": str(p.parent), "name": p.parent.name})
    return apps


def detect_node_projects() -> List[Dict]:
    projects = []
    for p in [WEB_ADMIN_DIR, FB_FUNC_DIR, REST_API_DIR]:
        pkg = p / "package.json"
        if pkg.exists():
            try:
                data = json.loads(pkg.read_text(encoding="utf-8"))
            except Exception:
                data = {}
            projects.append({
                "path": str(p),
                "name": p.name,
                "has_tests": bool(data.get("scripts", {}).get("test")),
                "pkg": data,
            })
    return projects


def detect_nextjs(project: Dict) -> bool:
    pkg = project.get("pkg", {})
    deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
    has_next_dep = "next" in deps
    has_next_script = any("next" in (pkg.get("scripts", {}).get(k, "")) for k in pkg.get("scripts", {}))
    return has_next_dep or has_next_script


def detect_infra() -> Dict:
    firebase_json = None
    for c in FIREBASE_JSON_CANDIDATES:
        if c.exists():
            firebase_json = str(c)
            break
    return {
        "firebase_json": firebase_json,
        "firestore_rules": str(FIRESTORE_RULES) if FIRESTORE_RULES.exists() else None,
        "firebaserc": str(FIREBASE_RC) if FIREBASE_RC.exists() else None,
        "ci_dirs": [str(p) for p in [REPO_ROOT / "local-ci", REPO_ROOT / "tools"] if p.exists()],
    }


def node_build_and_tests(project_path: Path) -> Tuple[bool, bool, int, Dict[str, str]]:
    logs = {}
    # npm ci
    code_ci, out_ci, err_ci = run(["npm", "ci"], cwd=project_path)
    logs["npm_ci"] = f"exit={code_ci}\n{out_ci}\n{err_ci}"
    build_pass = False
    tests_pass = False
    discovered = 0
    if code_ci == 0:
        code_build, out_build, err_build = run(["npm", "run", "build"], cwd=project_path)
        logs["npm_build"] = f"exit={code_build}\n{out_build}\n{err_build}"
        build_pass = (code_build == 0)
        # tests if script exists
        pkg = project_path / "package.json"
        try:
            data = json.loads(pkg.read_text(encoding="utf-8"))
        except Exception:
            data = {}
        if data.get("scripts", {}).get("test"):
            # list tests via jest if available
            code_list, out_list, err_list = run(["npm", "test", "--", "--listTests", "--no-passWithNoTests"], cwd=project_path)
            logs["jest_list_tests"] = f"exit={code_list}\n{out_list}\n{err_list}"
            if code_list == 0:
                discovered = len([ln for ln in out_list.splitlines() if ln.strip()])
            # run tests strictly
            code_test, out_test, err_test = run(["npm", "test", "--", "--no-passWithNoTests"], cwd=project_path)
            logs["npm_test"] = f"exit={code_test}\n{out_test}\n{err_test}"
            tests_pass = (code_test == 0 and discovered > 0)
    return build_pass, tests_pass, discovered, logs


def flutter_analyze(app_path: Path) -> Tuple[bool, Dict[str, str]]:
    logs = {}
    code_ver, out_ver, err_ver = run(["flutter", "--version"], cwd=app_path)
    logs["flutter_version"] = f"exit={code_ver}\n{out_ver}\n{err_ver}"
    if code_ver != 0:
        logs["flutter_analyze"] = "BLOCKED: flutter not available"
        return False, logs
    code_an, out_an, err_an = run(["flutter", "analyze"], cwd=app_path)
    logs["flutter_analyze"] = f"exit={code_an}\n{out_an}\n{err_an}"
    return code_an == 0, logs


def run_staging_gate() -> Tuple[int, str, str]:
    gate = REPO_ROOT / "tools" / "gates" / "staging_gate_runner.py"
    if gate.exists():
        return run([sys.executable, str(gate), "--allow-skip-deploy"], cwd=REPO_ROOT)
    return 0, "(staging_gate_runner.py not found)", ""


def readiness_score(build_pass: bool, tests_pass: bool, tests_discovered: int, config_present: bool, tool_missing: bool) -> Tuple[int, List[str]]:
    score = 0
    blockers = []
    if build_pass:
        score += 40
    else:
        blockers.append("Build failed or not executed")
    if tests_pass and tests_discovered > 0:
        score += 40
    else:
        blockers.append("Tests failed or 0 discovered")
    if config_present:
        score += 20
    else:
        blockers.append("Config missing")
    if tool_missing:
        blockers.append("Required tool missing; capped at 20")
        score = min(score, 20)
    return score, blockers


def main():
    # Prepare bundle dirs
    ensure_dir(BUNDLE_DIR / "reports")
    ensure_dir(BUNDLE_DIR / "logs")
    ensure_dir(BUNDLE_DIR / "stdout")
    ensure_dir(BUNDLE_DIR / "hashes")

    # Capture dates and git
    clean, rev, porcelain = git_info()
    meta = {
        "date_utc": now_utc(),
        "date_beirut": now_beirut(),
        "git_rev": rev,
        "git_clean": clean,
    }

    # Inventory
    flutter_apps = detect_flutter_apps()
    node_projects = detect_node_projects()
    infra = detect_infra()
    inventory = {
        "flutter_apps": flutter_apps,
        "node_projects": node_projects,
        "infra": infra,
    }

    # Run staging gate (safe local verification)
    gate_code, gate_out, gate_err = run_staging_gate()
    write_text(BUNDLE_DIR / "logs" / "staging_gate_run.log", f"exit={gate_code}\n{gate_out}\n{gate_err}")
    write_text(BUNDLE_DIR / "stdout" / "run.out.txt", gate_out)
    write_text(BUNDLE_DIR / "stdout" / "run.err.txt", gate_err)
    write_text(BUNDLE_DIR / "stdout" / "run.exit.txt", str(gate_code))

    # Per-component verification
    readiness: Dict[str, Dict] = {}

    # Node projects: web-admin, firebase-functions, rest-api
    for proj in node_projects:
        p = Path(proj["path"])
        build_pass, tests_pass, discovered, logs = node_build_and_tests(p)
        # Determine config presence
        config_present = False
        if p == FB_FUNC_DIR:
            config_present = infra.get("firebase_json") is not None
        elif p == REST_API_DIR:
            config_present = (REST_API_DIR / "tsconfig.json").exists()
        elif p == WEB_ADMIN_DIR:
            config_present = (WEB_ADMIN_DIR / "tsconfig.json").exists()
        # Tool missing (Node/npm assumed available as we're running npm; infer from ci exit)
        tool_missing = False
        if "exit=" in logs.get("npm_ci", "") and logs["npm_ci"].startswith("exit=") and logs["npm_ci"].split("\n")[0] != "exit=0":
            # npm not available or install failed; treat as tool missing for score capping
            tool_missing = False  # Install failure isn't tool missing; leave False
        score, blockers = readiness_score(build_pass, tests_pass, discovered, config_present, tool_missing)
        readiness[p.name] = {
            "path": str(p),
            "build_pass": build_pass,
            "tests_pass": tests_pass,
            "tests_discovered": discovered,
            "config_present": config_present,
            "tool_missing": tool_missing,
            "score": score,
            "blockers": blockers,
            "is_nextjs": detect_nextjs(proj),
        }
        # Write logs per project
        for k, v in logs.items():
            write_text(BUNDLE_DIR / "logs" / f"{p.name}_{k}.log", v)

    # Flutter apps
    for app in flutter_apps:
        app_path = Path(app["path"]) if isinstance(app, dict) else Path(app)
        ok, fl_logs = flutter_analyze(app_path)
        tool_missing = "exit=" in fl_logs.get("flutter_version", "") and not fl_logs["flutter_version"].startswith("exit=0")
        # Config present for flutter: pubspec.yaml exists
        config_present = (app_path / "pubspec.yaml").exists()
        build_pass = ok  # analysis success treated as build pass for readiness
        tests_pass = False
        discovered = 0
        score, blockers = readiness_score(build_pass, tests_pass, discovered, config_present, tool_missing)
        readiness[app_path.name] = {
            "path": str(app_path),
            "build_pass": build_pass,
            "tests_pass": tests_pass,
            "tests_discovered": discovered,
            "config_present": config_present,
            "tool_missing": tool_missing,
            "score": score,
            "blockers": blockers,
        }
        for k, v in fl_logs.items():
            write_text(BUNDLE_DIR / "logs" / f"{app_path.name}_{k}.log", v)

    # Infra component readiness (optional)
    infra_ready = {
        "firebase_json_present": bool(infra.get("firebase_json")),
        "firestore_rules_present": bool(infra.get("firestore_rules")),
        "firebaserc_present": bool(infra.get("firebaserc")),
    }

    # Reports
    summary_lines = [
        f"Reality Scan (UTC): {meta['date_utc']}",
        f"Reality Scan (Beirut): {meta['date_beirut']}",
        f"Git rev: {meta['git_rev']} | Clean: {meta['git_clean']}",
        "",
        "Components Readiness:",
    ]
    for name, info in readiness.items():
        summary_lines.append(f"- {name}: score={info['score']} build_pass={info['build_pass']} tests_pass={info['tests_pass']} tests_discovered={info['tests_discovered']} config_present={info['config_present']}")
        if info["blockers"]:
            for b in info["blockers"]:
                summary_lines.append(f"  • BLOCKER: {b}")
    summary_lines.append("")
    summary_lines.append(f"Infra: firebase_json_present={infra_ready['firebase_json_present']} firestore_rules_present={infra_ready['firestore_rules_present']} firebaserc_present={infra_ready['firebaserc_present']}")

    write_text(BUNDLE_DIR / "reports" / "SUMMARY.md", "\n".join(summary_lines))
    write_text(BUNDLE_DIR / "reports" / "INVENTORY.json", json.dumps(inventory, indent=2))
    write_text(BUNDLE_DIR / "reports" / "READINESS.json", json.dumps(readiness, indent=2))
    # BLOCKERS.md
    blockers_all = []
    for name, info in readiness.items():
        for b in info.get("blockers", []):
            blockers_all.append(f"- {name}: {b}")
    write_text(BUNDLE_DIR / "reports" / "BLOCKERS.md", "\n".join(blockers_all) if blockers_all else "(none)")

    # Hashes
    compute_hashes(BUNDLE_DIR, BUNDLE_DIR / "hashes" / "SHA256SUMS.txt")

    # Final required prints
    print(f"SCAN_BUNDLE_PATH={BUNDLE_DIR}")
    print(f"SUMMARY_MD={BUNDLE_DIR / 'reports' / 'SUMMARY.md'}")
    print(f"SHA256SUMS={BUNDLE_DIR / 'hashes' / 'SHA256SUMS.txt'}")
    print(f"READINESS_JSON={BUNDLE_DIR / 'reports' / 'READINESS.json'}")


if __name__ == "__main__":
    # Ensure base dirs
    ensure_dir(BUNDLE_DIR)
    main()
