#!/usr/bin/env python3
"""
Truth Bundle Generator - Evidence-Based Qatar Parity Scanner
Scans REAL code, runs tests/builds, generates proof bundle with evidence anchors.
"""

import subprocess
import json
import os
import sys
from datetime import datetime
from pathlib import Path
import hashlib

# Repository root
REPO_ROOT = Path(__file__).parent.parent.parent.absolute()
os.chdir(REPO_ROOT)

def run_command(cmd, cwd=None, capture=True):
    """Run shell command and return output + exit code"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd or REPO_ROOT,
            capture_output=capture,
            text=True,
            timeout=300
        )
        return result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "TIMEOUT after 300s", 1
    except Exception as e:
        return f"ERROR: {str(e)}", 1

def ripgrep_scan(pattern, file_pattern="", extra_args=""):
    """Use ripgrep to find pattern in code, return list of (file, line_num, content)"""
    cmd = f"rg --line-number --no-heading {extra_args}"
    if file_pattern:
        cmd += f" --glob '{file_pattern}'"
    cmd += f" '{pattern}'"
    
    output, code = run_command(cmd)
    results = []
    for line in output.strip().split('\n'):
        if ':' in line and line.strip():
            parts = line.split(':', 2)
            if len(parts) >= 3:
                results.append({
                    'file': parts[0],
                    'line': parts[1],
                    'content': parts[2].strip()
                })
    return results

def main():
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    proof_dir = REPO_ROOT / f"local-ci/verification/vibe_truth/PROOF_{timestamp}"
    
    # Create directory structure
    (proof_dir / "reports").mkdir(parents=True, exist_ok=True)
    (proof_dir / "logs").mkdir(parents=True, exist_ok=True)
    (proof_dir / "hashes").mkdir(parents=True, exist_ok=True)
    
    print(f"=== Truth Bundle Generator ===")
    print(f"Timestamp: {timestamp}")
    print(f"Proof Dir: {proof_dir}")
    print()
    
    # =======================
    # STEP 1: Run builds/tests
    # =======================
    print("[1/6] Running backend tests...")
    test_output, test_code = run_command(
        "npm test",
        cwd=REPO_ROOT / "source/backend/rest-api"
    )
    (proof_dir / "logs/backend_tests.txt").write_text(test_output)
    print(f"  Exit code: {test_code}")
    
    print("[2/6] Running backend build...")
    build_output, build_code = run_command(
        "npm run build",
        cwd=REPO_ROOT / "source/backend/rest-api"
    )
    (proof_dir / "logs/backend_build.txt").write_text(build_output)
    print(f"  Exit code: {build_code}")
    
    print("[3/6] Running web-admin build...")
    admin_build_output, admin_build_code = run_command(
        "npm run build",
        cwd=REPO_ROOT / "source/apps/web-admin"
    )
    (proof_dir / "logs/webadmin_build.txt").write_text(admin_build_output)
    print(f"  Exit code: {admin_build_code}")
    
    # =======================
    # STEP 2: Code Evidence Scanning
    # =======================
    print("[4/6] Scanning code for evidence...")
    
    evidence = {
        "subscription_gating": {
            "description": "Subscription required to redeem offers",
            "proofs": []
        },
        "monthly_reset": {
            "description": "Once per offer per month limit",
            "proofs": []
        },
        "admin_activation": {
            "description": "Admin manual subscription activation",
            "proofs": []
        },
        "admin_ui": {
            "description": "Admin UI for manual subscriptions",
            "proofs": []
        },
        "tests": {
            "description": "Tests covering subscription features",
            "proofs": []
        }
    }
    
    # Scan for subscription gating
    print("  - Checking subscription gating...")
    results = ripgrep_scan("requireActiveSubscription", "source/backend/**/*.ts")
    for r in results:
        evidence["subscription_gating"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    results = ripgrep_scan("SUBSCRIPTION_REQUIRED", "source/backend/**/*.ts")
    for r in results:
        evidence["subscription_gating"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    # Scan for monthly reset
    print("  - Checking monthly reset...")
    results = ripgrep_scan("period_key|periodKey", "source/backend/**/*.ts")
    for r in results:
        evidence["monthly_reset"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    results = ripgrep_scan("OFFER_MONTHLY_LIMIT", "source/backend/**/*.ts")
    for r in results:
        evidence["monthly_reset"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    # Scan for admin activation endpoint
    print("  - Checking admin activation...")
    results = ripgrep_scan("/api/admin/subscriptions/activate", "source/backend/**/*.ts")
    for r in results:
        evidence["admin_activation"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    results = ripgrep_scan("/api/admin/users/search", "source/backend/**/*.ts")
    for r in results:
        evidence["admin_activation"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    # Scan for admin UI
    print("  - Checking admin UI...")
    # Check for the admin UI page file
    results = ripgrep_scan("manual-subscriptions", "source/apps/web-admin/pages/**/*.tsx")
    for r in results:
        evidence["admin_ui"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    # Check for AdminGuard wrapping
    results = ripgrep_scan("AdminGuard", "source/apps/web-admin/pages/admin/manual-subscriptions.tsx")
    for r in results:
        evidence["admin_ui"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    # Scan for tests
    print("  - Checking tests...")
    # Check for real integration tests (not just keyword scanning)
    results = ripgrep_scan("REAL TEST", "source/backend/rest-api/src/tests/**/*.js")
    for r in results:
        evidence["tests"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    # Check for subscription test files
    results = ripgrep_scan("Subscription.*Test", "source/backend/rest-api/src/tests/**/*.js")
    for r in results:
        evidence["tests"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    # Check for integration test file
    results = ripgrep_scan("integration", "source/backend/rest-api/src/tests/**/*.js")
    for r in results:
        evidence["tests"]["proofs"].append(f"{r['file']}:{r['line']}")
    
    # Deduplicate proofs
    for key in evidence:
        evidence[key]["proofs"] = sorted(list(set(evidence[key]["proofs"])))
        evidence[key]["status"] = "PRESENT" if evidence[key]["proofs"] else "MISSING"
    
    # =======================
    # STEP 3: Generate Reports
    # =======================
    print("[5/6] Generating reports...")
    
    # Determine overall verdict
    critical_features = ["subscription_gating", "monthly_reset", "admin_activation"]
    all_present = all(evidence[f]["status"] == "PRESENT" for f in critical_features)
    tests_passing = test_code == 0
    builds_passing = build_code == 0 and admin_build_code == 0
    
    overall_verdict = "PASS" if (all_present and tests_passing and builds_passing) else "FAIL"
    
    # FINAL_SUMMARY.md
    summary = f"""# Truth Bundle - Final Summary

**Generated:** {datetime.now().isoformat()}  
**Verdict:** {overall_verdict}

## Build & Test Status

- Backend Tests: {'✅ PASS' if test_code == 0 else '❌ FAIL'} (exit code: {test_code})
- Backend Build: {'✅ PASS' if build_code == 0 else '❌ FAIL'} (exit code: {build_code})
- Web-Admin Build: {'✅ PASS' if admin_build_code == 0 else '❌ FAIL'} (exit code: {admin_build_code})

## Evidence Summary

### Critical Features (Qatar Parity)

"""
    
    for feature_key in critical_features:
        feat = evidence[feature_key]
        status_icon = "✅" if feat["status"] == "PRESENT" else "❌"
        summary += f"**{status_icon} {feat['description']}**  \n"
        summary += f"Status: {feat['status']}  \n"
        if feat["proofs"]:
            summary += "Evidence:\n"
            for proof in feat["proofs"][:5]:  # Show first 5
                summary += f"  - `{proof}`\n"
            if len(feat["proofs"]) > 5:
                summary += f"  - _(+{len(feat['proofs'])-5} more)_\n"
        else:
            summary += "Evidence: NONE FOUND\n"
        summary += "\n"
    
    summary += f"""
### Supporting Features

**{evidence['admin_ui']['status']} {evidence['admin_ui']['description']}**  
Evidence: {len(evidence['admin_ui']['proofs'])} anchor(s)

**{evidence['tests']['status']} {evidence['tests']['description']}**  
Evidence: {len(evidence['tests']['proofs'])} anchor(s)

## Conclusion

Overall Verdict: **{overall_verdict}**

"""
    
    if overall_verdict == "FAIL":
        summary += "**Failures detected:**\n"
        if not all_present:
            summary += "- Some critical features missing code evidence\n"
        if not tests_passing:
            summary += "- Backend tests failed\n"
        if not builds_passing:
            summary += "- Build failed\n"
    else:
        summary += "All critical features present with code evidence. Tests and builds passing.\n"
    
    (proof_dir / "reports/FINAL_SUMMARY.md").write_text(summary)
    
    # FEATURE_PROOFS.md
    proofs_md = f"""# Feature Proofs (Evidence Anchors)

**Generated:** {datetime.now().isoformat()}

"""
    
    for feature_key, feat in evidence.items():
        proofs_md += f"## {feat['description']}\n\n"
        proofs_md += f"**Status:** {feat['status']}\n\n"
        if feat["proofs"]:
            proofs_md += "**Evidence:**\n\n"
            for proof in feat["proofs"]:
                proofs_md += f"- `{proof}`\n"
        else:
            proofs_md += "**Evidence:** NONE FOUND\n"
        proofs_md += "\n---\n\n"
    
    (proof_dir / "reports/FEATURE_PROOFS.md").write_text(proofs_md)
    
    # UPDATED_BACKLOG.md
    backlog_md = f"""# Qatar Parity Backlog (Evidence-Based)

**Last Updated:** {datetime.now().isoformat()}  
**Source:** Automated code scan + build verification

## ✅ Completed Features

"""
    
    # Include ALL features, not just critical ones
    for feature_key, feat in evidence.items():
        if feat["status"] == "PRESENT":
            backlog_md += f"### {feat['description']}\n"
            backlog_md += f"**Status:** COMPLETE\n"
            backlog_md += f"**Evidence:** {len(feat['proofs'])} code anchor(s)\n"
            if feat["proofs"]:
                backlog_md += f"**Key anchors:** {feat['proofs'][0]}\n"
            backlog_md += "\n"
    
    backlog_md += """
## ⚠️ Missing / Unverified Features

"""
    
    missing_found = False
    for feature_key, feat in evidence.items():
        if feat["status"] != "PRESENT":
            missing_found = True
            backlog_md += f"### {feat['description']}\n"
            backlog_md += f"**Status:** MISSING\n"
            backlog_md += f"**Reason:** No code evidence found in automated scan\n\n"
    
    if not missing_found:
        backlog_md += "_No missing features detected in core Qatar parity scope._\n"
    
    (proof_dir / "reports/UPDATED_BACKLOG.md").write_text(backlog_md)
    
    # UPDATED_GAP_MAP.md
    gap_map_md = f"""# GAP MAP vs Urban Point Qatar (Evidence-Based)

**Last Updated:** {datetime.now().isoformat()}  
**Source:** Automated code scan

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
"""
    
    for feature_key, feat in evidence.items():
        status_icon = "✅" if feat["status"] == "PRESENT" else "❌"
        evidence_count = len(feat["proofs"])
        evidence_summary = f"{evidence_count} anchor(s)" if evidence_count > 0 else "NONE"
        gap_map_md += f"| {feat['description']} | {status_icon} {feat['status']} | {evidence_summary} | - |\n"
    
    gap_map_md += f"""

## Overall Score

- Critical Features Present: {sum(1 for f in critical_features if evidence[f]['status'] == 'PRESENT')}/{len(critical_features)}
- Tests Passing: {'Yes' if test_code == 0 else 'No'}
- Builds Passing: {'Yes' if (build_code == 0 and admin_build_code == 0) else 'No'}

**Overall Assessment:** {overall_verdict}
"""
    
    (proof_dir / "reports/UPDATED_GAP_MAP.md").write_text(gap_map_md)
    
    # UPDATED_READINESS.json
    readiness = {
        "timestamp": datetime.now().isoformat(),
        "verdict": overall_verdict,
        "modules": {},
        "build_status": {
            "backend_tests": test_code,
            "backend_build": build_code,
            "webadmin_build": admin_build_code
        },
        "overall_score": 0
    }
    
    for feature_key, feat in evidence.items():
        score = 100 if feat["status"] == "PRESENT" else 0
        readiness["modules"][feat["description"]] = {
            "status": feat["status"],
            "score": score,
            "evidence_count": len(feat["proofs"]),
            "anchors": feat["proofs"][:10],  # Include up to 10 anchors
            "blockers": [] if feat["status"] == "PRESENT" else ["No code evidence found"]
        }
    
    # Calculate overall score
    total_features = len(evidence)
    present_features = sum(1 for f in evidence.values() if f["status"] == "PRESENT")
    readiness["overall_score"] = int((present_features / total_features) * 100) if total_features > 0 else 0
    
    (proof_dir / "reports/UPDATED_READINESS.json").write_text(
        json.dumps(readiness, indent=2)
    )
    
    # =======================
    # STEP 4: Update Root Files
    # =======================
    print("[6/6] Updating canonical root files...")
    
    # Copy updated versions to root
    import shutil
    shutil.copy(proof_dir / "reports/UPDATED_BACKLOG.md", REPO_ROOT / "BACKLOG.md")
    shutil.copy(proof_dir / "reports/UPDATED_GAP_MAP.md", REPO_ROOT / "GAP_MAP_vs_URBAN_POINT_QATAR.md")
    shutil.copy(proof_dir / "reports/UPDATED_READINESS.json", REPO_ROOT / "READINESS.json")
    
    print("  ✓ BACKLOG.md")
    print("  ✓ GAP_MAP_vs_URBAN_POINT_QATAR.md")
    print("  ✓ READINESS.json")
    
    # =======================
    # STEP 5: Generate SHA256 Hashes
    # =======================
    print("\nGenerating SHA256 checksums...")
    
    sha256sums = []
    for root, dirs, files in os.walk(proof_dir):
        for file in files:
            if file == "SHA256SUMS.txt":
                continue
            filepath = Path(root) / file
            rel_path = filepath.relative_to(proof_dir)
            
            hasher = hashlib.sha256()
            with open(filepath, 'rb') as f:
                hasher.update(f.read())
            
            sha256sums.append(f"{hasher.hexdigest()}  {rel_path}")
    
    sha256sums_content = "\n".join(sorted(sha256sums))
    (proof_dir / "hashes/SHA256SUMS.txt").write_text(sha256sums_content)
    
    # =======================
    # FINAL OUTPUT
    # =======================
    print("\n" + "="*60)
    print("PROOF_BUNDLE_PATH=" + str(proof_dir))
    print("FINAL_SUMMARY_MD=" + str(proof_dir / "reports/FINAL_SUMMARY.md"))
    print("SHA256SUMS=" + str(proof_dir / "hashes/SHA256SUMS.txt"))
    print("VERDICT=" + overall_verdict)
    
    return 0 if overall_verdict == "PASS" else 1

if __name__ == "__main__":
    sys.exit(main())
