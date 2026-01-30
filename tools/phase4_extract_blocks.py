#!/usr/bin/env python3
import yaml
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
SPEC_FILE = REPO_ROOT / 'spec' / 'requirements.yaml'
OUT_FILE = REPO_ROOT / 'local-ci' / 'verification' / 'phase4_evidence' / 'blocked24_blocks.txt'

TARGET_IDS = [
    'MERCH-OFFER-006','MERCH-PROFILE-001','MERCH-REDEEM-004','MERCH-REDEEM-005',
    'MERCH-SUBSCRIPTION-001','MERCH-STAFF-001',
    'ADMIN-POINTS-001','ADMIN-POINTS-002','ADMIN-POINTS-003',
    'ADMIN-ANALYTICS-001','ADMIN-ANALYTICS-002','ADMIN-FRAUD-001','ADMIN-PAYMENT-004',
    'ADMIN-CAMPAIGN-001','ADMIN-CAMPAIGN-002','ADMIN-CAMPAIGN-003',
    'BACKEND-SECURITY-001','BACKEND-DATA-001','BACKEND-ORPHAN-001',
    'INFRA-RULES-001','INFRA-INDEX-001',
    'TEST-MERCHANT-001','TEST-WEB-001','TEST-BACKEND-001'
]

def main():
    with open(SPEC_FILE) as f:
        data = yaml.safe_load(f)
    reqs = data.get('requirements', [])
    target = [r for r in reqs if r.get('id') in TARGET_IDS]
    with open(OUT_FILE, 'w') as out:
        for r in target:
            out.write('---\n')
            out.write(yaml.dump(r, default_flow_style=False, sort_keys=False))
            out.write('\n')
    print(f'Wrote {len(target)} blocks to {OUT_FILE}')

if __name__ == '__main__':
    main()
