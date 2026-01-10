#!/usr/bin/env bash
#
# ENV_GATE - Environment validation for Phase 3 execution
# Part of EXECUTION_CONTRACT.md
# Must exit non-zero and print "BLOCKER_ENV_GATE: <reason>" on any failure
#

set -euo pipefail

# Prepare evidence logging
TS="$(date +%Y%m%d_%H%M%S)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EDIR_TMP="/tmp/urbanpoints/${TS}"
EDIR_REPO="${REPO_ROOT}/docs/parity/evidence/env/${TS}"
mkdir -p "${EDIR_TMP}" "${EDIR_REPO}"
ENV_LOG_TMP="${EDIR_TMP}/env.log"
ENV_LOG_REPO="${EDIR_REPO}/env.log"

# Stream output to both logs in real time
exec > >(tee -a "${ENV_LOG_TMP}" | tee -a "${ENV_LOG_REPO}") 2>&1

echo "=========================================="
echo "ENV_GATE: Environment Validation"
echo "Timestamp: ${TS}"
echo "Repo Root: ${REPO_ROOT}"
echo "=========================================="
echo ""

BLOCKER=""

# ============================================================
# CHECK 1: Node Version
# ============================================================
echo "CHECK 1: Node Version"
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node -v)
    echo "  Node: $NODE_VERSION"
    
    # Extract major version
    NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
    if [ "$NODE_MAJOR" -ge 18 ]; then
        echo "  ✓ Node version acceptable (v18+)"
    else
        BLOCKER="Node version $NODE_VERSION unsupported (require v18+)"
    fi
else
    BLOCKER="Node not found in PATH"
fi
echo ""

# ============================================================
# CHECK 2: NPM Version
# ============================================================
echo "CHECK 2: NPM Version"
if command -v npm >/dev/null 2>&1; then
    NPM_VERSION=$(npm -v)
    echo "  NPM: v$NPM_VERSION"
    echo "  ✓ NPM available"
else
    BLOCKER="NPM not found in PATH"
fi
echo ""

# ============================================================
# CHECK 3: Java Version
# ============================================================
echo "CHECK 3: Java Version"
if command -v java >/dev/null 2>&1; then
    JAVA_OUTPUT=$(java -version 2>&1)
    echo "  Java: $(echo "$JAVA_OUTPUT" | head -1)"
    
    if echo "$JAVA_OUTPUT" | grep -qE 'openjdk|java'; then
        echo "  ✓ Java available"
    else
        BLOCKER="Java version detection failed"
    fi
else
    BLOCKER="Java not found in PATH"
fi
echo ""

# ============================================================
# CHECK 4-6: Port Checks (8080, 9099, 9150, 4400, 4000, 4500)
# ============================================================
echo "CHECK 4-6: Port Availability & Stale Kill"

check_port() {
    local port=$1
    local name=$2
    
    if command -v lsof >/dev/null 2>&1; then
        local pids
        pids=$(lsof -ti tcp:"${port}" 2>/dev/null || true)
        if [ -n "${pids}" ]; then
            echo "  Port ${port} (${name}): OCCUPIED by PID(s): ${pids}"
            echo "  KILLING_STALE_PORT:${port}:${pids}"
            echo "BLOCKER_NOTE: Killing stale processes on port ${port}"
            echo "${pids}" | xargs kill -9 >/dev/null 2>&1 || true
            sleep 1
            local still
            still=$(lsof -ti tcp:"${port}" 2>/dev/null || true)
            if [ -n "${still}" ]; then
                BLOCKER="Failed to free port ${port}, PIDs: ${still}"
            else
                echo "  ✓ Port ${port} freed"
            fi
        else
            echo "  Port ${port} (${name}): ✓ Available"
        fi
    else
        echo "  Port ${port} (${name}): ⚠ lsof not available, skipping check"
    fi
}

check_port 8080 "Firestore Emulator"
check_port 9099 "Auth Emulator"
check_port 9150 "Firestore WebSocket"
check_port 4400 "Emulator UI"
check_port 4000 "Emulator Hub"
check_port 4500 "Storage Emulator"
echo ""

# ============================================================
# CHECK 7: IPv4 Normalization
# ============================================================
echo "CHECK 7: IPv4 Normalization"
if [ -n "${FIRESTORE_EMULATOR_HOST:-}" ]; then
    echo "  FIRESTORE_EMULATOR_HOST: $FIRESTORE_EMULATOR_HOST"
    
    if echo "$FIRESTORE_EMULATOR_HOST" | grep -qE 'localhost|::1'; then
        echo "  NORMALIZING: FIRESTORE_EMULATOR_HOST -> 127.0.0.1:8080"
        export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
        echo "  ✓ Patched to 127.0.0.1:8080"
    else
        echo "  ✓ IPv4 normalized (no localhost/::1)"
    fi
else
    echo "  FIRESTORE_EMULATOR_HOST: (not set)"
    echo "  ⚠ Emulator host not configured (will be set by tests)"
fi

if [ -n "${FIREBASE_AUTH_EMULATOR_HOST:-}" ]; then
    echo "  FIREBASE_AUTH_EMULATOR_HOST: $FIREBASE_AUTH_EMULATOR_HOST"
    
    if echo "$FIREBASE_AUTH_EMULATOR_HOST" | grep -qE 'localhost|::1'; then
        echo "  NORMALIZING: FIREBASE_AUTH_EMULATOR_HOST -> 127.0.0.1:9099"
        export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
        echo "  ✓ Patched to 127.0.0.1:9099"
    fi
fi
echo ""

# ============================================================
# CHECK 8: Emulator Probe (TCP connectivity)
# ============================================================
echo "CHECK 8: Emulator Probe (127.0.0.1:8080)"

if command -v nc >/dev/null 2>&1; then
    # Try to connect with 2s timeout
    if timeout 2 bash -c 'echo > /dev/tcp/127.0.0.1/8080' 2>/dev/null; then
        echo "  ✓ Port 8080 is reachable (emulator running)"
    else
        echo "  ℹ Port 8080 not reachable (emulator not running)"
        echo "    This is OK - tests will auto-start emulator"
    fi
else
    echo "  ⚠ nc not available, skipping connectivity probe"
fi
echo ""

# ============================================================
# CHECK 9: Backend Root Exists
# ============================================================
echo "CHECK 9: Backend Root Exists"
BACKEND_A="${REPO_ROOT}/source/backend/firebase-functions"
BACKEND_B="${REPO_ROOT}/backend/firebase-functions"
if [ -d "${BACKEND_A}" ] || [ -d "${BACKEND_B}" ]; then
    echo "  ✓ Backend root present"
else
    BLOCKER="Backend root missing (expected one of: ${BACKEND_A} or ${BACKEND_B})"
fi
echo ""

# ============================================================
# FINAL RESULT
# ============================================================
echo "=========================================="
if [ -z "$BLOCKER" ]; then
    echo "ENV_GATE: PASS ✅"
    echo "=========================================="
    exit 0
else
    echo "ENV_GATE: FAIL ❌"
    echo "=========================================="
    echo ""
    echo "BLOCKER_ENV_GATE: $BLOCKER"
    exit 1
fi
