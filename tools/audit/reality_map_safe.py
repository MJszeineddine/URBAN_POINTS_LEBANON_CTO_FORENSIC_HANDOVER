#!/usr/bin/env python3
import json
import time
import hashlib
from pathlib import Path
from collections import defaultdict, Counter

EXCLUDE_PREFIXES = (".git/", "local-ci/")


def now() -> str:
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8", errors="replace"))


def sha256_bytes(data: bytes) -> str:
    h = hashlib.sha256()
    h.update(data)
    return h.hexdigest()


def norm(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


JUNK_DIR_MARKERS = [
    "/node_modules/",
    "/build/",
    "/dist/",
    "/.dart_tool/",
    "/.next/",
    "/.gradle/",
    "/Pods/",
    "/DerivedData/",
    "/.cache/",
    "/.turbo/",
    "/.idea/",
    "/.vscode/",
    "/coverage/",
    "/tmp/",
    "/.pytest_cache/",
]
JUNK_BASENAMES = {".DS_Store", "Thumbs.db", "npm-debug.log", "yarn-error.log", "pnpm-debug.log"}
JUNK_EXT = {".log", ".tmp", ".swp", ".swo", ".bak"}

STACK_PATTERNS = {
    "Flutter": ["/pubspec.yaml", "/lib/main.dart", "/android/", "/ios/"],
    "Next.js": ["/next.config", "/app/", "/pages/", "/next-env.d.ts"],
    "Firebase": ["/firebase.json", "/firestore.rules", "/storage.rules", "/functions/"],
    "REST/Express": ["/openapi", "/swagger", "express", "router"],
    "CI": ["/.github/workflows", "/Dockerfile", "/docker-compose", "/Makefile"],
}


def excluded(path: str) -> bool:
    p = norm(path)
    return p.startswith(EXCLUDE_PREFIXES)


def main() -> None:
    repo = Path.cwd()
    out = repo / "local-ci/verification/reality_map_safe/LATEST"
    proof = Path((out / "inputs/proof_path.txt").read_text(encoding="utf-8").strip())

    manifest = read_json(proof / "MANIFEST.json")
    offsets = read_json(proof / "OFFSETS.json")  # noqa: F841
    files = manifest.get("files", [])

    files = [f for f in files if not excluded(f.get("path", ""))]

    drift = []
    for f in files:
        p = norm(f["path"])
        disk = repo / p
        try:
            disk_bytes = disk.read_bytes()
            disk_sha = sha256_bytes(disk_bytes)
            if disk_sha != f["sha256"]:
                drift.append({"path": p, "expected": f["sha256"], "disk": disk_sha})
        except Exception as exc:  # noqa: BLE001
            drift.append({"path": p, "expected": f["sha256"], "error": str(exc)})

    if drift:
        (out / "gates/FAIL_repo_drift.json").write_text(
            json.dumps(drift, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
        (out / "reports/FINAL_GATE.txt").write_text("FAIL\n", encoding="utf-8")
        print("FAIL: repo drift in product-scope files.")
        return

    by_hash = defaultdict(list)
    by_ext = Counter()
    junk = []
    stack_hits = defaultdict(set)
    total_bytes = 0

    for f in files:
        p = norm(f["path"])
        size = int(f.get("size", 0))
        sha = f.get("sha256", "")
        total_bytes += size
        by_hash[sha].append(p)
        by_ext[Path(p).suffix.lower()] += 1

        pn = "/" + p.strip("/")
        bn = Path(p).name
        ext = Path(p).suffix.lower()
        if bn in JUNK_BASENAMES or ext in JUNK_EXT or any(marker in pn for marker in JUNK_DIR_MARKERS):
            junk.append({"path": p, "sha256": sha, "size": size})

        for stack, patterns in STACK_PATTERNS.items():
            for pattern in patterns:
                if pattern.startswith("/") and pattern in pn:
                    stack_hits[stack].add(p)
                    break
                if not pattern.startswith("/") and pattern in p:
                    stack_hits[stack].add(p)
                    break

    dup_groups = []
    for sha, paths in by_hash.items():
        if sha and len(paths) > 1:
            dup_groups.append({"sha256": sha, "count": len(paths), "paths": sorted(paths)})
    dup_groups.sort(key=lambda item: item["count"], reverse=True)

    (out / "analysis/stack_hits.json").write_text(
        json.dumps({key: sorted(val) for key, val in stack_hits.items()}, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    (out / "analysis/junk_candidates_top2000.json").write_text(
        json.dumps(junk[:2000], indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    (out / "analysis/duplicates_top500.json").write_text(
        json.dumps(dup_groups[:500], indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    (out / "analysis/extensions_count.json").write_text(
        json.dumps(by_ext, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    md = []
    md.append("# Reality Map (SAFE, No-Bypass, Product Scope)\n\n")
    md.append(f"- Generated: `{now()}`\n")
    md.append(f"- Proof source: `{proof}`\n")
    md.append("- Exclusions: `.git/`, `local-ci/`\n")
    md.append(f"- Files (product scope): **{len(files)}**\n")
    md.append(f"- Total bytes (product scope): **{total_bytes}**\n\n")

    md.append("## Stack hits (anchored by paths)\n\n")
    for stack in sorted(stack_hits.keys()):
        md.append(f"### {stack} ({len(stack_hits[stack])})\n")
        for path_str in sorted(list(stack_hits[stack]))[:60]:
            md.append(f"- `{path_str}`\n")
        if len(stack_hits[stack]) > 60:
            md.append("- ... see `analysis/stack_hits.json`\n")
        md.append("\n")

    md.append("## Junk candidates (non-destructive)\n")
    md.append("- See `analysis/junk_candidates_top2000.json`\n\n")

    md.append("## Duplicate content groups\n")
    md.append("- See `analysis/duplicates_top500.json`\n\n")

    md.append("## No-bypass guarantee (product scope)\n")
    md.append("- Drift gate PASSED for every non-excluded file.\n")

    (out / "reports/REALITY_MAP.md").write_text("".join(md), encoding="utf-8")
    (out / "reports/FINAL_GATE.txt").write_text("PASS\n", encoding="utf-8")
    print("PASS")
    print(str(out))
    print(str(out / "reports/REALITY_MAP.md"))
    print(str(out / "reports/FINAL_GATE.txt"))


if __name__ == "__main__":
    main()
