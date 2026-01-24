#!/usr/bin/env python3
import os
import sys
import json
import hashlib
import time
import re

HDR = re.compile(rb"^===== FILE_BEGIN (.+?) SIZE=(\d+) SHA256=([0-9a-f]{64}) =====$")
FTR = re.compile(rb"^===== FILE_END (.+?) =====$")


def sha256_bytes(data: bytes) -> str:
    h = hashlib.sha256()
    h.update(data)
    return h.hexdigest()


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: rebuild_manifest_from_concat.py <ALL_FILES_CONCAT.bin>", file=sys.stderr)
        sys.exit(2)

    concat_path = sys.argv[1]
    run_dir = os.path.dirname(concat_path)
    ts = time.strftime("%Y%m%d_%H%M%S", time.localtime())

    manifest_path = os.path.join(run_dir, "MANIFEST.json")
    offsets_path = os.path.join(run_dir, "OFFSETS.json")
    summary_path = os.path.join(run_dir, "SUMMARY.md")

    total_bytes_raw = 0
    concat_sha = hashlib.sha256()
    offsets = []
    files = []
    unreadable = []

    total_written = 0
    with open(concat_path, "rb") as f:
        def read_line() -> bytes:
            nonlocal total_written
            line = f.readline()
            concat_sha.update(line)
            total_written += len(line)
            return line

        while True:
            line_start = total_written
            line = read_line()
            if not line:
                break
            s = line.rstrip(b"\n")
            m = HDR.match(s)
            if not m:
                continue

            path = m.group(1).decode("utf-8", errors="replace")
            size = int(m.group(2).decode("ascii"))
            sha = m.group(3).decode("ascii")

            try:
                data_sha = hashlib.sha256()
                remaining = size
                while remaining > 0:
                    chunk = f.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise RuntimeError(f"Unexpected EOF while reading data for {path}")
                    data_sha.update(chunk)
                    concat_sha.update(chunk)
                    total_written += len(chunk)
                    remaining -= len(chunk)

                total_bytes_raw += size

                footer = None
                while True:
                    footer_candidate = read_line()
                    if not footer_candidate:
                        raise RuntimeError(f"Missing footer for {path}")
                    stripped = footer_candidate.rstrip(b"\n")
                    if stripped == b"":
                        continue
                    footer = stripped
                    break

                ft = FTR.match(footer)
                if not ft:
                    raise RuntimeError(f"Bad footer for {path}: {footer[:120]!r}")
                ft_path = ft.group(1).decode("utf-8", errors="replace")
                if ft_path != path:
                    raise RuntimeError(f"Footer path mismatch. hdr={path} ftr={ft_path}")

                disk_sha = data_sha.hexdigest()
                if disk_sha != sha:
                    raise RuntimeError(f"SHA mismatch for {path}: hdr={sha} computed={disk_sha}")

                offsets.append({
                    "path": path,
                    "size": size,
                    "sha256": sha,
                    "concat_start": line_start,
                    "concat_end": total_written,
                    "text_lines": None,
                    "encoding": None,
                })
                files.append({
                    "path": path,
                    "size": size,
                    "sha256": sha,
                    "text_lines": None,
                    "encoding": None,
                })

            except Exception as exc:  # noqa: BLE001
                unreadable.append({
                    "path": path,
                    "error": str(exc),
                    "concat_start": line_start,
                })
                break

    global_concat_sha256 = concat_sha.hexdigest()

    manifest = {
        "repo_root": os.path.abspath(os.getcwd()),
        "generated_at": ts,
        "excluded_dirs": [".git"],
        "file_count": len(files),
        "total_bytes": total_bytes_raw,
        "global_concat_sha256": global_concat_sha256,
        "unreadable_count": len(unreadable),
        "unreadable": unreadable,
        "files": files,
    }

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    with open(offsets_path, "w", encoding="utf-8") as f:
        json.dump(offsets, f, indent=2, ensure_ascii=False)

    top = sorted(files, key=lambda x: x["size"], reverse=True)[:20]
    with open(summary_path, "w", encoding="utf-8") as f:
        f.write("# Letter-by-letter Read Proof (Rebuilt Index)\n\n")
        f.write(f"- Generated at: {ts}\n")
        f.write(f"- Source: {concat_path}\n")
        f.write(f"- Files read: **{len(files)}**\n")
        f.write(f"- Total bytes read: **{total_bytes_raw}**\n")
        f.write(f"- Global concat SHA256: **{global_concat_sha256}**\n")
        f.write(f"- Unreadable files: **{len(unreadable)}**\n\n")
        f.write("## Evidence Artifacts\n")
        f.write("- MANIFEST.json\n- OFFSETS.json\n- ALL_FILES_CONCAT.bin\n\n")
        f.write("## Largest 20 files\n")
        for x in top:
            f.write(f"- {x['path']} — {x['size']} bytes — {x['sha256']}\n")

    status = "PASS" if not unreadable else "FAIL (unreadable entries present)"
    print(f"{status}: rebuilt MANIFEST/OFFSETS/SUMMARY from existing concat.")
    print("Run dir:", run_dir)
    print("Files:", len(files))
    print("Total bytes:", total_bytes_raw)
    print("Global concat SHA256:", global_concat_sha256)
    if unreadable:
        print("Unreadable entries:", len(unreadable))
        for entry in unreadable[:5]:
            print("-", entry)

    if unreadable:
        sys.exit(1)


if __name__ == "__main__":
    main()
