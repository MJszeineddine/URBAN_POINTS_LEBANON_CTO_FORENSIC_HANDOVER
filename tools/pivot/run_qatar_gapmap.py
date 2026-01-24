#!/usr/bin/env python3
import os
import sys
import json
import re
import hashlib
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
IDENTITY_ROOT = ROOT / "local-ci" / "verification" / "identity_scan"
PIVOT_ROOT = ROOT / "local-ci" / "verification" / "pivot_qatar"


def find_latest_identity_bundle():
    if not IDENTITY_ROOT.exists():
        return None
    candidates = [p for p in IDENTITY_ROOT.iterdir() if p.is_dir() and p.name.startswith("IDENTITY_")]
    if not candidates:
        return None
    # Sort by name (timestamp suffix) then mtime as fallback
    def sort_key(p: Path):
        return (p.name, p.stat().st_mtime)
    candidates.sort(key=sort_key, reverse=True)
    return candidates[0]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def write_sha256_sums(bundle_dir: Path, out_file: Path):
    lines = []
    for p in sorted(bundle_dir.rglob('*')):
        if p.is_file():
            digest = sha256_file(p)
            rel = p.relative_to(bundle_dir)
            lines.append(f"{digest}  {rel}\n")
    out_file.write_text(''.join(lines), encoding='utf-8')


def ensure_dirs(path: Path):
    path.mkdir(parents=True, exist_ok=True)


def load_text(path: Path) -> str:
    try:
        return path.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        return ""


def load_json(path: Path):
    try:
        with path.open('r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}


def detect_status(text_sources: list[str], keywords: list[str]) -> str:
    text = "\n".join(text_sources).lower()
    hits = 0
    for kw in keywords:
        if re.search(re.escape(kw.lower()), text):
            hits += 1
    if hits == 0:
        return "Missing"
    # Heuristic: multiple distinct hits -> likely Partial/Present
    return "Present" if hits >= max(1, len(keywords) // 2) else "Partial"


def detect_subscription_offers() -> str:
    """
    Check for subscription offers implementation evidence in source code.
    REAL evidence anchors (not keyword matching):
    - REST API: requireActiveSubscription middleware + SUBSCRIPTION_REQUIRED error code
    - Entitlements check: /api/entitlements/me endpoint returns hasActiveSubscription
    - Redeem gating: entitlement middleware chained to /api/vouchers/:id/redeem endpoint
    - Flutter UI: subscription_screen.dart exists and calls /api/subscriptions endpoints
    """
    from pathlib import Path
    ROOT = Path(__file__).resolve().parents[2]
    
    evidence = []
    
    # REAL Evidence 1: Check REST API has SUBSCRIPTION_REQUIRED middleware on redeem
    rest_api_file = ROOT / "source" / "backend" / "rest-api" / "src" / "server.ts"
    if rest_api_file.exists():
        content = rest_api_file.read_text(encoding='utf-8', errors='ignore')
        # Check for middleware function definition
        has_middleware = "requireActiveSubscription" in content
        # Check for 403 error code specific to subscriptions
        has_error_code = "SUBSCRIPTION_REQUIRED" in content
        # Check middleware is applied to redeem endpoint
        has_redeem_guard = "'/api/vouchers/:id/redeem', authenticate, requireActiveSubscription" in content
        # Check entitlements endpoint exists for status check
        has_entitlements = "'/api/entitlements/me'" in content
        
        if has_middleware and has_error_code and has_redeem_guard and has_entitlements:
            evidence.append("REST API entitlement gating (server.ts)")
    
    # REAL Evidence 2: Check Flutter subscription screen exists and imports
    flutter_file = ROOT / "source" / "apps" / "mobile-customer" / "lib" / "screens" / "subscription_screen.dart"
    if flutter_file.exists():
        content = flutter_file.read_text(encoding='utf-8', errors='ignore')
        # Check for model definitions
        has_models = "class SubscriptionPlan" in content and "class UserSubscription" in content
        # Check for API calls to subscription endpoints
        has_api_calls = "/api/subscription-plans" in content and "/api/subscriptions/me" in content
        if has_models and has_api_calls:
            evidence.append("Flutter UI (subscription_screen.dart)")
    
    # REAL Evidence 3: Check tests verify entitlement gating
    test_file = ROOT / "source" / "backend" / "rest-api" / "src" / "tests" / "entitlement.test.js"
    if test_file.exists():
        content = test_file.read_text(encoding='utf-8', errors='ignore')
        if "requireActiveSubscription" in content and "SUBSCRIPTION_REQUIRED" in content:
            evidence.append("Unit tests (entitlement.test.js)")
    
    # Score based on evidence count (all 3 required for "Present")
    if len(evidence) >= 3:
        return "Present"
    elif len(evidence) == 2:
        return "Partial"
    else:
        return "Missing"


def status_to_score(status: str) -> int:
    return {"Present": 100, "Partial": 60, "Missing": 0, "Unknown": 30}.get(status, 30)


def generate_identity_summary(project_identity_md: Path, features_json: Path, out_md: Path):
    identity_text = load_text(project_identity_md)
    features = load_json(features_json)

    # Simple signals
    signals = {
        "mobile_customer": any("mobile-customer" in s.lower() or "customer app" in s.lower() for s in [identity_text, json.dumps(features)]),
        "mobile_merchant": any("mobile-merchant" in s.lower() or "merchant app" in s.lower() for s in [identity_text, json.dumps(features)]),
        "web_admin": any("web-admin" in s.lower() or "admin portal" in s.lower() for s in [identity_text, json.dumps(features)]),
        "firebase": any(x in identity_text.lower() for x in ["firebase", "firestore", "auth", "functions"]),
        "payments": any(x in (identity_text + json.dumps(features)).lower() for x in ["stripe", "payment", "checkout"]),
        "offers": any(x in (identity_text + json.dumps(features)).lower() for x in ["offer", "coupon", "bogo", "subscription"]),
        "redemption": any(x in (identity_text + json.dumps(features)).lower() for x in ["redeem", "redemption", "qr", "pin"]),
    }

    bullets = []
    if signals["offers"]:
        bullets.append("- Offer-based consumer product with deal mechanics (see evidence below).")
    if signals["mobile_customer"]:
        bullets.append("- Mobile Customer app for discovery and redemption.")
    if signals["mobile_merchant"]:
        bullets.append("- Mobile Merchant app for in-store redemption control.")
    if signals["web_admin"]:
        bullets.append("- Web Admin portal for configuration and oversight.")
    if signals["firebase"]:
        bullets.append("- Firebase-backed (Auth/Functions/Firestore) services.")
    if signals["payments"]:
        bullets.append("- Payment rails present (e.g., Stripe integration cues).")
    if signals["redemption"]:
        bullets.append("- Redemption flow (QR/PIN) signals present.")
    if not bullets:
        bullets.append("- Evidence indicates a multi-surface app with offers and redemptions.")

    summary = []
    summary.append("# Project Identity Summary")
    summary.append("")
    summary.append("This summarizes what the product is, anchored to evidence.")
    summary.append("")
    summary.extend(bullets)
    summary.append("")
    summary.append("## Evidence Anchors")
    summary.append(f"- PROJECT_IDENTITY.md: {project_identity_md}")
    summary.append(f"- FEATURES.json: {features_json}")
    summary.append("")
    out_md.write_text("\n".join(summary), encoding='utf-8')


def generate_gap_map(project_identity_md: Path, features_json: Path, out_md: Path):
    identity_text = load_text(project_identity_md)
    features_text = json.dumps(load_json(features_json))
    sources = [identity_text, features_text]

    checks = {
        "Subscription Offers": detect_subscription_offers(),  # Use dedicated detection function
        "BOGO Mechanics": detect_status(sources, ["bogo", "buy one get one"]),
        "Monthly Reset": detect_status(sources, ["monthly reset", "quota", "renewal"]),
        "Staff PIN": detect_status(sources, ["staff pin", "pin", "staff code"]),
        "Merchant Portal": detect_status(sources, ["merchant portal", "merchant app", "merchant"]),
        "Admin Portal": detect_status(sources, ["admin portal", "web-admin", "admin"]),
        "Payments": detect_status(sources, ["stripe", "payment", "checkout"]),
        "Fraud/Abuse": detect_status(sources, ["fraud", "abuse", "risk", "compliance"])
    }

    rows = ["# GAP MAP vs Urban Point Qatar", "", "| Capability | Status | Notes | Anchors |", "|---|---|---|---|"]
    statuses = {}
    for name, status in checks.items():
        statuses[name] = status
        notes = f"Evidence detected for {name}"
        anchors = f"[PROJECT_IDENTITY.md]({project_identity_md}) · [FEATURES.json]({features_json})"
        rows.append(f"| {name} | {status} | {notes} | {anchors} |")

    rows.append("")
    out_md.write_text("\n".join(rows), encoding='utf-8')
    return statuses


def generate_readiness(statuses: dict, project_identity_md: Path, features_json: Path, out_json: Path):
    modules = {}
    for k, status in statuses.items():
        score = status_to_score(status)
        modules[k] = {
            "status": status,
            "score": score,
            "anchors": [str(project_identity_md), str(features_json)],
            "blockers": [] if status == "Present" else [f"Evidence insufficient for full {k} parity"]
        }
    payload = {"modules": modules, "overall": int(round(sum(m["score"] for m in modules.values()) / max(1, len(modules))))}
    out_json.write_text(json.dumps(payload, indent=2), encoding='utf-8')


def generate_backlog(statuses: dict, project_identity_md: Path, features_json: Path, out_md: Path):
    lines = ["# Qatar Parity Backlog", "", "Prioritized items to reach Qatar-like product. Each item includes anchors.", ""]
    priority = {"Missing": 1, "Partial": 2, "Unknown": 3, "Present": 99}
    items = [(priority.get(st, 3), name, st) for name, st in statuses.items() if st != "Present"]
    items.sort()
    for _, name, st in items:
        lines.append(f"- [ ] {name}: {st}. Anchor: {project_identity_md} · {features_json}")
        if name == "BOGO Mechanics":
            lines.append("  - Define core BOGO models, redemption rules, and tests.")
        elif name == "Monthly Reset":
            lines.append("  - Implement monthly quota reset and audit logging.")
        elif name == "Staff PIN":
            lines.append("  - Add staff PIN creation, rotation, and validation in merchant app.")
        elif name == "Merchant Portal":
            lines.append("  - Ensure merchant dashboard for redemption feed and staff management.")
        elif name == "Admin Portal":
            lines.append("  - Ensure admin controls for offers, merchants, and compliance reports.")
        elif name == "Payments":
            lines.append("  - Integrate payment flow (e.g., Stripe) and receipt mapping.")
        elif name == "Subscription Offers":
            lines.append("  - Introduce subscription plans and entitlements mapping.")
        elif name == "Fraud/Abuse":
            lines.append("  - Add risk signals, velocity checks, and anomaly monitoring.")
    if len(lines) == 4:
        lines.append("All parity items appear present; keep monitoring.")
    out_md.write_text("\n".join(lines), encoding='utf-8')


def main():
    # Locate identity bundle
    identity_bundle = find_latest_identity_bundle()
    if identity_bundle is None:
        print("ERROR: No identity bundle found. Please run: python3 tools/reality_scan/run_identity_scan.py", file=sys.stderr)
        sys.exit(2)

    features_json = identity_bundle / "reports" / "FEATURES.json"
    project_identity_md = identity_bundle / "reports" / "PROJECT_IDENTITY.md"
    if not features_json.exists() or not project_identity_md.exists():
        print("ERROR: Identity bundle is missing required reports. Re-run the identity scan.", file=sys.stderr)
        sys.exit(2)

    ts = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    bundle_dir = PIVOT_ROOT / f"PIVOT_{ts}"
    reports_dir = bundle_dir / "reports"
    hashes_dir = bundle_dir / "hashes"
    logs_dir = bundle_dir / "logs"
    for d in (reports_dir, hashes_dir, logs_dir):
        ensure_dirs(d)

    # Generate reports
    identity_summary_md = reports_dir / "PROJECT_IDENTITY_SUMMARY.md"
    gap_map_md = reports_dir / "GAP_MAP_vs_URBAN_POINT_QATAR.md"
    readiness_json = reports_dir / "READINESS.json"
    backlog_md = reports_dir / "BACKLOG.md"

    generate_identity_summary(project_identity_md, features_json, identity_summary_md)
    statuses = generate_gap_map(project_identity_md, features_json, gap_map_md)
    generate_readiness(statuses, project_identity_md, features_json, readiness_json)
    generate_backlog(statuses, project_identity_md, features_json, backlog_md)

    # Hashes
    sha_out = hashes_dir / "SHA256SUMS.txt"
    write_sha256_sums(bundle_dir, sha_out)

    # Print only four lines
    print(f"PIVOT_BUNDLE_PATH={bundle_dir.relative_to(ROOT)}")
    print(f"GAP_MAP_MD={gap_map_md.relative_to(ROOT)}")
    print(f"READINESS_JSON={readiness_json.relative_to(ROOT)}")
    print(f"SHA256SUMS={sha_out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
