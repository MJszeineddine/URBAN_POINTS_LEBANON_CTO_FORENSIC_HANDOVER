#!/usr/bin/env bash
# Quick test of production gate (no emulator required)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

echo "▶ Test 1: Production gate without Firebase (should fail preflight)"
cd "$REPO_ROOT"
if bash tools/zero_human_pain_gate_hard.sh 2>&1 | grep -q "NO_GO"; then
  echo "✅ Test 1 PASS: Gate correctly rejected without Firebase"
else
  echo "❌ Test 1 FAIL: Gate should have rejected"
  exit 1
fi

echo ""
echo "▶ Test 2: Demo gate (should always pass)"
if bash tools/zero_human_pain_gate_demo.sh 2>&1 | grep -q "DEMO_ONLY"; then
  echo "✅ Test 2 PASS: Demo gate produced DEMO_ONLY verdict"
else
  echo "❌ Test 2 FAIL: Demo gate should have passed"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║    ALL QUICK TESTS PASSED ✅                  ║"
echo "╚══════════════════════════════════════════════╝"
