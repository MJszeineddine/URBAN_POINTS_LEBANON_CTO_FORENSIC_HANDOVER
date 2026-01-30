#!/usr/bin/env python3
"""
Validate Firebase deploy configuration files.
"""
import json
import sys
from pathlib import Path

def main():
    repo_root = Path(__file__).parent.parent.parent
    errors = []
    
    # Validate firebase.json
    print("Validating firebase.json...")
    firebase_json = repo_root / "firebase.json"
    if not firebase_json.exists():
        errors.append("firebase.json not found at repo root")
    else:
        try:
            with open(firebase_json) as f:
                config = json.load(f)
            if not isinstance(config, dict):
                errors.append("firebase.json must be a single JSON object")
            else:
                print("✓ firebase.json is valid JSON")
        except json.JSONDecodeError as e:
            errors.append(f"firebase.json invalid JSON: {e}")
    
    # Validate firestore.rules
    print("Validating firestore.rules...")
    firestore_rules = repo_root / "firestore.rules"
    if not firestore_rules.exists():
        errors.append("firestore.rules not found at repo root")
    else:
        with open(firestore_rules) as f:
            content = f.read()
        
        # Check for single rules_version
        if content.count("rules_version =") != 1:
            errors.append(f"firestore.rules has {content.count('rules_version =')} rules_version declarations (expected 1)")
        
        # Check for single service block
        if content.count("service cloud.firestore {") != 1:
            errors.append(f"firestore.rules has {content.count('service cloud.firestore')} service blocks (expected 1)")
        
        # Check for deny-by-default
        if "allow read, write: if false;" not in content and "allow read, write: if false" not in content:
            print("⚠ WARNING: firestore.rules may not have deny-by-default catch-all")
        
        if not errors:
            print("✓ firestore.rules is valid")
    
    # Validate storage.rules
    print("Validating storage.rules...")
    storage_rules = repo_root / "storage.rules"
    if not storage_rules.exists():
        errors.append("storage.rules not found at repo root")
    else:
        with open(storage_rules) as f:
            content = f.read()
        
        # Check for single rules_version
        if content.count("rules_version =") != 1:
            errors.append(f"storage.rules has {content.count('rules_version =')} rules_version declarations (expected 1)")
        
        # Check for single service block
        if content.count("service firebase.storage {") != 1:
            errors.append(f"storage.rules has {content.count('service firebase.storage')} service blocks (expected 1)")
        
        # Check for deny-by-default
        if "allow read, write: if false" not in content:
            print("⚠ WARNING: storage.rules may not have deny-by-default catch-all")
        
        if not errors:
            print("✓ storage.rules is valid")
    
    # Validate firestore.indexes.json
    print("Validating firestore.indexes.json...")
    indexes_json = repo_root / "firestore.indexes.json"
    if not indexes_json.exists():
        errors.append("firestore.indexes.json not found at repo root")
    else:
        try:
            with open(indexes_json) as f:
                indexes = json.load(f)
            print("✓ firestore.indexes.json is valid JSON")
        except json.JSONDecodeError as e:
            errors.append(f"firestore.indexes.json invalid JSON: {e}")
    
    if errors:
        print("\n❌ DEPLOY CONFIG VALIDATION FAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1
    else:
        print("\n✅ All deploy config files valid")
        return 0

if __name__ == '__main__':
    sys.exit(main())
