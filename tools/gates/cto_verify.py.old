#!/usr/bin/env python3
"""
CTO VERIFICATION DIAGNOSTIC

Examines all Done orders and produces detailed evidence verification report.
Shows gate_command, gate.log contents, verdict.json, and execution patterns.
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple

from openpyxl import load_workbook


def get_timestamp() -> str:
    """Get current timestamp in Beirut TZ."""
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")


def split_csv(val) -> List[str]:
    """Split CSV string into list."""
    if not val:
        return []
    return [x.strip() for x in str(val).split(",") if x and x.strip()]


def load_orders(wb) -> Tuple[List[Dict], str]:
    """Load ORDERS sheet."""
    if "ORDERS" not in wb.sheetnames:
        return [], "ORDERS sheet not found"

    ws = wb["ORDERS"]
    rows = list(ws.iter_rows(values_only=True))
    if not rows:
        return [], "ORDERS sheet is empty"

    header = [str(c) if c is not None else "" for c in rows[0]]
    records = []
    for r in rows[1:]:
        if all(c is None for c in r):
            continue
        obj = {}
        for h, v in zip(header, r):
            if h:
                obj[h] = v if v is not None else ""
        records.append(obj)

    return records, None


def find_latest_evidence(evidence_root: Path, order_id: str) -> Tuple[Path, str]:
    """Find latest evidence folder for order."""
    order_dir = evidence_root / order_id
    if not order_dir.exists():
        return None, f"No evidence directory: {order_dir}"

    run_folders = [d for d in order_dir.iterdir() if d.is_dir()]
    if not run_folders:
        return None, f"No run folders in {order_dir}"

    run_folders.sort(reverse=True)
    return run_folders[0], None


def analyze_gate_log(gate_log_path: Path) -> Dict:
    """Analyze gate.log for execution signatures."""
    if not gate_log_path.exists():
        return {"exists": False, "error": "gate.log not found"}

    size = gate_log_path.stat().st_size
    
    # Read last 40 lines
    try:
        with open(gate_log_path, 'r', errors='replace') as f:
            lines = f.readlines()
        last_40 = "".join(lines[-40:])
    except Exception as e:
        return {"exists": True, "size": size, "error": f"Failed to read: {e}"}

    # Check for execution signatures
    signatures = {
        "npm_run": "npm run" in last_40,
        "flutter": "flutter" in last_40.lower(),
        "firebase": "firebase" in last_40.lower(),
        "jest": "jest" in last_40.lower(),
        "playwright": "playwright" in last_40.lower(),
        "gradle": "gradle" in last_40.lower(),
        "build_status": any(x in last_40 for x in ["BUILD SUCCESS", "BUILD FAILED"]),
        "test_summary": any(x in last_40 for x in ["PASS", "FAIL", "Tests:"]),
        "exit_code": "exit code" in last_40.lower() or "Exit code" in last_40
    }

    return {
        "exists": True,
        "size": size,
        "last_40_lines": last_40,
        "signatures": signatures,
        "signature_count": sum(signatures.values())
    }


def analyze_verdict(verdict_path: Path, gate_log_path: Path) -> Dict:
    """Analyze verdict.json."""
    if not verdict_path.exists():
        return {"exists": False, "error": "verdict.json not found"}

    try:
        with open(verdict_path, 'r') as f:
            verdict = json.load(f)
    except Exception as e:
        return {"exists": True, "error": f"Invalid JSON: {e}"}

    # Check mtime ordering
    verdict_mtime = verdict_path.stat().st_mtime
    gate_log_mtime = gate_log_path.stat().st_mtime if gate_log_path.exists() else 0
    created_after_log = verdict_mtime >= gate_log_mtime

    return {
        "exists": True,
        "content": verdict,
        "created_after_gate_log": created_after_log,
        "has_order_id": "order_id" in verdict,
        "has_run_ts": "run_ts" in verdict,
        "has_end_to_end_working": "end_to_end_working" in verdict,
        "end_to_end_value": verdict.get("end_to_end_working")
    }


def verify_order(order: Dict, evidence_root: Path) -> Dict:
    """Verify a single Done order."""
    order_id = str(order.get("Order_ID", "")).strip()
    status = str(order.get("Status", "")).strip()
    gate_command = str(order.get("Gate_Command", "")).strip()

    result = {
        "order_id": order_id,
        "status": status,
        "gate_command": gate_command,
        "gate_command_trivial": not gate_command or gate_command.startswith("echo")
    }

    # Find evidence
    evidence_path, err = find_latest_evidence(evidence_root, order_id)
    if err:
        result["error"] = err
        result["has_evidence"] = False
        return result

    result["evidence_path"] = str(evidence_path)
    result["has_evidence"] = True

    # Analyze gate.log
    gate_log_path = evidence_path / "gate.log"
    result["gate_log"] = analyze_gate_log(gate_log_path)

    # Analyze verdict.json
    verdict_path = evidence_path / "verdict.json"
    result["verdict"] = analyze_verdict(verdict_path, gate_log_path)

    return result


def generate_verify_md(results: List[Dict], timestamp: str) -> str:
    """Generate human-readable verification report."""
    lines = [
        "# CTO Verification Report",
        f"**Timestamp:** {timestamp}",
        "",
        "## Purpose",
        "Verify that all Done orders have REAL gate execution evidence (not hand-written verdicts).",
        "",
        "## Summary",
        f"Total Done orders examined: {len(results)}",
        ""
    ]

    for result in results:
        lines.append(f"### {result['order_id']}")
        lines.append(f"**Status:** {result['status']}")
        lines.append(f"**Gate Command:** `{result['gate_command']}`")
        
        if result.get("gate_command_trivial"):
            lines.append("⚠️ **WARNING:** Gate command is trivial (empty or echo-only)")
        
        if not result.get("has_evidence"):
            lines.append(f"❌ **ERROR:** {result.get('error', 'No evidence')}")
            lines.append("")
            continue

        lines.append(f"**Evidence Path:** `{result['evidence_path']}`")
        lines.append("")

        # Gate log analysis
        gate_log = result.get("gate_log", {})
        lines.append("**gate.log Analysis:**")
        if not gate_log.get("exists"):
            lines.append(f"- ❌ Not found: {gate_log.get('error', 'missing')}")
        else:
            lines.append(f"- Size: {gate_log.get('size', 0)} bytes")
            sigs = gate_log.get("signatures", {})
            sig_count = gate_log.get("signature_count", 0)
            lines.append(f"- Execution signatures found: {sig_count}")
            if sig_count > 0:
                lines.append("  - Signatures:")
                for sig_name, found in sigs.items():
                    if found:
                        lines.append(f"    - ✓ {sig_name}")
            else:
                lines.append("  - ⚠️ NO execution signatures detected")
            
            lines.append("")
            lines.append("**gate.log (last 40 lines):**")
            lines.append("```")
            lines.append(gate_log.get("last_40_lines", ""))
            lines.append("```")

        # Verdict analysis
        verdict = result.get("verdict", {})
        lines.append("")
        lines.append("**verdict.json Analysis:**")
        if not verdict.get("exists"):
            lines.append(f"- ❌ Not found: {verdict.get('error', 'missing')}")
        else:
            lines.append(f"- Created after gate.log: {'✓' if verdict.get('created_after_gate_log') else '❌'}")
            lines.append(f"- Has order_id: {'✓' if verdict.get('has_order_id') else '❌'}")
            lines.append(f"- Has run_ts: {'✓' if verdict.get('has_run_ts') else '❌'}")
            lines.append(f"- end_to_end_working: {verdict.get('end_to_end_value')}")
            
            lines.append("")
            lines.append("**verdict.json content:**")
            lines.append("```json")
            lines.append(json.dumps(verdict.get("content", {}), indent=2))
            lines.append("```")

        lines.append("")
        lines.append("---")
        lines.append("")

    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description="CTO verification diagnostic")
    ap.add_argument("--excel", default="UrbanPoints_CTO_Master_Control_v4.xlsx")
    ap.add_argument("--evidence-root", default="docs/evidence")
    ap.add_argument("--output-dir", required=True)
    args = ap.parse_args()

    # Load Excel
    excel_path = Path(args.excel).resolve()
    evidence_root = Path(args.evidence_root).resolve()

    if not excel_path.exists():
        print(f"ERROR: Excel not found: {excel_path}", file=sys.stderr)
        sys.exit(1)

    wb = load_workbook(excel_path, data_only=True)
    orders, err = load_orders(wb)
    if err:
        print(f"ERROR: {err}", file=sys.stderr)
        sys.exit(1)

    # Filter Done orders
    done_orders = [o for o in orders if str(o.get("Status", "")).strip() == "Done"]
    print(f"Verifying {len(done_orders)} Done orders...")

    # Verify each
    timestamp = get_timestamp()
    results = [verify_order(order, evidence_root) for order in done_orders]

    # Generate outputs
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    verify_json = {
        "timestamp": timestamp,
        "total_done_orders": len(results),
        "results": results
    }

    verify_md = generate_verify_md(results, timestamp)

    with open(output_dir / "verify.json", 'w') as f:
        json.dump(verify_json, f, indent=2)

    with open(output_dir / "verify.md", 'w') as f:
        f.write(verify_md)

    print(f"Verification complete. Evidence: {output_dir}")


if __name__ == "__main__":
    main()
