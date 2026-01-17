#!/usr/bin/env python3
"""
CTO Admin Status Report Generator
Produces honest, evidence-based completion assessment
"""
import json
import yaml
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).parent.parent
EVID = ROOT / 'local-ci/verification/admin_report_evidence'
SPEC_FILE = ROOT / 'spec/requirements.yaml'

def read_exit_code(filename):
    """Read exit code from file, return int or -1 if missing"""
    f = EVID / filename
    if not f.exists():
        return -1
    try:
        return int(f.read_text().strip())
    except:
        return -1

def read_file_safe(filepath):
    """Read file safely, return empty string if missing"""
    try:
        return Path(filepath).read_text()
    except:
        return ""

# Collect evidence
evidence = {
    'git_commit': read_file_safe(EVID / 'git_commit.txt').strip(),
    'cto_gate_exit': read_exit_code('cto_gate_exit.txt'),
    'reality_gate_exit': read_exit_code('reality_gate_exit.txt'),
    'backend_build_exit': read_exit_code('backend_build_exit.txt'),
    'backend_test_exit': read_exit_code('backend_test_exit.txt'),
    'web_build_exit': read_exit_code('web_build_exit.txt'),
    'web_test_exit': read_exit_code('web_test_exit.txt'),
    'merchant_analyze_exit': read_exit_code('merchant_analyze_exit.txt'),
    'merchant_test_exit': read_exit_code('merchant_test_exit.txt'),
    'customer_analyze_exit': read_exit_code('customer_analyze_exit.txt'),
    'customer_test_exit': read_exit_code('customer_test_exit.txt'),
}

# Parse spec requirements
spec_data = yaml.safe_load(SPEC_FILE.read_text()) if SPEC_FILE.exists() else {}
requirements = spec_data.get('requirements', [])

# Count spec statuses
status_counts = {'READY': 0, 'BLOCKED': 0, 'PARTIAL': 0, 'MISSING': 0}
for req in requirements:
    status = req.get('status', 'MISSING')
    status_counts[status] = status_counts.get(status, 0) + 1

total_reqs = len(requirements)
ready_reqs = status_counts.get('READY', 0)
spec_completion = (ready_reqs / total_reqs * 100) if total_reqs > 0 else 0

# Determine reality completion (STRICT)
# Requirements are organized by category
# We need to check if the owning surface builds/tests pass

def get_surface_status(req):
    """Determine if requirement's owning surface has passing build/test"""
    cat = req.get('category', '').lower()
    anchors = req.get('anchors', [])
    
    # Determine which surface owns this requirement
    if any('backend' in a for a in anchors):
        return evidence['backend_build_exit'] == 0 and evidence['backend_test_exit'] == 0
    elif any('web-admin' in a for a in anchors):
        return evidence['web_build_exit'] == 0 and evidence['web_test_exit'] == 0
    elif any('mobile-merchant' in a for a in anchors):
        return evidence['merchant_analyze_exit'] == 0 and evidence['merchant_test_exit'] == 0
    elif any('mobile-customer' in a for a in anchors):
        return evidence['customer_analyze_exit'] == 0 and evidence['customer_test_exit'] == 0
    else:
        # Infra/multi-surface - require all to pass
        return all(v == 0 for k, v in evidence.items() if 'exit' in k and v != -1)

reality_proven = 0
technically_proven = 0
not_proven = 0

for req in requirements:
    status = req.get('status', 'MISSING')
    if status != 'READY':
        not_proven += 1
        continue
    
    # Check if surface builds/tests pass
    if get_surface_status(req):
        # Has anchors and surface passes - TECHNICALLY PROVEN
        if req.get('anchors'):
            technically_proven += 1
        else:
            # READY but no anchors
            not_proven += 1
    else:
        # Surface fails
        not_proven += 1

# Reality completion = technically proven / total (NO functionally proven without E2E evidence)
reality_completion = (technically_proven / total_reqs * 100) if total_reqs > 0 else 0

# Determine GO/NO-GO
all_builds_pass = all(evidence[k] == 0 for k in [
    'backend_build_exit', 'backend_test_exit',
    'web_build_exit', 'web_test_exit',
    'merchant_analyze_exit', 'merchant_test_exit',
    'customer_analyze_exit', 'customer_test_exit'
] if evidence[k] != -1)

cto_gate_pass = evidence['cto_gate_exit'] == 0
reality_gate_pass = evidence['reality_gate_exit'] == 0

verdict = "GO" if (all_builds_pass and cto_gate_pass and reality_gate_pass and ready_reqs > 0) else "NO-GO"

# Reasons list
reasons = []
if not all_builds_pass:
    failed = [k.replace('_exit', '') for k, v in evidence.items() if '_exit' in k and v != 0 and v != -1]
    reasons.append(f"Build/test failures: {', '.join(failed)}")
if not cto_gate_pass:
    reasons.append(f"CTO gate failed (exit={evidence['cto_gate_exit']})")
if not reality_gate_pass:
    reasons.append(f"Reality gate failed (exit={evidence['reality_gate_exit']})")
if ready_reqs == 0:
    reasons.append("Zero READY requirements in spec")
if technically_proven == 0:
    reasons.append("Zero requirements have technical proof (builds + anchors)")

# Not proven areas
not_proven_areas = []
for req in requirements:
    if req.get('status') != 'READY' or not get_surface_status(req) or not req.get('anchors'):
        not_proven_areas.append(req.get('id', 'unknown'))

# Write JSON summary
summary_json = {
    'timestamp': datetime.utcnow().isoformat() + 'Z',
    'git_commit': evidence['git_commit'],
    'spec_counts': status_counts,
    'total_requirements': total_reqs,
    'ready_requirements': ready_reqs,
    'spec_completion_percent': round(spec_completion, 1),
    'reality_completion_percent': round(reality_completion, 1),
    'technically_proven_count': technically_proven,
    'not_proven_count': not_proven,
    'surfaces': {
        'backend': {
            'build_exit': evidence['backend_build_exit'],
            'test_exit': evidence['backend_test_exit']
        },
        'web_admin': {
            'build_exit': evidence['web_build_exit'],
            'test_exit': evidence['web_test_exit']
        },
        'mobile_merchant': {
            'analyze_exit': evidence['merchant_analyze_exit'],
            'test_exit': evidence['merchant_test_exit']
        },
        'mobile_customer': {
            'analyze_exit': evidence['customer_analyze_exit'],
            'test_exit': evidence['customer_test_exit']
        }
    },
    'gates': {
        'cto_gate_exit': evidence['cto_gate_exit'],
        'reality_gate_exit': evidence['reality_gate_exit']
    },
    'verdict': verdict,
    'reasons': reasons,
    'not_proven_areas': not_proven_areas[:20],  # First 20
    'e2e_proof_exists': False  # HONEST: We don't have E2E flow evidence
}

(EVID / 'admin_status_summary.json').write_text(json.dumps(summary_json, indent=2))

print(f"✓ Generated JSON summary: {EVID}/admin_status_summary.json")
print(f"  Spec Completion: {spec_completion:.1f}%")
print(f"  Reality Completion: {reality_completion:.1f}%")
print(f"  Verdict: {verdict}")
print(json.dumps(summary_json, indent=2))
