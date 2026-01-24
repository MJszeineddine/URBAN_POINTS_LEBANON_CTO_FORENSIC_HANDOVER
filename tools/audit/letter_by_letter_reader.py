#!/usr/bin/env python3
import os, sys, json, hashlib, time, pathlib

EXCLUDE_DIRS = {".git"}  # ONLY allowed exclusion

def sha256_bytes(data: bytes) -> str:
    h = hashlib.sha256()
    h.update(data)
    return h.hexdigest()

def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def is_probably_text(b: bytes) -> bool:
    if not b:
        return True
    # Heuristic: if it contains NUL, treat as binary
    if b"\x00" in b:
        return False
    # Try UTF-8 decode strictly
    try:
        b.decode("utf-8")
        return True
    except Exception:
        return False

def safe_relpath(root: str, p: str) -> str:
    rp = os.path.relpath(p, root)
    return rp.replace("\\", "/")

def walk_all_files(repo_root: str):
    for dirpath, dirnames, filenames in os.walk(repo_root):
        # Prune excluded dirs
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for fn in filenames:
            yield os.path.join(dirpath, fn)

def main():
    repo_root = os.getcwd()
    # basic sanity: must contain .git OR at least look like a repo root
    if not os.path.isdir(os.path.join(repo_root, ".git")):
        # still proceed, but warn
        pass

    ts = time.strftime("%Y%m%d_%H%M%S", time.localtime())
    out_dir = os.path.join(repo_root, "local-ci", "verification", "letter_by_letter", ts)
    os.makedirs(out_dir, exist_ok=True)

    manifest_path = os.path.join(out_dir, "MANIFEST.json")
    summary_path  = os.path.join(out_dir, "SUMMARY.md")
    concat_path   = os.path.join(out_dir, "ALL_FILES_CONCAT.bin")
    offsets_path  = os.path.join(out_dir, "OFFSETS.json")

    files = []
    unreadable = []

    # Collect file list deterministically
    all_paths = sorted(set(walk_all_files(repo_root)))
    # Exclude output folder itself if reruns happen inside local-ci/verification/letter_by_letter
    all_paths = [p for p in all_paths if os.path.abspath(out_dir) not in os.path.abspath(p)]

    total_bytes = 0
    concat_sha = hashlib.sha256()
    offsets = []
    current_offset = 0

    # Open concat file once, append every file with delimiter header
    with open(concat_path, "wb") as concat_f:
        for p in all_paths:
            ap = os.path.abspath(p)
            # Ensure we never read inside .git
            parts = pathlib.Path(ap).parts
            if ".git" in parts:
                continue

            rel = safe_relpath(repo_root, ap)
            try:
                data = open(ap, "rb").read()
            except Exception as e:
                unreadable.append({"path": rel, "error": str(e)})
                continue

            size = len(data)
            total_bytes += size

            file_hash = sha256_bytes(data)

            # Text metadata (optional)
            text_lines = None
            encoding = None
            if is_probably_text(data):
                try:
                    s = data.decode("utf-8")
                    encoding = "utf-8"
                    # Count lines robustly
                    text_lines = s.count("\n") + (0 if s.endswith("\n") or s == "" else 1)
                except Exception:
                    # still consider it "text-ish" but unknown encoding
                    encoding = None
                    text_lines = None

            # Write delimiter header + raw bytes into concat
            header = (f"\n\n===== FILE_BEGIN {rel} SIZE={size} SHA256={file_hash} =====\n").encode("utf-8")
            footer = (f"\n===== FILE_END {rel} =====\n").encode("utf-8")

            start = current_offset
            concat_f.write(header); current_offset += len(header)
            concat_f.write(data);   current_offset += len(data)
            concat_f.write(footer); current_offset += len(footer)

            # Update global sha based on exact bytes written (header+data+footer)
            concat_sha.update(header)
            concat_sha.update(data)
            concat_sha.update(footer)

            offsets.append({
                "path": rel,
                "size": size,
                "sha256": file_hash,
                "concat_start": start,
                "concat_end": current_offset,
                "text_lines": text_lines,
                "encoding": encoding,
            })

            files.append({
                "path": rel,
                "size": size,
                "sha256": file_hash,
                "text_lines": text_lines,
                "encoding": encoding,
            })

    global_concat_sha256 = concat_sha.hexdigest()

    manifest = {
        "repo_root": os.path.abspath(repo_root),
        "generated_at": ts,
        "excluded_dirs": sorted(list(EXCLUDE_DIRS)),
        "file_count": len(files),
        "total_bytes": total_bytes,
        "global_concat_sha256": global_concat_sha256,
        "unreadable_count": len(unreadable),
        "unreadable": unreadable,
        "files": files,
    }

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    with open(offsets_path, "w", encoding="utf-8") as f:
        json.dump(offsets, f, indent=2, ensure_ascii=False)

    # Summary
    top = sorted(files, key=lambda x: x["size"], reverse=True)[:20]
    with open(summary_path, "w", encoding="utf-8") as f:
        f.write("# Letter-by-letter Read Proof\n\n")
        f.write(f"- Generated at: `{ts}`\n")
        f.write(f"- Repo root: `{os.path.abspath(repo_root)}`\n")
        f.write(f"- Excluded dirs: `{', '.join(sorted(EXCLUDE_DIRS))}`\n")
        f.write(f"- Files read: **{len(files)}**\n")
        f.write(f"- Total bytes read: **{total_bytes}**\n")
        f.write(f"- Global concat SHA256: **{global_concat_sha256}**\n")
        f.write(f"- Unreadable files: **{len(unreadable)}**\n\n")
        if unreadable:
            f.write("## Unreadable (FAIL)\n")
            for u in unreadable:
                f.write(f"- `{u['path']}` — {u['error']}\n")
            f.write("\n")
        f.write("## Evidence Artifacts\n")
        f.write(f"- `MANIFEST.json` (per-file hashes)\n")
        f.write(f"- `OFFSETS.json` (per-file offsets in concat)\n")
        f.write(f"- `ALL_FILES_CONCAT.bin` (byte stream of everything)\n\n")
        f.write("## Largest 20 files\n")
        for x in top:
            f.write(f"- `{x['path']}` — {x['size']} bytes — {x['sha256']}\n")

    # Gate: fail if any unreadable
    if unreadable:
        print("FAIL: Some files could not be read.")
        print(f"Output: {out_dir}")
        print(f"Unreadable count: {len(unreadable)}")
        for u in unreadable[:50]:
            print(f"- {u['path']}: {u['error']}")
        sys.exit(2)

    print("PASS: Read ALL files (excluding .git) with byte-level proof.")
    print(f"Output: {out_dir}")
    print(f"Files read: {len(files)}")
    print(f"Total bytes: {total_bytes}")
    print(f"Global concat SHA256: {global_concat_sha256}")

if __name__ == "__main__":
    main()
