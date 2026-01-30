#!/usr/bin/env python3
import os, sys, json, time, re
from pathlib import Path

def r(p):
  try:
    return Path(p).read_text(encoding="utf-8", errors="replace")
  except Exception:
    return ""

def write(p, s):
  Path(p).parent.mkdir(parents=True, exist_ok=True)
  Path(p).write_text(s, encoding="utf-8")

def load_latest_index(out_dir):
  p = Path(out_dir)/"extracts"/"latest_artifacts_index.json"
  if not p.exists(): return {}
  try:
    return json.loads(p.read_text(encoding="utf-8"))
  except Exception:
    return {}

def parse_git_log(path):
  entries = []
  if not Path(path).exists(): return entries
  for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
    parts = line.split("|", 3)
    if len(parts) != 4: continue
    h, ad, an, s = parts
    entries.append({"hash": h, "date": ad, "author": an, "subject": s})
  return entries

def parse_git_changed(path):
  m = {}
  if not Path(path).exists(): return m
  cur = None
  for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
    if line.startswith("COMMIT "):
      cur = line
      m[cur] = []
    else:
      if cur and line.strip():
        m[cur].append(line.strip())
  return m

def milestone_from_path(p):
  s = str(p).replace("\\","/")
  if "letter_by_letter" in s: return "letter_by_letter"
  if "cto_reality_audit" in s: return "cto_reality_audit"
  if "cto_fixpack" in s: return "cto_fixpack"
  if "today_proof_lab" in s: return "today_proof_lab"
  if "ledger_2w" in s: return "ledger_2w"
  return None

def extract_status(text):
  # look for PASS/FAIL lines
  for pat in [r"PASS/FAIL:\s*(PASS|FAIL)", r"Status:\s*(PASS|FAIL)", r"\b(PASS|FAIL)\b"]:
    m = re.search(pat, text, re.IGNORECASE)
    if m: return m.group(1).upper()
  return "UNKNOWN"

def head_excerpt(path, n=120):
  try:
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    return "\n".join(lines[:n]) + ("\n" if lines else "")
  except Exception:
    return ""

def main():
  out = sys.argv[1] if len(sys.argv)>1 else "local-ci/verification/ledger_2w/LATEST"
  outp = Path(out)
  git_log = outp/"git"/"git_log_14d.txt"
  git_changed = outp/"git"/"git_changed_files_14d.txt"
  idx = load_latest_index(out)

  git_entries = parse_git_log(git_log)
  changed = parse_git_changed(git_changed)

  # Build artifact list
  artifacts = []
  for bn, info in idx.items():
    artifacts.append({"basename": bn, **info, "milestone": milestone_from_path(info["path"])})
  artifacts.sort(key=lambda x: x.get("mtime",0), reverse=True)

  # Attempt to pick key milestone folders by scanning local-ci/verification
  verif_root = Path(os.getcwd())/"local-ci"/"verification"
  milestone_folders = {}
  if verif_root.exists():
    for p in verif_root.rglob("*"):
      if p.is_dir():
        ms = milestone_from_path(p)
        if ms and ms not in milestone_folders:
          milestone_folders[ms] = str(p)

  # Determine latest gate result if present
  final_gate_path = idx.get("FINAL_GATE.txt", {}).get("path")
  final_gate_txt = head_excerpt(final_gate_path) if final_gate_path else ""
  overall_status = extract_status(final_gate_txt)

  ledger = {
    "generated_at": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()),
    "repo_root": str(Path(os.getcwd())),
    "time_window_days": 14,
    "overall_latest_status": overall_status,
    "latest_final_gate_path": final_gate_path,
    "milestone_folders_detected": milestone_folders,
    "git_commits_14d_count": len(git_entries),
    "git_commits_14d": git_entries[:200],
    "latest_artifacts": artifacts,
  }

  write(outp/"reports"/"LEDGER_2W.json", json.dumps(ledger, indent=2, ensure_ascii=False))

  # CEO-readable MD
  md = []
  md.append("# 2-Week Project Ledger (Evidence-Backed)\n")
  md.append(f"- Generated: `{ledger['generated_at']}`\n")
  md.append(f"- Repo root: `{ledger['repo_root']}`\n")
  md.append(f"- Window: last **14 days**\n")
  md.append(f"- Latest overall status (from FINAL_GATE): **{overall_status}**\n")
  if final_gate_path:
    md.append(f"- Latest FINAL_GATE: `{final_gate_path}`\n")
  md.append("\n## Milestones detected (by folder names)\n")
  for k,v in sorted(milestone_folders.items()):
    md.append(f"- **{k}** → `{v}`\n")

  md.append("\n## Latest key artifacts (newest first)\n")
  for a in artifacts[:30]:
    ts = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(a.get("mtime",0)))
    md.append(f"- `{a['basename']}` — `{a['path']}` — {a.get('size','?')} bytes — mtime {ts}\n")

  md.append("\n## Git activity (last 14 days)\n")
  if not git_entries:
    md.append("- (No git history captured or repo not a git checkout)\n")
  else:
    for e in git_entries[:50]:
      md.append(f"- `{e['hash'][:10]}` {e['date']} — {e['subject']}\n")

  write(outp/"reports"/"LEDGER_2W.md", "".join(md))

  # No-repeat guard (simple: list milestone folders + artifacts)
  nr = []
  nr.append("# NO-REPEAT GUARD\n\n")
  nr.append("## Already executed milestone work (detected by artifacts/folders)\n")
  for k,v in sorted(milestone_folders.items()):
    nr.append(f"- {k}: `{v}`\n")
  nr.append("\n## Key artifacts already produced\n")
  for a in artifacts[:50]:
    nr.append(f"- `{a['basename']}` at `{a['path']}`\n")
  write(outp/"reports"/"NO_REPEAT_GUARD.md", "".join(nr))

  # Next actions (evidence-linked; based on blockers keywords in FINAL_GATE excerpt if present)
  na = []
  na.append("# TOP NEXT ACTIONS (Evidence-Linked)\n\n")
  if final_gate_txt.strip():
    na.append("## Latest FINAL_GATE excerpt (evidence)\n\n```text\n")
    na.append(final_gate_txt[:4000])
    na.append("\n```\n\n")
  na.append("## Proposed next actions\n")
  na.append("- If latest status is FAIL due to infra (emulators/ports), prioritize emulator bring-up + health proof.\n")
  na.append("- If FAIL due to missing deps, install deps in the specific package.json that runs the failing script.\n")
  na.append("- If FAIL due to missing fixtures, add fixtures under tools/fixtures and rerun only those proofs.\n")
  na.append("\n(These are placeholders unless FINAL_GATE shows exact blockers; keep evidence-first.)\n")
  write(outp/"reports"/"TOP_ACTIONS_NEXT.md", "".join(na))

  print(f"OUT: {out}")
  print("WROTE: reports/LEDGER_2W.md")
  print("WROTE: reports/NO_REPEAT_GUARD.md")
  print("WROTE: reports/TOP_ACTIONS_NEXT.md")
  print("WROTE: reports/LEDGER_2W.json")

if __name__ == "__main__":
  main()
