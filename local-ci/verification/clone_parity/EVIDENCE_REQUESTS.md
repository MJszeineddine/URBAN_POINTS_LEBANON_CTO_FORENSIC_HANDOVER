Evidence Requests — Exact Proofs Needed

Requested Proofs
1) Customer redemption journey: Open app → show code → redeem → confirm success. Expected: local-ci/verification/e2e_proof_pack/flow_proof_customer_qr.md
2) Merchant approval journey: Create offer → submit → approve → visible as active. Expected: local-ci/verification/e2e_proof_pack/flow_proof_merchant_approve.md
3) Subscription access journey: Attempt access without subscription → denied; with subscription → allowed. Expected: local-ci/verification/e2e_proof_pack/flow_proof_subscription_gate.md
4) Phone code sign-in: Enter phone → receive code → verify → signed in. Expected: local-ci/verification/e2e_proof_pack/flow_proof_phone_code_login.md
5) Bilingual experience: Arabic and English screens recorded. Expected: local-ci/verification/e2e_proof_pack/flow_proof_bilingual.md
6) Nearby-first ordering: Offers listed with nearby-first behavior recorded. Expected: local-ci/verification/e2e_proof_pack/flow_proof_location_priority.md
7) Push message delivery: Create and deliver a message; user sees it. Expected: local-ci/verification/e2e_proof_pack/flow_proof_push_delivery.md

How to Capture (use existing scripts when possible)
- Run: tools/e2e/run_e2e_proof_pack_v2.sh
- Store each proof as a short markdown file under local-ci/verification/e2e_proof_pack/ with a timestamp, steps taken, and outcome.
- Include any logs or screenshots as files in the same folder.

Expected Output Paths
- local-ci/verification/e2e_proof_pack/flow_proof_customer_qr.md
- local-ci/verification/e2e_proof_pack/flow_proof_merchant_approve.md
- local-ci/verification/e2e_proof_pack/flow_proof_subscription_gate.md
- local-ci/verification/e2e_proof_pack/flow_proof_phone_code_login.md
- local-ci/verification/e2e_proof_pack/flow_proof_bilingual.md
- local-ci/verification/e2e_proof_pack/flow_proof_location_priority.md
- local-ci/verification/e2e_proof_pack/flow_proof_push_delivery.md