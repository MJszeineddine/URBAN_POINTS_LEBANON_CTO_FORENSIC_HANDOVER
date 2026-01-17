#!/usr/bin/env python3
"""Print gate failures from cto_verify_report.json grouped by component prefix."""

import json
from pathlib import Path
from collections import defaultdict

def main():
    report_path = Path(__file__).parent.parent / "local-ci" / "verification" / "cto_verify_report.json"
    
    if not report_path.exists():
        print(f"ERROR: Report not found at {report_path}")
        return 1
    
    with open(report_path) as f:
        report = json.load(f)
    
    # Extract all failures
    all_failures = []
    if "checks" in report and isinstance(report["checks"], dict):
        for check_name, check_data in report["checks"].items():
            if isinstance(check_data, dict) and "failures" in check_data:
                for failure in check_data["failures"]:
                    all_failures.append((check_name, failure))
    
    # Group by component prefix
    by_prefix = defaultdict(list)
    for check_name, failure in all_failures:
        # Extract requirement ID prefix (e.g., CUST-, MERCH-, ADMIN-)
        parts = failure.split(":")
        if parts:
            req_id = parts[0].strip()
            prefix = req_id.split("-")[0] if "-" in req_id else "OTHER"
            by_prefix[prefix].append((check_name, failure))
    
    # Print summary
    print("=" * 80)
    print("CTO VERIFY GATE FAILURES")
    print("=" * 80)
    print(f"\nTotal failures: {len(all_failures)}")
    print(f"Status: {report.get('status', 'UNKNOWN')}")
    print(f"Timestamp: {report.get('timestamp', 'UNKNOWN')}")
    
    # Print counts by prefix
    print("\n" + "=" * 80)
    print("FAILURES BY COMPONENT PREFIX")
    print("=" * 80)
    for prefix in sorted(by_prefix.keys()):
        failures = by_prefix[prefix]
        print(f"\n{prefix}: {len(failures)} failures")
        for check_name, failure in failures:
            print(f"  [{check_name}] {failure}")
    
    # Print all checks status
    print("\n" + "=" * 80)
    print("ALL CHECKS STATUS")
    print("=" * 80)
    if "checks" in report:
        for check_name, check_data in report["checks"].items():
            if isinstance(check_data, dict):
                passed = check_data.get("passed", False)
                status_icon = "✅" if passed else "❌"
                failure_count = len(check_data.get("failures", []))
                print(f"{status_icon} {check_name}: {'PASS' if passed else f'FAIL ({failure_count} failures)'}")
    
    return 0 if len(all_failures) == 0 else 1

if __name__ == "__main__":
    exit(main())
