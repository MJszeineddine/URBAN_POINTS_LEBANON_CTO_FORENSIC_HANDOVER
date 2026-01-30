# BLOCKER — MERCHANT APP FEATURES

**Requirements**:
- MERCH-OFFER-006: Media Upload (Images/Videos)
- MERCH-PROFILE-001: Store Profile Management (logo/banner/documents)
- MERCH-REDEEM-004: Redemption Logs with Filters
- MERCH-REDEEM-005: Anti-Fraud Rate Limiting UI
- MERCH-SUBSCRIPTION-001: Subscription Status & Management
- MERCH-STAFF-001: Staff Account Management

**Status:** BLOCKED  
**Category:** Merchant App Features  

---

## Why BLOCKED

All six merchant app requirements require new UI screens and/or workflows:

### MERCH-OFFER-006: Media Upload
- Image picker integration
- Firebase Storage upload handling
- Progress UI and error handling

### MERCH-PROFILE-001: Store Profile Management
- Logo/banner upload screens
- Document upload for compliance (business license)
- Form validation and error handling

### MERCH-REDEEM-004: Redemption Logs with Filters
- Date range picker
- Offer filter dropdown
- CSV export functionality

### MERCH-REDEEM-005: Anti-Fraud UI
- UI showing fraud warnings
- Merchant able to see rate limiting status
- Integration with backend fraud detection

### MERCH-SUBSCRIPTION-001: Subscription Management
- Upgrade/downgrade UI
- Stripe Customer Portal integration
- Payment method management screens

### MERCH-STAFF-001: Staff Account Management
- New staff screen/form
- Role assignment
- Access control management

These are **substantial UI/UX implementations** requiring Flutter development, user testing, and integration testing.

## Next Steps

1. Design UI/UX for each feature
2. Implement screens and forms in Flutter
3. Add form validation
4. Integrate with backend callables
5. Test end-to-end workflows
6. Performance testing with real data

---

**Document Created:** 2026-01-16
