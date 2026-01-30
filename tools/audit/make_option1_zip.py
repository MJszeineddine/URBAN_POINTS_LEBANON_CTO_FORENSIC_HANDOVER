#!/usr/bin/env python3
"""
Repo Export ZIP Creator (Option 1)
Packages entire repository with smart exclusions.
"""

import os
import sys
import zipfile
from pathlib import Path
from datetime import datetime

# Exclusion patterns
EXCLUDE_DIRS = {
    '.git',
    'node_modules',
    'dist',
    'build',
    '.next',
    '.dart_tool',
    'coverage',
    'Pods',
    'DerivedData',
    '__pycache__',
    '.pytest_cache',
    '.turbo',
    '.parcel-cache',
    'evidence',
}

EXCLUDE_PATTERNS_LOCAL_CI = {
    'evidence',
    'STRICT_',
    'PROJECT_',
}

EXCLUDE_EXTENSIONS = {
    '.zip', '.7z', '.rar',
    '.png', '.jpg', '.jpeg', '.webp', '.gif',
    '.mp4', '.mp3', '.pdf',
    '.exe', '.dmg', '.pkg', '.apk', '.ipa',
    '.a', '.so', '.dll',
}

EXCLUDE_FILES = {
    '.DS_Store',
    'Thumbs.db',
}

def find_repo_root():
    """Find repo root by looking for markers up the directory tree."""
    markers = {'.git', 'package.json', 'pubspec.yaml', 'firebase.json'}
    current = Path(os.getcwd()).resolve()
    
    while current != current.parent:
        for marker in markers:
            if (current / marker).exists():
                return current
        current = current.parent
    
    return Path(os.getcwd()).resolve()

def should_exclude(rel_path_str, is_dir):
    """Check if a path should be excluded."""
    parts = Path(rel_path_str).parts
    
    # Check directory names
    for part in parts:
        if part in EXCLUDE_DIRS:
            return True, f"EXCLUDE_DIR:{part}"
        if part.startswith('.') and part not in {'.gitignore', '.env.example'}:
            if part != '.github':  # Keep .github but exclude other hidden dirs
                return True, f"HIDDEN_DIR:{part}"
    
    # Check local-ci patterns
    if 'local-ci' in parts:
        for i, part in enumerate(parts):
            if part == 'local-ci':
                remaining = parts[i+1:]
                for pattern in EXCLUDE_PATTERNS_LOCAL_CI:
                    for subpart in remaining:
                        if pattern in subpart:
                            return True, f"LOCAL_CI_PATTERN:{pattern}"
    
    # For files: check extension and name
    if not is_dir:
        path_obj = Path(rel_path_str)
        
        # Check filename
        if path_obj.name in EXCLUDE_FILES:
            return True, f"EXCLUDE_FILE:{path_obj.name}"
        
        # Check extension
        if path_obj.suffix.lower() in EXCLUDE_EXTENSIONS:
            return True, f"EXCLUDE_EXT:{path_obj.suffix}"
    
    return False, None

def create_repo_zip():
    """Create the repo export ZIP."""
    repo_root = find_repo_root()
    print(f"[INFO] Repo root: {repo_root}")
    
    # Create output directory
    export_dir = repo_root / 'local-ci' / 'exports'
    export_dir.mkdir(parents=True, exist_ok=True)
    
    zip_path = export_dir / 'URBAN_POINTS_REPO_OPTION1.zip'
    included_log = export_dir / 'URBAN_POINTS_REPO_OPTION1.included.txt'
    excluded_log = export_dir / 'URBAN_POINTS_REPO_OPTION1.excluded.txt'
    
    included_files = []
    excluded_files = []
    
    print(f"[INFO] Creating ZIP: {zip_path}")
    
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        # Walk all files
        all_items = sorted(repo_root.rglob('*'))
        
        for item_path in all_items:
            try:
                rel_path = item_path.relative_to(repo_root)
                rel_str = str(rel_path)
                
                # Skip the output directory itself
                if 'local-ci/exports' in rel_str:
                    excluded_files.append((rel_str, 'OUTPUT_DIR'))
                    continue
                
                is_dir = item_path.is_dir()
                should_exc, reason = should_exclude(rel_str, is_dir)
                
                if should_exc:
                    excluded_files.append((rel_str, reason))
                else:
                    if not is_dir:
                        # Add file to zip
                        zf.write(item_path, arcname=rel_str)
                        included_files.append(rel_str)
            except Exception as e:
                print(f"[WARN] Error processing {item_path}: {e}")
    
    # Write logs
    with open(included_log, 'w') as f:
        f.write(f"# Included Files in URBAN_POINTS_REPO_OPTION1.zip\n")
        f.write(f"# Generated: {datetime.now().isoformat()}\n")
        f.write(f"# Total files: {len(included_files)}\n\n")
        for fname in sorted(included_files):
            f.write(f"{fname}\n")
    
    with open(excluded_log, 'w') as f:
        f.write(f"# Excluded Paths in URBAN_POINTS_REPO_OPTION1.zip\n")
        f.write(f"# Generated: {datetime.now().isoformat()}\n")
        f.write(f"# Total excluded: {len(excluded_files)}\n\n")
        for path, reason in sorted(excluded_files):
            f.write(f"{path:80s} | {reason}\n")
    
    # Get ZIP stats
    zip_size = zip_path.stat().st_size
    
    # Get top 20 largest files in the ZIP
    largest_files = []
    with zipfile.ZipFile(zip_path, 'r') as zf:
        for info in zf.infolist():
            largest_files.append((info.filename, info.file_size))
    
    largest_files.sort(key=lambda x: x[1], reverse=True)
    top_20 = largest_files[:20]
    
    # Print report
    print("\n" + "="*80)
    print("ZIP EXPORT COMPLETE")
    print("="*80)
    print(f"ZIP Path:        {zip_path}")
    print(f"ZIP Size:        {zip_size:,} bytes ({zip_size / (1024*1024):.2f} MB)")
    print(f"Files Included:  {len(included_files)}")
    print(f"Files Excluded:  {len(excluded_files)}")
    print(f"\nIncluded Log:    {included_log}")
    print(f"Excluded Log:    {excluded_log}")
    print("\n" + "-"*80)
    print("TOP 20 LARGEST FILES IN ZIP:")
    print("-"*80)
    print(f"{'Rank':<5} {'Size (MB)':<12} {'Filename':<63}")
    print("-"*80)
    for i, (fname, size) in enumerate(top_20, 1):
        size_mb = size / (1024*1024)
        print(f"{i:<5} {size_mb:<12.2f} {fname:<63}")
    print("="*80)
    
    return zip_path, zip_size, len(included_files), top_20

if __name__ == '__main__':
    try:
        zip_path, size, count, top_20 = create_repo_zip()
        sys.exit(0)
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
