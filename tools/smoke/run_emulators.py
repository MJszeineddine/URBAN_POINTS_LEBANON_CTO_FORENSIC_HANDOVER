#!/usr/bin/env python3
"""
Firebase Emulators Runner for Smoke Tests
Starts Firestore + Functions + Auth emulators in headless mode
"""

import os
import sys
import json
import subprocess
import time
import socket
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent
EVIDENCE_DIR = Path(os.environ.get('EVIDENCE_DIR', REPO_ROOT / 'local-ci' / 'evidence' / 'PIPELINE' / 'latest'))
LOGS_DIR = EVIDENCE_DIR / 'logs'
LOGS_DIR.mkdir(parents=True, exist_ok=True)

EMULATOR_PORTS = {
    'firestore': 8080,
    'functions': 5001
}

def preflight_checks():
    """Check Node and Java availability (BLOCKING)."""
    print("[PREFLIGHT] Checking dependencies...")
    
    # Check Node
    try:
        node_result = subprocess.run(['node', '--version'], 
                                    capture_output=True, timeout=5, check=True)
        print(f"  ✅ Node: {node_result.stdout.decode().strip()}")
    except:
        print("  ❌ Node not found")
        return False, "NODE_MISSING"
    
    # Check Java (REQUIRED for Firestore emulator)
    try:
        java_result = subprocess.run(['java', '-version'], 
                                    capture_output=True, timeout=5, check=True)
        java_version = java_result.stderr.decode().split('\n')[0]
        print(f"  ✅ Java: {java_version}")
    except:
        print("  ❌ Java not found (required for Firestore emulator)")
        return False, "JAVA_MISSING"
    
    # Check Firebase CLI via direct path to local binary
    smoke_dir = Path(__file__).parent
    firebase_bin = smoke_dir / 'node_modules' / '.bin' / 'firebase'
    
    if not firebase_bin.exists():
        print(f"  ❌ Firebase CLI not found at {firebase_bin}")
        print("     Run: cd tools/smoke && npm install")
        return False, "FIREBASE_CLI_MISSING"
    
    try:
        fb_result = subprocess.run([str(firebase_bin), '--version'],
                                  capture_output=True, timeout=10, check=True)
        print(f"  ✅ Firebase CLI (local): {fb_result.stdout.decode().strip()}")
    except Exception as e:
        print(f"  ❌ Firebase CLI failed: {e}")
        return False, "FIREBASE_CLI_MISSING"
    
    return True, None

def check_port_open(port, timeout=30):
    """Check if port is open (emulator ready)."""
    start = time.time()
    while time.time() - start < timeout:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            result = sock.connect_ex(('127.0.0.1', port))
            sock.close()
            if result == 0:
                return True
        except:
            pass
        time.sleep(0.5)
    return False

def start_emulators():
    """Start Firebase emulators in background."""
    print("\n[EMULATORS] Starting Firebase Emulators...")
    
    # Find firebase.json
    firebase_json = REPO_ROOT / 'firebase.json'
    if not firebase_json.exists():
        print(f"ERROR: firebase.json not found at {firebase_json}")
        return None, None
    
    # Use direct path to firebase binary from tools/smoke/node_modules
    smoke_dir = Path(__file__).parent
    firebase_bin = smoke_dir / 'node_modules' / '.bin' / 'firebase'
    
    if not firebase_bin.exists():
        print(f"ERROR: firebase binary not found at {firebase_bin}")
        print("Run: cd tools/smoke && npm install")
        return None, None
    
    emulator_log = LOGS_DIR / 'emulators.log'
    
    cmd = [
        str(firebase_bin), 'emulators:start',
        '--only', 'firestore,functions',
        '--project', 'demo-urbanpoints'
    ]
    
    # Write emulator start command to log for evidence
    (LOGS_DIR / 'emulators_start.log').write_text(f"Command: {' '.join(cmd)}\nCwd: {REPO_ROOT}\nFirebase bin: {firebase_bin}\n\n")
    
    try:
        proc = subprocess.Popen(
            cmd,
            cwd=REPO_ROOT,
            stdout=open(emulator_log, 'w'),
            stderr=subprocess.STDOUT,
            text=True
        )
        
        print(f"[EMULATORS] Started (PID: {proc.pid}), waiting for ports...")
        
        # Wait for all ports to open
        for name, port in EMULATOR_PORTS.items():
            if check_port_open(port, timeout=60):
                print(f"  ✅ {name} ready on port {port}")
            else:
                print(f"  ❌ {name} failed to start on port {port}")
                proc.terminate()
                return None, None
        
        # Write probe info
        probe = {
            'pid': proc.pid,
            'ports': EMULATOR_PORTS,
            'status': 'running',
            'command': ' '.join(cmd),
            'firebase_bin': str(firebase_bin)
        }
        (EVIDENCE_DIR / 'emulator_probe.json').write_text(json.dumps(probe, indent=2))
        
        return proc, emulator_log
        
    except Exception as e:
        print(f"ERROR starting emulators: {e}")
        return None, None

def stop_emulators(proc):
    """Stop emulators cleanly."""
    if proc and proc.poll() is None:
        print("\n[EMULATORS] Stopping...")
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
        print("[EMULATORS] Stopped")

def run_smoke_tests():
    """Run smoke tests against emulators."""
    print("\n[SMOKE] Running smoke tests...")
    
    # Set emulator env vars
    env = os.environ.copy()
    env['FIRESTORE_EMULATOR_HOST'] = f'localhost:{EMULATOR_PORTS["firestore"]}'
    env['FUNCTIONS_EMULATOR_HOST'] = f'localhost:{EMULATOR_PORTS["functions"]}'
    env['EVIDENCE_DIR'] = str(EVIDENCE_DIR)
    
    smoke_script = Path(__file__).parent / 'run_smoke.js'
    if not smoke_script.exists():
        print(f"ERROR: Smoke script not found: {smoke_script}")
        return False
    
    try:
        result = subprocess.run(
            ['node', str(smoke_script)],
            cwd=smoke_script.parent,
            env=env,
            capture_output=True,
            text=True,
            timeout=120
        )
        
        # Write smoke log
        smoke_log = LOGS_DIR / 'smoke.log'
        smoke_log.write_text(f"STDOUT:\n{result.stdout}\n\nSTDERR:\n{result.stderr}")
        
        if result.returncode == 0:
            print("  ✅ Smoke tests PASSED")
            return True
        else:
            print(f"  ❌ Smoke tests FAILED (rc {result.returncode})")
            return False
            
    except subprocess.TimeoutExpired:
        print("  ❌ Smoke tests TIMEOUT")
        return False
    except Exception as e:
        print(f"  ❌ Smoke tests ERROR: {e}")
        return False

def main():
    """Main entry point."""
    # Run preflight checks first
    checks_ok, blocker = preflight_checks()
    if not checks_ok:
        print(f"\n❌ PREFLIGHT FAILED: {blocker}")
        # Write blocker to evidence
        blocker_info = {
            'blocker_type': 'external',
            'blocker_name': blocker,
            'resolution': {
                'NODE_MISSING': 'Install Node.js from nodejs.org',
                'JAVA_MISSING': 'Install Java JRE/JDK (required for Firestore emulator)',
                'FIREBASE_CLI_MISSING': 'Run: cd tools/smoke && npm install'
            }.get(blocker, 'Unknown blocker')
        }
        (EVIDENCE_DIR / 'preflight_blocker.json').write_text(json.dumps(blocker_info, indent=2))
        sys.exit(3 if blocker in ['NODE_MISSING', 'JAVA_MISSING'] else 1)
    
    proc, log_file = start_emulators()
    
    if not proc:
        print("\n❌ EMULATORS FAILED TO START")
        sys.exit(1)
    
    try:
        # Run smoke tests
        smoke_ok = run_smoke_tests()
        
        if smoke_ok:
            print("\n✅ EMULATORS + SMOKE: PASS")
            sys.exit(0)
        else:
            print("\n❌ SMOKE TESTS FAILED")
            sys.exit(1)
            
    finally:
        stop_emulators(proc)

if __name__ == '__main__':
    main()
