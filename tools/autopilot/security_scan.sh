#!/usr/bin/env bash
set -euo pipefail

# security_scan.sh
# Scans the repo for real secrets (sk_live_ keys, private keys, service accounts)
# Excludes local-ci and tools directories from search results but still fails if a real key appears anywhere else.

OUT="$1"
mkdir -p "$(dirname "$OUT")"

echo "security scan run: $(date -u +'%Y-%m-%dT%H:%M:%SZ')" > "$OUT"
echo "exclusions: local-ci/, tools/" >> "$OUT"
echo "" >> "$OUT"

# Patterns to detect
PATTERNS=(
  'sk_live_[0-9a-zA-Z_\-]{16,}'
  '-----BEGIN (RSA )?PRIVATE KEY-----'
  '-----BEGIN ENCRYPTED PRIVATE KEY-----'
  '"type": "service_account"'
)

FAIL=0
for p in "${PATTERNS[@]}"; do
  echo "Searching for pattern: $p" >> "$OUT"
  # Search repo, excluding local-ci and tools
  # Use grep with binary-file=without-match to avoid binaries
  if grep -RIn --binary-file=without-match --exclude-dir={.git,local-ci,tools,node_modules} -E "$p" . >> "$OUT" 2>/dev/null; then
    echo "---> MATCHES FOUND for pattern: $p" >> "$OUT"
    FAIL=1
  else
    echo "no matches for: $p" >> "$OUT"
  fi
done

# Allowlist: public Firebase API keys (AIza) are ok — search separately for them but do not fail
echo "" >> "$OUT"
echo "Allowlist (Firebase API keys) - not flagged as failures:" >> "$OUT"
grep -RIn --binary-file=without-match --exclude-dir={.git,local-ci,tools,node_modules} -E 'AIza[0-9A-Za-z\-_]{35}' . >> "$OUT" 2>/dev/null || true

if [ "$FAIL" -ne 0 ]; then
  echo "SECURITY: real secret patterns found" >> "$OUT"
  exit 2
else
  echo "SECURITY: no high-confidence secret patterns found" >> "$OUT"
  exit 0
fi
