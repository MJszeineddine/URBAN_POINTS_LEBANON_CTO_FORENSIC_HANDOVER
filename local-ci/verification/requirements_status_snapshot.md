# Requirements Status Snapshot

- Totals: READY=11, PARTIAL=2, BLOCKED=3
- READY: UP-FS-001 auth, UP-FS-003 points, UP-FS-004 offers, UP-FS-005 compliance_reporting, UP-FS-007 maintenance_jobs, UP-FS-010 customer_app, UP-FS-011 merchant_app, UP-FS-012 admin_portal, UP-FS-013 firestore_rules, UP-FS-014 firestore_indexes, UP-FS-015 firebase_project
- PARTIAL: UP-FS-002 qr_redemption, UP-FS-006 notifications
- BLOCKED: UP-FS-008 payments_stripe, UP-FS-009 legacy_rest_api, UP-FS-016 observability_release
- Blockers: 
  - UP-FS-008: Missing STRIPE_ENABLED=1, sk_live_* secret key, webhook secret; see [BLOCKER_UP-FS-008.md](BLOCKER_UP-FS-008.md)
  - UP-FS-009: Postgres schema (tables, stored functions) not in repo; see [BLOCKER_UP-FS-009.md](BLOCKER_UP-FS-009.md)
  - UP-FS-016: No structured logging, monitoring dashboards, CI/CD pipeline; see [BLOCKER_UP-FS-016.md](BLOCKER_UP-FS-016.md)
- Phase B Actions Completed:
  - Admin portal moderation now uses secure callables (adminUpdateUserRole, adminBanUser, adminUpdateMerchantStatus, adminDisableOffer) with admin doc checks
  - Firestore rules rewritten to cover users, merchants, offers, redemptions, audit_logs, idempotency_keys, points_expiry_events, and other server-only collections
  - Full stack gate run logged to [local-ci/verification/full_stack_gate_run.log](local-ci/verification/full_stack_gate_run.log)
  - Blocker files created documenting unblock actions for Stripe, REST API, and observability
- Source spec: [spec/requirements.yaml](spec/requirements.yaml)
