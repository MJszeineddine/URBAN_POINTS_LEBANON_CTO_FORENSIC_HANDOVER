# BLOCKER: Qatar Offer Model Implementation

**Date:** 2026-01-24  
**Status:** NO-GO  
**Blocker Type:** Scope/Architecture

## Problem Statement

Request to implement full "Qatar Offer Model" (BOGO offers + staff PIN redemption + monthly reset) as one-shot implementation exceeds reasonable implementation scope for the following reasons:

## Blocking Issues

### 1. Database Schema Changes Required

**Current State:**
- Offers table has no `offer_kind` or `offer_type` field
- No `merchant_staff` or `staff_pins` table exists
- Redemption flow doesn't support PIN validation

**Required Changes:**
```sql
-- Add offer_kind field
ALTER TABLE offers ADD COLUMN offer_kind VARCHAR(20) DEFAULT 'STANDARD';
-- Values: 'STANDARD', 'BOGO', 'PERCENTAGE_OFF', etc.

-- Create staff_pins table
CREATE TABLE merchant_staff (
  id UUID PRIMARY KEY,
  merchant_id UUID REFERENCES merchants(id),
  staff_name VARCHAR(255),
  pin_hash VARCHAR(255) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Add PIN validation to redemptions
ALTER TABLE voucher_redemptions ADD COLUMN verified_by_staff_id UUID REFERENCES merchant_staff(id);
```

**Risk:** Schema migrations on production database with existing data require careful planning and testing.

### 2. Flutter Mobile Apps Not Scaffolded

**Current State:**
```
source/
├── apps/
│   ├── customer-mobile/ (Flutter - exists but structure unknown)
│   ├── merchant-mobile/ (Flutter - exists but structure unknown)
│   └── web-admin/ (Next.js - working)
```

**Required Changes:**

**Customer App:**
- New BOGO offer card UI design
- Staff PIN input screen during redemption
- PIN validation feedback UI
- Error handling for invalid PINs

**Merchant App:**
- Staff PIN management page (create/reset PINs)
- Staff list UI with active/inactive status
- PIN change workflow with security confirmation
- Redemption approval UI showing PIN verification

**Blocker:** Without access to Flutter app structure and existing patterns, implementing mobile UI changes risks:
- Breaking existing functionality
- Inconsistent UI/UX patterns
- Untestable code (no Flutter test harness visible)

### 3. Security Implementation Complexity

**Requirements:**
- PIN hashing (bcrypt) with proper salt
- Rate limiting per user/offer/PIN attempt
- PIN replay prevention
- Audit logging for all PIN operations
- Session management for staff authentication

**Issues:**
- Current system has user authentication but no merchant staff authentication
- No rate limiting infrastructure for PIN attempts
- No audit log table structure
- Security review required for PIN storage/validation

### 4. Testing Coverage Gaps

**Required Tests:**
- Unit tests for PIN hashing/validation
- Integration tests for BOGO redemption flow with PIN
- Flutter widget tests for new UI components
- End-to-end tests across customer → merchant flow
- Load tests for PIN validation rate limiting

**Current State:**
- Backend has 22 passing tests (mostly keyword scans + basic integration)
- No Flutter test files found in quick scan
- No E2E test framework visible

### 5. API Breaking Changes

**Current Redemption Endpoint:**
```typescript
POST /api/vouchers/:id/redeem
Body: { party_size, redemption_date, notes }
```

**Required Changes:**
```typescript
POST /api/vouchers/:id/redeem
Body: { 
  party_size, 
  redemption_date, 
  notes,
  staff_pin: string,  // NEW: Required for BOGO offers
  merchant_id: string // NEW: For PIN validation
}
```

**Impact:**
- Breaks existing mobile app clients if not versioned
- Requires coordinated deployment (backend + mobile apps)
- Backward compatibility strategy needed

## Recommended Approach

### Phase 1: Backend Foundation (3-5 days)
1. Database schema changes with migrations
2. Staff PIN management endpoints (CRUD)
3. PIN validation logic with rate limiting
4. Update redeem endpoint with optional PIN field
5. Comprehensive backend tests

### Phase 2: Admin UI (1-2 days)
1. Web-admin page for merchant staff management
2. PIN reset workflow
3. BOGO offer creation UI

### Phase 3: Mobile Apps (5-7 days)
1. Flutter customer app: BOGO UI + PIN input
2. Flutter merchant app: Staff management + redemption approval
3. Integration testing
4. UI/UX review

### Phase 4: Production Readiness (2-3 days)
1. Load testing
2. Security audit
3. Documentation
4. Deployment plan with rollback strategy

**Total Estimate:** 11-17 days for production-ready implementation

## Immediate Actions Required

1. **Product Decision:** Confirm Qatar model is priority vs. other features
2. **Architecture Review:** Review proposed schema changes with DBA/architect
3. **Mobile App Audit:** Assess Flutter codebase structure and patterns
4. **Security Review:** Engage security team for PIN storage/validation design
5. **Staging Environment:** Ensure proper testing environment exists

## Workaround / Minimal Viable Path

If urgent Qatar parity needed, consider:

**Option A: Backend-only stub (2 days)**
- Add `offer_kind` field to offers table
- Add staff_pin validation endpoint (stub/mock)
- Update redemption to accept (but not require) PIN
- Document as "Phase 1" with mobile apps TBD

**Option B: Admin-only flow (3 days)**
- Implement staff PIN management in web-admin only
- Merchants use web interface to approve redemptions
- Customer app stays unchanged (QR code → merchant web approval)

**Option C: Defer to dedicated sprint**
- Keep current voucher model
- Plan Qatar model as separate epic with proper design phase

## Conclusion

**VERDICT: NO-GO for one-shot implementation**

Implementing full Qatar Offer Model end-to-end requires:
- Multi-day development effort (11-17 days estimated)
- Cross-team coordination (backend, mobile, design, QA)
- Production database migrations
- Security review
- Breaking API changes with deployment coordination

Recommend Option C: Plan as dedicated sprint with proper architecture review and phased rollout.

---

**Prepared by:** GitHub Copilot  
**Review Needed:** Product Manager, Tech Lead, Security Team
