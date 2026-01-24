#!/usr/bin/env python3
import json
import subprocess
import time
from pathlib import Path

def find_repo_root(start: Path) -> Path:
    cur = start
    while cur != cur.parent:
        if (cur / ".git").exists():
            return cur
        cur = cur.parent
    return start

ROOT = find_repo_root(Path(__file__).resolve())
INVENTORY_FILE = ROOT / "local-ci" / "verification" / "cto_reality_audit" / "LATEST" / "inventory" / "tools_scripts.txt"
LOG_DIR = ROOT / "local-ci" / "verification" / "cto_reality_audit" / "LATEST" / "logs"
GATES_STATUS = ROOT / "local-ci" / "verification" / "cto_reality_audit" / "LATEST" / "gates" / "GATES_STATUS.json"

SCRIPT_TIMEOUT = 10

def infer_command(script: Path):
    ext = script.suffix.lower()
    if ext == ".py":
        return ["python3", str(script)]
    if ext == ".sh":
        return ["bash", str(script)]
    if ext in (".js", ".mjs"):
        return ["node", str(script)]
    # default to bash to avoid skipping
    return ["bash", str(script)]

def safe_basename(script: Path) -> str:
    return script.name.replace(" ", "_")

def main():
    if not INVENTORY_FILE.exists():
        raise SystemExit(f"Missing {INVENTORY_FILE}")

    statuses = []
    for line in INVENTORY_FILE.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        script_path = (ROOT / line).resolve()
        cmd = infer_command(script_path)
        base = safe_basename(script_path)
        out_file = LOG_DIR / f"{base}.out.txt"
        err_file = LOG_DIR / f"{base}.err.txt"
        start = time.time()
        start_ts = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(start))

        with open(out_file, "wb") as out_f, open(err_file, "ab") as err_f:
            try:
                result = subprocess.run(
                    cmd,
                    cwd=ROOT,
                    stdout=out_f,
                    stderr=err_f,
                    check=False,
                    timeout=SCRIPT_TIMEOUT,
                )
                exit_code = result.returncode
            except subprocess.TimeoutExpired:
                err_f.write(f"\nTIMEOUT after {SCRIPT_TIMEOUT}s\n".encode("utf-8"))
                exit_code = 124
            except Exception as exc:
                exit_code = -999
                err_f.write(str(exc).encode("utf-8", errors="ignore"))

        end = time.time()
        end_ts = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(end))
        statuses.append({
            "script": line,
            "cmd": " ".join(cmd),
            "exit_code": exit_code,
            "start": start_ts,
            "end": end_ts,
        })

    GATES_STATUS.write_text(json.dumps(statuses, indent=2))

if __name__ == "__main__":
    main()
