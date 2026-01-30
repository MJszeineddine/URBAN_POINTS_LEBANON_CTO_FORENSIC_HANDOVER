#!/usr/bin/env python3
"""
Reality Map Evidence Extractor
Scans all components and generates proof anchors for REALITY_MAP.md
"""

import os
import json
import subprocess
from pathlib import Path
from collections import defaultdict

REPO_ROOT = Path.cwd()

# ============================================================================
# BACKEND FIREBASE FUNCTIONS
# ============================================================================

def extract_firebase_functions():
    """Extract Firebase functions info"""
    fb_func_path = REPO_ROOT / "source/backend/firebase-functions"
    result = {
        "path": str(fb_func_path),
        "exists": fb_func_path.exists(),
        "files": {},
        "exported_functions": [],
        "triggers": [],
        "env_vars": [],
        "tests": False
    }
    
    if not fb_func_path.exists():
        return result
    
    # Check key files
    key_files = [
        "src/index.ts",
        "src/core/auth.ts",
        "src/core/users.ts",
        "src/core/offers.ts",
        "src/core/points.ts",
        "src/core/qr.ts",
        "src/core/payments.ts",
        "package.json",
        ".env.example",
        ".env.deployment"
    ]
    
    for f in key_files:
        fpath = fb_func_path / f
        if fpath.exists():
            result["files"][f] = "EXISTS"
    
    # Parse index.ts for exports
    index_file = fb_func_path / "src/index.ts"
    if index_file.exists():
        try:
            with open(index_file, 'r') as f:
                content = f.read()
                # Find exports
                for line in content.split('\n'):
                    if 'export' in line and ('==' in line or 'onCall' in line or 'onRequest' in line or 'handler' in line.lower()):
                        func_name = line.split('export')[-1].strip().split('=')[0].strip().split('(')[0].strip()
                        if func_name:
                            result["exported_functions"].append(func_name)
        except:
            pass
    
    # Check for tests
    test_files = list(fb_func_path.glob("**/*.test.ts")) + list(fb_func_path.glob("**/*.spec.ts"))
    result["tests"] = len(test_files) > 0
    
    return result

# ============================================================================
# BACKEND REST API
# ============================================================================

def extract_rest_api():
    """Extract REST API info"""
    api_path = REPO_ROOT / "source/backend/rest-api"
    result = {
        "path": str(api_path),
        "exists": api_path.exists(),
        "files": {},
        "endpoints": [],
        "controllers": [],
        "env_vars": [],
        "tests": False
    }
    
    if not api_path.exists():
        return result
    
    # Check key files
    key_files = [
        "src/server.ts",
        "src/routes/index.ts",
        "src/controllers/authController.ts",
        "src/controllers/usersController.ts",
        "src/controllers/offersController.ts",
        "src/controllers/pointsController.ts",
        "package.json",
        ".env",
        ".env.example"
    ]
    
    for f in key_files:
        fpath = api_path / f
        if fpath.exists():
            result["files"][f] = "EXISTS"
    
    # Find routes
    routes_dir = api_path / "src/routes"
    if routes_dir.exists():
        for route_file in routes_dir.glob("*.ts"):
            result["endpoints"].append(route_file.name)
    
    # Find controllers
    controllers_dir = api_path / "src/controllers"
    if controllers_dir.exists():
        for ctrl_file in controllers_dir.glob("*.ts"):
            result["controllers"].append(ctrl_file.name)
    
    # Check for tests
    test_files = list(api_path.glob("**/*.test.ts")) + list(api_path.glob("**/*.spec.ts"))
    result["tests"] = len(test_files) > 0
    
    return result

# ============================================================================
# WEB ADMIN
# ============================================================================

def extract_web_admin():
    """Extract Web Admin info"""
    web_path = REPO_ROOT / "source/apps/web-admin"
    result = {
        "path": str(web_path),
        "exists": web_path.exists(),
        "files": {},
        "pages": [],
        "components": [],
        "tests": False,
        "e2e": False
    }
    
    if not web_path.exists():
        return result
    
    key_files = [
        "package.json",
        "src/main.tsx",
        "src/App.tsx",
        "tsconfig.json",
        "vite.config.ts"
    ]
    
    for f in key_files:
        fpath = web_path / f
        if fpath.exists():
            result["files"][f] = "EXISTS"
    
    # Find pages
    pages_dir = web_path / "src/pages"
    if pages_dir.exists():
        for page_file in pages_dir.glob("*.tsx"):
            result["pages"].append(page_file.stem)
    
    # Find components
    components_dir = web_path / "src/components"
    if components_dir.exists():
        for comp_file in components_dir.glob("*.tsx"):
            result["components"].append(comp_file.stem)
    
    # Check for tests
    test_files = list(web_path.glob("**/*.test.ts*")) + list(web_path.glob("**/*.spec.ts*"))
    result["tests"] = len(test_files) > 0
    
    # Check for e2e
    e2e_files = list(web_path.glob("**/e2e/**")) + list(web_path.glob("**/*.e2e.ts*"))
    result["e2e"] = len(e2e_files) > 0
    
    return result

# ============================================================================
# MOBILE APPS
# ============================================================================

def extract_mobile_apps():
    """Extract mobile app info"""
    mobile_base = REPO_ROOT / "source/apps"
    result = {}
    
    if not mobile_base.exists():
        return result
    
    for app_dir in mobile_base.iterdir():
        if not app_dir.is_dir() or app_dir.name in ['web-admin', '.']:
            continue
        
        pubspec = app_dir / "pubspec.yaml"
        if pubspec.exists():
            app_info = {
                "path": str(app_dir),
                "type": "flutter",
                "pubspec_exists": True,
                "files": {},
                "screens": [],
                "tests": False
            }
            
            key_files = ["pubspec.yaml", "lib/main.dart", "android/app/build.gradle", "ios/Podfile"]
            for f in key_files:
                fpath = app_dir / f
                if fpath.exists():
                    app_info["files"][f] = "EXISTS"
            
            # Find screens
            lib_dir = app_dir / "lib"
            if lib_dir.exists():
                for screen_file in lib_dir.glob("screens/*.dart"):
                    app_info["screens"].append(screen_file.stem)
            
            # Check for tests
            test_files = list(app_dir.glob("test/**/*.dart"))
            app_info["tests"] = len(test_files) > 0
            
            result[app_dir.name] = app_info
    
    return result

# ============================================================================
# INFRASTRUCTURE & CONFIG
# ============================================================================

def extract_infra_config():
    """Extract infra and config files"""
    result = {
        "firebase": False,
        "firestore_rules": False,
        "storage_rules": False,
        "firestore_indexes": False,
        "ci_workflows": [],
        "env_files": []
    }
    
    # Firebase config
    firebase_json = REPO_ROOT / "firebase.json"
    if firebase_json.exists():
        result["firebase"] = True
    
    # Firestore rules
    firestore_rules = REPO_ROOT / "firestore.rules"
    if firestore_rules.exists():
        result["firestore_rules"] = True
    
    # Storage rules
    storage_rules = REPO_ROOT / "storage.rules"
    if storage_rules.exists():
        result["storage_rules"] = True
    
    # Firestore indexes
    firestore_indexes = REPO_ROOT / "firestore.indexes.json"
    if firestore_indexes.exists():
        result["firestore_indexes"] = True
    
    # CI workflows
    workflows_dir = REPO_ROOT / ".github/workflows"
    if workflows_dir.exists():
        for wf_file in workflows_dir.glob("*.yml"):
            result["ci_workflows"].append(wf_file.name)
    
    # Env files
    env_patterns = [".env", ".env.example", ".env.local"]
    for pattern in env_patterns:
        if list(REPO_ROOT.glob(f"**/{pattern}")):
            result["env_files"].append(pattern)
    
    return result

# ============================================================================
# MAIN EXTRACTION
# ============================================================================

def main():
    data = {
        "timestamp": open("local-ci/verification/reality_map/LATEST/inventory/run_timestamp.txt").read().strip(),
        "git_commit": open("local-ci/verification/reality_map/LATEST/inventory/git_commit.txt").read().strip(),
        "firebase_functions": extract_firebase_functions(),
        "rest_api": extract_rest_api(),
        "web_admin": extract_web_admin(),
        "mobile_apps": extract_mobile_apps(),
        "infra_config": extract_infra_config()
    }
    
    # Write comprehensive JSON
    with open("local-ci/verification/reality_map/LATEST/extract/components.json", "w") as f:
        json.dump(data, f, indent=2)
    
    # Print summary
    print(f"Firebase Functions: {data['firebase_functions']['exists']}")
    print(f"REST API: {data['rest_api']['exists']}")
    print(f"Web Admin: {data['web_admin']['exists']}")
    print(f"Mobile Apps: {len(data['mobile_apps'])} found")
    print(f"CI Workflows: {len(data['infra_config']['ci_workflows'])}")

if __name__ == "__main__":
    main()
