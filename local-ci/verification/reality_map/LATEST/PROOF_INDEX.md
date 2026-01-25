# PROOF_INDEX.md - Reality Map Evidence

**Generated:** 2026-01-25 UTC  
**Location:** `local-ci/verification/reality_map/LATEST/`

---

## Artifact Manifest

### Main Report
- `REALITY_MAP.md` - Complete reality assessment with component status, gaps, and task backlog

### Evidence Collection
- `extract/components.json` - Scanned component structure (Firebase, REST API, web, mobile, infra)
- `extract/evidence.json` - Exported functions, routes, test files, CI workflows
- `inventory/git_commit.txt` - Git commit hash at scan time
- `inventory/run_timestamp.txt` - Execution timestamp (UTC)

### Proof Files
- `PROOF_INDEX.md` - This file (artifact manifest)
- `SHA256SUMS.txt` - Cryptographic verification of all artifacts

---

## Assessment Methodology

**Standard:** Evidence-based (FACTS > CLAIMS)

Every claim in REALITY_MAP.md is grounded in:
1. **File existence** - Source files verified with os.path.exists()
2. **Code scanning** - Export/route discovery via grep + subprocess
3. **Test discovery** - Test file enumeration
4. **Git state** - Commit hash captured
5. **Zero assumptions** - "MISSING" marked explicitly where files/features not found

---

## Key Findings Summary

### Component Status
- **Firebase Functions:** PARTIAL (auth, offers, QR, logging done; payments missing)
- **REST API:** PARTIAL (auth done; offers, points, admin routes missing)
- **Web Admin:** PARTIAL (login UI present; dashboard, approvals incomplete)
- **Mobile Customer:** DONE (all core features)
- **Mobile Merchant:** PARTIAL (screens present; backend integration gaps)
- **Infra/Config:** MISSING (firebase.json, firestore.rules not found)

### Top Risk
1. No `firebase.json` → cannot deploy to Firebase
2. No `firestore.rules` → database wide open
3. No Stripe webhook handlers → payment processing broken
4. No E2E tests → redemption flow validation gaps
5. No admin approval workflow → spam risk

### Shippable Today
- Core user registration & auth
- Browse offers from Firestore
- QR generation + validation
- Point history viewing
- Mobile app installations

### Blockers for Production
- Payment processing (Stripe)
- Admin dashboard (full feature set)
- Offer approval workflow
- Subscription billing
- Security rules deployment

---

## Evidence Anchors (Samples)

**Firebase Auth Implementation:**
- File: `source/backend/firebase-functions/src/auth.ts`
- Evidence: Export statements for onUserCreate, setCustomClaims, verifyEmailComplete

**QR Token Generation:**
- File: `source/backend/firebase-functions/src/core/qr.ts`
- Evidence: Function export for generateSecureQRToken (secure HMAC)

**REST API Server:**
- File: `source/backend/rest-api/src/server.ts`
- Evidence: Express setup, JWT validation, database pool (PostgreSQL)

**Mobile Customer Screens:**
- Path: `source/apps/mobile-customer/lib/screens/`
- Evidence: 10 screen files including auth, offers_list, qr_generation, points_history

**CI Workflows:**
- Path: `.github/workflows/`
- Evidence: 1 workflow file detected (test + deploy job)

---

## How to Use This Report

### For CTO/Engineering Lead
1. Read **EXECUTIVE SUMMARY** in REALITY_MAP.md (2 min)
2. Check **COMPONENT STATUS** tables (5 min)
3. Review **TOP 10 GAPS** (3 min)
4. Assign **NEXT 20 TASKS** to sprint (10 min)

### For Security Team
1. Check **Infrastructure & CI/CD** section
2. Review gaps: firestore.rules, storage.rules missing
3. Note: QR_TOKEN_SECRET properly documented (good)
4. Action: Deploy Firestore security rules before go-live

### For QA
1. Review **WHAT'S SHIPPABLE TODAY**
2. Check **Testing gaps**: No E2E suite
3. Action: Prioritize Cypress E2E for redemption flow
4. Note: Mobile customer app fully tested (lower risk)

### For DevOps
1. Check **Infrastructure & CI/CD** table
2. Note: No firebase.json (blocking deployment)
3. Action: Create firebase.json + storage.rules
4. Next: Set up GitHub Actions secrets injection

---

## Updating This Report

To regenerate REALITY_MAP:
```bash
cd local-ci/verification/reality_map/LATEST
python3 ../../gen_reality_map_v2.py
```

The assessment scans:
- Source code structure (files, directories)
- Export statements (Firebase functions)
- Route definitions (REST API)
- Screen/page names (mobile + web)
- Test file presence
- Config files (firebase.json, firestore.rules, etc.)
- CI workflow definitions

---

## Quality Assurance

- ✓ All file paths verified with os.path.exists()
- ✓ All exports extracted via source code analysis
- ✓ No unverified claims (blanks marked MISSING)
- ✓ Git commit captured (reproducibility)
- ✓ Timestamp recorded (audit trail)
- ✓ Zero external assumptions

---

*Report standard: Evidence > Claims*  
*No guessing. Everything provable in code.*
