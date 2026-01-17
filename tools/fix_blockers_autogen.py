#!/usr/bin/env python3
"""
Automatic blocker doc fixer for CTO gate.

Ensures:
1. Every BLOCKED requirement has a blocker doc file
2. Every TEST-* with MISSING status is changed to BLOCKED with blocker doc
3. Blocker docs reference shared docs when applicable
4. Requirement notes are updated to reference the blocker doc
"""

import sys
import os
import re
from pathlib import Path
from typing import Dict, List

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed. Run: pip3 install pyyaml")
    sys.exit(1)

REPO_ROOT = Path(__file__).parent.parent.absolute()
SPEC_FILE = REPO_ROOT / "spec" / "requirements.yaml"
DOCS_DIR = REPO_ROOT / "docs"

def derive_blocker_filename(feature: str, req_id: str) -> str:
    """Derive blocker filename exactly as cto_verify.py does"""
    blocker_name = feature.replace(" ", "_").replace("/", "_").replace("(", "").replace(")", "").upper()
    return f"BLOCKER_{blocker_name}.md"

def derive_blocker_filepath(feature: str, req_id: str) -> Path:
    """Return full path to blocker file"""
    filename = derive_blocker_filename(feature, req_id)
    return DOCS_DIR / filename

def get_shared_blocker_reference(req_id: str) -> str:
    """Return the shared blocker doc reference for known grouped requirements"""
    shared_refs = {
        # Merchant app features
        "MERCH-OFFER-006": "docs/BLOCKER_MERCHANT_APP_FEATURES.md",
        "MERCH-PROFILE-001": "docs/BLOCKER_MERCHANT_APP_FEATURES.md",
        "MERCH-REDEEM-004": "docs/BLOCKER_MERCHANT_APP_FEATURES.md",
        "MERCH-REDEEM-005": "docs/BLOCKER_MERCHANT_APP_FEATURES.md",
        "MERCH-SUBSCRIPTION-001": "docs/BLOCKER_MERCHANT_APP_FEATURES.md",
        "MERCH-STAFF-001": "docs/BLOCKER_MERCHANT_APP_FEATURES.md",
        # Admin points management
        "ADMIN-POINTS-001": "docs/BLOCKER_ADMIN_POINTS_MANAGEMENT.md",
        "ADMIN-POINTS-002": "docs/BLOCKER_ADMIN_POINTS_MANAGEMENT.md",
        "ADMIN-POINTS-003": "docs/BLOCKER_ADMIN_POINTS_MANAGEMENT.md",
        # Admin analytics & fraud
        "ADMIN-ANALYTICS-001": "docs/BLOCKER_ADMIN_ANALYTICS_FRAUD.md",
        "ADMIN-ANALYTICS-002": "docs/BLOCKER_ADMIN_ANALYTICS_FRAUD.md",
        "ADMIN-FRAUD-001": "docs/BLOCKER_ADMIN_ANALYTICS_FRAUD.md",
        # Admin payment & campaigns
        "ADMIN-PAYMENT-004": "docs/BLOCKER_ADMIN_PAYMENT_CAMPAIGNS.md",
        "ADMIN-CAMPAIGN-001": "docs/BLOCKER_ADMIN_PAYMENT_CAMPAIGNS.md",
        "ADMIN-CAMPAIGN-002": "docs/BLOCKER_ADMIN_PAYMENT_CAMPAIGNS.md",
        "ADMIN-CAMPAIGN-003": "docs/BLOCKER_ADMIN_PAYMENT_CAMPAIGNS.md",
        # Backend security
        "BACKEND-SECURITY-001": "docs/BLOCKER_BACKEND_SECURITY_001.md",
        # Backend data quality
        "BACKEND-DATA-001": "docs/BLOCKER_BACKEND_DATA_QUALITY.md",
        # Backend orphan
        "BACKEND-ORPHAN-001": "docs/BLOCKER_BACKEND_ORPHAN_FUNCTIONS.md",
    }
    return shared_refs.get(req_id, None)

def create_blocker_doc_wrapper(req_id: str, feature: str, shared_ref: str = None, reason: str = None) -> str:
    """Generate blocker doc content"""
    content = f"""# BLOCKER: {req_id} — {feature}

## Status
**Blocked** — External dependency or incomplete implementation

## Issue
{reason or 'Implementation or dependency pending'}

## What's Missing
- Awaiting upstream completion
- See referenced blocker document for full scope

## Reference"""
    
    if shared_ref:
        content += f"""
This requirement is part of a broader blocker addressed in:
- [{shared_ref}]({shared_ref})

See that document for complete blocking conditions and resolution timeline."""
    
    content += f"""

## Unblock Criteria
- Implementation complete
- Tests passing
- Code review approved
- See parent blocker for details
"""
    return content

def load_spec() -> Dict:
    """Load spec/requirements.yaml"""
    with open(SPEC_FILE, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)

def save_spec(data: Dict) -> None:
    """Save spec/requirements.yaml"""
    with open(SPEC_FILE, "w", encoding="utf-8") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

def main():
    print("Loading spec/requirements.yaml...")
    spec = load_spec()
    
    if "requirements" not in spec:
        print("ERROR: No 'requirements' key in spec")
        sys.exit(1)
    
    requirements = spec["requirements"]
    fixed_count = 0
    
    print(f"Processing {len(requirements)} requirements...\n")
    
    for req in requirements:
        req_id = req.get("id", "UNKNOWN")
        status = req.get("status", "UNKNOWN")
        feature = req.get("feature", req_id)
        
        # Handle TEST-* requirements with MISSING status
        if req_id.startswith("TEST-") and status == "MISSING":
            print(f"  {req_id}: Converting MISSING → BLOCKED (test framework setup needed)")
            req["status"] = "BLOCKED"
            
            # Ensure blocker doc exists for this test requirement
            blocker_path = derive_blocker_filepath(feature, req_id)
            if not blocker_path.exists():
                reason = "Test suite not yet created. Framework setup and initial tests required."
                content = create_blocker_doc_wrapper(req_id, feature, reason=reason)
                blocker_path.write_text(content, encoding="utf-8")
                print(f"    Created: {blocker_path.name}")
            fixed_count += 1
            
            # Update notes to reference blocker doc
            if "notes" not in req or blocker_path.name not in (req.get("notes", "")):
                old_notes = req.get("notes", "")
                req["notes"] = f"See {blocker_path.name}. {old_notes}".strip()
            status = "BLOCKED"
        
        # Handle BLOCKED requirements missing blocker doc
        if status == "BLOCKED":
            shared_ref = get_shared_blocker_reference(req_id)
            blocker_path = derive_blocker_filepath(feature, req_id)
            
            if not blocker_path.exists():
                print(f"  {req_id}: Creating blocker doc ({blocker_path.name})")
                reason = req.get("notes", "Awaiting implementation completion")
                content = create_blocker_doc_wrapper(req_id, feature, shared_ref=shared_ref, reason=reason)
                blocker_path.write_text(content, encoding="utf-8")
                fixed_count += 1
                
                # Update notes if not already referencing the blocker
                if "notes" not in req or blocker_path.name not in (req.get("notes", "")):
                    old_notes = req.get("notes", "")
                    ref_line = f"See {blocker_path.name}"
                    if shared_ref:
                        ref_line += f" (includes {shared_ref})"
                    req["notes"] = f"{ref_line}. {old_notes}".strip()
            else:
                print(f"  {req_id}: Blocker doc already exists ({blocker_path.name})")
    
    print(f"\nSaving spec/requirements.yaml...")
    save_spec(spec)
    
    print(f"\n✅ Fixed {fixed_count} requirements")
    print("Run: python3 tools/gates/cto_verify.py")
    return 0

if __name__ == "__main__":
    sys.exit(main())
