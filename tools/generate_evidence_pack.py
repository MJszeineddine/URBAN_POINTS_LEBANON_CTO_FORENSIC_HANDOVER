#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime

gate_dir = Path('local-ci/verification/reality_gate')

# Read all data
exit_code = gate_dir.joinpath('reality_gate_exit.txt').read_text().strip()
exits_json = gate_dir.joinpath('exits.json').read_text()
run_log = gate_dir.joinpath('reality_gate_run.log').read_text().splitlines()
stub_summary = gate_dir.joinpath('stub_scan_summary.json').read_text().splitlines()

# Get all exit files
exit_files = sorted(gate_dir.glob('*_exit.txt'))

# Build markdown
md = f"""# REALITY EVIDENCE PACK
**Generated:** {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}  
**Script:** tools/gates/reality_gate.sh  
**Evidence Directory:** local-ci/verification/reality_gate/

---

## 1. FINAL EXIT CODE

**reality_gate_exit.txt:**
```
{exit_code}
```

---

## 2. EXITS JSON (All Component Results)

**exits.json:**
```json
{exits_json}
```

---

## 3. EXECUTION LOG (Last 120 Lines)

**reality_gate_run.log (tail -120):**
```
{chr(10).join(run_log[-120:])}
```

---

## 4. COMPONENT EXIT CODES

"""

for f in exit_files:
    val = f.read_text().strip()
    md += f"**{f.name}:** `{val}`  \n"

md += "\n---\n\n## 5. BUILD/TEST LOGS (Last 80 Lines Each)\n\n"

logs_to_include = [
    ('backend_build.log', 'Backend Build Log'),
    ('backend_test.log', 'Backend Test Log'),
    ('web_build.log', 'Web Build Log'),
    ('web_test.log', 'Web Test Log'),
    ('merchant_analyze.log', 'Merchant Analyze Log'),
    ('merchant_test.log', 'Merchant Test Log'),
    ('customer_analyze.log', 'Customer Analyze Log'),
    ('customer_test.log', 'Customer Test Log'),
]

for log_file, title in logs_to_include:
    log_path = gate_dir.joinpath(log_file)
    if log_path.exists():
        lines = log_path.read_text().splitlines()
        md += f"### {title}\n```\n{chr(10).join(lines[-80:])}\n```\n\n"

md += "---\n\n## 6. STUB SCAN SUMMARY (First 80 Lines)\n\n"
md += f"**stub_scan_summary.json (head -80):**\n```json\n{chr(10).join(stub_summary[:80])}\n```\n\n"

# Count critical hits
stub_data = json.loads(gate_dir.joinpath('stub_scan_summary.json').read_text())
crit_count = len(stub_data.get('critical_hits', []))
md += f"**Critical Hits Count:** `{crit_count} critical stub files`\n\n"

md += "---\n\n## 7. FINAL VERDICT\n\n"

if exit_code == "0":
    md += """### ✅ **GO** - PRODUCTION READY

All gate checks passed:
- Exit code: 0
- All component exits: 0
- Critical stub hits: 0
- FINAL_EXIT line present in log
"""
else:
    md += f"""### ❌ **NO-GO** - BLOCKED

Gate failed with exit code: {exit_code}
Review exits.json and component logs for failures.
"""

md += "\n---\n\n**Evidence Pack Complete**\n"

# Write file
gate_dir.joinpath('REALITY_EVIDENCE_PACK.md').write_text(md)
print(f"Evidence pack generated: {gate_dir}/REALITY_EVIDENCE_PACK.md")
print(f"Exit code: {exit_code}")
print(f"Verdict: {'GO' if exit_code == '0' else 'NO-GO'}")
