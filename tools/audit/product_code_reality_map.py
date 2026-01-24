#!/usr/bin/env python3
"""
Product Code Reality Map - Read source/apps/** and source/backend/** only
NO skip. Every file. Line-by-line analysis.
"""
import os
import json
import hashlib
import re
from pathlib import Path
from datetime import datetime
from collections import defaultdict

OUTPUT_DIR = 'reality_map'
PRODUCT_ROOTS = ['source/apps', 'source/backend']

# Exclude patterns (nested)
EXCLUDE_PATTERNS = {
    '.git/', 'local-ci/', 'node_modules/', '/build/', '/dist/', '/.next/',
    '/.dart_tool/', '/coverage/', '/venv/', '/.venv/', '__pycache__/', '.cache/',
    '.pyc', '.so', '.o', '.a', '.lib', '.dll', '.exe', '.zip', '.tar', '.gz',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '/logs/', '/log/', '.log', '.pid', '.tmp', '.temp',
}

# Code file extensions (text)
CODE_EXTENSIONS = {
    '.ts', '.tsx', '.js', '.jsx', '.json', '.dart', '.yaml', '.yml',
    '.py', '.java', '.kt', '.swift', '.m', '.mm', '.c', '.cpp', '.h',
    '.hpp', '.cs', '.php', '.sql', '.sh', '.bash', '.go', '.rs', '.rb',
    '.html', '.css', '.scss', '.less', '.graphql', '.proto', '.xml',
}

# Junk code patterns
JUNK_PATTERNS = [
    (r'\bTODO\b', 'TODO'),
    (r'\bFIXME\b', 'FIXME'),
    (r'\bHACK\b', 'HACK'),
    (r'\bPLACEHOLDER\b', 'PLACEHOLDER'),
    (r'console\.log\(', 'console.log'),
    (r'\bprint\(', 'print('),
    (r'\bdebugger\b', 'debugger'),
]

def should_exclude(rel_path):
    """Check if path should be excluded"""
    path_str = str(rel_path)
    for pattern in EXCLUDE_PATTERNS:
        if pattern in path_str:
            return True
    return False

def is_code_file(rel_path):
    """Check if file is code (by extension)"""
    ext = Path(rel_path).suffix.lower()
    return ext in CODE_EXTENSIONS

def sha256_file(path):
    """Compute file SHA256"""
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while chunk := f.read(1024*1024):
            h.update(chunk)
    return h.hexdigest()

def read_code_file(path):
    """Read code file and extract metadata"""
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
        
        line_count = len(lines)
        sha256 = sha256_file(path)
        size = os.path.getsize(path)
        
        junk_hits = []
        for line_num, line in enumerate(lines, 1):
            for pattern, label in JUNK_PATTERNS:
                if re.search(pattern, line, re.IGNORECASE):
                    snippet = line.strip()[:150]
                    junk_hits.append({
                        'file': str(path),
                        'line': line_num,
                        'pattern': label,
                        'snippet': snippet
                    })
        
        return {
            'path': str(path),
            'size': size,
            'sha256': sha256,
            'line_count': line_count,
            'junk_code_hits': junk_hits,
            'error': None
        }
    except Exception as e:
        return {
            'path': str(path),
            'error': str(e)
        }

def walk_product_code(repo_root):
    """Walk only source/apps and source/backend"""
    files_read = []
    errors = []
    
    for root_folder in PRODUCT_ROOTS:
        root_path = repo_root / root_folder
        if not root_path.exists():
            errors.append(f"Product root missing: {root_folder}")
            continue
        
        for root, dirs, filenames in os.walk(root_path):
            # Filter excluded dirs
            dirs[:] = [d for d in dirs if not should_exclude(os.path.join(root, d))]
            
            for fname in filenames:
                full_path = os.path.join(root, fname)
                rel_path = os.path.relpath(full_path, repo_root)
                
                # Skip excluded and non-code
                if should_exclude(rel_path) or not is_code_file(rel_path):
                    continue
                
                # Read file
                result = read_code_file(full_path)
                if result['error']:
                    errors.append(f"{rel_path}: {result['error']}")
                else:
                    files_read.append(result)
    
    return files_read, errors

def detect_dead_code(files_read):
    """Detect unreferenced code files"""
    # Build import graph from all code files
    referenced_files = set()
    file_paths = {f['path'].replace('\\', '/').lower(): f for f in files_read}
    
    for file_info in files_read:
        try:
            with open(file_info['path'], 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
            
            # Extract imports/requires
            import_patterns = [
                r"import\s+['\"]([^'\"]+)['\"]",
                r'from\s+["\']([^"\']+)["\']',
                r'require\(["\']([^"\']+)["\']\)',
                r'import\s+\*\s+from\s+["\']([^"\']+)["\']',
            ]
            
            for pattern in import_patterns:
                for match in re.finditer(pattern, content):
                    imported = match.group(1).lower()
                    # Normalize path
                    for key in file_paths:
                        if imported in key or key.endswith(imported):
                            referenced_files.add(key)
        except:
            pass
    
    dead_code = []
    for file_info in files_read:
        normalized_path = file_info['path'].replace('\\', '/').lower()
        
        # Likely entrypoints
        if any(ep in normalized_path for ep in ['main.', 'index.', 'app.', 'pages/', '/api/']):
            continue
        
        if normalized_path not in referenced_files:
            dead_code.append({
                'path': file_info['path'],
                'size': file_info['size'],
                'reason': 'unreferenced_in_imports'
            })
    
    return dead_code

def main():
    repo_root = Path.cwd()
    output_dir = repo_root / OUTPUT_DIR
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Reading product code from: {PRODUCT_ROOTS}")
    print(f"Excluding: node_modules, build, dist, .next, .dart_tool, venv, logs, etc.")
    print()
    
    # Walk and read files
    print("=== Reading Product Code ===")
    files_read, read_errors = walk_product_code(repo_root)
    print(f"Files read: {len(files_read)}")
    print(f"Read errors: {len(read_errors)}")
    
    if read_errors:
        print("\nErrors encountered:")
        for err in read_errors[:10]:
            print(f"  - {err}")
        if len(read_errors) > 10:
            print(f"  ... and {len(read_errors) - 10} more")
    
    # Aggregate junk code
    print("\n=== Analyzing Junk Code ===")
    all_junk_hits = []
    for file_info in files_read:
        all_junk_hits.extend(file_info.get('junk_code_hits', []))
    print(f"Junk code hits: {len(all_junk_hits)}")
    
    # Detect dead code
    print("\n=== Detecting Dead Code ===")
    dead_code = detect_dead_code(files_read)
    print(f"Dead code candidates: {len(dead_code)}")
    
    # Write FILES_READ.json
    print("\n=== Writing Outputs ===")
    files_read_output = [
        {
            'path': f['path'],
            'bytes': f['size'],
            'sha256': f['sha256'],
            'line_count': f['line_count']
        }
        for f in files_read
    ]
    
    with open(output_dir / 'FILES_READ.json', 'w') as f:
        json.dump(files_read_output, f, indent=2)
    print(f"  Wrote FILES_READ.json ({len(files_read_output)} files)")
    
    # Write JUNK_CODE.json
    with open(output_dir / 'JUNK_CODE.json', 'w') as f:
        json.dump(all_junk_hits, f, indent=2)
    print(f"  Wrote JUNK_CODE.json ({len(all_junk_hits)} hits)")
    
    # Write DEAD_CODE.json
    with open(output_dir / 'DEAD_CODE.json', 'w') as f:
        json.dump(dead_code, f, indent=2)
    print(f"  Wrote DEAD_CODE.json ({len(dead_code)} candidates)")
    
    # Compute statistics
    total_lines = sum(f['line_count'] for f in files_read)
    total_bytes = sum(f['size'] for f in files_read)
    junk_by_pattern = defaultdict(int)
    for hit in all_junk_hits:
        junk_by_pattern[hit['pattern']] += 1
    
    # Write REALITY_MAP.md
    reality_map_md = f"""# PRODUCT CODE REALITY MAP
## Urban Points Lebanon | source/apps/** and source/backend/** only

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

---

## EXECUTIVE SUMMARY

### Scope
- **Product roots scanned:** {', '.join(PRODUCT_ROOTS)}
- **Excluded:** node_modules, build, dist, .next, .dart_tool, venv, logs, docs, PDFs, generated artifacts
- **Reads per file:** 100% line-by-line (NO skip)

### File Inventory
- **Total code files:** {len(files_read)}
- **Total bytes:** {total_bytes:,} ({total_bytes/1e6:.1f} MB)
- **Total lines of code:** {total_lines:,}
- **Average lines/file:** {total_lines//len(files_read) if files_read else 0}

### Code Quality Issues
- **Junk code hits:** {len(all_junk_hits)}
- **Dead code candidates:** {len(dead_code)}

---

## JUNK CODE PATTERN BREAKDOWN

"""
    for pattern, count in sorted(junk_by_pattern.items(), key=lambda x: -x[1]):
        reality_map_md += f"- **{pattern}:** {count:,} occurrences\n"
    
    reality_map_md += f"""
---

## TOP JUNK CODE OCCURRENCES

"""
    for i, hit in enumerate(sorted(all_junk_hits, key=lambda x: x['file'])[:50], 1):
        reality_map_md += f"{i}. `{hit['file']}:{hit['line']}` [{hit['pattern']}] {hit['snippet'][:80]}\n"
    
    if len(all_junk_hits) > 50:
        reality_map_md += f"\n... and {len(all_junk_hits) - 50} more in JUNK_CODE.json\n"
    
    reality_map_md += f"""
---

## DEAD CODE CANDIDATES

**Total:** {len(dead_code)} unreferenced files

Sample:
"""
    for dc in dead_code[:20]:
        reality_map_md += f"- `{dc['path']}` ({dc['size']:,} bytes)\n"
    
    if len(dead_code) > 20:
        reality_map_md += f"\n... and {len(dead_code) - 20} more in DEAD_CODE.json\n"
    
    reality_map_md += f"""
---

## READ ERRORS & COMPLETENESS

**Read errors encountered:** {len(read_errors)}
"""
    if read_errors:
        reality_map_md += "\nErrors:\n"
        for err in read_errors[:20]:
            reality_map_md += f"- {err}\n"
        if len(read_errors) > 20:
            reality_map_md += f"\n... and {len(read_errors) - 20} more\n"
    
    reality_map_md += f"""
---

## RECOMMENDATIONS

1. **Clean junk code:** Remove {junk_by_pattern.get('console.log', 0) + junk_by_pattern.get('print(', 0)} debug statements
2. **Review TODOs:** Address {junk_by_pattern.get('TODO', 0)} TODO comments
3. **Evaluate dead code:** Review {len(dead_code)} potentially unreferenced files
4. **Remove placeholder code:** Clean {junk_by_pattern.get('PLACEHOLDER', 0)} placeholder entries

---

**Analysis Details:** See FILES_READ.json, JUNK_CODE.json, DEAD_CODE.json
"""
    
    with open(output_dir / 'REALITY_MAP.md', 'w') as f:
        f.write(reality_map_md)
    print(f"  Wrote REALITY_MAP.md")
    
    # Determine gate status
    gate_pass = len(read_errors) == 0
    
    gate_content = f"""{"PASS" if gate_pass else "FAIL"}
Timestamp: {datetime.now().isoformat()}
Files read: {len(files_read)}
Total lines: {total_lines:,}
Read errors: {len(read_errors)}
Junk code hits: {len(all_junk_hits)}
Dead code candidates: {len(dead_code)}
"""
    
    if not gate_pass:
        gate_content += f"\nUnreadable/Missing files ({len(read_errors)}):\n"
        for err in read_errors[:50]:
            gate_content += f"- {err}\n"
        if len(read_errors) > 50:
            gate_content += f"... and {len(read_errors) - 50} more\n"
    
    with open(output_dir / 'FINAL_GATE.txt', 'w') as f:
        f.write(gate_content)
    print(f"  Wrote FINAL_GATE.txt")
    
    # Print summary
    print()
    print("=" * 80)
    print(f"GATE STATUS: {'PASS ✅' if gate_pass else 'FAIL ❌'}")
    print("=" * 80)
    print()
    print(f"Files read: {len(files_read)}")
    print(f"Lines: {total_lines:,}")
    print(f"Junk code hits: {len(all_junk_hits)}")
    print(f"Dead code: {len(dead_code)}")
    print(f"Read errors: {len(read_errors)}")
    print()

if __name__ == "__main__":
    main()
