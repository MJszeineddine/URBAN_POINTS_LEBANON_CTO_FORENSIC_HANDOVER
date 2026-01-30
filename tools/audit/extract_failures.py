#!/usr/bin/env python3
import json
import os
import pathlib
from datetime import datetime

ROOT = pathlib.Path(__file__).resolve().parents[2]
FIXPACK_ROOT = ROOT / "local-ci" / "verification" / "cto_fixpack_01" / "LATEST"
BEFORE_DIR = FIXPACK_ROOT / "before"
REPORT_PATH = FIXPACK_ROOT / "reports" / "failures_excerpt.md"

def main():
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    gate_status = BEFORE_DIR / "gates" / "GATES_STATUS.json"
    lines = [
        "# Failure Excerpts",
        "",
        f"_Generated: {datetime.utcnow().isoformat()}Z_",
        "",
    ]
    if gate_status.exists():
        data = json.loads(gate_status.read_text())
        lines.append("## Gate Failures")
        for entry in data:
            if entry.get("exit_code", 0) == 0:
                continue
            script = entry.get("script")
            lines.append(f"### {script} (exit {entry.get('exit_code')})")
            out_log = BEFORE_DIR / "logs" / (pathlib.Path(script).name + ".out.txt")
            err_log = BEFORE_DIR / "logs" / (pathlib.Path(script).name + ".err.txt")
            for label, log_path in (("stdout", out_log), ("stderr", err_log)):
                if not log_path.exists():
                    continue
                lines.append(f"**{label}:** `{log_path.relative_to(ROOT)}`")
                with log_path.open("r", errors="ignore") as fh:
                    snippet = "".join(fh.readlines()[:200])
                lines.append("```")
                lines.append(snippet.rstrip() or "<empty>")
                lines.append("```")
            lines.append("")
    else:
        lines.append("No gate status file found.")

    # e2e BLOCKED
    lines.append("## E2E BLOCKED States")
    if BEFORE_DIR.exists():
        for path in BEFORE_DIR.rglob("e2e_*.out.txt"):
            text = path.read_text(errors="ignore")
            for l in text.splitlines():
                if "BLOCKED" in l:
                    rel = path.relative_to(ROOT)
                    lines.append(f"- `{rel}` — {l.strip()}")
                    break
    REPORT_PATH.write_text("\n".join(lines))

if __name__ == "__main__":
    main()
