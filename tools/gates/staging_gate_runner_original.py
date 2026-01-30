#!/usr/bin/env python3
import os
import re
import json
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = REPO_ROOT / "local-ci" / "verification" / "staging_gate" / "LATEST"

SCAN_TARGETS = [
    REPO_ROOT / "source" / "backend",
    REPO_ROOT / "source" / "apps" / "web-admin" / "pages",
]
EXCLUDE_DIRS = {"node_modules", ".next", "dist", "build"}

ENV_PATTERN = re.compile(r"process\\.env\\.([A-Z0-9_]+)")
NEXT_PUBLIC_PATTERN = re.compile(r"NEXT_PUBLIC_[A-Z0-9_]+")

# Secrets to redact in logs
SENSITIVE_KEYS = {
    "QR_TOKEN_SECRET", "STRIPE_SECRET_KEY", "JWT_SECRET", 
    "TWILIO_AUTH_TOKEN", "DATABASE_URL", "SENTRY_DSN"
}


def log(msg: str):
    print(msg)


def ensure_output_dir():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def load_dotenv_file(path: Path):
    if not path.exists():
        return {}
    loaded = {}
    try:
        with path.open("r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip().strip('"').strip("'")
                if k and v and k not in os.environ:
                    os.environ[k] = v
                    loaded[k] = v
    except Exception:
        pass
    return loaded


def discover_env_vars():
    env_vars = set()
    next_public_vars = set()
    requires_functions_config = False

    for target in SCAN_TARGETS:
        if not target.exists():
            continue
        for root, dirs, files in os.walk(target):
            # prune excluded dirs
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
            for f in files:
                if not (f.endswith(".ts") or f.endswith(".tsx") or f.endswith(".js") or f.endswith(".jsx")):
                    continue
                p = Path(root) / f
                try:
                    with p.open("r", encoding="utf-8", errors="ignore") as fh:
                        content = fh.read()
                    for m in ENV_PATTERN.finditer(content):
                        env_vars.add(m.group(1))
                    for m in NEXT_PUBLIC_PATTERN.finditer(content):
                        next_public_vars.add(m.group(0))
                    # Detect Firebase Functions runtime config usage without regex paren pitfalls
                    if "functions.config(" in content:
                        requires_functions_config = True
                except Exception:
                    # skip unreadable files
                    pass

    # Fallback baseline required vars derived from code review
    baseline_required = {
        "DATABASE_URL",
        "JWT_SECRET",
        "CORS_ORIGIN",
        "API_RATE_LIMIT_WINDOW_MS",
        "API_RATE_LIMIT_MAX_REQUESTS",
        "PORT",
        "STRIPE_SECRET_KEY",
        "STRIPE_WEBHOOK_SECRET",
        "SENTRY_DSN",
        "TWILIO_ACCOUNT_SID",
        "TWILIO_AUTH_TOKEN",
        "WHATSAPP_NUMBER",
        "QR_TOKEN_SECRET",
    }

    env_vars = env_vars.union(baseline_required)

    return {
        "env_vars": sorted(env_vars),
        "next_public_vars": sorted(next_public_vars),
        "requires_functions_config": requires_functions_config,
    }


def check_env_presence(vars_list):
    present = {}
    missing = {}
    for name in vars_list:
        val = os.environ.get(name)
        if val:
            present[name] = True
        else:
            missing[name] = True
    return present, missing


def write_json(path: Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, sort_keys=True)


def write_text(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        f.write(text)


def main():
    ensure_output_dir()
    ts = time.strftime("%Y-%m-%d %H:%M:%S")

    # Load optional env overlays
    overlays = {}
    overlays.update(load_dotenv_file(REPO_ROOT / ".env.staging"))
    overlays.update(load_dotenv_file(REPO_ROOT / "source" / "backend" / "rest-api" / ".env.staging"))
    # Load .env.local from firebase-functions if it exists (local dev/deploy secret)
    overlays.update(load_dotenv_file(REPO_ROOT / "source" / "backend" / "firebase-functions" / ".env.local"))
    # Load .env.local from rest-api if it exists (local dev/staging secret)
    overlays.update(load_dotenv_file(REPO_ROOT / "source" / "backend" / "rest-api" / ".env.local"))

    discovery = discover_env_vars()
    present, missing = check_env_presence(discovery["env_vars"])  # only server-side envs gate

    # Redact sensitive values in present dict (only show SET/MISSING)
    present_redacted = {}
    for key in present.keys():
        if key in SENSITIVE_KEYS:
            present_redacted[key] = "SET (redacted)"
        else:
            present_redacted[key] = True
    
    missing_redacted = {}
    for key in missing.keys():
        if key in SENSITIVE_KEYS:
            missing_redacted[key] = "MISSING (secret)"
        else:
            missing_redacted[key] = True

    env_check = {
        "timestamp": ts,
        "repo_root": str(REPO_ROOT),
        "detected_env_vars": discovery["env_vars"],
        "detected_next_public_vars": discovery["next_public_vars"],
        "requires_functions_config": discovery["requires_functions_config"],
        "present": sorted(present_redacted.keys()),
        "missing": sorted(missing_redacted.keys()),
        "env_overlays_loaded": sorted([k for k in overlays.keys() if k not in SENSITIVE_KEYS] + 
                                      ([f"{k} (redacted)" for k in overlays.keys() if k in SENSITIVE_KEYS])),
    }
    write_json(OUTPUT_DIR / "env_check.json", env_check)

    # Evidence-based REQUIRED environment variables (from REQUIRED_ENVS.md)
    # Rule (a): Module-level/unconditional checks at startup
    REQUIRED_VARS = {
        "QR_TOKEN_SECRET": {  # Firebase Functions module-init check (index.ts:58-60)
            "file": "source/backend/firebase-functions/src/index.ts",
            "line": "58-60",
            "component": "Firebase Functions",
            "reason": "Module-level throw if missing in production; blocks startup"
        },
        "JWT_SECRET": {  # REST API module-init check (server.ts:21-22)
            "file": "source/backend/rest-api/src/server.ts",
            "line": "21-22",
            "component": "REST API",
            "reason": "ensureRequiredEnv() called at module init; exit(1) if missing"
        },
        "DATABASE_URL": {  # REST API module-init check (server.ts:24-25)
            "file": "source/backend/rest-api/src/server.ts",
            "line": "24-25",
            "component": "REST API",
            "reason": "ensureRequiredEnv() called at module init; exit(1) if missing"
        },
    }
    
    # Check for missing REQUIRED vars (strict STOP behavior)
    missing_required = {var: info for var, info in REQUIRED_VARS.items() if var not in present}
    
    gate_summary = {
        "timestamp": ts,
        "required_vars_check": "PASS" if not missing_required else "FAIL",
        "optional_vars_missing": len(missing) - len(missing_required),
        "components": {
            "firebase_functions": "READY" if "QR_TOKEN_SECRET" in present else "BLOCKED",
            "rest_api": "READY" if ("JWT_SECRET" in present and "DATABASE_URL" in present) else "BLOCKED",
        },
    }
    
    if missing_required:
        # STRICT STOP: Create blocker and fail gate
        blocker_lines = [
            "# CRITICAL: REQUIRED Environment Variables Missing",
            "",
            "The following REQUIRED environment variables are missing.",
            "These are enforced at module initialization and will cause startup failure.",
            "",
        ]
        
        for var in sorted(missing_required.keys()):
            info = REQUIRED_VARS[var]
            blocker_lines.extend([
                f"## {var}",
                f"",
                f"**Component:** {info['component']}",
                f"**Evidence:** {info['file']}:{info['line']}",
                f"**Reason:** {info['reason']}",
                f"",
                f"**Error:** Missing from environment.",
                f"",
            ])
        
        blocker_lines.extend([
            "## Resolution",
            "",
            "1. For QR_TOKEN_SECRET:",
            "   - Ensure source/backend/firebase-functions/.env.local exists",
            "   - Run: npm run build (in firebase-functions/)",
            "",
            "2. For JWT_SECRET and DATABASE_URL (REST API):",
            "   - Set these in your deployment environment",
            "   - Ensure source/backend/rest-api/.env or deployment config contains these vars",
            "",
            "3. Retry staging gate:",
            "   python3 tools/gates/staging_gate_runner.py",
            "",
            "---",
            "",
            "See REQUIRED_ENVS.md for complete evidence-based analysis.",
        ])
        
        write_text(OUTPUT_DIR / "BLOCKER.md", "\n".join(blocker_lines))
        write_text(OUTPUT_DIR / "FINAL_GATE.txt", "FAIL: MISSING_REQUIRED_ENV_VARS")
        write_json(OUTPUT_DIR / "GATE_SUMMARY.json", gate_summary)
        
        log("❌ GATE FAILURE: Required environment variables missing.")
        for var in sorted(missing_required.keys()):
            log(f"   ❌ {var} ({REQUIRED_VARS[var]['component']})")
        log("")
        log("See BLOCKER.md for resolution steps.")
        log(f"Artifacts: {OUTPUT_DIR}/")
        return
    
    # All REQUIRED vars present; note optional vars
    if missing:
        info_lines = [
            "# Optional Environment Variables (Non-Critical for Staging Gate)",
            "",
            "The following optional environment variables are missing.",
            "These are NOT checked at module initialization and have graceful fallbacks.",
            "",
            "Missing variables:",
            "",
        ] + [f"- {name}" for name in sorted(missing.keys())]
        
        info_lines.extend([
            "",
            "See REQUIRED_ENVS.md for details on why these are optional.",
            "Artifacts written to local-ci/verification/staging_gate/LATEST/.",
        ])
        write_text(OUTPUT_DIR / "OPTIONAL_VARS_MISSING.md", "\n".join(info_lines))
    
    # All REQUIRED vars present: gate PASS
    write_json(OUTPUT_DIR / "GATE_SUMMARY.json", gate_summary)
    write_text(OUTPUT_DIR / "FINAL_GATE.txt", "PASS: ALL_REQUIRED_ENVS_SET")
    log("✓ Staging gate PASS: All required environment variables are set.")
    log("✓ Firebase Functions + REST API are ready for deployment.")
    if missing:
        log(f"⚠ Note: {len(missing)} optional env vars missing (non-blocking)")



if __name__ == "__main__":
    main()
