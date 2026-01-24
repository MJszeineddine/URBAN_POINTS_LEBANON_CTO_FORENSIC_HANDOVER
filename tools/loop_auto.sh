#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")" && pwd))"
cd "$REPO_ROOT"

python3 tools/audit/run_gates.py
