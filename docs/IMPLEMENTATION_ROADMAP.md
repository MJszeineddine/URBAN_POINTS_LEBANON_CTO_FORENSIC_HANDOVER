# Full-Stack Implementation Roadmap (Evidence-Only)

Status: Strict CTO rule → FULL-STACK: NO (0 journey packs)
Scope: Customer app (Flutter), Merchant app (Flutter), Web Admin (Next.js), Backend (Firebase Functions + REST API)

## Phases

### 1) Environment Prerequisites
- Firebase: add firebase.json + emulator configs (auth, firestore, functions)
- Playwright: ensure browsers installed (`npx playwright install`)
- Flutter: install SDK, set device/emulator, enable integration_test
- Node: install 18/20, pnpm/npm setup per projects
- Evidence to produce:
  - local-ci/verification/roadmap_evidence/env_prereqs.log

### 2) Backend Emulator Proof
- Configure emulator: add firebase.json in repo root or functions dir
- Run: tools/e2e/e2e_backend_emulator_proof.sh
- Expected artifacts:
  - local-ci/verification/e2e_proof_pack/backend_emulator/VERDICT.json
  - local-ci/verification/e2e_proof_pack/backend_emulator/RUN.log
- Acceptance: VERDICT → PASS (not BLOCKED)

### 3) Web Admin E2E Proof (Playwright)
- Confirm project scripts in source/apps/web-admin/package.json
- Install deps, run Playwright:
  - tools/e2e/e2e_web_admin_playwright_proof.sh
- Artifacts:
  - local-ci/verification/e2e_proof_pack/web_admin/VERDICT.json
  - local-ci/verification/e2e_proof_pack/web_admin/playwright.log
- Acceptance: VERDICT → PASS (journey script runs)

### 4) Mobile Integration Proofs
- Customer: tools/e2e/e2e_mobile_customer_integration_proof.sh
- Merchant: tools/e2e/e2e_mobile_merchant_integration_proof.sh
- Requirements: physical device or emulator configured
- Artifacts:
  - local-ci/verification/e2e_proof_pack/mobile_customer/VERDICT.json
  - local-ci/verification/e2e_proof_pack/mobile_merchant/VERDICT.json
- Acceptance: each → PASS

### 5) Real E2E Journey Packs (>=5)
- For each scenario, produce a pack:
  - RUN.log (timestamps, steps)
  - UI evidence (screenshots or video)
  - manifest.json (sha256 of all artifacts)
  - verdict.json (GO/NO-GO per scenario)
- Path convention:
  - local-ci/verification/e2e_journeys/<scenario_name>/<artifact>
- Acceptance: journey_proofs_valid_count ≥ 5

### 6) Clone Parity Recompute
- Re-run clone parity tools to update metrics
- Evidence:
  - local-ci/verification/clone_parity/VERDICT.json
  - local-ci/verification/clone_parity/RUN.log

### 7) Full-Stack Gate Re-run
- Run: tools/gates/full_stack_gate.sh
- Evidence:
  - local-ci/verification/full_stack_gate/VERDICT.json
  - local-ci/verification/full_stack_gate/RUN.log
- Acceptance: CTO rule satisfied → FULL-STACK: YES

## Acceptance Criteria Summary
- Backend emulator: PASS
- Web admin Playwright: PASS
- Mobile integration proofs: PASS x2
- Journey packs: ≥5 with required artifacts
- Full-stack gate: YES

## Notes
- All outputs must be deterministic and written under local-ci/verification/*
- Do not assume values; tie every claim to an artifact
