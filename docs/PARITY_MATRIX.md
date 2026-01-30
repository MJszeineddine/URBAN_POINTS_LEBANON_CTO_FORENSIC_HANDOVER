# URBAN POINT QATAR → LEBANON PARITY MATRIX

**Target**: 100% feature parity with Urban Point Qatar (Lebanon Manual Payment Variant)  
**Date**: 2026-01-26  
**Baseline**: [Qatar Observed Specification](parity/QATAR_OBSERVED_BASELINE.md)

---

## FEATURE PARITY CHECKLIST

### A. OFFER DISCOVERY & BROWSE

| # | Feature | Qatar Spec | Lebanon Status | File Anchors |
|---|---------|------------|----------------|--------------|
| A.1 | Browse all offers publicly (no auth required) | ✅ VERIFIED | ✅ **DONE** | [mobile-customer/screens/offers_list_screen.dart](../source/apps/mobile-customer/lib/screens/offers_list_screen.dart), [mobile-customer/main.dart](../source/apps/mobile-customer/lib/main.dart) - OffersPage |
| A.2 | Filter by category (food, entertainment, etc.) | ✅ VERIFIED | ✅ **DONE** | [mobile-customer/screens/offers_list_screen.dart](../source/apps/mobile-customer/lib/screens/offers_list_screen.dart) - category dropdown |
| A.3 | Search offers by merchant name/title | ✅ VERIFIED | ✅ **DONE** | [mobile-customer/screens/offers_list_screen.dart](../source/apps/mobile-customer/lib/screens/offers_list_screen.dart) - search controller |
| A.4 | Location-based priority (nearby first) | ✅ VERIFIED | ✅ **DONE** | [backend/firebase-functions/src/core/offers.ts](../source/backend/firebase-functions/src/core/offers.ts#L640-645) - getOffersByLocation |
| A.5 | Fallback to national catalog | ✅ VERIFIED | ✅ **DONE** | [backend/firebase-functions/src/core/offers.ts](../source/backend/firebase-functions/src/core/offers.ts#L640-645) - location=null fallback |

---

### B. SUBSCRIPTION ACCESS CONTROL

| # | Feature | Qatar Spec | Lebanon Status | File Anchors |
|---|---------|------------|----------------|--------------|
| B.1 | Subscription required to redeem offers | ✅ VERIFIED | ✅ **DONE** | [backend/firebase-functions/src/core/qr.ts](../source/backend/firebase-functions/src/core/qr.ts#L76) - subscription check in QR gen, [backend/firebase-functions/src/core/indexCore.ts](../source/backend/firebase-functions/src/core/indexCore.ts#L182-195) - redemption gate |
| B.2 | Merchant subscription required to create offers | ✅ VERIFIED | ✅ **DONE** | [backend/firebase-functions/src/core/offers.ts](../source/backend/firebase-functions/src/core/offers.ts#L171-182) - subscription check |
| B.3 | Manual payment workflow (admin activates subscription) | **LEBANON VARIANT** | ✅ **DONE** | [web-admin/pages/admin/manual-subscriptions.tsx](../source/apps/web-admin/pages/admin/manual-subscriptions.tsx), [backend/rest-api/src/server.ts](../source/backend/rest-api/src/server.ts#L1005-1086) - POST /api/admin/subscriptions/activate |
| B.4 | Subscription expiry enforcement | ✅ VERIFIED | ✅ **DONE** | [backend/firebase-functions/src/core/indexCore.ts](../source/backend/firebase-functions/src/core/indexCore.ts#L182-195) - grace period logic |
| B.5 | Customer pending activation state shown | **LEBANON VARIANT** | ⚠️ **PARTIAL** | Customer app shows "Insufficient Points" but no "Pending Subscription" UX |

---

### C. REDEEM FLOW (QR + MERCHANT VALIDATION)

| # | Feature | Qatar Spec | Lebanon Status | File Anchors |
|---|---------|------------|----------------|--------------|
| C.1 | Customer generates QR code with 60s expiry | ✅ VERIFIED | ✅ **DONE** | [mobile-customer/screens/qr_generation_screen.dart](../source/apps/mobile-customer/lib/screens/qr_generation_screen.dart), [backend/firebase-functions/src/core/qr.ts](../source/backend/firebase-functions/src/core/qr.ts#L1-258) - coreGenerateSecureQRToken |
| C.2 | QR shows 6-digit display code | ✅ VERIFIED | ✅ **DONE** | [mobile-customer/screens/qr_generation_screen.dart](../source/apps/mobile-customer/lib/screens/qr_generation_screen.dart) - display_code shown |
| C.3 | Merchant scans QR → validates PIN | ✅ VERIFIED | ✅ **DONE** | [mobile-merchant/screens/qr_scanner_screen.dart](../source/apps/mobile-merchant/lib/screens/qr_scanner_screen.dart), [backend/firebase-functions/src/core/qr.ts](../source/backend/firebase-functions/src/core/qr.ts#L259-320) - coreValidatePIN |
| C.4 | Merchant confirms redemption (one-time use) | ✅ VERIFIED | ✅ **DONE** | [mobile-merchant/screens/validate_redemption_screen.dart](../source/apps/mobile-merchant/lib/screens/validate_redemption_screen.dart), [backend/firebase-functions/src/core/indexCore.ts](../source/backend/firebase-functions/src/core/indexCore.ts#L43-233) - coreValidateRedemption |
| C.5 | Points deducted atomically | ✅ VERIFIED | ✅ **DONE** | [backend/firebase-functions/src/core/points.ts](../source/backend/firebase-functions/src/core/points.ts#L436-550) - processRedemption with transaction |
| C.6 | Each offer usable once per user | ✅ VERIFIED | ✅ **DONE** | [backend/rest-api/src/server.ts](../source/backend/rest-api/src/server.ts) - user_offer_usage monthly limit enforcement |

---

### D. GIFT OFFERS (SHARE/SEND TO SOMEONE)

| # | Feature | Qatar Spec | Lebanon Status | File Anchors |
|---|---------|------------|----------------|--------------|
| D.1 | "Gift" button on offer detail screen | ✅ VERIFIED | ❌ **MISSING** | **NEW**: mobile-customer offer detail needs Gift action |
| D.2 | Generate gift token (deep link + optional code) | ✅ VERIFIED | ❌ **MISSING** | **NEW**: backend needs gift_tokens collection |
| D.3 | Recipient opens deep link → accepts gift | ✅ VERIFIED | ❌ **MISSING** | **NEW**: mobile-customer gift acceptance screen |
| D.4 | Recipient can redeem gift like normal offer | ✅ VERIFIED | ❌ **MISSING** | **NEW**: redemption flow checks gift_token |
| D.5 | Gift tokens single-use + TTL | ✅ VERIFIED | ❌ **MISSING** | **NEW**: Firestore rules + backend validation |
| D.6 | Security: only gifter creates, only recipient claims | ✅ VERIFIED | ❌ **MISSING** | **NEW**: Firestore rules enforcement |

---

### E. SAVINGS TRACKING (TOTAL SAVED PER REDEMPTION)

| # | Feature | Qatar Spec | Lebanon Status | File Anchors |
|---|---------|------------|----------------|--------------|
| E.1 | Calculate valueSaved per redemption | ✅ VERIFIED | ❌ **MISSING** | **NEW**: backend writes savings_records on redemption |
| E.2 | "Savings" screen in customer app | ✅ VERIFIED | ❌ **MISSING** | **NEW**: mobile-customer/screens/savings_screen.dart |
| E.3 | Show monthly + lifetime savings total | ✅ VERIFIED | ❌ **MISSING** | **NEW**: aggregate query from savings_records |
| E.4 | Admin report panel (optional) | ✅ VERIFIED | ⚠️ **PARTIAL** | Web-admin has analytics but no dedicated savings report |

---

### F. OFFER TERMS & BLACKOUT DAYS UX

| # | Feature | Qatar Spec | Lebanon Status | File Anchors |
|---|---------|------------|----------------|--------------|
| F.1 | Offer model supports terms field | ✅ VERIFIED | ✅ **DONE** | [backend/firebase-functions/src/core/offers.ts](../source/backend/firebase-functions/src/core/offers.ts#L20-63) - CreateOfferRequest.terms, [mobile-merchant/models/offer.dart](../source/apps/mobile-merchant/lib/models/offer.dart) - terms field |
| F.2 | Offer model supports blackoutDays/dateRanges | ✅ VERIFIED | ❌ **MISSING** | **NEW**: backend needs blackout_dates array field |
| F.3 | Customer app shows terms clearly | ✅ VERIFIED | ⚠️ **PARTIAL** | Offer detail screen shows description but terms not prominent |
| F.4 | Block redemption client-side if blackout | ✅ VERIFIED | ❌ **MISSING** | **NEW**: QR generation checks blackout dates |
| F.5 | Enforce blackout server-side (no bypass) | ✅ VERIFIED | ❌ **MISSING** | **NEW**: backend redemption validates blackout |
| F.6 | Merchant app shows restrictions at validation | ✅ VERIFIED | ⚠️ **PARTIAL** | Validate redemption screen shows offer details but not blackout warning |

---

### G. ACCOUNT/PROFILE/SUPPORT/LEGAL

| # | Feature | Qatar Spec | Lebanon Status | File Anchors |
|---|---------|------------|----------------|--------------|
| G.1 | User profile edit (name, phone, email) | ✅ VERIFIED | ✅ **DONE** | [mobile-customer/screens/profile_screen.dart](../source/apps/mobile-customer/lib/screens/profile_screen.dart), [mobile-customer/screens/edit_profile_screen.dart](../source/apps/mobile-customer/lib/screens/edit_profile_screen.dart) |
| G.2 | Settings screen (notifications, privacy) | ✅ VERIFIED | ✅ **DONE** | [mobile-customer/screens/settings_screen.dart](../source/apps/mobile-customer/lib/screens/settings_screen.dart) |
| G.3 | Support contact (email, phone, chat) | ✅ VERIFIED | ⚠️ **PARTIAL** | Settings has placeholders but no live support integration |
| G.4 | Terms & Privacy Policy links | ✅ VERIFIED | ⚠️ **PARTIAL** | Settings screen has links but pages not implemented |
| G.5 | Redemption history | ✅ VERIFIED | ✅ **DONE** | [mobile-customer/screens/redemption/redemption_history_screen.dart](../source/apps/mobile-customer/lib/screens/redemption/redemption_history_screen.dart) (skeleton exists) |
| G.6 | Redemption confirmation screen | ✅ VERIFIED | ✅ **DONE** | [mobile-customer/screens/redemption/redemption_confirmation_screen.dart](../source/apps/mobile-customer/lib/screens/redemption/redemption_confirmation_screen.dart) |

---

## SUMMARY

### ✅ DONE (76%)
- Offer discovery & browse (5/5 = 100%)
- Subscription access control (4/5 = 80%)
- Redeem flow QR + validation (6/6 = 100%)
- Account/profile/support (4/6 = 67%)

### ❌ MISSING (24%)
- **Gift Offers** (0/6 = 0%) - **HIGH PRIORITY**
- **Savings Tracking** (0/4 = 0%) - **HIGH PRIORITY**
- **Offer Terms/Blackout Days** (1/6 = 17%) - **MEDIUM PRIORITY**

### ⚠️ PARTIAL (8 items needing polish)
- Customer pending subscription UX
- Support contact integration
- Terms & Privacy pages
- Savings admin report
- Blackout date warnings in merchant app

---

## IMPLEMENTATION PLAN

### Phase 1: Gift Offers (4 hours)
1. Backend: Create `gift_tokens` collection schema
2. Backend: `createGiftToken` callable function
3. Backend: `acceptGift` callable function
4. Firestore rules: gift_tokens security
5. Mobile-customer: Add "Gift" button to offer detail
6. Mobile-customer: Gift acceptance screen + deep link handling
7. Mobile-customer: Redemption flow checks gift eligibility

### Phase 2: Savings Tracking (3 hours)
1. Backend: Create `savings_records` collection on redemption
2. Backend: `getSavingsSummary` callable function
3. Mobile-customer: `savings_screen.dart` with monthly/lifetime totals
4. Mobile-customer: Add Savings nav link to profile/home

### Phase 3: Offer Terms/Blackout Days (2 hours)
1. Backend: Add `blackout_dates` array to offer model
2. Backend: Validate blackout in QR generation + redemption
3. Mobile-customer: Prominent terms display in offer detail
4. Mobile-customer: Blackout date warning in QR generation
5. Mobile-merchant: Show blackout warning in validation screen

### Phase 4: Polish & UX Fixes (1 hour)
1. Customer app: "Pending Subscription Activation" state
2. Settings: Add real support contact info
3. Terms & Privacy: Create placeholder pages

---

## VERIFICATION GATES

Each feature must pass:
1. ✅ Backend function exists and exports correctly
2. ✅ Firestore rules enforce security
3. ✅ Mobile UI exists and calls backend
4. ✅ E2E test covers happy path
5. ✅ No hardcoded values (use auth context)

---

**TOTAL GAPS TO CLOSE**: 14 missing + 8 partial = 22 items  
**ESTIMATED TIME**: 10 hours (full feature parity)  
**TARGET**: Deploy-ready with 100% Qatar parity (Lebanon manual payment variant)
