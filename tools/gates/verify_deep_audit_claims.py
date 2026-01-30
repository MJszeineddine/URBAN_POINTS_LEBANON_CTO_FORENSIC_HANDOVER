#!/usr/bin/env python3
"""
Forensic verifier for deep audit claims.
Compares claimed audit coverage and issue counts against actual evidence.
"""

import json
import os
import sys
import hashlib
from pathlib import Path
from collections import defaultdict
from datetime import datetime

# Paths
BASE = Path("/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER")
EVIDENCE = BASE / "local-ci/verification/deep_audit_evidence/LATEST"
INPUTS = EVIDENCE / "inputs"
DERIVED = EVIDENCE / "derived"
REPORTS = EVIDENCE / "reports"
PROOF = EVIDENCE / "proof"


def log(msg):
    print(f"[VERIFY] {msg}", flush=True)


def sha256_file(path):
    """Return SHA256 hash of file."""
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()


def read_tracked_files():
    """Read git tracked files list."""
    log("Reading git_tracked_files.txt...")
    tracked_file = INPUTS / "git_tracked_files.txt"
    
    if not tracked_file.exists():
        log(f"ERROR: {tracked_file} does not exist!")
        return []
    
    with open(tracked_file, 'r') as f:
        files = [line.strip() for line in f if line.strip()]
    
    # Normalize paths
    files = sorted(set(files))
    log(f"  Found {len(files)} unique tracked files")
    return files


def read_batch_files():
    """Read all batch*.txt files and return union + per-batch breakdown."""
    log("Reading batch*.txt files...")
    
    batch_files = sorted(INPUTS.glob("batch*.txt"))
    log(f"  Found {len(batch_files)} batch files")
    
    all_batches = {}
    union = set()
    
    for batch_file in batch_files:
        batch_name = batch_file.stem
        with open(batch_file, 'r') as f:
            files = [line.strip() for line in f if line.strip()]
        
        all_batches[batch_name] = sorted(set(files))
        union.update(files)
        log(f"    {batch_name}: {len(all_batches[batch_name])} files")
    
    log(f"  Total files in batch union: {len(union)}")
    
    # Find duplicates across batches
    duplicates = []
    seen = defaultdict(list)
    for batch_name, files in all_batches.items():
        for f in files:
            seen[f].append(batch_name)
    
    for filepath, batches in seen.items():
        if len(batches) > 1:
            duplicates.append({
                "file": filepath,
                "batches": batches,
                "count": len(batches)
            })
    
    log(f"  Found {len(duplicates)} duplicate files across batches")
    
    return {
        "union": sorted(union),
        "per_batch": all_batches,
        "duplicates": duplicates
    }


def read_json_reports():
    """Read all JSON reports and extract files + issues."""
    log("Reading JSON report files...")
    
    json_files = sorted(INPUTS.glob("*.json"))
    log(f"  Found {len(json_files)} JSON files")
    
    all_files = set()
    all_issues = []
    report_summaries = []
    
    for json_file in json_files:
        try:
            with open(json_file, 'r') as f:
                data = json.load(f)
            
            report_name = json_file.stem
            
            # Extract summary - handle multiple formats
            summary = data.get("summary", {})
            files_audited = summary.get("files_audited", 0) or data.get("total_files_audited", 0)
            total_issues = summary.get("total_issues", 0) or data.get("total_line_issues", 0)
            security_issues = summary.get("security_issues", 0) or data.get("security_issues_count", 0)
            quality_issues = summary.get("quality_issues", 0) or data.get("quality_issues_count", 0)
            
            if files_audited > 0 or total_issues > 0:
                report_summaries.append({
                    "report": report_name,
                    "files_audited": files_audited,
                    "total_issues": total_issues,
                    "security_issues": security_issues,
                    "quality_issues": quality_issues
                })
            
            # Extract files - handle multiple formats
            files_array = data.get("files", [])
            file_issues_total = 0
            
            # Format 1: files array with file + issues
            for file_obj in files_array:
                if isinstance(file_obj, dict) and "file" in file_obj:
                    all_files.add(file_obj["file"])
                    
                    file_issues = file_obj.get("issues", [])
                    file_issues_total += len(file_issues)
                    for issue in file_issues:
                        issue_copy = issue.copy()
                        issue_copy["source_file"] = file_obj["file"]
                        issue_copy["source_report"] = report_name
                        all_issues.append(issue_copy)
            
            # Format 2: top_N_risky_files with nested security_issues/quality_issues
            for key in ["top_10_risky_files", "top_20_risky_files", "files_with_issues"]:
                risky_files = data.get(key, [])
                for file_obj in risky_files:
                    if isinstance(file_obj, dict) and "file" in file_obj:
                        all_files.add(file_obj["file"])
                        
                        # Extract security issues
                        sec_issues = file_obj.get("security_issues", [])
                        for issue in sec_issues:
                            issue_copy = issue.copy()
                            issue_copy["source_file"] = file_obj["file"]
                            issue_copy["source_report"] = report_name
                            all_issues.append(issue_copy)
                        
                        # Extract quality issues
                        qual_issues = file_obj.get("quality_issues", [])
                        for issue in qual_issues:
                            issue_copy = issue.copy()
                            issue_copy["source_file"] = file_obj["file"]
                            issue_copy["source_report"] = report_name
                            all_issues.append(issue_copy)
                        
                        file_issues_total += len(sec_issues) + len(qual_issues)
            
            # Also check for "all_issues" key at root
            root_issues = data.get("all_issues", [])
            for issue in root_issues:
                issue_copy = issue.copy()
                issue_copy["source_report"] = report_name
                all_issues.append(issue_copy)
            
            log(f"    {report_name}: {len(all_files)} files, {file_issues_total + len(root_issues)} issues")
        
        except Exception as e:
            log(f"    ERROR reading {json_file}: {e}")
    
    log(f"  Total files in JSON union: {len(all_files)}")
    log(f"  Total issues extracted: {len(all_issues)}")
    
    return {
        "union": sorted(all_files),
        "issues": all_issues,
        "report_summaries": report_summaries
    }


def compute_coverage(tracked, batched_union, json_union):
    """Compute coverage metrics."""
    log("Computing coverage metrics...")
    
    tracked_set = set(tracked)
    batched_set = set(batched_union)
    json_set = set(json_union)
    
    # Coverage percentages
    tracked_in_batches = tracked_set & batched_set
    tracked_in_json = tracked_set & json_set
    
    batched_coverage = len(tracked_in_batches) / len(tracked_set) if tracked_set else 0
    json_coverage = len(tracked_in_json) / len(tracked_set) if tracked_set else 0
    
    # Missing files
    tracked_not_in_batches = sorted(tracked_set - batched_set)
    tracked_not_in_json = sorted(tracked_set - json_set)
    batched_not_in_tracked = sorted(batched_set - tracked_set)
    json_not_in_tracked = sorted(json_set - tracked_set)
    
    log(f"  Tracked files: {len(tracked_set)}")
    log(f"  Files in batches: {len(batched_set)}")
    log(f"  Files in JSON: {len(json_set)}")
    log(f"  Tracked ∩ Batches: {len(tracked_in_batches)} ({batched_coverage*100:.2f}%)")
    log(f"  Tracked ∩ JSON: {len(tracked_in_json)} ({json_coverage*100:.2f}%)")
    log(f"  Tracked - Batches: {len(tracked_not_in_batches)} missing")
    log(f"  Tracked - JSON: {len(tracked_not_in_json)} missing")
    log(f"  Batches - Tracked: {len(batched_not_in_tracked)} extra")
    log(f"  JSON - Tracked: {len(json_not_in_tracked)} extra")
    
    return {
        "tracked_total": len(tracked_set),
        "batched_total": len(batched_set),
        "json_total": len(json_set),
        "tracked_in_batches_count": len(tracked_in_batches),
        "tracked_in_json_count": len(tracked_in_json),
        "batched_coverage_pct": batched_coverage * 100,
        "json_coverage_pct": json_coverage * 100,
        "tracked_not_in_batches": tracked_not_in_batches,
        "tracked_not_in_json": tracked_not_in_json,
        "batched_not_in_tracked": batched_not_in_tracked,
        "json_not_in_tracked": json_not_in_tracked
    }


def analyze_issues(issues):
    """Analyze issues by category with evidence."""
    log("Analyzing issues by category...")
    
    categories = {
        "sql_injection": [],
        "xss": [],
        "eval_usage": [],
        "hardcoded_secrets": [],
        "weak_crypto": [],
        "http_not_https": [],
        "console_log": [],
        "todo_fixme": [],
        "other": []
    }
    
    severity_dist = defaultdict(int)
    
    for issue in issues:
        issue_type = issue.get("type", "").lower()
        pattern = issue.get("pattern", "").lower()
        severity = issue.get("severity", "UNKNOWN")
        severity_dist[severity] += 1
        
        # Categorize - check both type and pattern fields
        combined = f"{issue_type} {pattern}"
        
        if "sql" in combined and "inject" in combined:
            categories["sql_injection"].append(issue)
        elif "xss" in combined or "cross" in combined:
            categories["xss"].append(issue)
        elif "eval" in combined:
            categories["eval_usage"].append(issue)
        elif "secret" in combined or "key" in combined or "token" in combined or "credential" in combined:
            categories["hardcoded_secrets"].append(issue)
        elif "md5" in combined or "sha1" in combined or "crypto" in combined:
            categories["weak_crypto"].append(issue)
        elif "http" in combined:
            categories["http_not_https"].append(issue)
        elif "console" in combined:
            categories["console_log"].append(issue)
        elif "todo" in combined or "fixme" in combined:
            categories["todo_fixme"].append(issue)
        else:
            categories["other"].append(issue)
    
    log(f"  SQL Injection: {len(categories['sql_injection'])}")
    log(f"  XSS: {len(categories['xss'])}")
    log(f"  Eval Usage: {len(categories['eval_usage'])}")
    log(f"  Hardcoded Secrets: {len(categories['hardcoded_secrets'])}")
    log(f"  Weak Crypto: {len(categories['weak_crypto'])}")
    log(f"  HTTP (not HTTPS): {len(categories['http_not_https'])}")
    log(f"  Console.log: {len(categories['console_log'])}")
    log(f"  TODO/FIXME: {len(categories['todo_fixme'])}")
    log(f"  Other: {len(categories['other'])}")
    
    return {
        "categories": categories,
        "severity_distribution": dict(severity_dist)
    }


def detect_contradictions(coverage, analysis, report_summaries):
    """Detect contradictions between claims and evidence."""
    log("Detecting contradictions...")
    
    contradictions = []
    
    # Check if any markdown claims "ALL 962" or "100%" but coverage is not 100%
    markdown_files = [
        INPUTS / "COMPLETE_FILE_BY_FILE_AUDIT_REPORT.md",
        INPUTS / "AUDIT_INDEX.md",
        INPUTS / "AUDIT_EXECUTION_SUMMARY.md"
    ]
    
    for md_file in markdown_files:
        if md_file.exists():
            content = md_file.read_text()
            
            # Check for "ALL 962" claims
            if "ALL 962" in content.upper() or "962 FILES" in content.upper():
                if coverage["json_coverage_pct"] < 99.9:
                    contradictions.append({
                        "type": "coverage_claim_mismatch",
                        "file": md_file.name,
                        "claim": "ALL 962 files audited",
                        "reality": f"Only {coverage['json_coverage_pct']:.2f}% coverage ({coverage['tracked_in_json_count']}/{coverage['tracked_total']} files)"
                    })
            
            # Check for "100%" claims
            if "100%" in content and "coverage" in content.lower():
                if coverage["json_coverage_pct"] < 99.9:
                    contradictions.append({
                        "type": "100_percent_claim_mismatch",
                        "file": md_file.name,
                        "claim": "100% coverage",
                        "reality": f"Actual coverage: {coverage['json_coverage_pct']:.2f}%"
                    })
    
    # Check if summary totals match
    total_summary_files = sum(s["files_audited"] for s in report_summaries)
    if total_summary_files != coverage["json_total"]:
        contradictions.append({
            "type": "file_count_mismatch",
            "claim": f"JSON summaries claim {total_summary_files} files audited",
            "reality": f"JSON union contains {coverage['json_total']} unique files"
        })
    
    log(f"  Found {len(contradictions)} contradictions")
    
    return contradictions


def write_derived_artifacts(coverage, batch_data, json_data, analysis):
    """Write derived evidence files."""
    log("Writing derived artifacts...")
    
    # Coverage summary JSON
    coverage_summary = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "tracked_files": coverage["tracked_total"],
        "batched_files": coverage["batched_total"],
        "json_files": coverage["json_total"],
        "batched_coverage_pct": coverage["batched_coverage_pct"],
        "json_coverage_pct": coverage["json_coverage_pct"],
        "missing_from_batches_count": len(coverage["tracked_not_in_batches"]),
        "missing_from_json_count": len(coverage["tracked_not_in_json"]),
        "duplicate_files_count": len(batch_data["duplicates"]),
        "total_issues": len(json_data["issues"]),
        "severity_distribution": analysis["severity_distribution"],
        "category_counts": {k: len(v) for k, v in analysis["categories"].items()}
    }
    
    with open(DERIVED / "coverage_summary.json", 'w') as f:
        json.dump(coverage_summary, f, indent=2)
    
    # Missing files
    with open(DERIVED / "missing_tracked_not_in_batches.txt", 'w') as f:
        f.write(f"# {len(coverage['tracked_not_in_batches'])} tracked files NOT in any batch\n")
        for filepath in coverage["tracked_not_in_batches"]:
            f.write(f"{filepath}\n")
    
    with open(DERIVED / "missing_tracked_not_in_json.txt", 'w') as f:
        f.write(f"# {len(coverage['tracked_not_in_json'])} tracked files NOT in JSON reports\n")
        for filepath in coverage["tracked_not_in_json"]:
            f.write(f"{filepath}\n")
    
    # Duplicates
    with open(DERIVED / "duplicates_across_batches.txt", 'w') as f:
        f.write(f"# {len(batch_data['duplicates'])} files appearing in multiple batches\n")
        for dup in batch_data["duplicates"]:
            f.write(f"{dup['file']}\t{dup['count']}x\t{', '.join(dup['batches'])}\n")
    
    # Extra files in batches
    with open(DERIVED / "batches_not_in_tracked.txt", 'w') as f:
        f.write(f"# {len(coverage['batched_not_in_tracked'])} files in batches but NOT tracked\n")
        for filepath in coverage["batched_not_in_tracked"]:
            f.write(f"{filepath}\n")
    
    log(f"  Wrote coverage_summary.json")
    log(f"  Wrote missing/duplicate lists")


def write_claims_evidence(analysis):
    """Write detailed claims evidence report."""
    log("Writing claims evidence report...")
    
    with open(REPORTS / "claims_evidence.md", 'w') as f:
        f.write("# CLAIMS EVIDENCE REPORT\n\n")
        f.write(f"**Generated:** {datetime.utcnow().isoformat()}Z\n\n")
        f.write("## Security Issue Evidence\n\n")
        
        categories = analysis["categories"]
        
        for cat_name, issues in categories.items():
            if cat_name == "other" or cat_name.startswith("console") or cat_name.startswith("todo"):
                continue  # Skip quality issues here
            
            f.write(f"### {cat_name.upper().replace('_', ' ')} ({len(issues)} instances)\n\n")
            
            if issues:
                f.write("Top 20 Evidence Rows:\n\n")
                f.write("| File | Line | Severity | Snippet/Message |\n")
                f.write("|------|------|----------|------------------|\n")
                
                for issue in issues[:20]:
                    file = issue.get("source_file", "?")
                    line = issue.get("line", "?")
                    severity = issue.get("severity", "?")
                    message = issue.get("message", issue.get("code_snippet", ""))[:80]
                    f.write(f"| {file} | {line} | {severity} | {message} |\n")
                
                f.write("\n")
            else:
                f.write("*No evidence found.*\n\n")
        
        f.write("## Quality Issue Evidence\n\n")
        
        for cat_name in ["console_log", "todo_fixme"]:
            issues = categories[cat_name]
            f.write(f"### {cat_name.upper().replace('_', ' ')} ({len(issues)} instances)\n\n")
            
            if issues:
                f.write(f"Top 20 out of {len(issues)}:\n\n")
                f.write("| File | Line | Message |\n")
                f.write("|------|------|----------|\n")
                
                for issue in issues[:20]:
                    file = issue.get("source_file", "?")
                    line = issue.get("line", "?")
                    message = issue.get("message", "")[:100]
                    f.write(f"| {file} | {line} | {message} |\n")
                
                f.write("\n")
    
    log(f"  Wrote claims_evidence.md")


def write_exec_summary(coverage, analysis, contradictions, batch_data, json_data):
    """Write CEO-level executive summary."""
    log("Writing executive summary...")
    
    with open(REPORTS / "EXEC_SUMMARY.md", 'w') as f:
        f.write("# DEEP AUDIT VERIFICATION - EXECUTIVE SUMMARY\n\n")
        f.write(f"**Generated:** {datetime.utcnow().isoformat()}Z\n\n")
        f.write("## VERDICT\n\n")
        
        if coverage["json_coverage_pct"] >= 99.9 and not contradictions:
            f.write("✅ **PASS** - Claims verified with evidence.\n\n")
        else:
            f.write("🔴 **FAIL** - Claims do not match evidence.\n\n")
        
        f.write("## COVERAGE TRUTH\n\n")
        f.write(f"- **Git Tracked Files:** {coverage['tracked_total']}\n")
        f.write(f"- **Files in Batches:** {coverage['batched_total']}\n")
        f.write(f"- **Files in JSON Reports:** {coverage['json_total']}\n")
        f.write(f"- **Batched Coverage:** {coverage['batched_coverage_pct']:.2f}%\n")
        f.write(f"- **JSON Coverage:** {coverage['json_coverage_pct']:.2f}%\n")
        f.write(f"- **Missing from Batches:** {len(coverage['tracked_not_in_batches'])}\n")
        f.write(f"- **Missing from JSON:** {len(coverage['tracked_not_in_json'])}\n\n")
        
        f.write("## ISSUE COUNTS (Evidence-Based)\n\n")
        
        cats = analysis["categories"]
        f.write(f"- **SQL Injection:** {len(cats['sql_injection'])}\n")
        f.write(f"- **XSS:** {len(cats['xss'])}\n")
        f.write(f"- **Eval Usage:** {len(cats['eval_usage'])}\n")
        f.write(f"- **Hardcoded Secrets:** {len(cats['hardcoded_secrets'])}\n")
        f.write(f"- **Weak Crypto:** {len(cats['weak_crypto'])}\n")
        f.write(f"- **HTTP (not HTTPS):** {len(cats['http_not_https'])}\n")
        f.write(f"- **Console.log:** {len(cats['console_log'])}\n")
        f.write(f"- **TODO/FIXME:** {len(cats['todo_fixme'])}\n")
        f.write(f"- **Total Issues:** {len(json_data['issues'])}\n\n")
        
        f.write("## SEVERITY DISTRIBUTION\n\n")
        for sev, count in sorted(analysis["severity_distribution"].items()):
            f.write(f"- **{sev}:** {count}\n")
        f.write("\n")
        
        if contradictions:
            f.write("## CONTRADICTIONS DETECTED\n\n")
            for contra in contradictions:
                f.write(f"### {contra['type']}\n")
                f.write(f"- **Claim:** {contra['claim']}\n")
                f.write(f"- **Reality:** {contra['reality']}\n")
                if 'file' in contra:
                    f.write(f"- **Source:** {contra['file']}\n")
                f.write("\n")
        
        f.write("## BATCH BREAKDOWN\n\n")
        for batch_name, files in sorted(batch_data["per_batch"].items()):
            f.write(f"- **{batch_name}:** {len(files)} files\n")
        f.write("\n")
        
        f.write("## JSON REPORT SUMMARIES\n\n")
        for summary in json_data["report_summaries"]:
            f.write(f"### {summary['report']}\n")
            f.write(f"- Files: {summary['files_audited']}\n")
            f.write(f"- Total Issues: {summary['total_issues']}\n")
            f.write(f"- Security: {summary['security_issues']}\n")
            f.write(f"- Quality: {summary['quality_issues']}\n\n")
        
        f.write("## EVIDENCE ARTIFACTS\n\n")
        f.write("All evidence located in:\n")
        f.write("- `local-ci/verification/deep_audit_evidence/LATEST/derived/coverage_summary.json`\n")
        f.write("- `local-ci/verification/deep_audit_evidence/LATEST/derived/missing_*.txt`\n")
        f.write("- `local-ci/verification/deep_audit_evidence/LATEST/reports/claims_evidence.md`\n")
        f.write("- `local-ci/verification/deep_audit_evidence/LATEST/proof/verify_run.log`\n\n")
        
        f.write("## INPUT HASHES (Reproducibility)\n\n")
        git_tracked = INPUTS / "git_tracked_files.txt"
        if git_tracked.exists():
            f.write(f"- `git_tracked_files.txt`: {sha256_file(git_tracked)[:16]}...\n")
        
        for json_file in sorted(INPUTS.glob("*.json")):
            f.write(f"- `{json_file.name}`: {sha256_file(json_file)[:16]}...\n")
    
    log(f"  Wrote EXEC_SUMMARY.md")


def main():
    log("="*70)
    log("DEEP AUDIT CLAIMS VERIFICATION - FORENSIC MODE")
    log("="*70)
    
    # Step A: Read tracked files
    tracked = read_tracked_files()
    
    # Step B: Read batch files
    batch_data = read_batch_files()
    
    # Step C: Read JSON reports
    json_data = read_json_reports()
    
    # Step D: Compute coverage
    coverage = compute_coverage(tracked, batch_data["union"], json_data["union"])
    
    # Step E: Analyze issues
    analysis = analyze_issues(json_data["issues"])
    
    # Step F: Detect contradictions
    contradictions = detect_contradictions(coverage, analysis, json_data["report_summaries"])
    
    # Step G: Write artifacts
    write_derived_artifacts(coverage, batch_data, json_data, analysis)
    write_claims_evidence(analysis)
    write_exec_summary(coverage, analysis, contradictions, batch_data, json_data)
    
    # Step H: Gate decision
    log("="*70)
    log("GATE DECISION")
    log("="*70)
    
    gate_pass = True
    gate_reasons = []
    
    if len(coverage["tracked_not_in_batches"]) > 0:
        gate_pass = False
        gate_reasons.append(f"{len(coverage['tracked_not_in_batches'])} tracked files NOT in any batch")
    
    if coverage["json_coverage_pct"] < 99.9:
        gate_pass = False
        gate_reasons.append(f"JSON coverage is {coverage['json_coverage_pct']:.2f}%, not 100%")
    
    if contradictions:
        gate_pass = False
        gate_reasons.append(f"{len(contradictions)} contradictions detected between claims and evidence")
    
    if gate_pass:
        log("✅ GATE PASS - 100% coverage verified")
        
        with open(PROOF / "OK_DEEP_AUDIT_100_PERCENT.md", 'w') as f:
            f.write("# GATE PASS: DEEP AUDIT 100% VERIFIED\n\n")
            f.write(f"**Timestamp:** {datetime.utcnow().isoformat()}Z\n\n")
            f.write("## Coverage\n\n")
            f.write(f"- Tracked files: {coverage['tracked_total']}\n")
            f.write(f"- JSON coverage: {coverage['json_coverage_pct']:.2f}%\n")
            f.write(f"- Missing: {len(coverage['tracked_not_in_json'])}\n\n")
            f.write("## Issue Counts\n\n")
            f.write(f"- Total issues: {len(json_data['issues'])}\n")
            f.write(f"- Security: {sum(len(v) for k, v in analysis['categories'].items() if k not in ['console_log', 'todo_fixme', 'other'])}\n")
            f.write(f"- Quality: {len(analysis['categories']['console_log']) + len(analysis['categories']['todo_fixme'])}\n\n")
            f.write("## Input Hashes\n\n")
            git_tracked = INPUTS / "git_tracked_files.txt"
            if git_tracked.exists():
                f.write(f"- git_tracked_files.txt: {sha256_file(git_tracked)}\n")
        
        log("Wrote: proof/OK_DEEP_AUDIT_100_PERCENT.md")
        return 0
    
    else:
        log("🔴 GATE FAIL - Coverage incomplete or contradictions found")
        
        with open(PROOF / "BLOCKER_DEEP_AUDIT_NOT_100_PERCENT.md", 'w') as f:
            f.write("# BLOCKER: DEEP AUDIT NOT 100% COVERAGE\n\n")
            f.write(f"**Timestamp:** {datetime.utcnow().isoformat()}Z\n\n")
            f.write("## Failure Reasons\n\n")
            for reason in gate_reasons:
                f.write(f"- {reason}\n")
            f.write("\n")
            
            f.write("## Coverage Details\n\n")
            f.write(f"- Tracked files: {coverage['tracked_total']}\n")
            f.write(f"- JSON coverage: {coverage['json_coverage_pct']:.2f}%\n")
            f.write(f"- Files missing from batches: {len(coverage['tracked_not_in_batches'])}\n")
            f.write(f"- Files missing from JSON: {len(coverage['tracked_not_in_json'])}\n\n")
            
            f.write("## Missing Files (first 50)\n\n")
            for filepath in coverage["tracked_not_in_json"][:50]:
                f.write(f"- {filepath}\n")
            
            if len(coverage["tracked_not_in_json"]) > 50:
                f.write(f"\n... and {len(coverage['tracked_not_in_json']) - 50} more\n")
            
            f.write("\n## Contradictions\n\n")
            if contradictions:
                for contra in contradictions:
                    f.write(f"### {contra['type']}\n")
                    f.write(f"- Claim: {contra['claim']}\n")
                    f.write(f"- Reality: {contra['reality']}\n\n")
            else:
                f.write("*No contradictions in markdown claims (coverage issue only)*\n")
            
            f.write("\n## Evidence Location\n\n")
            f.write("See:\n")
            f.write("- `local-ci/verification/deep_audit_evidence/LATEST/derived/missing_tracked_not_in_json.txt`\n")
            f.write("- `local-ci/verification/deep_audit_evidence/LATEST/reports/EXEC_SUMMARY.md`\n")
        
        log("Wrote: proof/BLOCKER_DEEP_AUDIT_NOT_100_PERCENT.md")
        
        for reason in gate_reasons:
            log(f"  - {reason}")
        
        return 2


if __name__ == "__main__":
    try:
        exit_code = main()
        log(f"Exit code: {exit_code}")
        sys.exit(exit_code)
    except Exception as e:
        log(f"FATAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
