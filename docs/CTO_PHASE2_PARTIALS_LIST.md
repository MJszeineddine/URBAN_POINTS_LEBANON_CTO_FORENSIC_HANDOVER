# CTO PHASE 2: PARTIAL Requirements Analysis

**Generated:** 2026-01-16 14:54  
**Source:** local-ci/verification/cto_verify_report_phase2.json  
**Total PARTIAL Failures:** 7

---

## PARTIAL Requirements to Fix

| ID | Component | Current Status | Description | Anchors | Exact Missing Behavior | Fix Plan | Evidence Command(s) |
|----|-----------|----------------|-------------|---------|------------------------|----------|---------------------|
| MERCH-OFFER-004 | mobile-merchant | PARTIAL | Delete Offer | frontend: my_offers_screen.dart:_deleteOffer<br>backend: offers.ts:cancelOfferCallable | Hard delete vs soft delete ambiguity. Currently calls cancelOfferCallable (status=cancelled). Need clarification or implement hard delete. | Verify current behavior is sufficient (soft-delete is standard). If adequate, mark READY. If hard delete needed, implement deleteOffer callable. | `cd source/apps/mobile-merchant && flutter analyze && flutter test` |
| MERCH-PROFILE-001 | mobile-merchant | PARTIAL | Store Profile Management | frontend: merchant_service.dart<br>backend: admin.ts:getMerchantProfile | Missing logo/banner upload UI and business license/document upload for compliance. | Add image picker/uploader for logo/banner. Add document upload for compliance (business license). | `cd source/apps/mobile-merchant && flutter analyze && flutter test` |
| MERCH-REDEEM-004 | mobile-merchant | PARTIAL | Redemption Logs/History | frontend: validate_redemption_screen.dart<br>backend: qr.ts:getRedemptionHistory | Basic list exists. Missing filters (date range, offer), export, or detailed view. | Add date range picker. Add offer filter dropdown. Add CSV export button (or mark as future enhancement). | `cd source/apps/mobile-merchant && flutter analyze && flutter test` |
| MERCH-SUBSCRIPTION-001 | mobile-merchant | PARTIAL | Subscription Status Display | frontend: onboarding_service.dart<br>backend: subscriptionAutomation.ts | Shows plan name, status, expiry date. Missing upgrade/downgrade UI or payment method management. | Add upgrade/downgrade buttons linking to Stripe Customer Portal. Add payment method management UI. | `cd source/apps/mobile-merchant && flutter analyze && flutter test` |
| ADMIN-USER-001 | web-admin | PARTIAL | Users List & Search | frontend: pages/admin/users.tsx | Paginated user list. Search bar only filters loaded results, not full-text search. | Implement backend search endpoint or Algolia integration. OR: document limitation as acceptable (client-side filter sufficient for MVP). | `cd source/apps/web-admin && npm run build && npm test` |
| ADMIN-ANALYTICS-001 | web-admin | PARTIAL | Daily Stats Dashboard | frontend: pages/admin/dashboard.tsx | Dashboard displays daily redemptions, signups, active offers. WARNING: calculateDailyStats contains placeholder mock data. | Replace mock data with real Firestore queries. Ensure all stats are computed from actual collections. | `cd source/apps/web-admin && npm run build && npm test` |
| ADMIN-ANALYTICS-002 | web-admin | PARTIAL | Redemption Audit Logs | frontend: pages/admin/dashboard.tsx<br>backend: admin.ts:getRedemptionStats | Shows redemption list but no detailed audit trail (IP, device, geo coordinates, fraud score). | Add columns for IP, device, geo, fraud score to redemption log display. Ensure backend returns these fields. | `cd source/apps/web-admin && npm run build && npm test` |

---

## Implementation Strategy

### Phase 2A: Merchant App (4 requirements)
1. **MERCH-OFFER-004**: Verify soft-delete is sufficient → Mark READY
2. **MERCH-PROFILE-001**: Add logo/banner upload + document upload
3. **MERCH-REDEEM-004**: Add date/offer filters + export
4. **MERCH-SUBSCRIPTION-001**: Add upgrade/downgrade + payment method management

### Phase 2B: Web Admin (3 requirements)
1. **ADMIN-USER-001**: Implement backend search OR document client-side filter as sufficient
2. **ADMIN-ANALYTICS-001**: Replace mock data with real Firestore queries
3. **ADMIN-ANALYTICS-002**: Add audit trail columns (IP, device, geo, fraud score)

---

## Evidence Requirements

Each requirement must have:
1. ✅ Code implementation (anchors point to real code)
2. ✅ Flutter analyze / npm build passes with 0 errors
3. ✅ Tests pass (or existing test coverage maintained)
4. ✅ Logs captured in local-ci/verification/*_phase2.log

---

## Status Update Protocol

Only update `status: READY` in spec/requirements.yaml when:
- Implementation complete
- Build/analyze passes
- Evidence captured in logs
- Anchors verified

