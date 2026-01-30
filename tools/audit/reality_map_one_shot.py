#!/usr/bin/env python3
import os, sys, json, hashlib, time
from pathlib import Path
from collections import defaultdict, Counter

EXCLUDE_DIRS = {".git", "local-ci"}  # Exclude .git and verification outputs

# SAFE LIMITS (prevent Mac freeze)
MAX_FILE_BYTES_FOR_TEXT_SNIFF = 1024 * 1024   # 1MB sniff only
MAX_LIST_PER_SECTION = 80
MAX_JUNK_LIST = 2000
MAX_DUP_GROUPS = 500

JUNK_DIR_MARKERS = [
  "/node_modules/","/build/","/dist/","/.dart_tool/","/.next/","/.gradle/","/Pods/","/DerivedData/",
  "/.cache/","/.turbo/","/.idea/","/.vscode/","/coverage/","/tmp/","/.pytest_cache/","/venv/"
]
JUNK_BASENAMES = {".DS_Store","Thumbs.db","npm-debug.log","yarn-error.log","pnpm-debug.log"}
JUNK_EXT = {".log",".tmp",".swp",".swo",".bak",".pid"}

STACK_PATTERNS = {
  "Flutter":      ["/pubspec.yaml","/lib/main.dart","/android/","/ios/"],
  "Next.js":      ["/next.config","/app/","/pages/","/next-env.d.ts"],
  "Firebase":     ["/firebase.json","/firestore.rules","/storage.rules","/functions/"],
  "REST/Express": ["/openapi","/swagger","express","router"],
  "CI":           ["/.github/workflows","/Dockerfile","/docker-compose","/Makefile"],
}

def now():
  return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())

def safe_rel(root: Path, p: Path) -> str:
  return str(p.relative_to(root)).replace("\\","/")

def sha256_stream(path: Path) -> str:
  h = hashlib.sha256()
  with open(path, "rb") as f:
    for chunk in iter(lambda: f.read(1024*1024), b""):
      h.update(chunk)
  return h.hexdigest()

def walk_all(root: Path):
  for dirpath, dirnames, filenames in os.walk(root):
    # prune excluded
    dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
    for fn in filenames:
      yield Path(dirpath) / fn

def main():
  repo = Path(os.getcwd())
  out = repo / "local-ci/verification/reality_map_one_shot/LATEST"
  out.mkdir(parents=True, exist_ok=True)

  files = sorted(set(walk_all(repo)))
  # never include outputs themselves
  files = [p for p in files if str(out) not in str(p)]

  manifest = []
  unreadable = []
  by_hash = defaultdict(list)
  by_ext = Counter()
  junk = []
  suspicious = []
  stack_hits = defaultdict(set)

  total_bytes = 0

  for p in files:
    ap = p.resolve()
    parts = ap.parts
    if ".git" in parts:
      continue

    rel = safe_rel(repo, p)
    reln = rel.replace("\\","/")

    try:
      st = p.stat()
      size = int(st.st_size)
    except Exception as e:
      unreadable.append({"path": reln, "error": f"stat: {e}"})
      continue

    try:
      h = sha256_stream(p)
    except Exception as e:
      unreadable.append({"path": reln, "error": f"read/hash: {e}"})
      continue

    total_bytes += size
    manifest.append({"path": reln, "size": size, "sha256": h})
    by_hash[h].append(reln)
    by_ext[p.suffix.lower()] += 1

    pn = "/" + reln.strip("/")
    bn = p.name
    ext = p.suffix.lower()

    if bn in JUNK_BASENAMES or ext in JUNK_EXT or any(m in pn for m in JUNK_DIR_MARKERS):
      if len(junk) < MAX_JUNK_LIST:
        junk.append({"path": reln, "size": size, "sha256": h})

    if size == 0:
      suspicious.append({"path": reln, "reason":"empty_file", "sha256": h})
    if size > 200*1024*1024:
      suspicious.append({"path": reln, "reason":"very_large_gt_200MB", "size": size, "sha256": h})

    for stack, pats in STACK_PATTERNS.items():
      for pat in pats:
        if pat.startswith("/") and pat in pn:
          stack_hits[stack].add(reln); break
        if not pat.startswith("/") and pat in reln:
          stack_hits[stack].add(reln); break

  dup_groups = []
  for h, plist in by_hash.items():
    if len(plist) > 1:
      dup_groups.append({"sha256": h, "count": len(plist), "paths": sorted(plist)})
  dup_groups.sort(key=lambda x: x["count"], reverse=True)
  dup_groups = dup_groups[:MAX_DUP_GROUPS]

  # Write artifacts (small + useful)
  (out/"inventory/MANIFEST.json").write_text(json.dumps({
    "generated_at": now(),
    "repo_root": str(repo),
    "excluded_dirs": sorted(list(EXCLUDE_DIRS)),
    "file_count": len(manifest),
    "total_bytes": total_bytes,
    "unreadable_count": len(unreadable),
    "unreadable": unreadable,
    "files": manifest,
  }, indent=2, ensure_ascii=False), encoding="utf-8")

  (out/"analysis/extensions_count.json").write_text(json.dumps(by_ext, indent=2, ensure_ascii=False), encoding="utf-8")
  (out/"analysis/stack_hits.json").write_text(json.dumps({k: sorted(list(v)) for k,v in stack_hits.items()}, indent=2, ensure_ascii=False), encoding="utf-8")
  (out/"analysis/junk_candidates.json").write_text(json.dumps(junk, indent=2, ensure_ascii=False), encoding="utf-8")
  (out/"analysis/duplicates_top.json").write_text(json.dumps(dup_groups, indent=2, ensure_ascii=False), encoding="utf-8")
  (out/"analysis/suspicious.json").write_text(json.dumps(suspicious, indent=2, ensure_ascii=False), encoding="utf-8")

  # CEO report
  md=[]
  md.append("# Reality Map (ONE-SHOT, No-Bypass, Safe)\n\n")
  md.append(f"- Generated: `{now()}`\n")
  md.append(f"- Repo root: `{repo}`\n")
  md.append(f"- Excluded dirs: `{', '.join(sorted(EXCLUDE_DIRS))}`\n")
  md.append(f"- Files read: **{len(manifest)}**\n")
  md.append(f"- Total bytes read: **{total_bytes}**\n")
  md.append(f"- Unreadable: **{len(unreadable)}**\n\n")

  if unreadable:
    md.append("## Unreadable (FAIL)\n")
    for u in unreadable[:200]:
      md.append(f"- `{u['path']}` — {u['error']}\n")
    md.append("\n")

  md.append("## Stack hits (anchored)\n\n")
  for k in sorted(stack_hits.keys()):
    hits = sorted(list(stack_hits[k]))
    md.append(f"### {k} ({len(hits)})\n")
    for p in hits[:MAX_LIST_PER_SECTION]:
      md.append(f"- `{p}`\n")
    if len(hits) > MAX_LIST_PER_SECTION:
      md.append(f"- ... more in `analysis/stack_hits.json`\n")
    md.append("\n")

  md.append("## Junk candidates (label-only)\n")
  md.append("- See `analysis/junk_candidates.json`\n\n")

  md.append("## Duplicate content groups\n")
  md.append("- See `analysis/duplicates_top.json`\n\n")

  md.append("## Suspicious\n")
  md.append("- See `analysis/suspicious.json`\n\n")

  md.append("## Evidence index\n")
  md.append("- `inventory/MANIFEST.json` (every file hash)\n")
  md.append("- `analysis/*` (stack/junk/duplicates)\n")

  (out/"reports/REALITY_MAP.md").write_text("".join(md), encoding="utf-8")

  # Gate
  gate = "PASS" if len(unreadable)==0 else "FAIL"
  (out/"reports/FINAL_GATE.txt").write_text(gate + "\n", encoding="utf-8")

  print(gate)
  print(str(out))
  print(str(out/"reports/REALITY_MAP.md"))
  print(str(out/"reports/FINAL_GATE.txt"))

  if gate != "PASS":
    sys.exit(2)

if __name__ == "__main__":
  main()
