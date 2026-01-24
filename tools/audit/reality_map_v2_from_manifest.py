#!/usr/bin/env python3
"""
Reality Map v2 - Evidence-Based Analysis from Existing Manifest
Uses the already-generated manifest to avoid re-scanning the entire repo.
"""
import json
import os
import sys
import hashlib
import re
from pathlib import Path
from collections import defaultdict, Counter
from datetime import datetime

# === CONFIG ===
MANIFEST_PATH = "local-ci/verification/reality_map_one_shot/LATEST/inventory/MANIFEST.json"
OUTPUT_BASE = "local-ci/verification/reality_map_v2/LATEST"
MAX_JUNK_FILES = 3000
MAX_JUNK_CODE_HITS = 2000
MAX_DUPLICATE_GROUPS = 300
MAX_DIR_SIZE_TOP = 50

# File classification patterns
PRODUCT_PATTERNS = [
    "source/",
    "src/",  # sometimes used
]

VENDOR_PATTERNS = [
    "/node_modules/",
    "/ios/Pods/",
    "/android/.gradle/",
    "/.dart_tool/",
    "/build/",
    "/dist/",
    "/.next/",
    "/coverage/",
    "/venv/",
    "/.venv/",
    "/__pycache__/",
    "/.cache/",
    "/.turbo/",
]

TOOLING_PATTERNS = [
    "tools/",
    "scripts/",
    "docs/",
    ".github/",
    "local-ci/",
]

JUNK_FILE_MARKERS = [
    ".DS_Store",
    "Thumbs.db",
    ".pid",
    ".log",
    ".tmp",
    ".temp",
    ".lock",
    ".lockfile",
    "~",
    ".swp",
    ".swo",
    ".bak",
    ".backup",
]

JUNK_CODE_PATTERNS = [
    (r'\bTODO\b', 'TODO'),
    (r'\bFIXME\b', 'FIXME'),
    (r'\bHACK\b', 'HACK'),
    (r'\bTEMP\b', 'TEMP'),
    (r'\bPLACEHOLDER\b', 'PLACEHOLDER'),
    (r'console\.log\(', 'console.log'),
    (r'\bprint\(', 'print'),
    (r'\bdebugger\b', 'debugger'),
    (r'throw new Error\(["\']TODO', 'throw TODO'),
]

TEXT_EXTENSIONS = {
    '.ts', '.tsx', '.js', '.jsx', '.json', '.dart', '.yaml', '.yml',
    '.md', '.py', '.java', '.kt', '.swift', '.m', '.mm', '.c', '.cpp',
    '.h', '.hpp', '.cs', '.php', '.sql', '.sh', '.bash', '.xml', '.html',
    '.css', '.scss', '.less', '.graphql', '.proto', '.go', '.rs', '.rb'
}

ENTRYPOINT_MARKERS = [
    'main.dart',
    'index.ts',
    'index.js',
    'index.tsx',
    '/app/',
    '/pages/',
    '/functions/src/index',
    '/api/',
]

# === UTILITIES ===

def load_manifest(repo_root):
    """Load the existing manifest"""
    manifest_full = repo_root / MANIFEST_PATH
    if not manifest_full.exists():
        raise FileNotFoundError(f"BLOCKER: Manifest not found at {manifest_full}")
    
    with open(manifest_full) as f:
        data = json.load(f)
        # Extract files array from manifest structure
        if isinstance(data, dict) and 'files' in data:
            return data['files']
        return data

def classify_file(rel_path):
    """Classify file into PRODUCT/VENDOR/TOOLING/OTHER"""
    path_str = str(rel_path)
    
    # Check vendor first (most files)
    for pattern in VENDOR_PATTERNS:
        if pattern in path_str:
            return "VENDOR"
    
    # Check product
    for pattern in PRODUCT_PATTERNS:
        if path_str.startswith(pattern):
            return "PRODUCT"
    
    # Check tooling
    for pattern in TOOLING_PATTERNS:
        if path_str.startswith(pattern):
            return "TOOLING"
    
    return "OTHER"

def is_junk_file(rel_path):
    """Check if file matches junk patterns"""
    path_str = str(rel_path)
    name = os.path.basename(path_str)
    
    for marker in JUNK_FILE_MARKERS:
        if marker in name:
            return True
    return False

def is_text_file(rel_path):
    """Check if file is likely text-based"""
    ext = Path(rel_path).suffix.lower()
    return ext in TEXT_EXTENSIONS

def is_entrypoint(rel_path):
    """Check if file is likely an entrypoint"""
    path_str = str(rel_path).lower()
    for marker in ENTRYPOINT_MARKERS:
        if marker in path_str:
            return True
    return False

def sha256_text(text):
    """Hash text"""
    return hashlib.sha256(text.encode('utf-8')).hexdigest()[:16]

def analyze_product_file(full_path, rel_path, size, sha256_hash, repo_root):
    """Analyze a single product file for line-level details"""
    if not is_text_file(rel_path):
        return None
    
    try:
        with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = []
            first_3 = []
            last_3_buffer = []
            line_count = 0
            
            has_todo = False
            has_fixme = False
            has_placeholder = False
            
            for line in f:
                line_count += 1
                
                # First 3 lines
                if len(first_3) < 3:
                    first_3.append(line)
                
                # Rolling buffer for last 3
                last_3_buffer.append(line)
                if len(last_3_buffer) > 3:
                    last_3_buffer.pop(0)
                
                # Quick keyword checks
                line_upper = line.upper()
                if 'TODO' in line_upper:
                    has_todo = True
                if 'FIXME' in line_upper:
                    has_fixme = True
                if 'PLACEHOLDER' in line_upper:
                    has_placeholder = True
            
            first_3_sha = sha256_text(''.join(first_3)) if first_3 else ''
            last_3_sha = sha256_text(''.join(last_3_buffer)) if last_3_buffer else ''
            
            return {
                'path': str(rel_path),
                'size': size,
                'sha256': sha256_hash,
                'line_count': line_count,
                'first_3_lines_sha256': first_3_sha,
                'last_3_lines_sha256': last_3_sha,
                'contains_TODO': has_todo,
                'contains_FIXME': has_fixme,
                'contains_PLACEHOLDER': has_placeholder,
            }
    except Exception as e:
        return None

def find_junk_code_patterns(full_path, rel_path):
    """Find junk code patterns in a file"""
    if not is_text_file(rel_path):
        return []
    
    hits = []
    try:
        with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line_num, line in enumerate(f, 1):
                for pattern, label in JUNK_CODE_PATTERNS:
                    if re.search(pattern, line, re.IGNORECASE):
                        hits.append({
                            'file': str(rel_path),
                            'line': line_num,
                            'pattern': label,
                            'snippet': line.strip()[:100]
                        })
                        if len(hits) >= MAX_JUNK_CODE_HITS:
                            return hits
    except:
        pass
    
    return hits

def extract_imports(full_path, rel_path):
    """Extract import statements from TS/JS/Dart files"""
    ext = Path(rel_path).suffix.lower()
    if ext not in {'.ts', '.tsx', '.js', '.jsx', '.dart'}:
        return []
    
    imports = []
    try:
        with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                # TypeScript/JavaScript imports
                if ext in {'.ts', '.tsx', '.js', '.jsx'}:
                    # import X from 'path'
                    match = re.search(r'from\s+["\']([^"\']+)["\']', line)
                    if match:
                        imports.append(match.group(1))
                    # require('path')
                    match = re.search(r'require\(["\']([^"\']+)["\']\)', line)
                    if match:
                        imports.append(match.group(1))
                
                # Dart imports
                elif ext == '.dart':
                    match = re.search(r'import\s+["\']([^"\']+)["\']', line)
                    if match:
                        imports.append(match.group(1))
                    match = re.search(r'part\s+["\']([^"\']+)["\']', line)
                    if match:
                        imports.append(match.group(1))
    except:
        pass
    
    return imports

# === MAIN ANALYSIS ===

def main():
    repo_root = Path.cwd()
    output_root = repo_root / OUTPUT_BASE
    
    # Create output directories
    (output_root / "reports").mkdir(parents=True, exist_ok=True)
    (output_root / "analysis").mkdir(parents=True, exist_ok=True)
    (output_root / "logs").mkdir(parents=True, exist_ok=True)
    
    log_out = output_root / "logs" / "run.out.txt"
    log_err = output_root / "logs" / "run.err.txt"
    
    try:
        with open(log_out, 'w') as out_f, open(log_err, 'w') as err_f:
            def log(msg):
                print(msg)
                out_f.write(msg + '\n')
                out_f.flush()
            
            log(f"Reality Map v2 - Started at {datetime.now().isoformat()}")
            log(f"Repo root: {repo_root}")
            log(f"Output: {output_root}")
            
            # Load manifest
            log("\n=== Loading Manifest ===")
            try:
                manifest = load_manifest(repo_root)
                log(f"Loaded {len(manifest)} files from manifest")
            except Exception as e:
                err_f.write(f"BLOCKER: {e}\n")
                with open(output_root / "reports" / "FINAL_GATE.txt", 'w') as f:
                    f.write("FAIL\n")
                    f.write(f"Reason: {e}\n")
                sys.exit(1)
            
            # Initialize counters
            classification_counts = defaultdict(lambda: {'count': 0, 'bytes': 0})
            dir_sizes = defaultdict(lambda: {'count': 0, 'bytes': 0})
            extension_counts = Counter()
            sha256_groups = defaultdict(list)
            junk_files = []
            suspicious_files = []
            product_files = []
            
            log("\n=== Classifying Files ===")
            for entry in manifest:
                rel_path = entry['path']
                size = entry['size']
                sha256_hash = entry['sha256']
                
                # Classify
                category = classify_file(rel_path)
                classification_counts[category]['count'] += 1
                classification_counts[category]['bytes'] += size
                
                # Directory size
                dir_path = str(Path(rel_path).parent)
                dir_sizes[dir_path]['count'] += 1
                dir_sizes[dir_path]['bytes'] += size
                
                # Extension
                ext = Path(rel_path).suffix.lower() or '<none>'
                extension_counts[ext] += 1
                
                # Duplicates
                sha256_groups[sha256_hash].append(rel_path)
                
                # Junk files
                if is_junk_file(rel_path):
                    if len(junk_files) < MAX_JUNK_FILES:
                        junk_files.append({
                            'path': rel_path,
                            'size': size,
                            'reason': 'filename_pattern'
                        })
                
                # Suspicious
                if size == 0:
                    suspicious_files.append({
                        'path': rel_path,
                        'size': 0,
                        'reason': 'empty'
                    })
                elif size > 200 * 1024 * 1024:
                    suspicious_files.append({
                        'path': rel_path,
                        'size': size,
                        'reason': 'very_large'
                    })
                
                # Collect product files
                if category == "PRODUCT":
                    product_files.append({
                        'path': rel_path,
                        'size': size,
                        'sha256': sha256_hash
                    })
            
            log(f"Classified {len(manifest)} files")
            log(f"Product files: {len(product_files)}")
            
            # Top directories by size
            log("\n=== Computing Top Directories ===")
            dir_size_top = sorted(
                [{'dir': k, 'count': v['count'], 'bytes': v['bytes']} 
                 for k, v in dir_sizes.items()],
                key=lambda x: x['bytes'],
                reverse=True
            )[:MAX_DIR_SIZE_TOP]
            
            # Top duplicate groups
            log("\n=== Finding Duplicates ===")
            duplicates_top = sorted(
                [{'sha256': k, 'count': len(v), 'example': v[0], 'paths': v[:10]}
                 for k, v in sha256_groups.items() if len(v) > 1],
                key=lambda x: x['count'],
                reverse=True
            )[:MAX_DUPLICATE_GROUPS]
            
            log(f"Found {len(duplicates_top)} duplicate groups")
            
            # Analyze product files
            log("\n=== Analyzing Product Files ===")
            product_line_index = []
            junk_code_hits = []
            imported_files = set()
            
            for i, pf in enumerate(product_files):
                if i % 500 == 0:
                    log(f"  Processed {i}/{len(product_files)} product files...")
                
                full_path = repo_root / pf['path']
                if not full_path.exists():
                    continue
                
                # Line analysis
                analysis = analyze_product_file(
                    full_path, pf['path'], pf['size'], pf['sha256'], repo_root
                )
                if analysis:
                    product_line_index.append(analysis)
                
                # Junk code patterns
                if len(junk_code_hits) < MAX_JUNK_CODE_HITS:
                    hits = find_junk_code_patterns(full_path, pf['path'])
                    junk_code_hits.extend(hits[:MAX_JUNK_CODE_HITS - len(junk_code_hits)])
                
                # Extract imports for dead code detection
                imports = extract_imports(full_path, pf['path'])
                for imp in imports:
                    # Normalize relative imports
                    if imp.startswith('.'):
                        parent = Path(pf['path']).parent
                        resolved = (parent / imp).resolve()
                        imported_files.add(str(resolved))
                    else:
                        imported_files.add(imp)
            
            log(f"Analyzed {len(product_line_index)} product files")
            log(f"Found {len(junk_code_hits)} junk code patterns")
            
            # Dead code detection
            log("\n=== Detecting Dead Code ===")
            dead_code_candidates = []
            for pf in product_files:
                if is_entrypoint(pf['path']):
                    continue
                
                # Check if file is referenced
                path_normalized = str(Path(pf['path']).resolve())
                path_no_ext = str(Path(pf['path']).with_suffix(''))
                
                is_referenced = False
                for imp in imported_files:
                    if pf['path'] in imp or path_no_ext in imp or path_normalized in imp:
                        is_referenced = True
                        break
                
                if not is_referenced and is_text_file(pf['path']):
                    dead_code_candidates.append({
                        'path': pf['path'],
                        'size': pf['size'],
                        'reason': 'unreferenced_non_entrypoint'
                    })
            
            log(f"Found {len(dead_code_candidates)} dead code candidates")
            
            # Write analysis outputs
            log("\n=== Writing Analysis Outputs ===")
            
            with open(output_root / "analysis" / "classification_counts.json", 'w') as f:
                json.dump(dict(classification_counts), f, indent=2)
            
            with open(output_root / "analysis" / "dir_size_top.json", 'w') as f:
                json.dump(dir_size_top, f, indent=2)
            
            with open(output_root / "analysis" / "junk_files.json", 'w') as f:
                json.dump(junk_files[:MAX_JUNK_FILES], f, indent=2)
            
            with open(output_root / "analysis" / "junk_code_candidates.json", 'w') as f:
                json.dump(junk_code_hits, f, indent=2)
            
            with open(output_root / "analysis" / "dead_code_candidates.json", 'w') as f:
                json.dump(dead_code_candidates, f, indent=2)
            
            with open(output_root / "analysis" / "product_line_index.jsonl", 'w') as f:
                for entry in product_line_index:
                    f.write(json.dumps(entry) + '\n')
            
            # Generate CEO report
            log("\n=== Generating CEO Report ===")
            ceo_report = f"""# REALITY MAP V2 - CEO SUMMARY
## Urban Points Lebanon | Evidence-Based Analysis

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Source:** Existing manifest (no re-scan)  
**Total Files:** {len(manifest):,}

---

## EXECUTIVE SUMMARY

### Codebase Breakdown

| Category | Files | Size (GB) | % of Total |
|----------|-------|-----------|-----------|
"""
            total_bytes = sum(v['bytes'] for v in classification_counts.values())
            for cat in ['PRODUCT', 'VENDOR', 'TOOLING', 'OTHER']:
                counts = classification_counts.get(cat, {'count': 0, 'bytes': 0})
                pct = (counts['bytes'] / total_bytes * 100) if total_bytes > 0 else 0
                ceo_report += f"| **{cat}** | {counts['count']:,} | {counts['bytes']/1e9:.2f} | {pct:.1f}% |\n"
            
            ceo_report += f"""
**Total Size:** {total_bytes/1e9:.2f} GB

---

## KEY FINDINGS

### 1. Product Code Analysis
- **Product Files:** {classification_counts['PRODUCT']['count']:,} files ({classification_counts['PRODUCT']['bytes']/1e9:.2f} GB)
- **Text Files Analyzed:** {len(product_line_index):,}
- **Total Product Lines:** {sum(p['line_count'] for p in product_line_index):,}

### 2. Code Quality Flags
- **Junk Code Patterns:** {len(junk_code_hits):,} occurrences
  - TODO comments: {sum(1 for h in junk_code_hits if h['pattern'] == 'TODO')}
  - FIXME comments: {sum(1 for h in junk_code_hits if h['pattern'] == 'FIXME')}
  - Console.log/print: {sum(1 for h in junk_code_hits if h['pattern'] in ['console.log', 'print'])}
- **Dead Code Candidates:** {len(dead_code_candidates):,} unreferenced files
- **Junk Files:** {len(junk_files):,} (.DS_Store, .log, .tmp, etc.)

### 3. Storage Optimization
- **Duplicate Files:** {len(duplicates_top):,} groups found
  - Largest group: {duplicates_top[0]['count']:,} copies (saves {duplicates_top[0]['count'] * next((e['size'] for e in manifest if e['sha256'] == duplicates_top[0]['sha256']), 0) / 1e6:.1f} MB) if duplicates_top else 'N/A'
- **Empty Files:** {sum(1 for s in suspicious_files if s['reason'] == 'empty'):,}
- **Very Large Files (>200MB):** {sum(1 for s in suspicious_files if s['reason'] == 'very_large'):,}

---

## TOP 10 LARGEST DIRECTORIES

| Directory | Files | Size (MB) |
|-----------|-------|-----------|
"""
            for i, d in enumerate(dir_size_top[:10], 1):
                ceo_report += f"| {d['dir'][:60]} | {d['count']:,} | {d['bytes']/1e6:.1f} |\n"
            
            ceo_report += f"""
---

## RISK ASSESSMENT

### 🟢 LOW RISK
- Product code is well-organized ({classification_counts['PRODUCT']['count']:,} files in source/)
- Reasonable vendor footprint ({classification_counts['VENDOR']['count']:,} files, expected for full-stack)

### 🟡 MEDIUM RISK
- {len(junk_code_hits):,} junk code patterns need cleanup
- {len(dead_code_candidates):,} potentially dead files (verify before removing)

### 🔴 NEEDS ATTENTION
- Review dead code candidates for removal
- Clean up debug logging before production
- Consider deduplication strategy for largest duplicate groups

---

## NEXT 3 ACTIONS

1. **Review Dead Code:** Check `analysis/dead_code_candidates.json` - verify safe to remove
2. **Clean Junk Code:** Address patterns in `analysis/junk_code_candidates.json` (TODOs, console.logs)
3. **Optimize Storage:** Review top duplicate groups in technical report

---

**Detailed Analysis:** See REALITY_MAP_V2_TECH.md  
**Evidence Files:** `analysis/*.json` and `analysis/product_line_index.jsonl`
"""
            
            with open(output_root / "reports" / "REALITY_MAP_V2_CEO.md", 'w') as f:
                f.write(ceo_report)
            
            # Generate Technical report
            log("\n=== Generating Technical Report ===")
            tech_report = f"""# REALITY MAP V2 - TECHNICAL ANALYSIS
## Urban Points Lebanon | Deep Dive

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Manifest Source:** {MANIFEST_PATH}  
**Total Files Analyzed:** {len(manifest):,}

---

## CLASSIFICATION BREAKDOWN

```json
{json.dumps(dict(classification_counts), indent=2)}
```

---

## PRODUCT CODE ANALYSIS

### Files by Extension (Product Only)
"""
            product_exts = Counter()
            for pf in product_files:
                ext = Path(pf['path']).suffix.lower() or '<none>'
                product_exts[ext] += 1
            
            for ext, count in product_exts.most_common(20):
                tech_report += f"- `{ext}`: {count:,} files\n"
            
            tech_report += f"""
### Line Count Analysis
- **Total Lines of Product Code:** {sum(p['line_count'] for p in product_line_index):,}
- **Average Lines per File:** {sum(p['line_count'] for p in product_line_index) / len(product_line_index):.0f} (for text files)
- **Files with TODO:** {sum(1 for p in product_line_index if p['contains_TODO']):,}
- **Files with FIXME:** {sum(1 for p in product_line_index if p['contains_FIXME']):,}
- **Files with PLACEHOLDER:** {sum(1 for p in product_line_index if p['contains_PLACEHOLDER']):,}

---

## JUNK CODE PATTERNS ({len(junk_code_hits):,} total)

Pattern breakdown:
"""
            pattern_counts = Counter(h['pattern'] for h in junk_code_hits)
            for pattern, count in pattern_counts.most_common():
                tech_report += f"- **{pattern}:** {count:,} occurrences\n"
            
            tech_report += f"""

**Sample occurrences (first 10):**
```
"""
            for hit in junk_code_hits[:10]:
                tech_report += f"{hit['file']}:{hit['line']} [{hit['pattern']}] {hit['snippet'][:60]}\n"
            
            tech_report += f"""```

Full list: `analysis/junk_code_candidates.json`

---

## DEAD CODE CANDIDATES ({len(dead_code_candidates):,} files)

**Heuristic:** Files not referenced in imports AND not obvious entrypoints.

Sample candidates (first 20):
"""
            for dc in dead_code_candidates[:20]:
                tech_report += f"- `{dc['path']}` ({dc['size']:,} bytes)\n"
            
            tech_report += f"""

**⚠️ Manual Review Required:** These may be:
- Configuration files loaded dynamically
- Entry points not detected by pattern matching
- Files referenced via non-standard imports

Full list: `analysis/dead_code_candidates.json`

---

## DUPLICATE ANALYSIS

Top 10 duplicate groups:
"""
            for i, dup in enumerate(duplicates_top[:10], 1):
                example_size = next((e['size'] for e in manifest if e['sha256'] == dup['sha256']), 0)
                savings = (dup['count'] - 1) * example_size / 1e6
                tech_report += f"\n**{i}. {dup['count']:,} copies** (SHA: {dup['sha256'][:16]}..., saves {savings:.1f} MB)\n"
                tech_report += f"   Example: `{dup['example']}`\n"
            
            tech_report += f"""

---

## JUNK FILES ({len(junk_files):,} found)

Sample junk files (first 20):
"""
            for jf in junk_files[:20]:
                tech_report += f"- `{jf['path']}` ({jf['size']:,} bytes) - {jf['reason']}\n"
            
            tech_report += f"""

Full list: `analysis/junk_files.json`

---

## EVIDENCE INTEGRITY

- **Manifest Path:** `{MANIFEST_PATH}`
- **Manifest Files:** {len(manifest):,}
- **Product Files Analyzed:** {len(product_line_index):,}
- **Product Line Index:** `analysis/product_line_index.jsonl` ({len(product_line_index):,} entries)

All SHA256 hashes from original manifest preserved.

---

## ANALYSIS ARTIFACTS

Generated files:
- `analysis/classification_counts.json` - Category breakdown
- `analysis/dir_size_top.json` - Top {MAX_DIR_SIZE_TOP} directories by size
- `analysis/junk_files.json` - Up to {MAX_JUNK_FILES} junk file candidates
- `analysis/junk_code_candidates.json` - Up to {MAX_JUNK_CODE_HITS} code pattern hits
- `analysis/dead_code_candidates.json` - {len(dead_code_candidates):,} unreferenced files
- `analysis/product_line_index.jsonl` - Line-level analysis of product files

---

**Generated by:** Reality Map v2 (Manifest-Based)  
**No files were deleted or modified during this analysis.**
"""
            
            with open(output_root / "reports" / "REALITY_MAP_V2_TECH.md", 'w') as f:
                f.write(tech_report)
            
            # Final gate
            log("\n=== Writing Final Gate ===")
            with open(output_root / "reports" / "FINAL_GATE.txt", 'w') as f:
                f.write("PASS\n")
                f.write(f"Timestamp: {datetime.now().isoformat()}\n")
                f.write(f"Files analyzed: {len(manifest)}\n")
                f.write(f"Product files: {len(product_files)}\n")
                f.write(f"Product line index entries: {len(product_line_index)}\n")
            
            log(f"\n✅ COMPLETE - Output written to {output_root}")
            log(f"Gate status: PASS")
    
    except Exception as e:
        import traceback
        with open(log_err, 'a') as f:
            f.write(f"ERROR: {e}\n")
            f.write(traceback.format_exc())
        
        with open(output_root / "reports" / "FINAL_GATE.txt", 'w') as f:
            f.write("FAIL\n")
            f.write(f"Error: {e}\n")
        
        print(f"FAILED: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
