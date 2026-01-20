#!/usr/bin/env python3
"""
Strict validator for fullstack_line_audit results.
Fails if:
- pct_scanned < 95
- any requirement has zero anchors
- any requirement status != DONE while rollup reports 100%
- rollup math != recomputed math
"""
import json
import yaml
import sys
from pathlib import Path

AUDIT_OUT = Path('/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/local-ci/verification/fullstack_line_audit/LATEST')

def validate():
    """Validate audit results"""
    failures = []
    
    # Load data
    try:
        coverage = json.load(open(AUDIT_OUT / 'inventory/coverage_report.json'))
        rollup = json.load(open(AUDIT_OUT / 'matrix/completion_rollup.json'))
        matrix_data = yaml.safe_load(open(AUDIT_OUT / 'matrix/requirements_feature_matrix.yaml'))
        reqs = matrix_data.get('requirements', []) if isinstance(matrix_data, dict) else matrix_data or []
    except Exception as e:
        print(f"FAIL: Could not load audit files: {e}")
        return 1
    
    # CHECK 1: Coverage >= 95%
    pct = coverage.get('pct_scanned', 0)
    if pct < 95:
        failures.append(f"COVERAGE FAIL: {pct}% < 95% (inventory/coverage_report.json)")
    
    # CHECK 2: All requirements have anchors
    for r in reqs:
        req_id = r.get('id', 'UNKNOWN')
        anchors = r.get('anchors', [])
        if not anchors or len(anchors) == 0:
            failures.append(f"ANCHORS FAIL: {req_id} has zero anchors (matrix/requirements_feature_matrix.yaml)")
    
    # CHECK 3: Math reproducibility
    status_counts = {'DONE': 0, 'PARTIAL': 0, 'MISSING': 0}
    for r in reqs:
        status = r.get('status', 'MISSING')
        status_counts[status] = status_counts.get(status, 0) + 1
    
    total_all = len(reqs)
    done_all = status_counts['DONE']
    computed_pct = round(100 * done_all / max(1, total_all), 1) if total_all > 0 else 0
    
    reported_pct = rollup.get('project_overall_pct', 0)
    if computed_pct != reported_pct:
        failures.append(f"MATH FAIL: Computed {computed_pct}% ({done_all}/{total_all}) != reported {reported_pct}% (matrix/completion_rollup.json)")
    
    # CHECK 4: 100% consistency
    if reported_pct == 100.0:
        if status_counts['PARTIAL'] > 0 or status_counts['MISSING'] > 0:
            failures.append(f"INCONSISTENT: 100% reported but {status_counts['PARTIAL']} PARTIAL, {status_counts['MISSING']} MISSING (proof/COMPLETION_TABLE.md)")
    
    # Output
    if failures:
        print("FAIL")
        print()
        for f in failures:
            print(f"✗ {f}")
        return 1
    else:
        print("PASS")
        return 0

if __name__ == '__main__':
    sys.exit(validate())
