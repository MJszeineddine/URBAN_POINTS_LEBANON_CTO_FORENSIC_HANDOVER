#!/bin/bash
# Truth Bundle Runner - Execute evidence-based Qatar parity scanner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

echo "=== Running Truth Bundle Generator ==="
echo "Repository: $REPO_ROOT"
echo ""

# Make sure Python script is executable
chmod +x "$SCRIPT_DIR/truth_bundle.py"

# Execute the truth scanner
python3 "$SCRIPT_DIR/truth_bundle.py"

exit $?
