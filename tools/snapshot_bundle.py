#!/usr/bin/env python3
"""
Project Snapshot Bundle Creator
Produces auditable project snapshot for upload to ChatGPT
No source modifications, no installs, read-only artifacts
"""

import os
import sys
import json
import subprocess
import hashlib
import zipfile
from pathlib import Path
from datetime import datetime
from collections import defaultdict

# =============================================================================
# CONSTANTS
# =============================================================================

EXCLUDE_DIRS = {
    'node_modules', '.git', '.next', 'dist', 'build', 'coverage',
    '__pycache__', '.pytest_cache', '.venv', 'venv', 'env',
    'local-ci/evidence', '.gradle', '.idea', 'Pods', 'pubspec.lock'
}

EXCLUDE_FILES = {
    '.DS_Store', 'thumbs.db', '*.log'
}

# =============================================================================
# REPO ROOT DETECTION
# =============================================================================

def detect_repo_root():
    """Find repo root by checking for firebase.json or source/ dir."""
    cwd = Path.cwd()
    
    # Check if firebase.json or source/ exists in current dir
    if (cwd / 'firebase.json').exists() or (cwd / 'source').exists():
        return cwd
    
    # Walk up directories
    for parent in [cwd] + list(cwd.parents):
        if (parent / 'firebase.json').exists() or (parent / 'source').exists():
            return parent
    
    print("ERROR: Cannot detect repo root (no firebase.json or source/ found)")
    sys.exit(1)

REPO_ROOT = detect_repo_root()
TIMESTAMP = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
EVIDENCE_DIR = REPO_ROOT / 'local-ci' / 'evidence' / 'SNAPSHOT' / TIMESTAMP
EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)

# =============================================================================
# GIT INFORMATION
# =============================================================================

def run_git_cmd(cmd):
    """Run git command and return output."""
    try:
        result = subprocess.run(
            cmd,
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip()
    except Exception as e:
        return f"ERROR: {str(e)}"

git_commit = run_git_cmd(['git', 'rev-parse', 'HEAD'])
git_branch = run_git_cmd(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])
git_status = run_git_cmd(['git', 'status', '--porcelain'])

# Write git files
(EVIDENCE_DIR / 'git_commit.txt').write_text(git_commit)
(EVIDENCE_DIR / 'git_branch.txt').write_text(git_branch)
(EVIDENCE_DIR / 'git_status.txt').write_text(git_status)

# =============================================================================
# FILE INVENTORY (read-only, no exclusions for evidence dir itself)
# =============================================================================

def should_exclude(path_obj, relative_path):
    """Check if path should be excluded."""
    # Skip if in evidence dir itself
    if 'local-ci/evidence' in str(relative_path):
        return True
    
    # Skip excluded directories
    for part in path_obj.parts:
        if part in EXCLUDE_DIRS:
            return True
    
    return False

def collect_files():
    """Walk repo and collect all files (with sizes, no exclusions yet)."""
    files = []
    file_sizes = defaultdict(int)
    file_count = 0
    
    for root, dirs, filenames in os.walk(REPO_ROOT):
        # Remove excluded dirs in-place to prevent descent
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        
        for fname in filenames:
            fpath = Path(root) / fname
            rel_path = fpath.relative_to(REPO_ROOT)
            
            # Skip evidence dir
            if 'local-ci/evidence' in str(rel_path):
                continue
            
            # Skip if in excluded dirs (shouldn't happen after dirs[:] filter, but check)
            if should_exclude(fpath, rel_path):
                continue
            
            try:
                size = fpath.stat().st_size
                files.append({
                    'path': str(rel_path),
                    'size_bytes': size
                })
                file_count += 1
                file_sizes[str(rel_path)] = size
            except Exception:
                pass
    
    return files, file_count, sum(file_sizes.values())

files_list, file_count, total_size = collect_files()

# Write file inventory
inventory_text = '\n'.join(f"{f['path']} ({f['size_bytes']} bytes)" for f in files_list)
(EVIDENCE_DIR / 'file_inventory.txt').write_text(inventory_text)

# =============================================================================
# TREE (depth 4)
# =============================================================================

def build_tree(path, prefix='', max_depth=4, current_depth=0):
    """Build tree string."""
    if current_depth >= max_depth:
        return ''
    
    lines = []
    
    try:
        entries = sorted(path.iterdir())
    except PermissionError:
        return ''
    
    # Filter excluded dirs
    entries = [e for e in entries if e.name not in EXCLUDE_DIRS]
    
    for i, entry in enumerate(entries):
        is_last = i == len(entries) - 1
        current = '└── ' if is_last else '├── '
        lines.append(f"{prefix}{current}{entry.name}")
        
        if entry.is_dir():
            next_prefix = prefix + ('    ' if is_last else '│   ')
            subtree = build_tree(entry, next_prefix, max_depth, current_depth + 1)
            if subtree:
                lines.append(subtree)
    
    return '\n'.join(lines)

tree_str = f"{REPO_ROOT.name}/\n" + build_tree(REPO_ROOT)
(EVIDENCE_DIR / 'tree_top.txt').write_text(tree_str)

# =============================================================================
# SUMMARY.JSON
# =============================================================================

summary = {
    'timestamp': TIMESTAMP,
    'repo_root': str(REPO_ROOT),
    'git_commit': git_commit,
    'git_branch': git_branch,
    'file_count': file_count,
    'total_size_bytes': total_size,
    'total_size_mb': round(total_size / (1024 * 1024), 2),
    'evidence_dir': str(EVIDENCE_DIR),
    'excluded_dirs': sorted(EXCLUDE_DIRS)
}

(EVIDENCE_DIR / 'SUMMARY.json').write_text(json.dumps(summary, indent=2))

# =============================================================================
# CREATE ZIP SNAPSHOT
# =============================================================================

zip_path = EVIDENCE_DIR / 'PROJECT_SNAPSHOT.zip'

def should_zip_include(arcname):
    """Check if file should be included in zip."""
    # Skip evidence dir itself
    if 'local-ci/evidence' in arcname:
        return False
    
    # Skip excluded dirs
    parts = Path(arcname).parts
    for part in parts:
        if part in EXCLUDE_DIRS:
            return False
    
    return True

with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, filenames in os.walk(REPO_ROOT):
        # Remove excluded dirs
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        
        for fname in filenames:
            fpath = Path(root) / fname
            arcname = str(fpath.relative_to(REPO_ROOT))
            
            if should_zip_include(arcname):
                try:
                    zf.write(fpath, arcname=arcname)
                except Exception:
                    pass

# =============================================================================
# SHA256 CHECKSUM
# =============================================================================

def compute_sha256(filepath):
    """Compute SHA256 of file."""
    sha = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while True:
            data = f.read(65536)
            if not data:
                break
            sha.update(data)
    return sha.hexdigest()

zip_sha256 = compute_sha256(zip_path)
(EVIDENCE_DIR / 'PROJECT_SNAPSHOT.sha256.txt').write_text(zip_sha256)

# =============================================================================
# VALIDATION
# =============================================================================

required_files = [
    'SUMMARY.json',
    'git_commit.txt',
    'git_branch.txt',
    'git_status.txt',
    'file_inventory.txt',
    'tree_top.txt',
    'PROJECT_SNAPSHOT.zip',
    'PROJECT_SNAPSHOT.sha256.txt'
]

all_exist = all((EVIDENCE_DIR / fname).exists() for fname in required_files)
all_nonempty = all((EVIDENCE_DIR / fname).stat().st_size > 0 for fname in required_files)

if not all_exist or not all_nonempty:
    print("ERROR: Missing or empty required artifacts")
    sys.exit(1)

# =============================================================================
# FINAL OUTPUT
# =============================================================================

print("SNAPSHOT_DONE")
print(f"EVIDENCE_DIR={EVIDENCE_DIR}")
print(f"ZIP_PATH={zip_path}")
print(f"ZIP_SHA256={zip_sha256}")
print(f"FILE_COUNT={file_count}")

sys.exit(0)
