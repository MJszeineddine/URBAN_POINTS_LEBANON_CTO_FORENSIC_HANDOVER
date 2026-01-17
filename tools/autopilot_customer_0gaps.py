#!/usr/bin/env python3
import json, os, re, sys, time
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VER = ROOT / "local-ci" / "verification"
REQS = ROOT / "spec" / "requirements.yaml"

def sh(cmd, log, timeout=120, cwd=None):
    runner = ROOT / "tools" / "run_with_timeout.py"
    c = ["python3", str(runner), "--timeout", str(timeout), "--log", str(log), "--"] + cmd
    return subprocess.call(c, cwd=str(cwd or ROOT))

def read_json(p):
    return json.loads(Path(p).read_text(encoding="utf-8"))

def write_fail(msg):
    VER.mkdir(parents=True, exist_ok=True)
    (VER / "autopilot_fail.txt").write_text(msg + "\n", encoding="utf-8")
    print(msg, file=sys.stderr)

def run_gate():
    code = sh(["python3", "tools/gates/cto_verify.py"], VER / "gate_run.log", 120, ROOT)
    report = VER / "cto_verify_report.json"
    if not report.exists():
        write_fail("FAIL: cto_verify_report.json not created. See local-ci/verification/gate_run.log")
        return code, None
    return code, read_json(report)

def failing_customer_ids(report):
    fails = report.get("failures", []) or report.get("details", []) or []
    # robust: scan all text for IDs
    txt = json.dumps(report)
    ids = sorted(set(re.findall(r"\b(CUST-[A-Z0-9\-]+|TEST-CUSTOMER-[A-Z0-9\-]+)\b", txt)))
    # filter to those with non-READY status if present
    bad = []
    req_map = {r.get("id"): r for r in (report.get("requirements") or []) if isinstance(r, dict)}
    if req_map:
        for rid in ids:
            st = (req_map.get(rid, {}).get("status") or "").upper()
            if st and st not in ("READY", "BLOCKED"):
                bad.append(rid)
        if bad:
            return bad
    return ids

def ensure_dirs():
    VER.mkdir(parents=True, exist_ok=True)

def main():
    ensure_dirs()
    # Phase A: baseline flutter analyze/test determinism for customer app
    cust = ROOT / "source/apps/mobile-customer"
    if not cust.exists():
        write_fail("FAIL: customer app path missing: source/apps/mobile-customer")
        return 2

    # Always run analyze/test once per loop, but first prove tools exist
    gate_code, report = run_gate()
    if report is None:
        return 2

    max_iters = 30
    for it in range(1, max_iters + 1):
        ids = failing_customer_ids(report)
        if not ids:
            # Either everything READY/BLOCKED or gate has no customer failures
            break

        # Pick ONE requirement to fix at a time (highest priority order)
        priority = [
            "TEST-CUSTOMER-",
            "CUST-NOTIF-003",
            "CUST-REDEEM-002",
            "CUST-REDEEM-003",
            "CUST-OFFER-005",
            "CUST-GDPR-001",
            "CUST-GDPR-002",
            "CUST-OFFER-002",
            "CUST-OFFER-003",
        ]
        chosen = None
        for p in priority:
            for rid in ids:
                if rid.startswith(p) or rid == p:
                    chosen = rid
                    break
            if chosen:
                break
        if not chosen:
            chosen = ids[0]

        # Stop if this needs external creds: we only BLOCK with a blocker doc after actual error evidence.
        # NOTE: actual implementation is performed by Copilot edits, not this script.
        # This script is an enforcer: it runs tests/gate and refuses status flips without proof.
        (VER / "autopilot_customer.log").write_text(
            f"ITER {it}/{max_iters}\nCHOSEN={chosen}\n",
            encoding="utf-8"
        )

        print(f"\n=== AUTOPILOT ITER {it}: Fix {chosen} ===\n")

        # Run flutter analyze/test (must be deterministic)
        code_a = sh(["/opt/homebrew/bin/flutter", "analyze"], VER / "customer_app_analyze.log", 120, cust)
        if code_a != 0:
            write_fail(f"FAIL: flutter analyze failed (exit {code_a}). Fix code, then re-run autopilot.\nChosen={chosen}")
            return 3

        code_t = sh(["/opt/homebrew/bin/flutter", "test"], VER / "customer_app_test.log", 120, cust)
        if code_t == 124:
            write_fail("FAIL: flutter test timed out. Fix root cause (async loops/Firebase init/DI/mocks), then re-run autopilot.")
            return 4
        if code_t != 0:
            write_fail(f"FAIL: flutter test failed (exit {code_t}). Fix failing tests, then re-run autopilot.")
            return 5

        # If backend was touched, backend tests must run and pass fast (no emulator dependency for newly added tests)
        # We detect backend touch by checking git diff is not available here; Copilot will run backend tests when it changes backend.
        # This controller will ALWAYS run gate; backend tests are executed by Copilot when needed.
        gate_code, report = run_gate()
        if report is None:
            return 6

        # If chosen still failing, stop (no infinite loop without code changes)
        new_ids = failing_customer_ids(report)
        if chosen in new_ids:
            write_fail(
                f"FAIL: Requirement still failing after passing customer analyze/test. "
                f"You must implement missing wiring/backend/UI/tests for {chosen} in code, then re-run autopilot.\n"
                f"See local-ci/verification/cto_verify_report.json and gate_run.log."
            )
            return 7

    # Final gate must have no customer failures
    _, final_report = run_gate()
    if final_report is None:
        return 8
    final_ids = failing_customer_ids(final_report)
    if final_ids:
        write_fail(f"FAIL: Remaining customer failures: {final_ids}. See cto_verify_report.json")
        return 9

    # PASS summary file (evidence)
    (VER / "autopilot_pass.txt").write_text(
        "PASS: Customer CUST-* + TEST-CUSTOMER-* show no remaining failures in gate report.\n"
        "See gate_run.log, customer_app_analyze.log, customer_app_test.log, cto_verify_report.json\n",
        encoding="utf-8"
    )
    print("\nPASS: Customer autopilot gate shows no remaining CUST-/TEST-CUSTOMER- failures.\n")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
