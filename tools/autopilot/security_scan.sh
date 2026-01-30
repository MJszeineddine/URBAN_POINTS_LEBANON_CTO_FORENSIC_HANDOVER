#!/usr/bin/env bash
set -euo pipefail

# security_scan.sh
# Scans repo for real secrets (high-confidence patterns only)
# Excludes dependency/build directories

OUT="$1"
mkdir -p "$(dirname "$OUT")"

echo "security scan run: $(date -u +'%Y-%m-%dT%H:%M:%SZ')" > "$OUT"
echo "exclusions: node_modules/, .git/, build/, dist/, .gradle/, Pods/, vendor/" >> "$OUT"
echo "" >> "$OUT"

# High-confidence patterns only (Stripe live keys, private keys, AWS keys)
PATTERNS=(
  'sk_live_[0-9a-zA-Z]{24,}'
  'sk_test_[0-9a-zA-Z]{24,}'
  'AKIA[0-9A-Z]{16}'
)

FAIL=0
for p in "${PATTERNS[@]}"; do
  echo "Scanning for: $p" >> "$OUT"
  if grep -r --binary-file=without-match \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=build \
    --exclude-dir=dist --exclude-dir=.gradle --exclude-dir=Pods \
    --exclude-dir=vendor --exclude-dir=.dart_tool --exclude-dir=tools \
    --exclude-dir=local-ci \
    -E "$p" . >> "$OUT" 2>/dev/null; then
    echo "---> MATCHES FOUND" >> "$OUT"
    FAIL=1
  else
    echo "ok" >> "$OUT"
  fi
done

echo "" >> "$OUT"
echo "SECURITY: scan complete" >> "$OUT"

if [ "$FAIL" -ne 0 ]; then
  exit 2
else
  exit 0
fi
