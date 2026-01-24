#!/usr/bin/env python3
import os, sys, json, time

KEY_BASENAMES = [
  "FINAL_GATE.txt",
  "DELTA_SUMMARY.md",
  "CTO_REALITY_AUDIT.md",
  "FEATURE_MATRIX_MINI.md",
  "STACK_MAP.md",
  "failures_excerpt.md",
  "GATES_STATUS.json",
  "SUMMARY.md",
  "letter_by_letter_summary.md",
]

def find_all(root):
  for dp, dns, fns in os.walk(root):
    if "/.git" in dp:
      continue
    for fn in fns:
      yield os.path.join(dp, fn)

def newest_by_basename(paths):
  best = {}
  for p in paths:
    bn = os.path.basename(p)
    if bn not in KEY_BASENAMES:
      continue
    try:
      st = os.stat(p)
    except Exception:
      continue
    cur = best.get(bn)
    if cur is None or st.st_mtime > cur["mtime"]:
      best[bn] = {"path": p, "mtime": st.st_mtime, "size": st.st_size}
  return best

def md_index(best):
  lines = ["# Latest Artifacts Index (14d ledger helper)", ""]
  for bn, info in sorted(best.items()):
    ts = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(info["mtime"]))
    lines.append(f"- **{bn}** — `{info['path']}` — {info['size']} bytes — mtime {ts}")
  return "\n".join(lines) + "\n"

def main():
  out = sys.argv[1] if len(sys.argv) > 1 else "local-ci/verification/ledger_2w/LATEST"
  root = os.getcwd()
  verif = os.path.join(root, "local-ci", "verification")
  paths = list(find_all(verif)) if os.path.isdir(verif) else []
  best = newest_by_basename(paths)
  os.makedirs(os.path.join(out, "extracts"), exist_ok=True)
  jpath = os.path.join(out, "extracts", "latest_artifacts_index.json")
  mpath = os.path.join(out, "extracts", "latest_artifacts_index.md")
  with open(jpath, "w", encoding="utf-8") as f:
    json.dump(best, f, indent=2, ensure_ascii=False)
  with open(mpath, "w", encoding="utf-8") as f:
    f.write(md_index(best))
  print(f"Wrote: {jpath}")
  print(f"Wrote: {mpath}")

if __name__ == "__main__":
  main()
