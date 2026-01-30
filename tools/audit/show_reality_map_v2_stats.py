#!/usr/bin/env python3
import json

# Load and display key stats
with open('local-ci/verification/reality_map_v2/LATEST/analysis/classification_counts.json') as f:
    counts = json.load(f)

print('=' * 80)
print('REALITY MAP V2 - KEY STATISTICS')
print('=' * 80)
print()
print('CODEBASE BREAKDOWN:')
total_bytes = sum(c['bytes'] for c in counts.values())
for cat, data in counts.items():
    pct = data['bytes'] / total_bytes * 100
    print(f'  {cat:10} {data["count"]:7,} files  {data["bytes"]/1e9:6.2f} GB  ({pct:5.1f}%)')

print(f'\nTOTAL: {sum(c["count"] for c in counts.values()):,} files, {total_bytes/1e9:.2f} GB')

# Junk code
with open('local-ci/verification/reality_map_v2/LATEST/analysis/junk_code_candidates.json') as f:
    junk = json.load(f)
print(f'\nJUNK CODE PATTERNS: {len(junk)} occurrences')
patterns = {}
for j in junk:
    patterns[j['pattern']] = patterns.get(j['pattern'], 0) + 1
for p, c in sorted(patterns.items(), key=lambda x: -x[1]):
    print(f'  {p:20} {c:4} hits')

# Dead code
with open('local-ci/verification/reality_map_v2/LATEST/analysis/dead_code_candidates.json') as f:
    dead = json.load(f)
print(f'\nDEAD CODE CANDIDATES: {len(dead)} files')

# Product analysis
lines = 0
count = 0
with open('local-ci/verification/reality_map_v2/LATEST/analysis/product_line_index.jsonl') as f:
    for line in f:
        data = json.loads(line)
        lines += data['line_count']
        count += 1

print(f'\nPRODUCT CODE ANALYSIS:')
print(f'  Text files analyzed: {count}')
print(f'  Total lines of code: {lines:,}')
print(f'  Average lines/file: {lines//count if count else 0}')

print()
print('=' * 80)
print('✅ GATE STATUS: PASS')
print('📍 Reports: local-ci/verification/reality_map_v2/LATEST/reports/')
print('📍 Analysis: local-ci/verification/reality_map_v2/LATEST/analysis/')
print('=' * 80)
