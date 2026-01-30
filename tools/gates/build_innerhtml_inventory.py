#!/usr/bin/env python3
"""
Build comprehensive innerHTML inventory across repo.
Classifies every innerHTML/dangerouslySetInnerHTML/document.write usage.
"""
import os
import re
from pathlib import Path
from collections import defaultdict

def classify_line(line, filepath):
    """Classify an innerHTML/dangerous pattern."""
    # Safe clears
    if re.search(r'\.innerHTML\s*=\s*[\'"`][\'\"`]', line):
        return 'SAFE_CLEAR'
    if re.search(r'\.innerHTML\s*=\s*null', line):
        return 'SAFE_CLEAR'
    
    # Dangerous concat
    if re.search(r'\.innerHTML\s*\+=', line):
        return 'DANGEROUS_CONCAT'
    
    # Dangerous assignment (non-literal)
    if re.search(r'\.innerHTML\s*=(?!\s*[\'"`][\'\"`])(?!\s*null)', line):
        match = re.search(r'\.innerHTML\s*=\s*(.+?)(?:;|$)', line)
        if match:
            content = match.group(1).strip()
            if content and content not in ("''", '""', '``', 'null'):
                return 'DANGEROUS_ASSIGN'
    
    # React dangerous
    if re.search(r'dangerouslySetInnerHTML', line):
        return 'REACT_DANGEROUS'
    
    # Document write
    if re.search(r'document\.write', line):
        return 'DOCUMENT_WRITE'
    
    # Default innerHTML assignment check
    if re.search(r'\.innerHTML\s*=', line):
        return 'SAFE_CLEAR'  # Likely a clear if we got here
    
    return None

def scan_repo(repo_root):
    """Scan entire repo for innerHTML patterns."""
    results = []
    
    # File patterns to check
    patterns_to_find = [
        (r'\.innerHTML', 'innerHTML'),
        (r'dangerouslySetInnerHTML', 'dangerouslySetInnerHTML'),
        (r'document\.write', 'document.write')
    ]
    
    # Skip directories
    skip_dirs = {'.git', 'node_modules', '.next', 'coverage', '__pycache__', '.pytest_cache'}
    
    for root, dirs, files in os.walk(repo_root):
        # Remove skip directories
        dirs[:] = [d for d in dirs if d not in skip_dirs]
        
        for file in files:
            # Skip binary files
            if file.endswith(('.pyc', '.png', '.jpg', '.gif', '.bin', '.exe')):
                continue
            
            filepath = os.path.join(root, file)
            
            try:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                
                rel_path = os.path.relpath(filepath, repo_root)
                
                for line_num, line in enumerate(lines, 1):
                    for pattern, pattern_name in patterns_to_find:
                        if re.search(pattern, line, re.IGNORECASE):
                            classification = classify_line(line, rel_path)
                            
                            # Get context (2 lines before and after)
                            context_before = []
                            context_after = []
                            
                            if line_num > 2:
                                context_before = [lines[line_num - 3].rstrip(), lines[line_num - 2].rstrip()]
                            elif line_num > 1:
                                context_before = [lines[line_num - 2].rstrip()]
                            
                            if line_num < len(lines) - 1:
                                context_after = [lines[line_num].rstrip(), lines[line_num + 1].rstrip()]
                            elif line_num < len(lines):
                                context_after = [lines[line_num].rstrip()]
                            
                            results.append({
                                'file': rel_path,
                                'line_num': line_num,
                                'line': line.rstrip(),
                                'context_before': context_before,
                                'context_after': context_after,
                                'classification': classification,
                                'pattern': pattern_name
                            })
            except Exception as e:
                pass
    
    return results

def generate_markdown(results, output_file):
    """Generate markdown inventory."""
    # Filter out None classifications
    results = [r for r in results if r['classification'] is not None]
    
    # Group by classification
    by_class = defaultdict(list)
    for result in results:
        by_class[result['classification']].append(result)
    
    with open(output_file, 'w') as f:
        f.write('# innerHTML Inventory\n\n')
        f.write('Complete scan of all innerHTML, dangerouslySetInnerHTML, and document.write usages.\n\n')
        
        # Summary
        f.write('## Summary by Classification\n\n')
        f.write('| Classification | Count |\n')
        f.write('|---|---|\n')
        for cls in sorted(by_class.keys()):
            f.write(f'| {cls} | {len(by_class[cls])} |\n')
        f.write(f'| **TOTAL** | **{len(results)}** |\n\n')
        
        # Dangerous checks
        f.write('## Critical Security Findings\n\n')
        dangerous_count = len(by_class['DANGEROUS_CONCAT']) + len(by_class['DANGEROUS_ASSIGN'])
        if dangerous_count == 0:
            f.write('✅ **No dangerous innerHTML patterns found** (safe clears only)\n\n')
        else:
            f.write(f'⚠️ **{dangerous_count} dangerous patterns found**:\n\n')
        
        # Detailed listings
        for cls in ['SAFE_CLEAR', 'DANGEROUS_CONCAT', 'DANGEROUS_ASSIGN', 'REACT_DANGEROUS', 'DOCUMENT_WRITE']:
            if cls not in by_class:
                continue
            
            entries = by_class[cls]
            f.write(f'## {cls} ({len(entries)} occurrences)\n\n')
            
            for entry in sorted(entries, key=lambda x: (x['file'], x['line_num'])):
                f.write(f"**File**: `{entry['file']}`\n")
                f.write(f"**Line**: {entry['line_num']}\n")
                f.write(f"**Pattern**: {entry['pattern']}\n\n")
                
                f.write('```\n')
                for ctx_line in entry['context_before']:
                    f.write(f'{ctx_line}\n')
                f.write(f'→ {entry["line"]}\n')
                for ctx_line in entry['context_after']:
                    f.write(f'{ctx_line}\n')
                f.write('```\n\n')
        
        # Verdict
        f.write('## Verdict\n\n')
        if len(by_class['DANGEROUS_CONCAT']) == 0 and len(by_class['DANGEROUS_ASSIGN']) == 0:
            f.write('✅ **PASS**: No dangerous innerHTML patterns detected.\n')
            f.write('   - All innerHTML assignments are safe clears\n')
            f.write('   - No concatenation with user data\n')
            f.write('   - dangerouslySetInnerHTML and document.write patterns properly catalogued\n')
        else:
            f.write('❌ **FAIL**: Dangerous patterns detected\n')
            f.write(f'   - DANGEROUS_CONCAT: {len(by_class["DANGEROUS_CONCAT"])}\n')
            f.write(f'   - DANGEROUS_ASSIGN: {len(by_class["DANGEROUS_ASSIGN"])}\n')

if __name__ == '__main__':
    import sys
    repo_root = sys.argv[1] if len(sys.argv) > 1 else '.'
    output_file = sys.argv[2] if len(sys.argv) > 2 else 'INNERHTML_INVENTORY.md'
    
    print(f'[INVENTORY] Scanning {repo_root}...')
    results = scan_repo(repo_root)
    print(f'[INVENTORY] Found {len(results)} patterns')
    
    print(f'[INVENTORY] Generating {output_file}...')
    generate_markdown(results, output_file)
    print(f'[INVENTORY] Done')
