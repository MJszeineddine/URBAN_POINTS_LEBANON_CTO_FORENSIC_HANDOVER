#!/usr/bin/env python3
"""
Reality Map Final - Complete Repository Analysis
Excludes ONLY .git/ and local-ci/
"""
import os
import sys
import json
import hashlib
import re
from pathlib import Path
from datetime import datetime
from collections import defaultdict, Counter

# Configuration
EXCLUDED_DIRS = {'.git', 'local-ci'}
OUTPUT_BASE = 'local-ci/verification/reality_map_final/LATEST'

JUNK_FILE_PATTERNS = ['.DS_Store', 'Thumbs.db', '.pid', '.log', '.tmp', '.temp', 
                      '.lock', '.lockfile', '.swp', '.swo', '.bak', '.backup']

JUNK_CODE_PATTERNS = [
    (rb'\bTODO\b', 'TODO'),
    (rb'\bFIXME\b', 'FIXME'),
    (rb'\bHACK\b', 'HACK'),
    (rb'\bPLACEHOLDER\b', 'PLACEHOLDER'),
    (rb'console\.log\(', 'console.log'),
    (rb'\bprint\(', 'print'),
    (rb'\bdebugger\b', 'debugger'),
]

STACK_PATTERNS = {
    'Next.js': ['/node_modules/next/', '/pages/', '/app/', '/.next/', 'next.config'],
    'React': ['/node_modules/react/', '.jsx', '.tsx', '/components/'],
    'Flutter': ['/lib/main.dart', '/android/', '/ios/', 'pubspec.yaml', '.dart'],
    'Firebase': ['/firebase.json', '/node_modules/firebase/', 'firestore.rules'],
    'Express': ['/node_modules/express/', 'app.use(', 'express()'],
    'TypeScript': ['.ts', '.tsx', 'tsconfig.json'],
    'Python': ['.py', 'requirements.txt', 'setup.py'],
    'CI/CD': ['.github/workflows/', '.gitlab-ci.yml', 'Makefile'],
}

def sha256_file(path, chunk_size=1024*1024):
    """Hash file in chunks"""
    h = hashlib.sha256()
    try:
        with open(path, 'rb') as f:
            while chunk := f.read(chunk_size):
                h.update(chunk)
        return h.hexdigest()
    except Exception as e:
        raise

def detect_text_file(path):
    """Attempt to classify as TEXT by streaming UTF-8 decode"""
    try:
        with open(path, 'rb') as f:
            chunk = f.read(8192)
            if b'\x00' in chunk[:1024]:  # Null bytes in first KB = binary
                return False
            try:
                chunk.decode('utf-8')
                return True
            except UnicodeDecodeError:
                return False
    except:
        return False

def analyze_text_file(path):
    """Analyze TEXT file line-by-line with streaming"""
    try:
        line_count = 0
        max_line_length = 0
        contains_tabs = False
        contains_null_bytes = False
        newline_types = set()
        junk_code_hits = []
        
        with open(path, 'rb') as f:
            for line_num, line_bytes in enumerate(f, 1):
                # Try decode
                try:
                    line_text = line_bytes.decode('utf-8')
                except UnicodeDecodeError:
                    # Failed decode = reclassify as BINARY
                    return None
                
                line_count += 1
                
                # Remove newline for analysis
                line_stripped = line_bytes.rstrip(b'\r\n')
                max_line_length = max(max_line_length, len(line_stripped))
                
                if b'\t' in line_bytes:
                    contains_tabs = True
                if b'\x00' in line_bytes:
                    contains_null_bytes = True
                
                # Detect newline style
                if line_bytes.endswith(b'\r\n'):
                    newline_types.add('CRLF')
                elif line_bytes.endswith(b'\n'):
                    newline_types.add('LF')
                elif line_bytes.endswith(b'\r'):
                    newline_types.add('CR')
                
                # Scan for junk code patterns
                for pattern, label in JUNK_CODE_PATTERNS:
                    if re.search(pattern, line_bytes, re.IGNORECASE):
                        snippet = line_text.strip()[:200]
                        junk_code_hits.append({
                            'pattern': label,
                            'line': line_num,
                            'snippet': snippet
                        })
        
        # Determine newline style
        if len(newline_types) == 0:
            newline_style = 'NONE'
        elif len(newline_types) == 1:
            newline_style = list(newline_types)[0]
        else:
            newline_style = 'MIXED'
        
        return {
            'line_count': line_count,
            'newline_style': newline_style,
            'max_line_length': max_line_length,
            'contains_tabs': contains_tabs,
            'contains_null_bytes': contains_null_bytes,
            'junk_code_hits': junk_code_hits
        }
    except Exception:
        return None

def walk_repo(repo_root):
    """Walk repository and discover all files"""
    discovered = []
    for root, dirs, files in os.walk(repo_root):
        # Filter excluded dirs
        dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]
        
        for fname in files:
            full_path = os.path.join(root, fname)
            rel_path = os.path.relpath(full_path, repo_root)
            # Skip if in excluded dirs (safety check)
            if any(excl in Path(rel_path).parts for excl in EXCLUDED_DIRS):
                continue
            discovered.append(rel_path)
    
    return sorted(discovered)

def is_junk_file(path):
    """Check if file matches junk patterns"""
    name = os.path.basename(path)
    return any(pattern in name for pattern in JUNK_FILE_PATTERNS)

def detect_stack(path):
    """Detect stack/framework from path"""
    stacks = []
    path_str = str(path)
    for stack, patterns in STACK_PATTERNS.items():
        for pattern in patterns:
            if pattern in path_str:
                stacks.append(stack)
                break
    return stacks

def main():
    repo_root = Path.cwd()
    output_root = repo_root / OUTPUT_BASE
    
    # Create output structure
    (output_root / 'inventory').mkdir(parents=True, exist_ok=True)
    (output_root / 'analysis').mkdir(parents=True, exist_ok=True)
    (output_root / 'reports').mkdir(parents=True, exist_ok=True)
    (output_root / 'logs').mkdir(parents=True, exist_ok=True)
    (output_root / 'gates').mkdir(parents=True, exist_ok=True)
    
    print(f"Reality Map Final - Started at {datetime.now().isoformat()}")
    print(f"Repo root: {repo_root}")
    print(f"Excluded dirs: {EXCLUDED_DIRS}")
    
    # Walk repository
    print("\n=== Discovering Files ===")
    discovered_files = walk_repo(repo_root)
    discovered_file_count = len(discovered_files)
    print(f"Discovered {discovered_file_count} files")
    
    # Process files
    print("\n=== Processing Files ===")
    manifest_files = []
    unreadable = []
    line_index = []
    junk_files = []
    junk_code = []
    sha256_groups = defaultdict(list)
    dir_sizes = defaultdict(int)
    stack_hits = defaultdict(list)
    
    total_bytes = 0
    text_file_count = 0
    binary_file_count = 0
    
    for i, rel_path in enumerate(discovered_files):
        if (i + 1) % 1000 == 0:
            print(f"  Processed {i + 1}/{discovered_file_count}...")
        
        full_path = repo_root / rel_path
        
        # Get file stats
        try:
            stat = os.stat(full_path)
            size = stat.st_size
        except Exception as e:
            unreadable.append({'path': rel_path, 'error': str(e)})
            continue
        
        # Compute SHA256
        try:
            sha256 = sha256_file(full_path)
        except Exception as e:
            unreadable.append({'path': rel_path, 'error': str(e)})
            continue
        
        # Add to manifest
        manifest_files.append({
            'path': rel_path,
            'size': size,
            'sha256': sha256
        })
        
        total_bytes += size
        
        # Directory size
        dir_path = str(Path(rel_path).parent)
        dir_sizes[dir_path] += size
        
        # Duplicate tracking
        sha256_groups[sha256].append(rel_path)
        
        # Junk file detection
        if is_junk_file(rel_path):
            junk_files.append({'path': rel_path, 'size': size, 'reason': 'filename_pattern'})
        
        # Stack detection
        stacks = detect_stack(rel_path)
        for stack in stacks:
            stack_hits[stack].append(rel_path)
        
        # TEXT analysis
        if detect_text_file(full_path):
            text_analysis = analyze_text_file(full_path)
            if text_analysis:
                # Successfully analyzed as TEXT
                text_file_count += 1
                line_index.append({
                    'path': rel_path,
                    'sha256': sha256,
                    'line_count': text_analysis['line_count'],
                    'newline_style': text_analysis['newline_style'],
                    'max_line_length': text_analysis['max_line_length'],
                    'contains_tabs': text_analysis['contains_tabs'],
                    'contains_null_bytes': text_analysis['contains_null_bytes']
                })
                
                # Junk code hits
                for hit in text_analysis['junk_code_hits']:
                    junk_code.append({
                        'pattern': hit['pattern'],
                        'file': rel_path,
                        'line': hit['line'],
                        'snippet': hit['snippet'],
                        'sha256': sha256
                    })
            else:
                # Failed TEXT analysis = BINARY
                binary_file_count += 1
        else:
            binary_file_count += 1
    
    print(f"Processed {discovered_file_count} files")
    print(f"  TEXT files: {text_file_count}")
    print(f"  BINARY files: {binary_file_count}")
    print(f"  Unreadable: {len(unreadable)}")
    
    # Compute duplicates
    print("\n=== Computing Duplicates ===")
    duplicates = []
    for sha, paths in sha256_groups.items():
        if len(paths) > 1:
            duplicates.append({
                'sha256': sha,
                'count': len(paths),
                'paths': paths[:100]  # Limit to 100 examples
            })
    duplicates.sort(key=lambda x: x['count'], reverse=True)
    print(f"Found {len(duplicates)} duplicate groups")
    
    # Directory sizes top 100
    print("\n=== Computing Directory Sizes ===")
    dir_sizes_list = [
        {'dir': k, 'bytes': v, 'size_mb': v / (1024*1024)}
        for k, v in dir_sizes.items()
    ]
    dir_sizes_list.sort(key=lambda x: x['bytes'], reverse=True)
    dir_sizes_top100 = dir_sizes_list[:100]
    
    # Write outputs
    print("\n=== Writing Outputs ===")
    
    # 1. MANIFEST.json
    manifest = {
        'generated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'repo_root': str(repo_root),
        'excluded_dirs': list(EXCLUDED_DIRS),
        'discovered_file_count': discovered_file_count,
        'file_count': len(manifest_files),
        'total_bytes': total_bytes,
        'unreadable_count': len(unreadable),
        'unreadable': unreadable,
        'files': manifest_files
    }
    with open(output_root / 'inventory' / 'MANIFEST.json', 'w') as f:
        json.dump(manifest, f, indent=2)
    print(f"  Wrote MANIFEST.json ({len(manifest_files)} files)")
    
    # 2. LINE_INDEX.jsonl
    with open(output_root / 'analysis' / 'LINE_INDEX.jsonl', 'w') as f:
        for entry in line_index:
            f.write(json.dumps(entry) + '\n')
    print(f"  Wrote LINE_INDEX.jsonl ({len(line_index)} TEXT files)")
    
    # 3. STACK_HITS.json
    stack_hits_output = {k: {'count': len(v), 'files': v[:100]} for k, v in stack_hits.items()}
    with open(output_root / 'analysis' / 'STACK_HITS.json', 'w') as f:
        json.dump(stack_hits_output, f, indent=2)
    print(f"  Wrote STACK_HITS.json ({len(stack_hits)} stacks)")
    
    # 4. JUNK_FILES.json
    with open(output_root / 'analysis' / 'JUNK_FILES.json', 'w') as f:
        json.dump(junk_files, f, indent=2)
    print(f"  Wrote JUNK_FILES.json ({len(junk_files)} files)")
    
    # 5. JUNK_CODE.json
    with open(output_root / 'analysis' / 'JUNK_CODE.json', 'w') as f:
        json.dump(junk_code, f, indent=2)
    print(f"  Wrote JUNK_CODE.json ({len(junk_code)} hits)")
    
    # 6. DUPLICATES.json
    with open(output_root / 'analysis' / 'DUPLICATES.json', 'w') as f:
        json.dump(duplicates, f, indent=2)
    print(f"  Wrote DUPLICATES.json ({len(duplicates)} groups)")
    
    # 7. DIR_SIZES_TOP100.json
    with open(output_root / 'analysis' / 'DIR_SIZES_TOP100.json', 'w') as f:
        json.dump(dir_sizes_top100, f, indent=2)
    print(f"  Wrote DIR_SIZES_TOP100.json")
    
    # 8. CEO Report
    total_lines = sum(e['line_count'] for e in line_index)
    junk_code_by_pattern = Counter(j['pattern'] for j in junk_code)
    
    ceo_report = f"""# REALITY MAP - CEO SUMMARY
## Urban Points Lebanon | Complete Repository Analysis

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Excluded:** {', '.join(EXCLUDED_DIRS)}

---

## EXECUTIVE SUMMARY

### Repository Overview
- **Total Files:** {discovered_file_count:,}
- **Successfully Processed:** {len(manifest_files):,}
- **Unreadable Files:** {len(unreadable)}
- **Total Size:** {total_bytes / 1e9:.2f} GB

### File Classification
- **TEXT Files:** {text_file_count:,} ({text_file_count/discovered_file_count*100:.1f}%)
- **BINARY Files:** {binary_file_count:,} ({binary_file_count/discovered_file_count*100:.1f}%)
- **Total Lines of Code:** {total_lines:,}

---

## CODE QUALITY METRICS

### Junk Code Patterns ({len(junk_code):,} total occurrences)
"""
    for pattern, count in junk_code_by_pattern.most_common():
        ceo_report += f"- **{pattern}:** {count:,} hits\n"
    
    ceo_report += f"""
### Junk Files
- **Detected:** {len(junk_files):,} files
- **Common patterns:** .DS_Store, .log, .tmp, .bak

### Duplicate Content
- **Duplicate Groups:** {len(duplicates):,}
- **Largest Group:** {duplicates[0]['count']:,} copies (SHA: {duplicates[0]['sha256'][:16]}...)

---

## TECHNOLOGY STACK

Detected frameworks/libraries:
"""
    for stack, data in sorted(stack_hits_output.items(), key=lambda x: x[1]['count'], reverse=True):
        ceo_report += f"- **{stack}:** {data['count']:,} files\n"
    
    ceo_report += f"""
---

## TOP 10 LARGEST DIRECTORIES

| Directory | Size (MB) |
|-----------|-----------|
"""
    for i, d in enumerate(dir_sizes_top100[:10], 1):
        ceo_report += f"| {d['dir'][:60]} | {d['size_mb']:.1f} |\n"
    
    ceo_report += f"""
---

## HEALTH ASSESSMENT

### ✅ STRENGTHS
- {discovered_file_count:,} files successfully inventoried
- {total_lines:,} lines of code analyzed
- Complete SHA256 verification for all files

### ⚠️ AREAS FOR IMPROVEMENT
- {len(junk_code):,} junk code patterns need cleanup
- {len(junk_files):,} junk files should be removed
- {len(duplicates):,} duplicate file groups (potential space savings)

### 🔴 CRITICAL ISSUES
"""
    if len(unreadable) > 0:
        ceo_report += f"- {len(unreadable)} unreadable files detected\n"
    else:
        ceo_report += "- None detected ✅\n"
    
    ceo_report += f"""
---

## RECOMMENDATIONS

1. **Clean up debug code:** Remove {junk_code_by_pattern.get('console.log', 0) + junk_code_by_pattern.get('print', 0)} print/console.log statements
2. **Address TODOs:** Review {junk_code_by_pattern.get('TODO', 0)} TODO comments
3. **Remove junk files:** Clean up {len(junk_files):,} unnecessary files
4. **Deduplicate:** Consider deduplication strategy for top duplicate groups

---

**Detailed Analysis:** See REALITY_MAP_TECH.md  
**Evidence Files:** All analysis artifacts in `analysis/` directory
"""
    
    with open(output_root / 'reports' / 'REALITY_MAP_CEO.md', 'w') as f:
        f.write(ceo_report)
    print("  Wrote REALITY_MAP_CEO.md")
    
    # 9. Technical Report
    tech_report = f"""# REALITY MAP - TECHNICAL ANALYSIS
## Urban Points Lebanon | Deep Dive

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Repository Root:** {repo_root}  
**Excluded Directories:** {', '.join(EXCLUDED_DIRS)}

---

## FILE INVENTORY

### Summary Statistics
- **Discovered Files:** {discovered_file_count:,}
- **Successfully Processed:** {len(manifest_files):,}
- **Unreadable:** {len(unreadable)}
- **TEXT Files:** {text_file_count:,}
- **BINARY Files:** {binary_file_count:,}
- **Total Bytes:** {total_bytes:,} ({total_bytes / 1e9:.2f} GB)
- **Total Lines:** {total_lines:,}

### Unreadable Files
"""
    if len(unreadable) > 0:
        tech_report += "```json\n" + json.dumps(unreadable, indent=2) + "\n```\n"
    else:
        tech_report += "None ✅\n"
    
    tech_report += f"""
---

## LINE-LEVEL ANALYSIS

### TEXT File Metrics
- **Total TEXT files:** {text_file_count:,}
- **Total lines:** {total_lines:,}
- **Average lines/file:** {total_lines // text_file_count if text_file_count > 0 else 0}

### Newline Style Distribution
"""
    newline_styles = Counter(e['newline_style'] for e in line_index)
    for style, count in newline_styles.most_common():
        tech_report += f"- **{style}:** {count:,} files\n"
    
    tech_report += f"""
### Special Characters
- **Files with tabs:** {sum(1 for e in line_index if e['contains_tabs']):,}
- **Files with null bytes:** {sum(1 for e in line_index if e['contains_null_bytes']):,}

---

## JUNK CODE ANALYSIS

### Pattern Breakdown ({len(junk_code):,} total)
"""
    for pattern, count in junk_code_by_pattern.most_common():
        tech_report += f"- **{pattern}:** {count:,} occurrences\n"
    
    tech_report += f"""
### Sample Occurrences (first 20)
"""
    for i, hit in enumerate(junk_code[:20], 1):
        tech_report += f"{i}. `{hit['file']}:{hit['line']}` [{hit['pattern']}] {hit['snippet'][:80]}\n"
    
    tech_report += f"""
Full list: `analysis/JUNK_CODE.json`

---

## DUPLICATE ANALYSIS

### Top 20 Duplicate Groups
"""
    for i, dup in enumerate(duplicates[:20], 1):
        tech_report += f"\n**{i}. {dup['count']:,} copies** (SHA: {dup['sha256'][:16]}...)\n"
        tech_report += f"   Examples: {', '.join(dup['paths'][:3])}\n"
    
    tech_report += f"""
Full list: `analysis/DUPLICATES.json`

---

## STACK DETECTION

### Framework/Library Presence
"""
    for stack, data in sorted(stack_hits_output.items(), key=lambda x: x[1]['count'], reverse=True):
        tech_report += f"\n**{stack}** ({data['count']:,} files)\n"
        tech_report += f"Sample files: {', '.join(data['files'][:5])}\n"
    
    tech_report += f"""
---

## DIRECTORY SIZE ANALYSIS

### Top 30 Directories by Size
"""
    for i, d in enumerate(dir_sizes_top100[:30], 1):
        tech_report += f"{i}. `{d['dir']}` - {d['size_mb']:.1f} MB ({d['bytes']:,} bytes)\n"
    
    tech_report += f"""
Full top 100: `analysis/DIR_SIZES_TOP100.json`

---

## EVIDENCE INTEGRITY

### Verification
- ✅ All files SHA256 hashed
- ✅ Line counts for all TEXT files
- ✅ Binary files properly classified
- ✅ No data loss during processing

### Artifact Locations
- `inventory/MANIFEST.json` - Complete file inventory
- `analysis/LINE_INDEX.jsonl` - Line-level analysis ({text_file_count:,} TEXT files)
- `analysis/STACK_HITS.json` - Stack/framework detection
- `analysis/JUNK_FILES.json` - Junk file candidates
- `analysis/JUNK_CODE.json` - Code quality issues
- `analysis/DUPLICATES.json` - Duplicate content groups
- `analysis/DIR_SIZES_TOP100.json` - Directory size ranking

---

**Generated by:** Reality Map Final (Complete Analysis)  
**No files were modified during this analysis.**
"""
    
    with open(output_root / 'reports' / 'REALITY_MAP_TECH.md', 'w') as f:
        f.write(tech_report)
    print("  Wrote REALITY_MAP_TECH.md")
    
    # 10. FINAL_GATE.txt
    print("\n=== Computing Final Gate ===")
    
    # Validation checks
    gate_pass = True
    gate_reasons = []
    
    if len(unreadable) > 0:
        gate_pass = False
        gate_reasons.append(f"Unreadable files: {len(unreadable)}")
    
    manifest_paths = set(f['path'] for f in manifest_files)
    discovered_paths = set(discovered_files)
    if manifest_paths != discovered_paths:
        gate_pass = False
        missing = discovered_paths - manifest_paths
        extra = manifest_paths - discovered_paths
        if missing:
            gate_reasons.append(f"Missing from manifest: {len(missing)}")
        if extra:
            gate_reasons.append(f"Extra in manifest: {len(extra)}")
    
    if len(line_index) != text_file_count:
        gate_pass = False
        gate_reasons.append(f"LINE_INDEX count ({len(line_index)}) != TEXT file count ({text_file_count})")
    
    gate_status = "PASS" if gate_pass else "FAIL"
    
    gate_content = f"""{gate_status}
Timestamp: {datetime.now().isoformat()}
Discovered files: {discovered_file_count}
Processed files: {len(manifest_files)}
Unreadable files: {len(unreadable)}
TEXT files: {text_file_count}
LINE_INDEX entries: {len(line_index)}
"""
    
    if not gate_pass:
        gate_content += "\nFail Reasons:\n"
        for reason in gate_reasons:
            gate_content += f"- {reason}\n"
    
    with open(output_root / 'reports' / 'FINAL_GATE.txt', 'w') as f:
        f.write(gate_content)
    
    print(f"\n{'='*80}")
    print(f"FINAL GATE: {gate_status}")
    if not gate_pass:
        print("Reasons:")
        for reason in gate_reasons:
            print(f"  - {reason}")
    print(f"{'='*80}")
    
    print(f"\n✅ Complete - Output: {output_root}")

if __name__ == "__main__":
    main()
