# BLOCKER — ADMIN-ANALYTICS-001, ADMIN-ANALYTICS-002, ADMIN-FRAUD-001

**Requirements**:
- ADMIN-ANALYTICS-001: Daily Stats Dashboard (mock data issue)
- ADMIN-ANALYTICS-002: Redemption Audit Logs (missing audit trail details)
- ADMIN-FRAUD-001: Fraud Detection Dashboard (no UI)

**Status:** BLOCKED  
**Category:** Admin Dashboard Features  

---

## Why BLOCKED

### ADMIN-ANALYTICS-001
Dashboard contains mock/placeholder data. Real data aggregation requires:
- Real Firestore queries for redemptions, signups, active offers
- Performance optimization and caching
- Data validation and accuracy testing

### ADMIN-ANALYTICS-002
Audit logs missing critical details (IP, device, geo, fraud score). Implementation requires:
- Enhanced logging in redemption backend callable
- Audit collection schema redesign
- UI columns for all audit fields

### ADMIN-FRAUD-001
No fraud detection UI exists. Implementation requires:
- Fraud alerts dashboard with flagged users/redemptions
- Real-time or batch fraud scoring display
- Actions UI (lock user, pause merchant, etc.)

All three require substantial **dashboard UI development** and **backend enhancement**.

## Evidence Required

### ADMIN-ANALYTICS-001
- ✅ Mock data removed from `calculateDailyStats`
- ✅ Real Firestore queries implemented
- ✅ Dashboard displays accurate real data
- ✅ Query performance acceptable

### ADMIN-ANALYTICS-002
- ✅ Audit trail includes IP, device, geo, fraud score
- ✅ UI displays all audit fields in table
- ✅ Filtering by audit criteria works
- ✅ Export functionality

### ADMIN-FRAUD-001
- ✅ Fraud detection UI shows alerts
- ✅ Flagged users/redemptions displayed
- ✅ Admin can take actions (lock, pause)
- ✅ Integration with backend fraud detection

## Next Steps

1. Remove mock data from analytics
2. Design comprehensive audit trail schema
3. Build fraud detection dashboard UI
4. Implement real-time or batch fraud scoring display
5. Test with production-like data volumes

---

**Document Created:** 2026-01-16
