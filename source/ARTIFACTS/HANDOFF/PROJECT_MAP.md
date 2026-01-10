# PROJECT MAP

**Repository**: urbanpoints-lebanon-complete-ecosystem  
**Root**: `/home/user/urbanpoints-lebanon-complete-ecosystem`

## Structure

### Backend
- `backend/firebase-functions/` - Cloud Functions (TypeScript)
  - `src/index.ts` - Main exports
  - `src/core/` - Business logic
  - `src/__tests__/` - Test suites
  - `package.json`

### Mobile Apps (Flutter)
- `apps/mobile-customer/` - Customer app
  - `lib/main.dart`
  - `pubspec.yaml`
- `apps/mobile-merchant/` - Merchant app
  - `lib/main.dart`
  - `pubspec.yaml`
- `apps/mobile-admin/` - Admin app
  - `lib/main.dart`
  - `pubspec.yaml`

### Web Admin
- `apps/web-admin/` - Web admin interface
  - `index.html`
  - `package.json`

### Infrastructure
- `infra/firestore.rules` - Firestore security rules
- `infra/firestore.indexes.json` - Firestore indexes
- `infra/firebase.json` - Firebase config

### Tools
- `tools/fullstack_go_gate.sh` - Full-stack verification gate
- `release_gate.sh` - Release verification

### Evidence (Canonical)
- `ARTIFACTS/FS_GO/FINAL_FULLSTACK_VERDICT.json` - Final verdict
- `ARTIFACTS/FS_GO/EVIDENCE_INDEX.md` - Evidence index
- `ARTIFACTS/FS_GO/logs/` - Gate logs
- `ARTIFACTS/FS_GO/phase*/` - Phase evidence

### Handoff
- `ARTIFACTS/HANDOFF/HANDOFF_INDEX.md` - This handoff guide
- `ARTIFACTS/HANDOFF/PROJECT_MAP.md` - This file
- `ARTIFACTS/HANDOFF/ENVIRONMENT.txt` - Build environment
- `ARTIFACTS/HANDOFF/PROOFS/SUPABASE_ZERO_PROOF.md` - Supabase verification
