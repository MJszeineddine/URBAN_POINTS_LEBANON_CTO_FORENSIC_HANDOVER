#!/usr/bin/env python3
import json
from pathlib import Path

base = Path("local-ci/verification/reality_map_one_shot/LATEST/analysis")

# Junk stats
junk = json.load(open(base / "junk_candidates.json", encoding="utf-8"))
junk_bytes = sum(j["size"] for j in junk)
print(f"Junk candidates: {len(junk):,} files, {junk_bytes:,} bytes ({junk_bytes/1024/1024:.2f} MB)")

# Duplicate stats
dups = json.load(open(base / "duplicates_top.json", encoding="utf-8"))
print(f"\nTop 10 duplicate groups:")
for i, d in enumerate(dups[:10], 1):
    print(f"  {i}. {d['count']} copies, SHA256: {d['sha256'][:12]}...")
    if len(d['paths']) > 0:
        print(f"     Example: {d['paths'][0]}")

# Suspicious
sus = json.load(open(base / "suspicious.json", encoding="utf-8"))
empty = [s for s in sus if s["reason"] == "empty_file"]
large = [s for s in sus if s["reason"] == "very_large_gt_200MB"]
print(f"\nSuspicious files: {len(sus):,} total")
print(f"  - Empty files: {len(empty):,}")
print(f"  - Very large (>200MB): {len(large):,}")

# Stack hits
stacks = json.load(open(base / "stack_hits.json", encoding="utf-8"))
print(f"\nStack components detected:")
for stack, files in sorted(stacks.items(), key=lambda x: len(x[1]), reverse=True):
    print(f"  - {stack}: {len(files):,} files")
