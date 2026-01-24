#!/usr/bin/env python3
import os, sys, json, time, hashlib, re
from pathlib import Path
from collections import defaultdict, Counter

EXCLUDE_DIRS = {".git"}  # ONLY allowed exclusion

# Heuristics for "junk" classification (evidence-first labels; no deletions)
JUNK_DIR_MARKERS = [
  "/node_modules/", "/build/", "/dist/", "/.dart_tool/", "/.next/", "/.gradle/", "/Pods/",
  "/DerivedData/", "/.cache/", "/.turbo/", "/.idea/", "/.vscode/", "/coverage/", "/tmp/", "/.pytest_cache/",
  "/local-ci/",  # audit output, not product
]
JUNK_FILE_BASENAMES = {
  ".DS_Store", "Thumbs.db", ".env", ".env.local", ".env.production", ".env.development",
  "npm-debug.log", "yarn-error.log", "pnpm-debug.log",
}
JUNK_EXT = {".log", ".tmp", ".swp", ".swo", ".bak"}

STACK_MARKERS = [
  ("Flutter", ["pubspec.yaml", "/lib/main.dart", "/android/", "/ios/"]),
  ("Next.js", ["next.config", "/app/", "/pages/", "package.json"]),
  ("Firebase", ["firebase.json", "firestore.rules", "storage.rules", "/functions/", "firebase-functions"]),
  ("Express/REST", ["express", "router", "openapi", "swagger"]),
  ("CI", [".github/workflows", "Dockerfile", "docker-compose", "Makefile"]),
]

def sha256_bytes(b: bytes) -> str:
  h = hashlib.sha256(); h.update(b); return h.hexdigest()

def read_json(p: Path):
  return json.loads(p.read_text(encoding="utf-8", errors="replace"))

def safe_read_bytes(p: Path):
  return p.read_bytes()

def is_probably_text(b: bytes) -> bool:
  if not b: return True
  if b"\x00" in b: return False
  try:
    b.decode("utf-8"); return True
  except Exception:
    return False

def count_lines_utf8(b: bytes):
  try:
    s = b.decode("utf-8")
    return s.count("\n") + (0 if s.endswith("\n") or s == "" else 1)
  except Exception:
    return None

def now_ts():
  return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())

def normalize(path: str) -> str:
  return path.replace("\\","/")

def detect_letter_by_letter_root(repo_root: Path) -> Path:
  base = repo_root/"local-ci"/"verification"/"letter_by_letter"
  if not base.exists(): return None
  candidates = []
  for d in base.iterdir():
    if d.is_dir():
      m = d/"MANIFEST.json"
      o = d/"OFFSETS.json"
      c = d/"ALL_FILES_CONCAT.bin"
      s = d/"SUMMARY.md"
      if m.exists() and o.exists() and c.exists() and s.exists():
        candidates.append(d)
  if not candidates: return None
  candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
  return candidates[0]

def find_repo_root() -> Path:
  # Prefer git top-level; fallback cwd
  try:
    import subprocess
    p = subprocess.run(["git","rev-parse","--show-toplevel"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    if p.returncode == 0 and p.stdout.strip():
      return Path(p.stdout.strip())
  except Exception:
    pass
  return Path(os.getcwd())

def main():
  repo_root = find_repo_root()
  out = repo_root/"local-ci"/"verification"/"reality_map"/"LATEST"
  (out/"inputs").mkdir(parents=True, exist_ok=True)
  (out/"inventory").mkdir(parents=True, exist_ok=True)
  (out/"analysis").mkdir(parents=True, exist_ok=True)
  (out/"reports").mkdir(parents=True, exist_ok=True)
  (out/"logs").mkdir(parents=True, exist_ok=True)
  (out/"gates").mkdir(parents=True, exist_ok=True)

  lb = detect_letter_by_letter_root(repo_root)
  if lb is None:
    print("FAIL: No letter_by_letter proof folder found.")
    print("Expected under: local-ci/verification/letter_by_letter/<timestamp>/ with MANIFEST/OFFSETS/CONCAT.")
    sys.exit(2)

  manifest_p = lb/"MANIFEST.json"
  offsets_p  = lb/"OFFSETS.json"
  concat_p   = lb/"ALL_FILES_CONCAT.bin"
  summary_p  = lb/"SUMMARY.md"

  # Copy pointers (not the 5GB concat) + capture metadata
  (out/"inputs"/"letter_by_letter_path.txt").write_text(str(lb), encoding="utf-8")
  (out/"inputs"/"source_manifest_path.txt").write_text(str(manifest_p), encoding="utf-8")
  (out/"inputs"/"source_offsets_path.txt").write_text(str(offsets_p), encoding="utf-8")
  (out/"inputs"/"source_concat_path.txt").write_text(str(concat_p), encoding="utf-8")
  (out/"inputs"/"source_summary_path.txt").write_text(str(summary_p), encoding="utf-8")

  manifest = read_json(manifest_p)
  offsets  = read_json(offsets_p)

  # Gate 1: verify the manifest matches offsets length
  files = manifest.get("files", [])
  unreadable = manifest.get("unreadable", [])
  if len(files) != len(offsets):
    (out/"gates"/"FAIL_manifest_offsets_mismatch.txt").write_text(
      f"Manifest files={len(files)} offsets={len(offsets)}\n", encoding="utf-8"
    )
    print("FAIL: MANIFEST vs OFFSETS mismatch.")
    sys.exit(3)

  # Gate 2: unreadable in proof => FAIL
  if unreadable:
    (out/"gates"/"FAIL_unreadable_in_letter_by_letter.txt").write_text(
      json.dumps(unreadable, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print("FAIL: letter_by_letter proof had unreadable files.")
    sys.exit(4)

  # Build hash maps for duplicate detection
  by_hash = defaultdict(list)
  by_ext  = Counter()
  dir_counter = Counter()
  stack_hits = defaultdict(list)
  junk_files = []
  suspicious = []
  text_files = 0
  bin_files = 0
  total_bytes = 0

  # Optional: verify disk file still matches recorded SHA256 (spot drift)
  drift = []

  # Build index for fast lookup
  off_by_path = {normalize(x["path"]): x for x in offsets}

  for f in files:
    path = normalize(f["path"])
    size = int(f.get("size", 0))
    sha  = f.get("sha256")
    total_bytes += size

    by_hash[sha].append(path)

    ext = Path(path).suffix.lower()
    by_ext[ext] += 1

    # directory statistics
    parent = str(Path(path).parent).replace("\\","/")
    dir_counter[parent] += 1

    # text/binary count
    if f.get("text_lines") is None and f.get("encoding") is None:
      # unknown; cannot assume; classify later only by extension heuristics
      pass
    else:
      text_files += 1

    # Junk heuristics (label only)
    pnorm = "/" + path.strip("/")
    if Path(path).name in JUNK_FILE_BASENAMES or ext in JUNK_EXT:
      junk_files.append({"path": path, "reason": "junk_basename_or_ext", "sha256": sha, "size": size})
    if any(m in pnorm for m in JUNK_DIR_MARKERS):
      junk_files.append({"path": path, "reason": "junk_dir_marker", "sha256": sha, "size": size})

    # Suspicious (very small / empty / extremely large)
    if size == 0:
      suspicious.append({"path": path, "reason": "empty_file", "sha256": sha})
    if size > 200 * 1024 * 1024:
      suspicious.append({"path": path, "reason": "very_large_file_gt_200MB", "sha256": sha, "size": size})

    # Stack detection (anchors)
    for stack, markers in STACK_MARKERS:
      # marker match against path only (safe, no content assumptions)
      for m in markers:
        if m.startswith("/") and m in pnorm:
          stack_hits[stack].append(path)
          break
        if m.endswith(".yaml") or m.endswith(".json") or m.endswith(".rules") or m.endswith("Dockerfile") or m.endswith("Makefile"):
          if Path(path).name.startswith(m) or Path(path).name == m:
            stack_hits[stack].append(path); break
        if "next.config" in m and "next.config" in Path(path).name:
          stack_hits[stack].append(path); break

  # Duplicate content (exact sha)
  dup_groups = []
  for sha, plist in by_hash.items():
    if sha and len(plist) > 1:
      dup_groups.append({"sha256": sha, "count": len(plist), "paths": sorted(plist)})

  dup_groups.sort(key=lambda x: x["count"], reverse=True)

  # Drift check (OPTIONAL but strict): re-hash disk for a bounded sample? NO. Must be ALL or none.
  # Since user requested NO BYPASS, we verify ALL files on disk against recorded sha.
  for f in files:
    path = normalize(f["path"])
    sha_expected = f.get("sha256")
    disk_path = repo_root / path
    # Ensure we never go into .git (should not exist in manifest, but enforce)
    if "/.git/" in ("/"+path+"/"):
      continue
    try:
      b = safe_read_bytes(disk_path)
      sha_disk = sha256_bytes(b)
      if sha_disk != sha_expected:
        drift.append({"path": path, "expected": sha_expected, "disk": sha_disk})
    except Exception as e:
      drift.append({"path": path, "expected": sha_expected, "error": str(e)})

  # Gate 3: drift => FAIL (repo changed since proof)
  if drift:
    (out/"gates"/"FAIL_repo_drift_since_letter_by_letter.json").write_text(
      json.dumps(drift, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    (out/"reports"/"DRIFT.md").write_text(
      "# FAIL: Repo drift since letter-by-letter proof\n\n"
      f"- Detected: {len(drift)} files changed/unreadable since proof.\n"
      f"- Evidence: `gates/FAIL_repo_drift_since_letter_by_letter.json`\n",
      encoding="utf-8"
    )
    print("FAIL: Repo drift since letter-by-letter proof. Re-run letter_by_letter_reader first.")
    sys.exit(5)

  # Build an entrypoint/component map (evidence anchored by paths)
  entrypoints = defaultdict(list)
  # Flutter
  for p in stack_hits.get("Flutter", []):
    if p.endswith("pubspec.yaml") or p.endswith("/lib/main.dart") or p.endswith("lib/main.dart"):
      entrypoints["Flutter"].append(p)
  # Next.js
  for p in stack_hits.get("Next.js", []):
    if "next.config" in Path(p).name or "/app/" in ("/"+p+"/") or "/pages/" in ("/"+p+"/"):
      entrypoints["Next.js"].append(p)
  # Firebase
  for p in stack_hits.get("Firebase", []):
    if Path(p).name in {"firebase.json","firestore.rules","storage.rules"} or "/functions/" in ("/"+p+"/"):
      entrypoints["Firebase"].append(p)

  # Write inventory artifacts
  (out/"inventory"/"MANIFEST.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
  (out/"inventory"/"OFFSETS.json").write_text(json.dumps(offsets, indent=2, ensure_ascii=False), encoding="utf-8")
  (out/"analysis"/"duplicates.json").write_text(json.dumps(dup_groups[:5000], indent=2, ensure_ascii=False), encoding="utf-8")
  (out/"analysis"/"junk_files.json").write_text(json.dumps(junk_files[:50000], indent=2, ensure_ascii=False), encoding="utf-8")
  (out/"analysis"/"suspicious.json").write_text(json.dumps(suspicious[:50000], indent=2, ensure_ascii=False), encoding="utf-8")
  (out/"analysis"/"stack_hits.json").write_text(json.dumps({k: sorted(set(v)) for k,v in stack_hits.items()}, indent=2, ensure_ascii=False), encoding="utf-8")
  (out/"analysis"/"entrypoints.json").write_text(json.dumps({k: sorted(set(v)) for k,v in entrypoints.items()}, indent=2, ensure_ascii=False), encoding="utf-8")

  # Reality Map report (CEO-readable but fully anchored)
  rep = []
  rep.append("# FULL REALITY MAP (No-Bypass, Letter-by-Letter Proven)\n\n")
  rep.append(f"- Generated: `{now_ts()}`\n")
  rep.append(f"- Repo root: `{repo_root}`\n")
  rep.append(f"- Source proof folder: `{lb}`\n")
  rep.append(f"- Files proven read (excluding .git): **{manifest.get('file_count')}**\n")
  rep.append(f"- Total bytes (sum of files): **{manifest.get('total_bytes')}**\n")
  rep.append(f"- Global concat SHA256: **{manifest.get('global_concat_sha256')}**\n")
  rep.append("\n## 1) Inventory (full)\n\n")
  rep.append("- Full per-file list: `inventory/MANIFEST.json`\n")
  rep.append("- Per-file offsets in concat: `inventory/OFFSETS.json`\n")

  rep.append("\n## 2) Stack / Components (anchored)\n\n")
  for stack in sorted(stack_hits.keys()):
    hits = sorted(set(stack_hits[stack]))
    rep.append(f"### {stack}\n")
    rep.append(f"- Hit count: {len(hits)}\n")
    for p in hits[:50]:
      rep.append(f"- `{p}`\n")
    if len(hits) > 50:
      rep.append(f"- ... (see `analysis/stack_hits.json`)\n")
    rep.append("\n")

  rep.append("\n## 3) Entrypoints (anchored)\n\n")
  for comp in sorted(entrypoints.keys()):
    eps = sorted(set(entrypoints[comp]))
    rep.append(f"### {comp}\n")
    for p in eps[:50]:
      rep.append(f"- `{p}`\n")
    if len(eps) > 50:
      rep.append(f"- ... (see `analysis/entrypoints.json`)\n")
    rep.append("\n")

  rep.append("\n## 4) Junk / Noise / Generated (evidence-labeled)\n\n")
  rep.append("- Junk candidates list: `analysis/junk_files.json`\n")
  rep.append("- Suspicious files list: `analysis/suspicious.json`\n")
  rep.append("\n### Top junk signals (examples)\n")
  for j in junk_files[:40]:
    rep.append(f"- `{j['path']}` — {j['reason']} — {j.get('size','?')} bytes — {j.get('sha256','')}\n")

  rep.append("\n## 5) Duplicates (exact content duplicates by SHA256)\n\n")
  rep.append("- Duplicate groups: `analysis/duplicates.json`\n")
  for g in dup_groups[:30]:
    rep.append(f"- SHA `{g['sha256']}` — count {g['count']}\n")
    for p in g["paths"][:10]:
      rep.append(f"  - `{p}`\n")
    if len(g["paths"]) > 10:
      rep.append("  - ...\n")

  rep.append("\n## 6) No-Bypass Gate\n\n")
  rep.append("- PASS conditions:\n")
  rep.append("  - letter_by_letter proof has unreadable_count=0\n")
  rep.append("  - manifest and offsets match 1:1\n")
  rep.append("  - disk SHA256 matches recorded SHA256 for EVERY file (no drift)\n\n")
  rep.append("If any fails, see `gates/`.\n")

  (out/"reports"/"REALITY_MAP_FULL.md").write_text("".join(rep), encoding="utf-8")

  # FINAL GATE
  (out/"reports"/"FINAL_GATE.txt").write_text("PASS\n", encoding="utf-8")
  print("PASS: FULL REALITY MAP generated with no-bypass proof.")
  print(f"OUT: {out}")
  print("KEY FILES:")
  print(f"- {out/'reports'/'REALITY_MAP_FULL.md'}")
  print(f"- {out/'reports'/'FINAL_GATE.txt'}")
  print(f"- {out/'analysis'/'junk_files.json'}")
  print(f"- {out/'analysis'/'duplicates.json'}")

if __name__ == "__main__":
  main()
