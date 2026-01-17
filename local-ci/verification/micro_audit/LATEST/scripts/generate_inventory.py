#!/usr/bin/env python3
import os
import csv
from pathlib import Path

root = Path("/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER")
tracked_files = (root / "local-ci/verification/micro_audit/LATEST/inventory/git_tracked_files.txt").read_text().strip().split('\n')

inventory = []
for f in tracked_files:
    if not f.strip():
        continue
    fp = root / f
    if not fp.exists():
        continue
    
    # Classify surface
    surface = "unknown"
    if "backend/firebase-functions" in f:
        surface = "backend-functions"
    elif "backend/rest-api" in f:
        surface = "backend-api"
    elif "apps/web-admin" in f:
        surface = "web-admin"
    elif "apps/mobile-customer" in f:
        surface = "mobile-customer"
    elif "apps/mobile-merchant" in f:
        surface = "mobile-merchant"
    elif f.startswith("tools/"):
        surface = "tools"
    elif f.startswith("docs/"):
        surface = "docs"
    elif f.startswith("local-ci/"):
        surface = "infra"
    elif f.startswith("scripts/"):
        surface = "tools"
    
    # Classify type
    ftype = "unknown"
    ext = fp.suffix.lower()
    if ext in ['.ts', '.js', '.dart', '.py', '.sh']:
        ftype = "code"
    elif ext in ['.json', '.yaml', '.yml', '.toml', '.lock', '.md', '.txt']:
        if 'test' in f.lower() or 'spec' in f.lower():
            ftype = "test"
        elif ext == '.md' or ext == '.txt':
            ftype = "doc"
        else:
            ftype = "config"
    elif ext in ['.png', '.jpg', '.svg', '.gif']:
        ftype = "asset"
    elif 'test' in f.lower():
        ftype = "test"
    else:
        ftype = "unknown"
    
    size_bytes = fp.stat().st_size if fp.is_file() else 0
    
    inventory.append({
        'path': f,
        'type': ftype,
        'owner_surface': surface,
        'size_bytes': size_bytes,
        'last_commit': '2e0398c',
        'notes': '',
        'evidence': f'git ls-files | {f}'
    })

out_csv = root / "local-ci/verification/micro_audit/LATEST/reports/FILE_INVENTORY.csv"
out_csv.parent.mkdir(parents=True, exist_ok=True)
with open(out_csv, 'w', newline='') as csvf:
    writer = csv.DictWriter(csvf, fieldnames=['path','type','owner_surface','size_bytes','last_commit','notes','evidence'])
    writer.writeheader()
    writer.writerows(inventory)

print(f"FILE_INVENTORY.csv: {len(inventory)} files")
