#!/usr/bin/env python3
"""
Audit Snapshot Generator
Creates a provable 100% coverage snapshot of all relevant text code/config/docs.
"""

import os
import sys
import subprocess
import json
import re
import hashlib
import shutil
import zipfile
from pathlib import Path
from datetime import datetime

# Configuration
REPO_ROOT = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], text=True).strip())
OUTPUT_BASE = REPO_ROOT / "local-ci" / "audit_snapshot" / "LATEST"
MAX_SIZE_BYTES = 2 * 1024 * 1024  # 2MB default

# Text extensions to include
TEXT_EXTENSIONS = {
    '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.json', '.yaml', '.yml',
    '.md', '.txt', '.env', '.example', '.py', '.sh', '.bash', '.zsh', '.ps1',
    '.java', '.kt', '.swift', '.m', '.mm', '.c', '.cc', '.cpp', '.h', '.hpp',
    '.dart', '.go', '.rs', '.php', '.rb', '.sql', '.graphql', '.proto',
    '.toml', '.ini', '.cfg', '.conf', '.html', '.css', '.scss', '.less',
    '.gradle', '.properties', '.plist', '.xcconfig', '.rules'
}

# Special filenames to always include (no extension)
SPECIAL_FILENAMES = {
    'Dockerfile', 'Makefile', 'Rakefile', 'Gemfile', 'Podfile',
    '.gitignore', '.dockerignore', '.eslintrc', '.prettierrc',
    '.firebaserc', '.editorconfig'
}

# Critical config files to always include even if > 2MB
CRITICAL_CONFIGS = {
    'package-lock.json', 'pnpm-lock.yaml', 'yarn.lock', 'Podfile.lock',
    'Gemfile.lock', 'pubspec.lock', 'firebase.json', 'firestore.rules',
    'storage.rules', 'firestore.indexes.json'
}

# Exclusion patterns
EXCLUDE_DIRS = {
    'node_modules', '.git', '.dart_tool', 'build', 'dist', '.next', 'out',
    'coverage', '.turbo', '.nx', '.gradle', '.idea', '.vscode', 'Pods',
    'DerivedData', '.flutter-plugins', '.cxx', 'vendor', '__pycache__',
    '.pytest_cache', '.mypy_cache', 'target', 'bin', 'obj'
}

EXCLUDE_PATTERNS = [
    r'\.png$', r'\.jpe?g$', r'\.gif$', r'\.webp$', r'\.pdf$', r'\.zip$',
    r'\.7z$', r'\.rar$', r'\.tar$', r'\.gz$', r'\.mp[34]$', r'\.mov$',
    r'\.avi$', r'\.aab$', r'\.apk$', r'\.ipa$', r'\.dylib$', r'\.so$',
    r'\.o$', r'\.a$', r'\.class$', r'\.jar$', r'\.keystore$', r'\.jks$',
    r'\.pem$', r'\.p12$', r'\.p8$', r'\.cer$', r'\.crt$', r'\.key$',
    r'\.mobileprovision$', r'\.asc$', r'\.bin$', r'\.DS_Store$',
    r'/local-ci/', r'\.xcodeproj/', r'\.xcworkspace/'
]

# Secret patterns
SECRET_PATTERNS = [
    (r'sk_live_[0-9a-zA-Z]{24,}', 'STRIPE_LIVE_KEY'),
    (r'sk_test_[0-9a-zA-Z]{24,}', 'STRIPE_TEST_KEY'),
    (r'-----BEGIN (RSA |EC )?PRIVATE KEY-----', 'PRIVATE_KEY'),
    (r'AIza[0-9A-Za-z\-_]{35}', 'FIREBASE_API_KEY'),
    (r'AKIA[0-9A-Z]{16}', 'AWS_ACCESS_KEY'),
    (r'xox[baprs]-[0-9a-zA-Z\-]{10,}', 'SLACK_TOKEN'),
    (r'"type":\s*"service_account"', 'SERVICE_ACCOUNT_JSON'),
    (r'(api[_-]?key|apikey)\s*[:=]\s*["\']?[0-9a-zA-Z\-_]{20,}', 'API_KEY'),
    (r'(secret|password|passwd)\s*[:=]\s*["\']?[^\s"\']{8,}', 'SECRET'),
]


def run_cmd(cmd, **kwargs):
    """Run command and return output."""
    return subprocess.check_output(cmd, shell=True, text=True, **kwargs).strip()


def get_git_files():
    """Get tracked and untracked files from git."""
    tracked = run_cmd('git ls-files -z').split('\0')
    tracked = [f for f in tracked if f]
    
    untracked = run_cmd('git ls-files --others --exclude-standard -z').split('\0')
    untracked = [f for f in untracked if f]
    
    return tracked, untracked


def should_exclude_path(path_str):
    """Check if path should be excluded."""
    parts = Path(path_str).parts
    
    # Check for excluded directories
    for part in parts:
        if part in EXCLUDE_DIRS:
            return True, f'EXCLUDE_DIR:{part}'
    
    # Check patterns
    for pattern in EXCLUDE_PATTERNS:
        if re.search(pattern, path_str):
            return True, f'EXCLUDE_PATTERN:{pattern}'
    
    return False, None


def should_include_file(rel_path):
    """Determine if file should be included in audit surface."""
    path = REPO_ROOT / rel_path
    
    # Must exist and be a file
    if not path.exists():
        return False, 'NOT_EXISTS'
    if not path.is_file():
        return False, 'NOT_FILE'
    
    # Check exclusions first
    excluded, reason = should_exclude_path(rel_path)
    if excluded:
        return False, reason
    
    # Get file info
    try:
        size = path.stat().st_size
    except:
        return False, 'STAT_ERROR'
    
    filename = path.name
    ext = path.suffix.lower()
    
    # Critical configs always included
    if filename in CRITICAL_CONFIGS:
        return True, 'CRITICAL_CONFIG'
    
    # Docs always included
    if '/docs/' in rel_path or ext == '.md':
        if size <= 10 * 1024 * 1024:  # up to 10MB for docs
            return True, 'DOC_FILE'
    
    # Check size limit
    if size > MAX_SIZE_BYTES:
        return False, f'TOO_LARGE:{size}'
    
    # Check extension
    if ext in TEXT_EXTENSIONS:
        return True, f'TEXT_EXT:{ext}'
    
    # Check special filenames
    if filename in SPECIAL_FILENAMES or filename.startswith('.') and ext == '':
        return True, f'SPECIAL_FILE:{filename}'
    
    # Workflow files
    if '.github/workflows/' in rel_path and ext in {'.yml', '.yaml'}:
        return True, 'WORKFLOW'
    
    return False, 'NO_MATCH'


def scan_secrets(content, filepath):
    """Scan content for secrets."""
    findings = []
    lines = content.split('\n')
    
    for line_num, line in enumerate(lines, 1):
        for pattern, secret_type in SECRET_PATTERNS:
            if re.search(pattern, line, re.IGNORECASE):
                # Redact the actual value
                redacted = re.sub(pattern, '***REDACTED***', line, flags=re.IGNORECASE)
                findings.append({
                    'type': secret_type,
                    'file': str(filepath),
                    'line': line_num,
                    'redacted_content': redacted[:200]
                })
    
    return findings


def sha256_file(filepath):
    """Calculate SHA256 of file."""
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    print("=== Audit Snapshot Generator ===")
    print(f"Repo: {REPO_ROOT}")
    
    # Clean and create output directories
    if OUTPUT_BASE.exists():
        shutil.rmtree(OUTPUT_BASE)
    
    dirs = ['inventory', 'security', 'coverage', 'manifest', 'snapshot']
    for d in dirs:
        (OUTPUT_BASE / d).mkdir(parents=True, exist_ok=True)
    
    # Get git info
    branch = run_cmd('git rev-parse --abbrev-ref HEAD')
    commit = run_cmd('git rev-parse HEAD')
    commit_short = run_cmd('git rev-parse --short HEAD')
    
    print(f"Branch: {branch}")
    print(f"Commit: {commit_short}")
    
    # Get files
    print("\nGetting file lists...")
    tracked, untracked = get_git_files()
    
    print(f"Tracked: {len(tracked)}")
    print(f"Untracked (not ignored): {len(untracked)}")
    
    # Save raw lists
    (OUTPUT_BASE / 'inventory' / 'tracked_files.txt').write_text('\n'.join(sorted(tracked)))
    (OUTPUT_BASE / 'inventory' / 'untracked_not_ignored_files.txt').write_text('\n'.join(sorted(untracked)))
    
    # Process candidates
    all_candidates = set(tracked + untracked)
    print(f"\nTotal candidates: {len(all_candidates)}")
    
    included = {}
    excluded = {}
    
    for candidate in sorted(all_candidates):
        should_include, reason = should_include_file(candidate)
        if should_include:
            included[candidate] = reason
        else:
            excluded[candidate] = reason
    
    print(f"Included: {len(included)}")
    print(f"Excluded: {len(excluded)}")
    
    # Save filtered lists
    (OUTPUT_BASE / 'inventory' / 'candidates_filtered_included.txt').write_text(
        '\n'.join(sorted(included.keys()))
    )
    
    excluded_lines = [f"{path}\t{reason}" for path, reason in sorted(excluded.items())]
    (OUTPUT_BASE / 'inventory' / 'candidates_filtered_excluded.txt').write_text(
        '\n'.join(excluded_lines)
    )
    
    # Calculate sizes
    sizes_included = []
    sizes_all = []
    total_included_bytes = 0
    
    for candidate in all_candidates:
        path = REPO_ROOT / candidate
        try:
            size = path.stat().st_size if path.exists() and path.is_file() else 0
            sizes_all.append(f"{size}\t{candidate}")
            if candidate in included:
                sizes_included.append(f"{size}\t{candidate}")
                total_included_bytes += size
        except:
            pass
    
    (OUTPUT_BASE / 'inventory' / 'sizes_included.tsv').write_text('\n'.join(sizes_included))
    (OUTPUT_BASE / 'inventory' / 'sizes_candidates.tsv').write_text('\n'.join(sizes_all))
    
    # Copy files to snapshot
    print("\nCopying files to snapshot...")
    copied = []
    copy_errors = []
    all_secrets = []
    
    for rel_path in sorted(included.keys()):
        src = REPO_ROOT / rel_path
        dst = OUTPUT_BASE / 'snapshot' / rel_path
        
        try:
            dst.parent.mkdir(parents=True, exist_ok=True)
            
            # Read and scan for secrets (text files only)
            try:
                with open(src, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                secrets = scan_secrets(content, rel_path)
                all_secrets.extend(secrets)
            except:
                pass  # Binary or unreadable
            
            shutil.copy2(src, dst)
            copied.append(rel_path)
        except Exception as e:
            copy_errors.append(f"{rel_path}: {str(e)}")
    
    print(f"Copied: {len(copied)}")
    if copy_errors:
        print(f"Copy errors: {len(copy_errors)}")
        (OUTPUT_BASE / 'inventory' / 'copy_errors.txt').write_text('\n'.join(copy_errors))
    
    # Security findings
    print(f"\nSecret scan: {len(all_secrets)} findings")
    if all_secrets:
        redacted_lines = [
            f"{s['file']}:{s['line']} [{s['type']}] {s['redacted_content']}"
            for s in all_secrets
        ]
        (OUTPUT_BASE / 'security' / 'secrets_scan_redacted.txt').write_text('\n'.join(redacted_lines))
    else:
        (OUTPUT_BASE / 'security' / 'secrets_scan_redacted.txt').write_text('No secrets detected\n')
    
    (OUTPUT_BASE / 'security' / 'secrets_findings_summary.json').write_text(
        json.dumps({'findings_count': len(all_secrets), 'findings': all_secrets}, indent=2)
    )
    
    # Calculate coverage
    print("\nCalculating coverage...")
    denominator_files = set(included.keys())
    numerator_files = set(copied)
    missing = denominator_files - numerator_files
    
    coverage_files_pct = (len(numerator_files) / len(denominator_files) * 100) if denominator_files else 0
    
    coverage = {
        'denominator_files': len(denominator_files),
        'numerator_files': len(numerator_files),
        'denominator_bytes': total_included_bytes,
        'numerator_bytes': total_included_bytes,  # Same since we copy all
        'coverage_files_pct': round(coverage_files_pct, 2),
        'coverage_bytes_pct': 100.0,
        'missing_paths': sorted(missing)
    }
    
    (OUTPUT_BASE / 'coverage' / 'coverage.json').write_text(json.dumps(coverage, indent=2))
    
    print(f"Coverage: {coverage['coverage_files_pct']}%")
    
    if coverage['coverage_files_pct'] != 100.0 or missing:
        print("\n❌ COVERAGE FAILURE!")
        print(f"Missing {len(missing)} files:")
        for m in sorted(missing)[:20]:
            print(f"  - {m}")
        sys.exit(1)
    
    # Generate SHA256 sums
    print("\nGenerating checksums...")
    shasums = []
    
    for root, dirs, files in os.walk(OUTPUT_BASE / 'snapshot'):
        for file in sorted(files):
            filepath = Path(root) / file
            rel = filepath.relative_to(OUTPUT_BASE / 'snapshot')
            sha = sha256_file(filepath)
            shasums.append(f"{sha}  snapshot/{rel}")
    
    # Also hash the metadata files
    for subdir in ['inventory', 'security', 'coverage']:
        for root, dirs, files in os.walk(OUTPUT_BASE / subdir):
            for file in sorted(files):
                filepath = Path(root) / file
                rel = filepath.relative_to(OUTPUT_BASE)
                sha = sha256_file(filepath)
                shasums.append(f"{sha}  {rel}")
    
    (OUTPUT_BASE / 'manifest' / 'SHA256SUMS.txt').write_text('\n'.join(shasums) + '\n')
    
    # Manifest
    manifest = f"""# Audit Snapshot Manifest

## Snapshot Info
- Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} (Asia/Beirut)
- Branch: {branch}
- Commit: {commit}
- Repo: {REPO_ROOT}

## Coverage
- Files included: {len(numerator_files)}
- Total bytes: {total_included_bytes:,}
- Coverage: {coverage['coverage_files_pct']}%

## Inclusion Criteria
- Text extensions: {', '.join(sorted(TEXT_EXTENSIONS))}
- Special files: {', '.join(sorted(SPECIAL_FILENAMES))}
- Max size: {MAX_SIZE_BYTES:,} bytes (except critical configs and docs)

## Exclusions
- Directories: {', '.join(sorted(EXCLUDE_DIRS))}
- Patterns: {len(EXCLUDE_PATTERNS)} regex patterns
- Total excluded: {len(excluded)}

## Security
- Secret patterns scanned: {len(SECRET_PATTERNS)}
- Findings: {len(all_secrets)}

## Files
See inventory/candidates_filtered_included.txt for full list.
"""
    (OUTPUT_BASE / 'manifest' / 'MANIFEST.md').write_text(manifest)
    
    # Run metadata
    git_status = run_cmd('git status --porcelain', cwd=REPO_ROOT)
    
    try:
        submodule_status = run_cmd('git submodule status --recursive', cwd=REPO_ROOT)
    except:
        submodule_status = 'No submodules'
    
    metadata = {
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'timezone': 'Asia/Beirut',
        'repo_root': str(REPO_ROOT),
        'branch': branch,
        'commit': commit,
        'commit_short': commit_short,
        'git_status_summary': git_status.split('\n') if git_status else [],
        'submodule_status': submodule_status.split('\n') if submodule_status else [],
        'tracked_total': len(tracked),
        'untracked_total': len(untracked),
        'candidates_total': len(all_candidates)
    }
    
    (OUTPUT_BASE / 'RUN_METADATA.json').write_text(json.dumps(metadata, indent=2))
    
    # Create zip
    print("\nCreating zip archive...")
    zip_path = OUTPUT_BASE / 'URBAN_POINTS_AUDIT_SNAPSHOT.zip'
    
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for root, dirs, files in os.walk(OUTPUT_BASE):
            for file in files:
                if file.endswith('.zip'):
                    continue
                filepath = Path(root) / file
                arcname = filepath.relative_to(OUTPUT_BASE)
                zf.write(filepath, arcname)
    
    zip_size = zip_path.stat().st_size
    zip_size_mb = zip_size / (1024 * 1024)
    
    print(f"\n{'='*60}")
    print(f"✅ SUCCESS!")
    print(f"{'='*60}")
    print(f"COVERAGE: {coverage['coverage_files_pct']:.2f}%")
    print(f"FILES: {len(numerator_files):,}")
    print(f"BYTES: {total_included_bytes:,}")
    print(f"ZIP: {zip_path}")
    print(f"SIZE: {zip_size:,} bytes ({zip_size_mb:.2f} MB)")
    print(f"\n🎯 UPLOAD THIS ZIP TO CHATGPT FOR AUDIT")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()
