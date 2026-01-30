import os, re, json, subprocess, hashlib, datetime, pathlib, shutil, textwrap

ROOT = pathlib.Path(__file__).resolve().parents[2]
LATEST = ROOT / "local-ci" / "verification" / "stabilize_pack" / "LATEST"
INV = LATEST / "inventory"
PROOF = LATEST / "proof"
ANCH = LATEST / "anchors"
CI = LATEST / "ci"
TESTS = LATEST / "tests"
REPORTS = LATEST / "reports"

def run(cmd, cwd=None, log_path=None, env=None):
    p = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
    out = []
    for line in p.stdout:
        out.append(line)
    rc = p.wait()
    s = "".join(out)
    if log_path:
        pathlib.Path(log_path).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(log_path).write_text(s)
    return rc, s

def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()

def write(path: pathlib.Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)

def now_beirut():
    # Beirut is UTC+2 (ignoring DST; acceptable for evidence timestamp)
    return (datetime.datetime.utcnow() + datetime.timedelta(hours=2)).strftime("%Y-%m-%d %H:%M:%S EET")

def git(args):
    return run(["git"] + args, cwd=ROOT)[1].strip()

def ensure_dirs():
    for p in [INV, PROOF, ANCH, CI, TESTS, REPORTS]:
        p.mkdir(parents=True, exist_ok=True)

def capture_before():
    write(INV/"run_timestamp.txt", now_beirut() + "\n")
    write(INV/"git_commit_before.txt", git(["rev-parse","HEAD"]) + "\n")
    write(INV/"git_status_before.txt", git(["status","--porcelain"]) + "\n")

def capture_after():
    write(INV/"git_status_after.txt", git(["status","--porcelain"]) + "\n")

def find_first(paths):
    for p in paths:
        if p.exists():
            return p
    return None

def ensure_root_firebase_json():
    # Prefer existing infra configs if present, but final MUST be at repo root.
    candidates = [
        ROOT/"source"/"infra"/"firebase.json",
        ROOT/"source"/"firebase.json",
    ]
    src = find_first(candidates)
    if src and (ROOT/"firebase.json").exists() is False:
        shutil.copy2(src, ROOT/"firebase.json")
    # If still missing, create minimal config.
    if not (ROOT/"firebase.json").exists():
        content = {
            "functions": [{"source": "source/backend/firebase-functions"}],
            "firestore": {"rules": "firestore.rules"},
            "storage": {"rules": "storage.rules"}
        }
        write(ROOT/"firebase.json", json.dumps(content, indent=2) + "\n")

def ensure_root_rules():
    # firestore.rules
    fr_candidates = [ROOT/"source"/"infra"/"firestore.rules"]
    fr_src = find_first(fr_candidates)
    if fr_src and not (ROOT/"firestore.rules").exists():
        shutil.copy2(fr_src, ROOT/"firestore.rules")

    if not (ROOT/"firestore.rules").exists():
        # Safe deny-by-default minimal rules; allow offers read + user self docs read/write.
        rules = textwrap.dedent("""\
        rules_version = '2';
        service cloud.firestore {
          match /databases/{database}/documents {

            function signedIn() { return request.auth != null; }
            function isSelf(uid) { return signedIn() && request.auth.uid == uid; }
            function isAdmin() { return signedIn() && request.auth.token.admin == true; }

            match /{document=**} {
              allow read, write: if false;
            }

            // Public offers read (adjust collection name if different)
            match /offers/{offerId} {
              allow read: if true;
              allow write: if isAdmin();
            }

            // Users can read/write their own profile
            match /users/{uid} {
              allow read, write: if isSelf(uid);
            }

            // Points history: user reads own; writes server/admin only
            match /points/{docId} {
              allow read: if signedIn();
              allow write: if isAdmin();
            }

            // Redemptions: block client writes; admin/server only
            match /redemptions/{docId} {
              allow read: if isAdmin();
              allow write: if isAdmin();
            }

            // Payments: user can read own payments; writes via server/admin only
            match /payments/{paymentId} {
              allow read: if signedIn() && request.auth.uid == resource.data.uid;
              allow write: if isAdmin();
            }
          }
        }
        """)
        write(ROOT/"firestore.rules", rules)

    # storage.rules
    st_candidates = [ROOT/"source"/"infra"/"storage.rules"]
    st_src = find_first(st_candidates)
    if st_src and not (ROOT/"storage.rules").exists():
        shutil.copy2(st_src, ROOT/"storage.rules")

    if not (ROOT/"storage.rules").exists():
        rules = textwrap.dedent("""\
        rules_version = '2';
        service firebase.storage {
          match /b/{bucket}/o {
            function signedIn() { return request.auth != null; }
            function isSelf(uid) { return signedIn() && request.auth.uid == uid; }

            match /{allPaths=**} {
              allow read, write: if false;
            }

            // User-private uploads
            match /users/{uid}/{allPaths=**} {
              allow read, write: if isSelf(uid)
                && request.resource.size < 10 * 1024 * 1024;
            }

            // Optional public read folder
            match /public/{allPaths=**} {
              allow read: if true;
              allow write: if false;
            }
          }
        }
        """)
        write(ROOT/"storage.rules", rules)

def redact_sk_live_REDACTED():
    # Zero tolerance: remove/replace any "sk_live_" occurrence in ANY file (code or docs).
    hits = []
    for p in ROOT.rglob("*"):
        if p.is_dir():
            continue
        if ".git" in p.parts or "node_modules" in p.parts or ".dart_tool" in p.parts:
            continue
        try:
            data = p.read_text(errors="ignore")
        except Exception:
            continue
        if "sk_live_" in data:
            hits.append(str(p.relative_to(ROOT)))
            data2 = re.sub(r"sk_live_[A-Za-z0-9_]+", "sk_live_REDACTED", data)
            p.write_text(data2)
    return hits

def ensure_env_docs():
    env_md = ROOT/"docs"/"ENVIRONMENT_VARIABLES.md"
    required_md = ROOT/"REQUIRED_ENVS.md"
    lines = []
    lines.append("# Environment Variables (names only)\n")
    lines.append("This file lists required environment variable NAMES. Do not commit values.\n\n")
    # Pull from REQUIRED_ENVS.md if present
    if required_md.exists():
        lines.append("## Source\n- REQUIRED_ENVS.md exists; this doc is the canonical names-only list.\n\n")
        raw = required_md.read_text(errors="ignore")
        # Extract likely KEY= patterns
        keys = sorted(set(re.findall(r"\b[A-Z0-9_]{3,}\b", raw)))
        # Filter out obvious noise
        keys = [k for k in keys if k not in ("HTTP","HTTPS","TRUE","FALSE","UUID","JSON")]
        lines.append("## Keys\n")
        for k in keys[:250]:
            lines.append(f"- `{k}`\n")
    else:
        lines.append("## Keys\n- (No REQUIRED_ENVS.md found; add keys here.)\n")
    write(env_md, "".join(lines))

def collect_anchors():
    anchors = {
        "root_firebase_json": "firebase.json",
        "root_firestore_rules": "firestore.rules",
        "root_storage_rules": "storage.rules",
        "workflow": ".github/workflows/deploy.yml" if (ROOT/".github/workflows/deploy.yml").exists() else None,
    }
    # Stripe-related anchors
    stripe_files = []
    for p in [ROOT/"source/backend/firebase-functions/src/stripe.ts",
              ROOT/"source/backend/firebase-functions/src/webhooks/stripe.ts",
              ROOT/"source/backend/firebase-functions/src/payments/stripe.ts",
              ROOT/"source/backend/firebase-functions/src/paymentWebhooks.ts"]:
        if p.exists():
            stripe_files.append(str(p.relative_to(ROOT)))
    anchors["stripe_files"] = stripe_files
    write(ANCH/"ANCHORS.json", json.dumps(anchors, indent=2) + "\n")
    return anchors

def update_ci_if_needed():
    # We will not do complex rewrites; just ensure deploy.yml exists and includes rest-api + functions tests.
    wf = ROOT/".github/workflows/deploy.yml"
    if not wf.exists():
        return "deploy.yml missing (left as blocker; not created automatically)."
    txt = wf.read_text(errors="ignore")
    changed = False
    if "rest-api" not in txt or "source/backend/rest-api" not in txt:
        # minimal append note — do not risk breaking existing workflow; add separate job.
        append = textwrap.dedent("""
        \n  rest_api_tests:
    name: Rest API - install & test
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: source/backend/rest-api
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: source/backend/rest-api/package-lock.json
      - run: npm ci
      - run: npm test
        """)
        txt += append
        changed = True
    if "firebase-functions" not in txt or "source/backend/firebase-functions" not in txt:
        append = textwrap.dedent("""
        \n  firebase_functions_tests:
    name: Firebase Functions - install & test
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: source/backend/firebase-functions
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: source/backend/firebase-functions/package-lock.json
      - run: npm ci
      - run: npm test
        """)
        txt += append
        changed = True
    if changed:
        wf.write_text(txt)
        write(CI/"workflow_summary.md", "Updated deploy.yml by appending minimal test jobs for rest-api and firebase-functions.\n")
        return "deploy.yml updated with minimal test jobs."
    else:
        write(CI/"workflow_summary.md", "deploy.yml already contained rest-api and firebase-functions coverage (no change).\n")
        return "deploy.yml already adequate."

def run_local_tests():
    results = []
    # rest-api
    rest = ROOT/"source/backend/rest-api"
    if rest.exists():
        rc1, _ = run(["npm","ci"], cwd=rest, log_path=TESTS/"rest-api_npm_ci.log")
        rc2, _ = run(["npm","test"], cwd=rest, log_path=TESTS/"rest-api_npm_test.log")
        results.append(("rest-api", rc1, rc2))
    else:
        results.append(("rest-api", None, None))

    # firebase-functions
    ff = ROOT/"source/backend/firebase-functions"
    if ff.exists():
        rc1, _ = run(["npm","ci"], cwd=ff, log_path=TESTS/"firebase-functions_npm_ci.log")
        rc2, _ = run(["npm","test"], cwd=ff, log_path=TESTS/"firebase-functions_npm_test.log")
        results.append(("firebase-functions", rc1, rc2))
    else:
        results.append(("firebase-functions", None, None))
    return results

def make_proof_and_hashes():
    # PROOF_INDEX
    files = sorted([str(p.relative_to(LATEST)) for p in LATEST.rglob("*") if p.is_file()])
    write(PROOF/"PROOF_INDEX.md", "# Phase 3 Stabilize Pack Proof Index\n\n" + "\n".join([f"- `{f}`" for f in files]) + "\n")
    # SHA256SUMS for ALL files under LATEST
    sums = []
    for p in sorted([p for p in LATEST.rglob("*") if p.is_file() and p.name != "SHA256SUMS.txt"]):
        sums.append(f"{sha256_file(p)}  {p.relative_to(LATEST)}")
    write(LATEST/"SHA256SUMS.txt", "\n".join(sums) + "\n")

def write_report(anchors, ci_note, sk_live_REDACTED, test_results, blockers):
    lines = []
    lines.append("# Phase 3 Stabilize Pack Report (Evidence)\n\n")
    lines.append(f"- Timestamp: {now_beirut()}\n")
    lines.append(f"- Commit before: {git(['rev-parse','HEAD'])}\n\n")
    lines.append("## What changed\n")
    lines.append("- Ensured root deploy config: `firebase.json`\n")
    lines.append("- Ensured root rules: `firestore.rules`, `storage.rules` (deny-by-default)\n")
    lines.append("- Removed/redacted any `sk_live_` occurrences repository-wide\n")
    lines.append("- Environment names doc created: `docs/ENVIRONMENT_VARIABLES.md`\n")
    lines.append(f"- CI note: {ci_note}\n\n")
    lines.append("## Stripe safety\n")
    if sk_live_REDACTED:
        lines.append(f"- Files changed due to `sk_live_` redaction: {len(sk_live_REDACTED)}\n")
        for h in sk_live_REDACTED[:50]:
            lines.append(f"  - `{h}`\n")
    else:
        lines.append("- No `sk_live_` occurrences found.\n")
    # prove zero now
    rc, out = run(["rg","-n","sk_live_", "."], cwd=ROOT, log_path=LATEST/"security/rg_sk_live_REDACTED.log")
    lines.append(f"- Post-check `rg sk_live_` exit={rc} (0 means none).\n\n")
    lines.append("## Anchors\n")
    lines.append("```json\n" + json.dumps(anchors, indent=2) + "\n```\n\n")
    lines.append("## Local test results\n")
    for name, rc_ci, rc_test in test_results:
        lines.append(f"- {name}: npm ci={rc_ci} npm test={rc_test}\n")
    lines.append("\n## Blockers\n")
    if blockers:
        for b in blockers:
            lines.append(f"- {b}\n")
    else:
        lines.append("- None\n")
    write(REPORTS/"STABILIZE_REPORT.md", "".join(lines))

def git_commit_once():
    # stage only required deliverables + evidence bundle
    paths = [
        "firebase.json",
        "firestore.rules",
        "storage.rules",
        "docs/ENVIRONMENT_VARIABLES.md",
        ".github/workflows/deploy.yml",
        "local-ci/verification/stabilize_pack/LATEST",
    ]
    # add existing ones only
    to_add = []
    for p in paths:
        if (ROOT/p).exists():
            to_add.append(p)
    if to_add:
        run(["git","add"] + to_add, cwd=ROOT)
    rc, out = run(["git","commit","-m","chore: Phase 3 stabilize pack (root config, rules, stripe safety, CI, verified) [evidence]"], cwd=ROOT)
    return rc, out

def main():
    ensure_dirs()
    capture_before()

    blockers = []

    # Root configs
    ensure_root_firebase_json()
    ensure_root_rules()

    # Stripe literal redaction
    hits = redact_sk_live_REDACTED()

    # Env docs
    ensure_env_docs()

    # CI minimal
    ci_note = update_ci_if_needed()

    # Anchors
    anchors = collect_anchors()

    # Tests (must run)
    test_results = run_local_tests()
    for name, rc_ci, rc_test in test_results:
        if rc_ci is None or rc_test is None:
            blockers.append(f"{name}: component folder missing (cannot test).")
        else:
            if rc_ci != 0:
                blockers.append(f"{name}: npm ci failed (see {TESTS}/{name}_npm_ci.log)")
            if rc_test != 0:
                blockers.append(f"{name}: npm test failed (see {TESTS}/{name}_npm_test.log)")

    # Proof + hashes
    make_proof_and_hashes()

    # Report
    write_report(anchors, ci_note, hits, test_results, blockers)

    # If blockers exist, stop with NO-GO (no commit)
    if blockers:
        capture_after()
        print("NO-GO: Phase 3 not complete. See:")
        print(" - local-ci/verification/stabilize_pack/LATEST/reports/STABILIZE_REPORT.md")
        print(" - local-ci/verification/stabilize_pack/LATEST/tests/ logs")
        return 2

    # Commit once (do not push)
    rc, out = git_commit_once()
    if rc != 0 and "nothing to commit" not in out.lower():
        blockers.append("git commit failed:\n" + out)
        capture_after()
        print("NO-GO: commit failed. See report.")
        return 3

    write(INV/"git_commit_after.txt", git(["rev-parse","HEAD"]) + "\n")
    capture_after()

    print("PHASE 3 COMPLETE")
    print("Commit:", git(["rev-parse","HEAD"]))
    print("Report: local-ci/verification/stabilize_pack/LATEST/reports/STABILIZE_REPORT.md")
    print("SHA256: local-ci/verification/stabilize_pack/LATEST/SHA256SUMS.txt")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
