#!/usr/bin/env python3
"""
Code Generator for Callable Wrappers
Generates skeleton callable wrappers from contract
"""

import sys
import json
from pathlib import Path

REPO_ROOT = Path.cwd()
CONTRACT_FILE = REPO_ROOT / 'spec' / 'api_contract' / 'callables.json'
WRAPPER_FILE = REPO_ROOT / 'source' / 'backend' / 'firebase-functions' / 'src' / 'callableWrappers.ts'

def load_contract():
    """Load callable contract."""
    if not CONTRACT_FILE.exists():
        print(f"ERROR: Contract file not found: {CONTRACT_FILE}")
        return None
    
    return json.loads(CONTRACT_FILE.read_text())

def generate_wrapper_skeleton(callable_name, params=None):
    """Generate TypeScript callable wrapper skeleton."""
    return f"""
/**
 * {callable_name} - Auto-generated skeleton
 * TODO: Implement actual logic
 */
exports.{callable_name} = functions.https.onCall(async (data, context) => {{
  // Validate auth
  if (!context.auth) {{
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }}
  
  // TODO: Implement {callable_name} logic
  // Expected params: {json.dumps(params) if params else 'unknown'}
  
  throw new functions.https.HttpsError('unimplemented', '{callable_name} not implemented yet');
}});
"""

def update_wrappers(contract):
    """Update callableWrappers.ts with missing functions."""
    if not WRAPPER_FILE.exists():
        print(f"ERROR: Wrapper file not found: {WRAPPER_FILE}")
        return
    
    content = WRAPPER_FILE.read_text()
    client_callables = contract.get('client_used', [])
    
    added = []
    for callable_name in client_callables:
        if f'exports.{callable_name}' not in content:
            skeleton = generate_wrapper_skeleton(callable_name)
            content += skeleton
            added.append(callable_name)
    
    if added:
        WRAPPER_FILE.write_text(content)
        print(f"Added {len(added)} skeleton wrappers:")
        for name in added:
            print(f"  - {name}")
    else:
        print("No missing wrappers (all callables already exist)")

def main():
    """Main entry point."""
    print("Callable Wrapper Code Generator")
    print("="*70)
    
    contract = load_contract()
    if not contract:
        sys.exit(1)
    
    print(f"Client callables: {len(contract.get('client_used', []))}")
    print(f"Server exports: {len(contract.get('server_exports', []))}")
    print(f"Missing: {len(contract.get('missing_on_server', []))}")
    
    if contract.get('missing_on_server'):
        print("\nGenerating wrappers for missing callables...")
        update_wrappers(contract)
    else:
        print("\n✅ All callables implemented")
    
    sys.exit(0)

if __name__ == '__main__':
    main()
