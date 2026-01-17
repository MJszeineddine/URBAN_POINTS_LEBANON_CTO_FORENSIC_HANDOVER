#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )"/../.. && pwd)"
"$ROOT_DIR/tools/gates/reality_gate.sh" || true
EX="$ROOT_DIR/local-ci/verification/reality_gate/exits.json"
if [[ -f "$EX" ]]; then
  crit=$(python3 -c "import json;print(json.load(open('$EX')).get('critical_stub_hits',1))")
  ec=$(python3 -c "import json;d=json.load(open('$EX'));print(max(d.get('cto_gate',1),d.get('backend_build',1),d.get('backend_test',1),d.get('web_build',1),d.get('web_test',1),d.get('merchant_analyze',1),d.get('merchant_test',1),d.get('customer_analyze',1),d.get('customer_test',1),d.get('stub_scan',1)))")
  if [[ "$crit" == "0" && "$ec" == "0" ]]; then
    exit 0
  else
    exit 1
  fi
else
  echo "Missing exits.json" >&2
  exit 2
fi
